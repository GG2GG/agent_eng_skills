#!/usr/bin/env bash
#
# gitlab-repo-sync.sh — clone (and keep up to date) every GitLab repo the
# token holder can access, into a consistent local mirror that preserves
# the GitLab group/namespace structure.
#
#   GitLab (<your-gitlab-host>) -> $AGENTIC_HOME/gitlab-repos/
#   GitLab (gitlab.com / <your-org>)          -> $AGENTIC_HOME/app-repos/  (separate tooling)
#
# Idempotent: missing repos are cloned, existing ones are fetched + fast-
# forwarded (only when the working tree is clean — local work is never
# clobbered). Safe to run on a cron every few hours. Targets bash 3.2 (the
# macOS system shell), so no EXIT traps in background subshells, no `wait -n`.
#
# Security model:
#   - The token comes from the environment, or from a single line of an .env
#     file (never `source`d — only one variable is grepped out).
#   - The token reaches git via GIT_ASKPASS, so it is never written to
#     .git/config and never appears in argv / `ps`. The /user pre-check and
#     project enumeration read it from the environment (python urllib), not a
#     curl -H argv. Clone/fetch run with `credential.helper=` so the token is
#     never cached into the macOS Keychain or any global helper.
#   - Existing remotes are normalised to token-less HTTPS only when they
#     already point at this GitLab host; a foreign origin is left untouched.
#
# Token (first match wins):
#   GITLAB_SYNC_TOKEN  or  SELF_HOSTED_GITLAB_TOKEN  exported in the environment
#   …otherwise   SELF_HOSTED_GITLAB_TOKEN=  is read from one line of GITLAB_SYNC_ENV_FILE.
#
# Config (all overridable via env):
#   AGENTIC_HOME  workspace root (default: $HOME/agentic)
#   GITLAB_SYNC_HOST       default: <your-gitlab-host>
#   GITLAB_SYNC_DEST       default: $AGENTIC_HOME/gitlab-repos
#   GITLAB_SYNC_ENV_FILE   default: $AGENTIC_HOME/.env  (only read if no token in env)
#   GITLAB_SYNC_JOBS       default: 6   (parallel git operations; positive integer)
#   GITLAB_SYNC_INCLUDE_ARCHIVED   set to 1 to also mirror archived repos
#   GITLAB_SYNC_LIMIT      cap number of repos processed (0 = no cap; for testing)
#
set -euo pipefail

WORKSPACE="${AGENTIC_HOME:-$HOME/agentic}"
GITLAB_HOST="${GITLAB_SYNC_HOST:-<your-gitlab-host>}"
DEST_ROOT="${GITLAB_SYNC_DEST:-$WORKSPACE/gitlab-repos}"
ENV_FILE="${GITLAB_SYNC_ENV_FILE:-$WORKSPACE/.env}"
JOBS="${GITLAB_SYNC_JOBS:-6}"
INCLUDE_ARCHIVED="${GITLAB_SYNC_INCLUDE_ARCHIVED:-0}"
LIMIT="${GITLAB_SYNC_LIMIT:-0}"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
die() { log "FATAL: $*" >&2; exit 1; }

# --- validate JOBS is a positive integer (avoids arithmetic abort below) -----
case "$JOBS" in ''|*[!0-9]*) die "GITLAB_SYNC_JOBS must be a positive integer (got: '$JOBS')";; esac
[ "$JOBS" -ge 1 ] || die "GITLAB_SYNC_JOBS must be >= 1 (got: $JOBS)"

# --- token: env first, then one line of the .env (never source it) -----------
GITLAB_SYNC_TOKEN="${GITLAB_SYNC_TOKEN:-${SELF_HOSTED_GITLAB_TOKEN:-}}"
if [ -z "$GITLAB_SYNC_TOKEN" ] && [ -f "$ENV_FILE" ]; then
  # grep||true keeps the pipeline alive under pipefail when the line is absent;
  # sed strips a trailing " # comment" and surrounding whitespace; tr drops quotes/CR.
  GITLAB_SYNC_TOKEN="$( { grep -E '^SELF_HOSTED_GITLAB_TOKEN=' "$ENV_FILE" || true; } \
                  | head -1 | sed -E 's/^[^=]*=//; s/[[:space:]]+#.*$//; s/^[[:space:]]*//; s/[[:space:]]*$//' \
                  | tr -d '"'"'"'\r' )"
