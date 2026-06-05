# Per-bead spec template

One spec per bead, written to `.sdlc/beads/bead-NN-<slug>.md` in the repo (add `.sdlc/` to `.gitignore`). This file is the complete brief an autonomous agent works from — it must succeed with **no back-and-forth**. Dispatch it via `ao spawn --prompt "$(cat .sdlc/beads/bead-NN-<slug>.md)"` or by creating a tracked issue per bead and `ao batch-spawn`.

## Template

```markdown
# Bead NN: <short name>

> You are an IMPLEMENTATION bead, not the router. Implement ONLY this bead.
> Do not spawn other agents. Do not edit files outside your allowed paths.
> Do not change shared contracts/types/schema — they are fixed (see Contracts).

## Objective
One concrete, verifiable outcome.

## Scope
- ALLOWED PATHS: `src/api/invoice/**`, `tests/api/invoice/**`
- FORBIDDEN PATHS: `package.json`, `package-lock.json`, `src/api/index.ts`,
  `prisma/schema.prisma`, any migration, any central router/barrel file.
- OUT OF SCOPE: <things a reader might assume but that belong to another bead>

## Contracts (FIXED — do not modify)
- Types: `InvoiceType` already exists in `src/types/invoice.ts` (Wave 0).
- API: implement `POST /api/invoice` → `{ id, status, total }`.
- Events / flags / permissions this bead must honor.
- Compatibility: bead-03 (frontend) consumes this exact response shape.

## Dependencies
- Depends on: Wave 0 contract merged (yes/no) · bead X (yes/no).
- Can proceed with stubs: yes/no (and which stubs).

## Tests Required (TDD — write the failing test FIRST)
- Failing test to write first: <file>, proving <behavior>. Capture the initial
  red run output before implementing.
- Product-surface test (REQUIRED): exercise the real public surface —
  API endpoint / UI route / CLI / job runner / webhook / service boundary.
- Support tests: unit (changed logic), integration (changed boundaries),
  worker/job (async behavior), UI/e2e (changed workflows).
- Mocks: only external network/payment/email. NEVER mock the code path you
  are validating inside this bead.

## Validation Commands
VERIFICATION_COMMAND: `npm run test -- tests/api/invoice`
Do NOT report complete until this returns exit code 0. Paste the passing
output into your final report.

## Port Allocation (use .env.local — NEVER edit .env; it is a symlink)
Run `scripts/allocate-ports.sh NN` and write the block to `.env.local`:
  APP_PORT=<assigned>  API_PORT=<assigned>  TEST_PORT=<assigned>
  DB_NAME=<repo>_bead_NN   COMPOSE_PROJECT_NAME=<repo>-bead-NN
Never bind a hardcoded port; always read process.env / .env.local.
Tear down any servers/containers you started before reporting done.

## Done Criteria
- [ ] Implementation complete within allowed paths only.
- [ ] Failing-test-first followed; VERIFICATION_COMMAND green locally.
- [ ] No unrelated files changed; no shared contracts modified.
- [ ] Final report: phase, tests added, files touched, blockers, validation output.
- [ ] Notes for the router's integration step.
```

## Why each section exists

- **The "implementation bead, not router" header** stops nested `ao spawn` and scope creep — the two failure modes that wreck parallel runs.
- **Allowed/forbidden paths** are what make worktrees actually disjoint at merge time. Without them, agents drift into shared files.
- **Contracts marked FIXED** enforce the immutable-contract rule: a bead that can't comply must fail loudly, not silently reshape the API and break dependents.
- **Tests Required with concrete filenames** is the guard against "minimum tests" decaying into "no tests." Naming the files up front makes their absence obvious in review.
- **VERIFICATION_COMMAND** is the objective, un-fakeable completion gate — the agent pastes real passing output, not a claim.
- **Port + DB + compose namespace** prevent the parallel-worktree collisions detailed in `ao-operations.md`.
