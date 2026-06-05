# Integration playbook — merging the swarm back together

Parallel beads don't eliminate integration work; they **move it onto the router (you)**. Budget an explicit integration pass — four green worktrees are not a shipped feature until they're wired together and validated as a whole.

## Wave-based merge sequence

Don't merge passively as beads finish. Merge in dependency order:

1. **Review each bead diff independently.** Reject unrelated churn, scope violations (files outside allowed paths), and any unsanctioned change to shared contracts *before* merging.
2. **Merge Wave 0 first** (already on the base branch from step 3 of the protocol — confirm it's there).
3. **Rebase / update each Wave-1 bead onto the current base** so it carries the real contracts, not the stale snapshot it branched from.
4. **Merge lowest-conflict beads first.** Get the easy, disjoint ones in to shrink the surface for the harder ones.
5. **Run combined local validation after each meaningful merge batch** — not just at the end. Catch cross-bead breakage while you still know which merge caused it.
6. **Wave 3 wiring (router-owned).** Now add the imports into the central router / index / barrel files / route tables that beads were forbidden to touch. This is where the frontend bead gets wired to the real backend bead.
7. **Final regression + docs + PR cleanup**, then open the PR/MR.

## Stop and reconcile when

- Two beads edited the same core files (boundary leak — your allowed-paths globs weren't disjoint enough).
- A contract changed *after* dependent beads started (a bead violated the immutable-contract rule, or Wave 0 was wrong).
- A migration or generated artifact conflicts.
- A bead could not produce a product-surface test.
- An agent is repeating the same failure with no new evidence.

Reconciling means: pause the fan-out, fix the root cause (usually a spec/contract/scope error), and re-dispatch — not patch around it in one worktree.

## Failure policy (decide BEFORE dispatch, not mid-incident)

When a bead fails, pick one deliberately instead of poking a broken session forever:

| Situation | Action |
|---|---|
| Transient / environment (port, dep, DB) | Fix the spec, re-spawn the bead. |
| Bead too big / ambiguous | Split into smaller beads, re-dispatch. |
| Small, well-understood fix | Inline repair by the router (`<=25` lines) is fine. |
| Bead blocked on another bead | Defer; merge its dependency first, then resume. |
| Fundamentally wrong approach | Kill the bead, re-scope the spec, re-spawn. |

## Observability is part of "done"

`ao status` tells you a session is *active*, not that the work is *good*. Require every bead's final report to state: current phase, tests added (with filenames), files touched, blockers hit, and the `VERIFICATION_COMMAND` output. Without that, you're integrating blind. Quality is asserted with evidence, never assumed from activity.

## Ship gate

- Every bead's `VERIFICATION_COMMAND` green locally.
- Combined product-surface suite green locally.
- PR/MR opened → **CI must end green before merge** (the pipeline-gate hard rule). CI never blocked the build; it is the final ship check.
