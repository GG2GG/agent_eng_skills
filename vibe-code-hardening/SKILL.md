---
name: vibe-code-hardening
description: Harden vibe-coded prototypes with architecture boundaries, QA harnesses, CI/CD backward pressure, local hooks, static analysis, and release gates.
triggers:
- vibe coded
- vibe-coded
- vibe coding
- harden prototype
- architecture cleanup
- add ci
- ci/cd gates
- qa harness
- verification harness
- static verification
- pre-commit hooks
- linting
- ruff
- clippy
- cargo clippy
- typecheck
- test harness
---

# vibe-code-hardening

Use this skill to convert a promising prototype into a codebase that can survive repeated agent edits. Treat "vibe-coded" work as a hypothesis: preserve what works, write down the intended behavior, then add mechanical pressure so future changes must prove they are safe.

## Operating stance

- Start by discovering the actual stack, entrypoints, deploy path, and current behavior. Do not impose a framework rewrite just because the project is messy.
- Prefer small gates that run on every change over a big architecture document nobody enforces.
- Capture behavior before refactoring. For fragile code, characterization tests are the harness that lets you improve design without losing the product.
- Use CI as the source of truth. Local hooks are fast feedback; CI is the merge/deploy contract.
- When the existing project has too much debt to make strict gates pass immediately, create a ratchet: baseline current failures, block new failures, then burn the baseline down in follow-up work.

## First pass audit

Before editing, gather:

- `git status`, repo layout, package manifests, lockfiles, Docker files, existing CI, and deploy scripts.
- How to install, run, test, build, and deploy the project.
- Main user workflows and API/UI boundaries.
- Existing "god files", duplicated models, implicit globals, untyped dictionaries/objects, hidden side effects, and env/secrets handling.
- Current verification gaps: no tests, no typecheck, lint warnings ignored, generated code not reviewed, CI only builds but does not test, or deployment bypasses review.

Write down the smallest useful hardening plan in the repo's own planning system if the task has multiple phases.

## Architecture pressure

Shape the code so verification has something stable to grab:

- Slice by user-facing capability, not by agent transcript. A feature should have a clear entrypoint, boundary schema, tests, and ownership.
- Put typed contracts at IO boundaries: HTTP request/response schemas, CLI args, queue payloads, config, database rows, file formats, third-party API responses.
- Isolate side effects behind thin adapters: network, filesystem, database, subprocesses, timers, email, payments, and model calls.
- Keep orchestration separate from pure domain logic. Pure functions are easier to test, fuzz, and refactor.
- Replace ambient state with explicit config. Load secrets from env/files through one config module and never from scattered call sites.
- Break up large files only after tests exist. Extract one behavior-preserving unit at a time.
- Add health checks and structured logs for long-running services and background jobs so failures are diagnosable by the next agent.

## QA harnesses for vibe-coded code

Build the harness around intent, not around whatever implementation the model happened to generate:

- **Characterization tests:** lock the current golden path before refactors. Use fixtures and snapshots only for externally meaningful behavior.
- **Contract tests:** validate API schemas, event payloads, CLI output, database migrations, and third-party adapter assumptions.
- **Integration tests:** cover the workflows a user actually cares about. Prefer these before deep unit tests in unstable prototypes.
- **Property tests:** use Hypothesis, fast-check, proptest, or equivalent for parsers, calculations, normalization, dedupe, ranking, permissions, and date/time code.
- **Visual/E2E tests:** use Playwright/Cypress plus screenshots for UI prototypes. Assert user-visible results, not implementation details.
- **Regression tests for bugs:** every fixed production-like bug gets a focused test that would have failed before the fix.
- **Generated-test review:** if an agent writes tests, check that assertions come from product intent or documented contracts. Do not accept tests that merely mirror the current buggy code.

## CI/CD backward pressure

Backward pressure means the pipeline rejects unsafe work before it reaches users. Add stages in this order:

1. Reproducible install from lockfiles.
2. Formatting check.
3. Lint with warnings as errors once the baseline is clean.
4. Type/static checks.
5. Unit and characterization tests.
6. Integration/API/contract tests.
7. Build/package verification.
8. Security and dependency audit.
9. Preview deploy or smoke test for user-facing apps.
10. Production deploy guarded by required checks, rollback criteria, and observability.

Practical rules:

- Required checks must run on the branch that will merge, not just locally.
- CI should fail closed on missing env, missing lockfile, broken migrations, skipped tests, and typecheck drift.
- Use deterministic caches, pinned tool versions, and `npm ci`/`pnpm install --frozen-lockfile`/`uv sync --frozen`/`cargo --locked` style installs.
- Keep deploy separate from verify. A green build is not permission to deploy unless the environment gate also passes.
- Add smoke tests after deploy: health endpoint, one authenticated happy path when possible, background worker health, and recent error-rate checks.

## Local hooks

Use hooks for quick feedback, never as the only control:

- **pre-commit:** formatting, whitespace, large-file check, secret scan, fast lint, generated-file freshness checks.
- **pre-push:** typecheck, targeted tests, build smoke, migration check when relevant.
- **commit-msg:** issue key or conventional commit validation only if the repo already uses it.

Keep pre-commit under roughly 10 seconds. Put slower checks in pre-push or CI. Hooks may auto-fix formatting, but CI must still verify formatting in check-only mode.

## Static verification menu

Pick the project-native tools before adding new ones:

- **Python:** `ruff check`, `ruff format --check`, `pyright` or `mypy`, `pytest`, `pip-audit`, `bandit` or Semgrep for security-sensitive code.
- **TypeScript/JavaScript:** `biome` or ESLint + Prettier, `tsc --noEmit`, Vitest/Jest, Playwright for UI, `npm audit`/`pnpm audit`, dependency pruning.
- **Rust:** `cargo fmt --check`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo test --workspace`, `cargo audit`, `cargo deny check`.
- **Go:** `gofmt`, `go vet`, `staticcheck`, `go test ./...`, `govulncheck`.
- **General:** Gitleaks/TruffleHog for secrets, Semgrep for SAST, lockfile audit, dead-code/dependency checks, Dockerfile/container scans when shipping images.

Rust/Clippy is the model for all stacks: actionable warnings, idiomatic fixes, and zero tolerated warnings once the baseline is clean.

## Hardening workflow

1. Run the existing checks and record the actual baseline.
2. Add the smallest harness that captures the main workflow.
3. Add formatting/lint/type/static checks in check-only mode.
4. Wire CI to run the same commands from a clean install.
5. Fix or baseline existing failures. Do not hide failures with broad ignores.
6. Refactor architecture one slice at a time behind the harness.
7. Add local hooks after CI commands exist, reusing the same scripts.
8. Document `install`, `test`, `lint`, `typecheck`, `build`, and `deploy` commands in the repo.

## Avoid

- Big rewrites before a harness exists.
- Adding tools the stack does not need just to look rigorous.
- Snapshot tests that freeze accidental markup instead of user-visible behavior.
- CI that only runs on `main` after merge.
- Hooks that mutate large parts of the tree without the user asking.
- Blanket `ignore`, `allow`, `any`, `# noqa`, `eslint-disable`, or `clippy::allow` rules to get green checks.
- Claims that code is production-ready without current verification output.
