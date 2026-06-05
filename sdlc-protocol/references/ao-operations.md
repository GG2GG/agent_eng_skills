# AO operations — dispatch, ports, footguns, debugging

## Dispatching beads

AO gives every session its own real git worktree (`workspace: worktree` in `agent-orchestrator.yaml`). Two dispatch paths:

```bash
# Prompt-driven (fastest): inject the whole bead spec as the prompt.
ao spawn --prompt "$(cat .sdlc/beads/bead-01-invoice-api.md)"

# Issue-driven (preferred when you want tracked artifacts + PR linkage):
# create one issue per bead (GitLab / Linear / bd), then:
ao batch-spawn 1421 1422 1423 1424     # built-in duplicate detection
```

`ao spawn` flags are limited: `--prompt`, `--agent`, `--open`, `--claim-pr`, `--assign-on-github`. **There is no `--env` flag** — per-bead environment (ports, DB names) is delivered *inside the bead spec*, which instructs the agent to write its own `.env.local`. Do not assume a spawn-time env override exists.

After dispatch, monitor:

```bash
ao status              # branch, activity, PR, CI per session
ao events list         # spawns, transitions, CI failures
ao send <session> "Checkpoint: phase? tests added? files touched? blockers? VERIFICATION_COMMAND output?"
ao session ls          # list sessions
ao session kill <s>    # terminate a bead
ao doctor              # install / environment / runtime health
```

Arm a `Monitor` loop with a concrete exit condition (grep for `completed|pr_created|ready_for_review` AND for `Failed|needs_input|fixing_ci`) per the Async Work Self-Monitoring rule — don't wait to be asked "is it done."

## Port allocation (the #1 parallel-worktree footgun)

Isolated worktrees do **not** isolate the network. Four agents each starting a dev server / test DB on the default port collide instantly. Reserved on this machine: **AO dashboard 3000 (alias pins 3010), terminalPort 14800, directTerminalPort 14801** — keep beads well clear of those.

Give every bead a deterministic, non-overlapping **port block** in the high range, derived from its index. Use `scripts/allocate-ports.sh <bead-index>`:

```
Base = 32000 + index*100
bead-01 → APP 32100  API 32101  TEST 32102  DB 32132  REDIS 32179
bead-02 → APP 32200  API 32201  TEST 32202  DB 32232  REDIS 32279
```

The bead writes this block to **`.env.local`** and reads ports from env — never a hardcoded literal, and never `.env` (AO symlinks the real `.env` into every worktree, so editing it corrupts the shared file for all sessions and all other beads).

## Other parallel-worktree footguns (call these out in every bead spec)

- **Shared database state.** Four beads running integration tests against the same `localhost:5432/appdb` corrupt each other. Each bead uses a unique DB name (`<repo>_bead_NN`) or a per-bead Postgres schema (`?schema=bead_NN`), or an in-memory/SQLite test DB. Never run destructive seed/reset against a shared DB.
- **Docker Compose collisions.** Set `COMPOSE_PROJECT_NAME=<repo>-bead-NN` so container/network names don't clash.
- **Cache / namespace collisions.** Unique Redis namespace/DB index per bead.
- **Lockfile thrashing.** Concurrent `npm/pnpm install` across worktrees corrupts the shared package-manager cache and produces conflicting lockfiles. **One bead owns the lockfile**, and dependency changes land in **Wave 0 on the base branch** so each worktree's post-create install is a restore, not a resolve. A bead that discovers it needs a new dependency PAUSES and signals the router — it does not add it unilaterally.
- **Migrations.** Exactly one bead (Wave 0) owns migrations. Parallel migrations collide badly.
- **Generated artifacts.** Prisma client, OpenAPI/GraphQL types, snapshots — single owner or a Wave-0 contract bead.
- **Workers hitting shared infra.** Background workers in a bead must not connect to shared production/staging resources.

## Debugging a stuck or failing AO agent

1. `ao status` + `ao events list` — is it active, idle, waiting, or `fixing_ci` in a loop?
2. `ao send <session> "Give me a 5-line failure summary + current diff + last test output."`
3. Decide, don't poke: **unblock** with one narrow instruction, **re-scope** the bead smaller, or **kill + re-spawn** with a corrected spec. A bead repeating the same failure with no new evidence is stuck — terminate it; don't let one bead hold the whole feature hostage.
4. If it's an environment problem (port in use, missing dep, DB down), fix the *spec* (port block, Wave-0 dep) and re-spawn rather than hand-patching one worktree.
5. `ao doctor` for runtime/install health if multiple sessions misbehave the same way.
