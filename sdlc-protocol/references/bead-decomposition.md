# Bead decomposition + the Wave Model

A **bead** is one work unit a single AO agent owns end-to-end in its own worktree. A good bead has: a coherent user- or system-visible behavior; a mostly-disjoint file set from other beads; a clear API/schema/contract boundary; its own tests; and a mergeable implementation that doesn't require another bead to exist first.

## Don't slice by "frontend vs backend" alone

That horizontal split sounds clean but couples everything: the frontend bead can't validate without the backend bead's shape, and both fight over shared routes/types. Prefer **vertical, contract-bounded** slices.

## Decomposition axes (pick what fits the feature)

1. **Contract bead (first, if multiple beads share surface).** Shared API schema, DB migration shape, event names, shared types, feature flags, permission model. Keep it tiny. It is Wave 0 and merges before anything depends on it.
2. **Vertical user-flow beads.** "create campaign", "edit campaign", "campaign list filters", "campaign analytics worker". Slice the flow cleanly rather than by layer.
3. **Boundary beads.** Service-A integration, worker pipeline, admin UI, public API, billing hook, webhook ingestion. Each external boundary is a natural seam.
4. **Risk beads.** Isolate the scary parts: risky migrations, third-party API integration, auth/permissions, background jobs. Containing risk in one bead keeps a failure from poisoning the others.
5. **Test-harness bead.** If the feature area has no test infrastructure, the first bead builds reusable fixtures, factories, mock servers, or Playwright/component-test setup. Everyone downstream depends on it → Wave 0.

Default to **~4 beads**. Don't force the number: 2 when coupling is high, 6–8 only when ownership is genuinely disjoint. More beads = more integration cost, not less work.

## The Wave Model (strict dependency ordering)

Worktrees are isolated, but **merge is not** — if four agents all edit `routes.ts`, `schema.prisma`, and `package.json`, integration is a bloodbath. Constrain parallelism to disjoint sets, ordered by dependency:

```
Wave 0  (SYNC, router does it, NOT parallelized)
        Contracts · shared types skeleton · DB migration shape · feature flags
        · dependency + lockfile changes · test harness/fixtures
        → committed to the base branch the beads branch from.

Wave 1  (PARALLEL beads)
        Independent implementation beads. Build against the Wave-0 contracts.
        Backends/workers/services. Forbidden from touching registries,
        central routers, barrel files, migrations, or the lockfile.

Wave 2  (PARALLEL or staged)
        Cross-bead integration, UI wired to real APIs, UX polish,
        migration hardening. Often a frontend bead consuming Wave-1 APIs.

Wave 3  (router)
        Registry wiring (imports into main router/index), final regression,
        docs, PR cleanup.
```

**Why Wave 0 is synchronous:** the contract and the lockfile are the things every bead reads. Lock them first, on the base branch, so each worktree branches from a stable foundation and its post-create `npm install` is a fast restore — not a concurrent dependency *resolve* that thrashes the shared package-manager cache and produces conflicting lockfiles.

## Bead boundary rules

- A bead spec must declare an explicit **allowed-paths glob** (e.g. `src/features/invoicing/**`) and a **forbidden-paths** list (registries, central routers, `package.json`, migrations).
- Beads **never** edit central wiring (`index.ts`, `main.ts`, route tables, barrel exports). The router wires imports in Wave 3 *after* beads land.
- The Wave-0 **interface contract is immutable** to a bead. If a bead can't fulfill it, it cleanly fails and alerts the router — it must **not** unilaterally change shared types/schemas (that silently breaks every dependent bead at integration time).
- Exactly one bead owns migrations. Exactly one bead owns the lockfile. Exactly one bead owns each generated artifact (Prisma client, OpenAPI/GraphQL types).
