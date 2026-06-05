# [SPEC-SLUG]: <one-line title>

> **One-liner:** <what + why in ≤ 25 words. State the user-visible change, not the implementation.>

**Source thread:** <URL>
**Participants:** <name (role)>, <name (role)>, <name (role)>
**Created:** <YYYY-MM-DD> by `pm-thread-to-spec`
**Status:** draft → ready-for-ao-spawn

---

## 1. Verification Protocol (run these to know it works)

> Verification is written **first**, not last. The agent's job is to make every command below exit `0`. If you cannot write a command for a requirement, the requirement is too vague — rewrite it.

```bash
# From repo root, with the worktree activated:

# V1 — schema migration applied
<migration verify command, e.g.>
psql $DATABASE_URL -c "\d <new_table>" | grep -q "<column>" && echo PASS || echo FAIL

# V2 — endpoint behavior
<curl/http command + jq assertion>

# V3 — feature flag wired
<grep / config check>

# V4 — tests
pytest <path/to/test_file>::<test_name> -q
# OR
npm test -- <test-file>

# V5 — type check + lint clean on touched files
ruff check <touched files>
pyright <touched files>     # or: tsc --noEmit
```

All commands exit `0` on a healthy build. Any non-zero exit means the slice that owns that command is not done.

---

## 2. State of the World (what exists today)

> Filled in from `Explore` agent findings. Cite file:line.

**Domain area:** <product / package / app>

**Code that exists:**
- `<path>:<line>` — <what it does>
- `<path>:<line>` — <what it does>

**Database / schemas:**
- `<table>` — columns: <list>; current row count: <approx>; migration last touched: `<filename>`

**External integrations already wired:**
- <service> — entry point at `<path>`

**Environment / dependencies the change relies on:**
- `.env` keys: `<KEY1>`, `<KEY2>`
- Services that must be running locally: <postgres@5432, redis@6379, …>
- CLI tools: `<tool>` v`<min-version>`

**Tests / fixtures the agent will reuse:**
- `<path>` — <what it covers>

---

## 3. Vertical Slices (atomic, verifiable steps)

> Each slice is independently mergeable in a small PR. Each slice has its own verification command from §1. Order matters — the agent works top to bottom.

### Slice 1 — <short label>
- **Current:** <what is true today, in code terms>
- **Target:** <what is true after this slice>
- **Touches:** `<files>` (≤ 5 ideally)
- **Acceptance (must pass):** `V1`, `V2` from §1

### Slice 2 — <short label>
- **Current:** …
- **Target:** …
- **Touches:** `<files>`
- **Acceptance:** `V3`

### Slice 3 — <short label>
- **Current:** …
- **Target:** …
- **Touches:** `<files>`
- **Acceptance:** `V4`, `V5`

---

## 4. Architectural Decisions (locked) + Reference Patterns

> Each decision MUST cite either (a) prior art in the codebase, or (b) the participant in the source thread who locked it. No free-floating opinions.

- **D1 — <decision>**: <one sentence>. Prior art: `<path>:<line>` (or "Locked by <Name> in thread at <ts>").
- **D2 — <decision>**: …

**Reference patterns the worker should imitate** (DO NOT invent new patterns when one of these fits):
- `<path>` — copy this file's structure for <thing>
- `<path>` — copy this test fixture/factory pattern
- `<path>` — copy this migration style

---

## 5. Contracts (pinned verbatim — every slice references these)

> The shapes the worker must produce. If the worker would change any of these, it must stop and flag (see §11 Ambiguity Protocol). Bullets are not allowed here — use code blocks.

**Database schema:**
```sql
-- exact DDL, copy-paste-able
CREATE TABLE <name> (
    id BIGINT PRIMARY KEY,
    ...
);
```

**API request/response:**
```http
POST /api/<endpoint>
Content-Type: application/json

{ "field": "type", ... }

200 OK
{ "field": "type", ... }

4xx error codes (exhaustive):
  - 400: <when>
  - 404: <when>
  - 409: <when>
```

**Event / message payloads (if any):**
```json
{ "event": "<name>", "payload": { ... } }
```

**Backwards-compatibility constraints:**
- <existing consumer> must keep working — <how it currently calls this>

---

## 6. In Scope / Out of Scope (negative constraints — load-bearing)

**In scope:**
- <thing>
- <thing>

**Out of scope — DO NOT TOUCH (and why):**
- `<file/area>` — <reason, e.g. "auth middleware, frozen for the security audit">
- <feature> — <reason, e.g. "shipping in M003, separate spec">
- Refactoring `<area>` while you're in there — <reason, e.g. "blast radius too large for one PR">

> The single most common autonomous-agent failure mode is refactoring out-of-scope code. If you find yourself touching something not listed under "In scope", **stop and flag it as Open Question** rather than fixing it.

---

## 7. Assumptions (anything not confirmed in the thread)

- **A1:** <assumption stated explicitly>. Falsifies the spec if wrong because <reason>.
- **A2:** …

---

## 8. Open Questions for Humans (numbered; named owner)

1. <question>? — owner: <@name>
2. <question>? — owner: <@name>

> The worker should NOT block on these. It should ship the spec with the assumption recorded above, and surface the question in the PR description.

---

## 9. Risk

| Dimension | Score (1–10) | Notes |
|---|---|---|
| Blast radius | <n> | <which systems break if this goes wrong> |
| Reversibility | <n> | <how easy is rollback> |
| Unknowns | <n> | <what would only become clear at runtime> |
| **Overall risk** | <n> | <one-line summary> |

Single biggest unknown: <one sentence>.

---

## 10. Ambiguity Protocol (when to stop and ask vs. proceed)

The worker resolves ambiguity in this exact order. Do NOT invent product behavior.

1. **Search the codebase** for an existing convention (`grep` / Glob + Read). If one exists, follow it. Cite the file in the PR.
2. **Re-read this spec's Contracts (§5) and Architectural Decisions (§4).** If the answer is implied there, follow it.
3. **Check the source thread** at the URL in the header for an answer the digest missed.
4. **Pick the option the spec's Assumptions (§7) imply.** Record the choice in the PR description.
5. If steps 1–4 don't resolve it: **stop, do not guess.** Open the PR as a draft with the question added to the description under `### Unresolved`, and ping the Open Question owner from §8.

Forbidden moves: inventing schema columns not in §5, refactoring files in §6 "Out of Scope", adding dependencies not approved in §4, disabling tests to make CI pass.

---

## 11. Handoff

After human review of §8, run:

```bash
ao spawn --prompt "Implement the spec at $(pwd)/<spec-path>. Follow the Verification Protocol (§1) exactly — every command must exit 0 before opening the PR. Treat the Contracts (§5) as immutable. Do NOT touch anything listed under §6 'Out of Scope'. Follow the Ambiguity Protocol (§10) when stuck — never invent product behavior."
```

**PR expectations the worker must meet:**
- Title: `<prefix>: <one-liner from header>`
- Description links this spec by absolute path
- Description has a `### Verification` block pasting the output of each §1 command
- Description has a `### Risk` block restating §9 with anything new the worker learned
- Description has an `### Unresolved` block listing any §8 questions the worker hit (empty if clean)
- Migrations (if any) are in their own commit, separate from app code
- No unrelated refactors

---

*Generated by `pm-thread-to-spec` skill. Template version 1.*