fi
[ -n "$GITLAB_SYNC_TOKEN" ] || die "no token: export SELF_HOSTED_GITLAB_TOKEN (or GITLAB_SYNC_TOKEN), or put it in $ENV_FILE"
export GITLAB_SYNC_TOKEN

command -v git >/dev/null     || die "git not found on PATH"
command -v python3 >/dev/null || die "python3 not found on PATH"

API="https://${GITLAB_HOST}/api/v4"

# --- validate token (python urllib — token via env, never in argv) -----------
WHOAMI="$(GITLAB_API="$API" python3 - <<'PY' 2>/dev/null || true
import os, sys, json, urllib.request
req = urllib.request.Request(os.environ["GITLAB_API"] + "/user",
                             headers={"PRIVATE-TOKEN": os.environ["GITLAB_SYNC_TOKEN"]})
try:
    with urllib.request.urlopen(req, timeout=30) as r:
        sys.stdout.write(json.load(r).get("username", ""))
except Exception:
    pass
PY
)"
[ -n "$WHOAMI" ] || die "token rejected by ${API}/user (check your VPN connectivity + token validity)"
log "authenticated to ${GITLAB_HOST} as ${WHOAMI}"

# --- GIT_ASKPASS: feed the token without persisting it -----------------------
ASKPASS="$(mktemp -t gitlab-askpass.XXXXXX)"
cat >"$ASKPASS" <<'ASK'
#!/usr/bin/env bash
case "$1" in
  Username*) printf 'oauth2' ;;
  *)         printf '%s' "${GITLAB_SYNC_TOKEN}" ;;
esac
ASK
chmod 700 "$ASKPASS"
PROJLIST="$(mktemp -t gitlab-projects.XXXXXX)"
RESULTS="$(mktemp -t gitlab-results.XXXXXX)"
trap 'rm -f "$ASKPASS" "$PROJLIST" "$RESULTS"' EXIT

export GIT_ASKPASS="$ASKPASS" GIT_TERMINAL_PROMPT=0
# Applied to every authenticated git op: no credential caching (keeps the token
# out of the Keychain), plus a low-speed timeout so one hung connection can't
# stall its batch forever. Intentionally word-split, so leave unquoted.
GIT_SAFE="-c credential.helper= -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=60"

# --- enumerate accessible projects (paginated) -------------------------------
log "enumerating accessible projects (archived=${INCLUDE_ARCHIVED})…"
GITLAB_API="$API" INCLUDE_ARCHIVED="$INCLUDE_ARCHIVED" LIMIT="$LIMIT" python3 - "$PROJLIST" <<'PY'
import os, sys, json, urllib.request, urllib.parse
api   = os.environ["GITLAB_API"]
token = os.environ["GITLAB_SYNC_TOKEN"]
incl  = os.environ.get("INCLUDE_ARCHIVED", "0") == "1"
limit = int(os.environ.get("LIMIT", "0") or "0")
out   = open(sys.argv[1], "w")
page, n = 1, 0
while True:
    qs = {"membership": "true", "simple": "true", "per_page": "100", "page": str(page)}
    if not incl:
        qs["archived"] = "false"
    req = urllib.request.Request(f"{api}/projects?" + urllib.parse.urlencode(qs),
                                 headers={"PRIVATE-TOKEN": token})
    with urllib.request.urlopen(req, timeout=60) as r:
        batch = json.load(r)
    for p in batch:
        out.write(p["path_with_namespace"] + "\n"); n += 1
        if limit and n >= limit:
            break
    if (limit and n >= limit) or len(batch) < 100:
        break
    page += 1
