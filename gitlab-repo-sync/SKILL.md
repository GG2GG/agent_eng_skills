---
name: gitlab-repo-sync
description: Clone every accessible self-hosted GitLab repo into a consistent local mirror (`~/Sync/agentic/gitlab-repos/`), preserving group/namespace structure, and keep them current on a 3-hour cron. Use when asked to "mirror my GitLab repos locally", "clone all my GitLab projects", "keep my local repos up to date", or to bootstrap a workstation's local copy of a self-hosted GitLab. Targets any self-hosted GitLab — set `GITLAB_SYNC_HOST` to point at yours.
---

# gitlab-repo-sync

Keep a complete, current local mirror of every GitLab repo you can reach — one command, then a cron.

This skill targets any self-hosted GitLab. Set `GITLAB_SYNC_HOST` to your instance (for example `gitlab.example.com`). It enumerates every project your token has membership on and clones each into a local tree that mirrors the GitLab group path, then fast-forwards them on a schedule.

## Destination convention

| Source | Host | Local root |
|---|---|---|
| **Self-hosted GitLab** | `$GITLAB_SYNC_HOST` | `~/Sync/agentic/gitlab-repos/` |
| **GitLab.com** (private repos over SSH) | `gitlab.com` | `~/Sync/agentic/app-repos/` (separate tooling) |

A project at `competitive-intelligence/competitor-product-surface` lands at
`~/Sync/agentic/gitlab-repos/competitive-intelligence/competitor-product-surface`.

This skill ships the self-hosted GitLab side. The `app-repos/` (gitlab.com) mirror is a
separate concern — gitlab.com clones go over SSH (`git@gitlab.com:…`, HTTPS
fails on private repos), so it needs its own token + transport. See "GitLab.com
counterpart" below.

## What it does

`scripts/gitlab-repo-sync.sh`:

1. Reads `SELF_HOSTED_GITLAB_TOKEN` from the environment or a single line of the project `.env` (never `source`s it).
2. Validates the token against `GET /api/v4/user`; bails clearly if the host is unreachable or the token is dead.
3. Enumerates every accessible project via `GET /api/v4/projects?membership=true` (paginated, archived excluded by default).
4. For each repo: **clones** if missing, otherwise **fetches + fast-forwards** — but only when the working tree is clean, so local edits are never clobbered. Dirty repos are fetched (so refs are current) but not pulled.
5. Prints a status summary (cloned / updated / fetched / failed).

It is idempotent and safe to re-run any time.

## Run it manually

```bash
# point it at your GitLab host + token, then sync everything you can access
export GITLAB_SYNC_HOST=gitlab.example.com
export SELF_HOSTED_GITLAB_TOKEN=glpat-…       # or GITLAB_SYNC_TOKEN
bash scripts/gitlab-repo-sync.sh

# quick test against a throwaway dir (first 3 repos only)
GITLAB_SYNC_LIMIT=3 GITLAB_SYNC_DEST=/tmp/gitlab-test bash scripts/gitlab-repo-sync.sh
```

The token is resolved in this order: `GITLAB_SYNC_TOKEN` → `SELF_HOSTED_GITLAB_TOKEN` (environment) → the `SELF_HOSTED_GITLAB_TOKEN=` line of `GITLAB_SYNC_ENV_FILE`. Export the token and you need no `.env` file at all.

### Config (env vars)

| Var | Default | Purpose |
|---|---|---|
| `GITLAB_SYNC_HOST` | — (required) | Your self-hosted GitLab host (e.g. `gitlab.example.com`) |
| `SELF_HOSTED_GITLAB_TOKEN` / `GITLAB_SYNC_TOKEN` | — (required) | API token with `api` + `read_repository` scopes |
| `AGENTIC_HOME` | `~/agentic` | Workspace root that the other paths derive from |
| `GITLAB_SYNC_DEST` | `$AGENTIC_HOME/gitlab-repos` | Local mirror root |
| `GITLAB_SYNC_ENV_FILE` | `$AGENTIC_HOME/.env` | Token file, read only if no token in env |
| `GITLAB_SYNC_JOBS` | `6` | Parallel git operations |
| `GITLAB_SYNC_INCLUDE_ARCHIVED` | `0` | Set `1` to also mirror archived repos |
| `GITLAB_SYNC_LIMIT` | `0` | Cap repo count (0 = no cap); for testing/partial runs |

> The launchd installer auto-detects the SyncThing layout (`~/Sync/agentic`) when present and pins it into the cron, so an existing mirror there keeps working without any manual config.

## Install the 3-hour cron

macOS launchd job:

```bash
bash scripts/install_launchd.sh
# then trigger an immediate first full clone:
launchctl kickstart -k gui/$(id -u)/local.agentic.gitlab-repo-sync
```

- Runs every 3 hours (`StartInterval` 10800s).
- Logs to `~/Library/Logs/gitlab-repo-sync/{stdout,stderr}.log`.
- Re-running the installer cleanly reloads the agent.
- **Token for the cron:** launchd jobs have no shell environment, so an exported token isn't visible to the scheduled run. The installer resolves a token *file* (`$GITLAB_SYNC_ENV_FILE` if set, else `$WORKSPACE/.env`) containing `SELF_HOSTED_GITLAB_TOKEN=` and pins it into the plist as `GITLAB_SYNC_ENV_FILE`. If none is found it installs anyway and prints a warning telling you which file to create.

To remove it:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/local.agentic.gitlab-repo-sync.plist
rm ~/Library/LaunchAgents/local.agentic.gitlab-repo-sync.plist
```

A plain crontab equivalent, if you prefer cron over launchd:

```
0 */3 * * * /bin/bash /ABSOLUTE/PATH/gitlab-repo-sync.sh >> $HOME/Library/Logs/gitlab-repo-sync/cron.log 2>&1
```

## Security model

- The token is read from **one line** of `.env` — the whole file is never `source`d.
- The token reaches git via `GIT_ASKPASS`, so it is **never written to `.git/config`** and **never appears in argv / `ps`**. The `/user` pre-check and project enumeration read it from the environment via python `urllib` (not a `curl -H` argv).
- Clone/fetch run with `-c credential.helper=`, so the token is **never cached** into the macOS Keychain or any global credential helper.
- Clones use token-less remotes (`https://oauth2@$GITLAB_SYNC_HOST/<path>.git`). An existing repo's `origin` is normalised to this form **only when it already points at the same GitLab host** — a foreign `origin` is reported as `remote-mismatch-skip` and left untouched.
- If your GitLab instance is reachable only over a VPN, the job is a no-op (clean failure) when off-VPN.

## GitLab.com counterpart (app-repos/)

The same enumerate-and-mirror shape works for gitlab.com → `~/Sync/agentic/app-repos/`, but the transport differs: gitlab.com private repos clone over **SSH** (`git@gitlab.com:<your-org>/…`), not token-HTTPS. That variant is intentionally **not** wired into this script — it needs a gitlab.com PAT for enumeration and a working SSH key for clones. Track it as a sibling `app-repo-sync` if/when needed.
