# Validation contract — TDD without a CI gate

**REQUIRED BACKGROUND:** `superpowers:test-driven-development` defines the RED → GREEN → REFACTOR discipline. This file does not replace it — it specifies the per-bead validation *contract* that makes TDD safe when CI is **not** the gate during the build.

## The core problem

We deliberately don't block on CI green to keep momentum across beads. That removes the safety net. So **local tests become the gate**, and the contract must be un-fakeable: a bead cannot mark itself done on reasoning alone, and "minimum tests" must not decay into "a mock that always passes."

## The Rule of the Verification Command

Every bead spec names a `VERIFICATION_COMMAND`. The agent may not exit, hand off, or report complete until that command returns **exit code 0**, and it must paste the raw passing output into its final report. Activity is not completion; green output is.

## What "minimum product-surface tests" means concretely

The minimum is **not** "some unit tests." It is at least one test that exercises the bead's behavior through its **real public surface**:

| Bead surface | Product-surface test |
|---|---|
| API endpoint | supertest/httpx call hitting the real route → asserts response shape + status |
| UI flow | Playwright/component mount that drives the actual user interaction |
| CLI command | invoke the command, assert stdout/exit code |
| Background worker / job | enqueue → run the real job runner → assert side effect |
| Webhook / event handler | post a real payload → assert handler effect |
| Service boundary | call the real client against a stubbed *external* dependency |

Unit tests are **support**, not product-surface. A bead with only unit tests has not met the contract.

## The TDD sequence each bead follows

1. **RED first.** Write the failing test that proves the target behavior. Run it. Capture the red output *before* implementing. (A test that passes immediately on a fresh feature proves nothing.)
2. **GREEN.** Write the minimum implementation to pass.
3. **REFACTOR.** Clean up while staying green.
4. **Full validation set** for what changed:
   - Unit tests for changed pure logic.
   - Integration/API tests for changed boundaries.
   - Worker/job tests for async behavior.
   - UI/e2e/component tests for changed workflows.
   - Migration forward+rollback (or a schema assertion) when DB changes exist.

## Anti-fakery rules

- **Mock only true externals** — network, payment, email, third-party APIs. NEVER mock the code path the bead is validating. A bead that mocks its own logic has tested nothing.
- **No always-green tests.** If a test passes without the implementation, it's not a test — it's a placeholder. Delete it and write a real one.
- **Can't write the test? STOP and report.** If a bead genuinely cannot produce a product-surface test (missing harness, untestable design), it must halt and tell the router — not silently proceed to "done." Missing test infrastructure is a Wave-0 test-harness bead, not a thing to skip.

## Red flags (the bead is about to violate the contract)

- "I manually verified it works" → not the contract. Run `VERIFICATION_COMMAND`.
- "I'll add tests after it's working" → tests-after = "what does this do"; tests-first = "what should this do." Write the failing test first.
- "A unit test covers it" → unit ≠ product-surface. Add the real-surface test.
- "I mocked the service so it passes" → if you mocked the path under test, you proved nothing.
- "CI will catch the rest" → CI is not the gate here. Local green is.