out.close()
sys.stderr.write(f"  {n} projects\n")
PY
TOTAL="$(wc -l < "$PROJLIST" | tr -d ' ')"
[ "$TOTAL" -gt 0 ] || die "no accessible projects returned"
mkdir -p "$DEST_ROOT"

# --- per-repo worker (runs in a background subshell) -------------------------
# Body runs as the LHS of `|| true`, which suspends set -e for everything inside
# it — so a mid-flight failure (e.g. mkdir) can never skip the result line. The
# final printf ALWAYS runs (bash 3.2 won't fire EXIT traps in bg subshells, so
# we must not rely on a trap here). st defaults to CRASHED.
handle_repo() {
  local path="$1"
  local dest="$DEST_ROOT/$path"
  local url="https://oauth2@${GITLAB_HOST}/${path}.git"
  local st="CRASHED"
  {
    if [ -d "$dest/.git" ]; then
      local cur ok=1
      cur="$(git -C "$dest" remote get-url origin 2>/dev/null || true)"
      case "$cur" in
        "$url") : ;;
        "")     git -C "$dest" remote add origin "$url" 2>/dev/null \
                  || git -C "$dest" remote set-url origin "$url" 2>/dev/null || true ;;
        *"@${GITLAB_HOST}/"*|*"//${GITLAB_HOST}/"*|*"${GITLAB_HOST}:"*)
                git -C "$dest" remote set-url origin "$url" 2>/dev/null || true ;;  # same host: scrub token
        *)      st="remote-mismatch-skip"; ok=0 ;;                                  # foreign origin: leave it
      esac
      if [ "$ok" = 1 ]; then
        if ! git $GIT_SAFE -C "$dest" fetch --prune --quiet origin 2>/dev/null; then
          st="fetch-FAILED"
        elif [ -n "$(git -C "$dest" status --porcelain 2>/dev/null)" ]; then
          st="fetched(dirty-skip-pull)"
        elif git -C "$dest" rev-parse --verify --quiet '@{u}' >/dev/null 2>&1; then
          if git -C "$dest" merge --ff-only --quiet '@{u}' 2>/dev/null; then st="updated"; else st="fetched(no-ff)"; fi
        else
          st="fetched(no-upstream)"
        fi
      fi
    else
      mkdir -p "$(dirname "$dest")"
      if git $GIT_SAFE clone --quiet "$url" "$dest" 2>/dev/null; then st="cloned"; else st="clone-FAILED"; fi
    fi
  } 2>/dev/null || true
  printf '%s\t%s\n' "$st" "$path" >> "$RESULTS"
}

# --- bounded-parallel sweep (portable: works on bash 3.2) --------------------
log "syncing ${TOTAL} repos into ${DEST_ROOT} (${JOBS} parallel)…"
i=0
while IFS= read -r path; do
  [ -n "$path" ] || continue
  handle_repo "$path" &
  i=$((i + 1))
  if [ $((i % JOBS)) -eq 0 ]; then wait; fi
done < "$PROJLIST"
wait

# --- summary -----------------------------------------------------------------
log "----- summary -----"
sort "$RESULTS" | awk -F'\t' '{c[$1]++} END {for (k in c) printf "  %-26s %d\n", k, c[k]}' | sort
PROCESSED="$(wc -l < "$RESULTS" | tr -d ' ')"
FAILED="$(grep -cE '^(clone-FAILED|fetch-FAILED|CRASHED)' "$RESULTS" || true)"
log "done: ${PROCESSED}/${TOTAL} repos reported, ${FAILED} failures"
[ "$PROCESSED" -eq "$TOTAL" ] || log "WARNING: ${TOTAL} enumerated but only ${PROCESSED} reported"
if [ "${FAILED:-0}" -gt 0 ]; then
  log "failed repos:"; grep -E '^(clone-FAILED|fetch-FAILED|CRASHED)' "$RESULTS" | sed 's/^/  /'
fi
{ [ "${FAILED:-0}" -eq 0 ] && [ "$PROCESSED" -eq "$TOTAL" ]; } || exit 1
exit 0
