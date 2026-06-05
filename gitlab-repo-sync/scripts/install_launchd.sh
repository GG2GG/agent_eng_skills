#!/usr/bin/env bash
# Install the gitlab-repo-sync launchd job (runs every 3 hours).
# Idempotent: re-running reinstalls/reloads the agent cleanly.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
TEMPLATE="$SCRIPT_DIR/local.agentic.gitlab-repo-sync.plist.template"
LABEL="local.agentic.gitlab-repo-sync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs/gitlab-repo-sync"

# Workspace root the cron mirrors into. Honour an explicit override, else
# auto-detect the SyncThing layout (~/Sync/agentic), else plain
# ~/agentic — so the cron is deterministic regardless of host.
if [ -n "${AGENTIC_HOME:-}" ]; then
  WORKSPACE="$AGENTIC_HOME"
elif [ -d "$HOME/Sync/agentic" ]; then
  WORKSPACE="$HOME/Sync/agentic"
else
  WORKSPACE="$HOME/agentic"
fi

# launchd jobs have no shell environment, so the scheduled run cannot see a
# token you exported in this shell. Pin a token *file* into the plist. Prefer an
# explicit override, then the workspace .env, then a sibling personal-ops/.env.
ENV_FILE=""
for cand in "${GITLAB_SYNC_ENV_FILE:-}" "$WORKSPACE/.env" "$WORKSPACE/personal-ops/.env"; do
  if [ -n "$cand" ] && [ -f "$cand" ] && grep -qE '^SELF_HOSTED_GITLAB_TOKEN=' "$cand"; then
    ENV_FILE="$cand"; break
  fi
done
if [ -z "$ENV_FILE" ]; then
  ENV_FILE="$WORKSPACE/.env"
  echo "WARNING: no token file containing SELF_HOSTED_GITLAB_TOKEN was found." >&2
  echo "  The scheduled job will FAIL to authenticate until you create:" >&2
  echo "    $ENV_FILE   (a line:  SELF_HOSTED_GITLAB_TOKEN=glpat-...)" >&2
fi

mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"
chmod +x "$SCRIPT_DIR/gitlab-repo-sync.sh"

python3 - "$TEMPLATE" "$PLIST" "$REPO_ROOT" "$HOME" "$WORKSPACE" "$ENV_FILE" <<'PY'
import sys
from pathlib import Path
from xml.sax.saxutils import escape
template, output = Path(sys.argv[1]), Path(sys.argv[2])
repo_root, home, workspace, env_file = sys.argv[3:7]
text = template.read_text(encoding="utf-8")
for marker, value in (("__REPO_ROOT__", repo_root), ("__HOME__", home),
                      ("__WORKSPACE__", workspace), ("__ENV_FILE__", env_file)):
    text = text.replace(marker, escape(value))   # XML-escape & < > in paths
output.write_text(text, encoding="utf-8")
PY

plutil -lint "$PLIST" >/dev/null
launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl enable "gui/$(id -u)/$LABEL"

echo "Installed: $PLIST"
echo "Token file for the cron: $ENV_FILE"
echo "Runs every 3 hours. Logs: $LOG_DIR/{stdout,stderr}.log"
echo "Run an immediate first sync with:"
echo "  launchctl kickstart -k gui/$(id -u)/$LABEL"
