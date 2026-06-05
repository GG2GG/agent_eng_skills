#!/usr/bin/env bash
# allocate-ports.sh — emit a deterministic, collision-free port block for an
# SDLC-protocol bead, to be written into the bead's .env.local (NEVER .env,
# which AO symlinks into every worktree).
#
# Usage:   allocate-ports.sh <bead-index> [repo-slug]
# Example: allocate-ports.sh 1 invoicing  >> .env.local
#
# Scheme:  Base = 32000 + index*100   (well clear of AO's 3000/3010/14800/14801)
#          Each bead owns a 100-port block, so up to ~600 beads never collide.
set -euo pipefail

IDX="${1:-}"
REPO="${2:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo app)")}"

if ! [[ "$IDX" =~ ^[0-9]+$ ]] || (( IDX < 1 )); then
  echo "usage: allocate-ports.sh <bead-index>=1..600 [repo-slug]" >&2
  exit 1
fi
if (( IDX > 600 )); then
  echo "bead-index $IDX out of range (max 600 before the block reaches reserved ports)" >&2
  exit 1
fi

BASE=$(( 32000 + IDX * 100 ))
NN=$(printf '%02d' "$IDX")

cat <<EOF
# --- SDLC bead-${NN} port block (from allocate-ports.sh; write to .env.local) ---
APP_PORT=$(( BASE + 0 ))
API_PORT=$(( BASE + 1 ))
TEST_PORT=$(( BASE + 2 ))
DB_PORT=$(( BASE + 32 ))
REDIS_PORT=$(( BASE + 79 ))
DB_NAME=${REPO}_bead_${NN}
COMPOSE_PROJECT_NAME=${REPO}-bead-${NN}
REDIS_NAMESPACE=${REPO}:bead${NN}
# Read ports from env; never hardcode. Tear down servers/containers before reporting done.
EOF
