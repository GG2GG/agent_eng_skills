---
name: sdlc-protocol
description: Use when the user says "follow SDLC", "follow proper SDLC", "follow SDLC protocol", "follow SDLC Framework", or asks to build a large product feature/spec that warrants a branch + PR. The protocol for decomposing a feature into AO-isolated, parallel, TDD-validated work units.
triggers:
- follow sdlc
- follow proper sdlc
- follow the sdlc
- sdlc protocol
- sdlc framework
- proper sdlc
- our sdlc
- build this feature
- implement this spec
- ship this product feature
- break this into beads
- parallelize this build
- aoswarm this
---

# sdlc-protocol

How this machine ships a large product feature from a spec: decompose into a small number of **beads** (parallel work units), build each in its own **AOSwarm worktree** so contexts stay clean and never collide, validate every bead with **real tests (TDD)**, and integrate through a reviewable branch. CI is **observed, never a blocker** during the build — local product-surface tests are the gate.

**You (this session) are the ROUTER + REVIEWER.** AO bead agents implement; you decompose, dispatch, monitor, and integrate. You do **not** implement the feature inline.

## When this applies

- A feature/spec large enough to warrant its own branch + PR/MR, sliceable into 2+ mostly-independent pieces.
- **NOT** for: one-line fixes, config tweaks, docs, a single tightly-coupled change (`<=25` lines) — those are inline edits. If it isn't really an SDLC-scale build, say so and do it inline.

## The protocol (7 steps)

```
0. Detect scope        → SDLC-scale? If not, stop and do it inline.
1. Decompose           → contract-first, file-disjoint beads + assign waves
2. Write bead specs    → one spec file per bead, from the template
3. Wave 0 (SYNC, you)  → land contracts/schema/migrations/shared types/deps on base FIRST
4. Dispatch Wave 1+    → ao spawn / ao batch-spawn, one isolated worktree per bead
5. Monitor the swarm   → ao status / ao events list / ao send; require progress reports
6. Integrate in waves  → review each diff, merge Wave 0, rebase, merge low-conflict first, validate
7. Verify + ship       → every bead's VERIFICATION_COMMAND green locally → combined tests → PR
```

### 0 — Detect scope
Confirm this is SDLC-scale (multi-piece feature, branch + PR). If trivial or single-coupled, **do not** stand up beads — do it inline and stop here.

### 1 — Decompose into beads
Slice by **file ownership + contract boundary + vertical user-flow**, NOT just "frontend/backend". Default to ~4 beads; use 2 when coupling is high, 6–8 only when ownership is genuinely disjoint. Assign each bead to a wave. → **`references/bead-decomposition.md`** (heuristics + the Wave Model).

The single most important rule: **contracts have ONE owner.** Shared schema, DB migrations, event names, shared types, generated clients (Prisma/OpenAPI/GraphQL), feature flags, the dependency lockfile — each belongs to exactly one bead (almost always Wave 0). Parallel edits to these = a merge bloodbath.

### 2 — Write a bead spec per bead
Every bead gets a spec file (`.sdlc/beads/bead-NN-<slug>.md` in the repo, gitignored). Use the template — Objective, Scope (allowed/forbidden paths), Contracts, Dependencies, **Tests Required**, **Validation Commands**, **Port Allocation**, Done Criteria. → **`references/bead-spec-template.md`**. Assign ports with **`scripts/allocate-ports.sh <bead-index>`**.

### 3 — Wave 0 yourself (synchronous, NOT parallelized)
Before dispatching anything, the router lands the shared foundation on the base branch: contract/types skeleton, DB migration shape, feature flags, and the dependency + lockfile changes (so each worktree's install is a restore, not a resolve). If the feature area lacks test infra, Wave 0 also builds the test harness (fixtures, factories, mock servers, Playwright setup). Commit this to the base branch the beads will branch from.

### 4 — Dispatch implementation beads
One isolated worktree per bead via AO. Do **not** wait for CI between beads. → **`references/ao-operations.md`** (dispatch commands, the port scheme, parallel-worktree footguns, debugging stuck agents).

### 5 — Monitor the swarm
Activity ≠ quality. Poll `ao status` / `ao events list`; use `ao send <session>` to request a structured checkpoint (phase, tests added, files touched, blockers, validation result). Arm a Monitor loop per the Async Work Self-Monitoring rule in CLAUDE.md.

### 6 — Integrate in waves
Parallel beads move integration work onto you — budget for it explicitly. Review each bead diff, reject unrelated churn, merge Wave 0 first, rebase Wave 1 onto it, merge lowest-conflict beads first, and run combined local validation after each merge batch. → **`references/integration-playbook.md`**.

### 7 — Verify + ship
Each bead's `VERIFICATION_COMMAND` must be green locally (the bead is not "done" until it is). Run the combined product-surface suite, then open the PR/MR. CI must end green before merge (pipeline-gate rule) — but it never blocked the *build*.

## Non-negotiables

| Rule | Why |
|---|---|
| **TDD per bead** — failing test first, real product-surface test, can't complete until `VERIFICATION_COMMAND` exits 0. Can't write tests? STOP and report, don't proceed. | Without CI as the gate, local tests ARE the gate. → `references/validation-contract.md` |
| **CI observed, never blocking** during the build | Momentum across beads; CI is a final check, not a per-bead barrier. |
| **One owner per contract** (schema/migrations/types/generated/lockfile) | Parallel edits to shared surfaces destroy the merge. |
| **Orchestrate via AO, never implement the feature inline** | Composes with the `ao-edit-guard` hook instead of fighting it (see below). |
| **No nested AO spawn** — a bead agent never spawns more beads | Prevents runaway fan-out and routing loops. |
| **`.env.local`, never `.env`** for per-bead ports/secrets | AO symlinks the real `.env` into every worktree — editing it corrupts the shared file for all sessions. |

## How this composes with the `ao-edit-guard` hook

The hook is **enforcement**; this skill is **orchestration**. They agree: SDLC code work goes through AO. This skill is the *payload generator* — it writes bead specs and calls `ao spawn` / `ao batch-spawn` explicitly, so the hook passes the work through rather than blocking it. Don't try to "write code inline and let the hook catch it." The only inline edits allowed during an SDLC build are orchestration artifacts (bead specs, `.sdlc/` files, `.ao-rules`) and `<=25`-line surgical fixes that are not the feature implementation itself.

## Reference files (load on demand)

- `references/bead-decomposition.md` — slicing heuristics, decomposition axes, the Wave Model.
- `references/bead-spec-template.md` — the exact per-bead spec template + a filled example.
- `references/validation-contract.md` — TDD-without-CI rules; what "minimum product-surface tests" means concretely.
- `references/ao-operations.md` — AO dispatch, the deterministic port scheme, parallel-worktree footguns, stuck-agent debugging.
- `references/integration-playbook.md` — wave-based merge/reconcile model, stop-and-reconcile triggers, failure policy.
- `scripts/allocate-ports.sh` — emits a deterministic `.env.local` port block for a given bead index.
