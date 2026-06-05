---
name: pm-thread-to-spec
description: |
  Convert a product-discussion thread (ClickUp / Slack / Linear / GitHub) into an Agentic TaskSpec — a spec optimised for autonomous coding agents (DevBot via `ao spawn`, OpenHands, Devin, SWE-agent). Use when the user provides a thread URL/dump and says "turn this into a spec", "make a spec from this thread", "PRD for this", "hand this to DevBot", "spec for the engineering team", or similar.
argument-hint: "<thread-url-or-path> [--ao-spawn]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
  - WebFetch
metadata:
  type: skill
  family: pm
  output: .planning/specs/<slug>/SPEC.md
---

<objective>
Turn an unstructured product-discussion thread (ClickUp/Slack/Linear/GitHub/transcript paste) into a single Markdown spec an autonomous agent can execute without further user input. Position in workflow:

  thread → **pm-thread-to-spec** → `ao spawn ISSUE` → PR

The spec MUST be **verification-first** (every requirement names the shell command or test that proves it true) and **negative-constraint-aware** (every out-of-scope item is named so the agent doesn't refactor the world).

NOT to be confused with:
- `gsd:spec-phase` — Socratic interview when **no thread exists yet** (this skill assumes a thread already exists; it digests, it does not interview).
- `gsd:plan-phase` — produces a multi-task plan; this skill produces ONE spec per slice that can be planned later.
- Anthropic `feature-dev` — interactive 6-phase flow with the user in the loop; this skill is one-shot for handoff to a worker.
</objective>

<when_to_use>
Trigger when the user provides any of:
- A ClickUp chat URL (`app.clickup.com/<team>/chat/r/<channel>/t/<msg>`)
- A Slack thread URL (`<workspace>.slack.com/archives/<channel>/p<ts>`)
- A Linear issue URL or ticket ID
- A GitHub issue/discussion URL
- A pasted thread or meeting transcript

AND signals intent to ship: "spec", "PRD", "hand off to DevBot/ao", "for engineering", "build this", "turn into work".

DO NOT trigger for:
- Pure summaries with no engineering handoff intent
- Threads about non-code work (hiring, sales calls)
- Requests for analysis only — use `external-context` or `deep-dive` instead
</when_to_use>

<process>

## Step 1 — Fetch the thread
Pick the right fetcher based on the URL scheme. **Never paste raw API tokens into prompts**; load `CLICKUP_API_TOKEN` from your project's `.env` (or set `CLICKUP_ENV_FILE` to override the path).

| Source | Tool |
|---|---|
| ClickUp v3 chat | `scripts/fetch_clickup_thread.py <url>` (in this skill dir) |
| Slack | Run your workspace's slack morning-digest script (lives in a separate private repo; path is env-overridable) with `--thread <url>` |
| Linear | `gh api graphql -F query=@linear-issue.graphql -F id=<id>` or MCP `linear_get_issue` |
| GitHub | `gh issue view <url> --json title,body,comments` |
| Paste | Read the conversation buffer directly |

Resolve all `@user` mentions to real names via the workspace user lookup. Include attachments (screenshots, JSON dumps) — do NOT lose them.

## Step 2 — Probe codebase in parallel
Launch 2–4 `Explore` agents in **one** message, each with a different lens, before drafting anything:

1. **State of the world** — what exists today in the area the thread talks about? File paths, table names, current call sites.
2. **Adjacent features** — what looks similar that the agent can crib patterns from?
3. **Constraint surface** — auth, rate limits, feature flags, existing migrations, deploy gates that bind the change.
4. **Test surface** — what test files exist for the area; which fixtures/factories does the agent reuse?

These findings populate the spec's **State of the World** section and become the verification baseline.

## Step 3 — Extract from the thread
Build a structured intermediate (not part of the final spec) covering:

- **Participants**: who said what, with role (PM/eng/lead).
- **Decisions locked**: every statement the participants explicitly agreed on.
- **Open questions**: every "we haven't decided" or unresolved dispute.
- **Schema/API sketches**: ANY tables, columns, endpoints, payloads named in-thread — copy verbatim, then verify against codebase.
- **Out-of-scope mentions**: every "we won't do X here" or "later phase" — these become Negative Constraints.

## Step 4 — Resolve ambiguity at most once
For each open question, prefer ONE round of `AskUserQuestion` (up to 4 questions, multiselect when applicable) before drafting. After that round, write the spec with explicit assumptions in an **Assumptions** section — do not loop on questions.

## Step 5 — Write the spec
Use `templates/spec.md` (next to this SKILL.md). Section order is **load-bearing** — do not reorder. The template enforces verification-first by placing acceptance shell commands **before** implementation hints.

Write to `.planning/specs/<slug>/SPEC.md` if `.planning/` exists; otherwise `reports/specs/<slug>/SPEC.md`.

## Step 6 — Optional: hand off to the worker
If `--ao-spawn` is passed (or the user explicitly asks "send it to DevBot"), end the run with:

```bash
ao spawn --prompt "Implement the spec at <abs path>. Follow Verification Protocol exactly. Open a PR when all acceptance shell commands pass."
```

Do NOT call `ao spawn` without confirmation when the spec touches:
- Production code paths labelled `auth`, `billing`, `migration`
- More than 8 files in the In-Scope list
- Anything the **Risk** section rates ≥ 7/10

</process>

<spec_template_summary>
Header block (title, one-liner ≤25 words, source thread URL, participants, created date, status) then 11 numbered sections, in this order — order is load-bearing, do NOT reorder:

1. **Verification Protocol** *(written first, not last)* — exact shell commands the worker must pass for completion. Every requirement in §3 references one of these.
2. **State of the World** — current code reality from Explore-agent probes (file paths, tables, APIs, env keys, services).
3. **Vertical Slices** — atomic units of work, each with Current/Target/Touches/Acceptance-command.
4. **Architectural Decisions + Reference Patterns** — locked patterns + files to imitate, with cited prior art.
5. **Contracts** — schemas, API shapes, error codes, event payloads, back-compat constraints — pinned verbatim in code blocks.
6. **In Scope / Out of Scope (Negative Constraints)** — explicit fences with reason for each exclusion.
7. **Assumptions** — anything not confirmed in-thread, each with its falsifier.
8. **Open Questions for Humans** — numbered, with a named owner each.
9. **Risk** — 1–10 across blast radius / reversibility / unknowns, plus single biggest unknown.
10. **Ambiguity Protocol** — strict 5-step order the worker follows when stuck (search → contracts → thread → assumptions → stop+draft-PR). Lists forbidden moves.
11. **Handoff** — exact `ao spawn` command + PR expectations (verification output pasted, risk restated, unresolved listed, migrations split into own commit).

See `templates/spec.md` for the filled-in skeleton with phrasings that empirically improve agent success — acceptance criteria as runnable shell commands, negative constraints stated as "DO NOT touch X because Y", contracts pinned in code blocks not bullets.
</spec_template_summary>

<failure_modes_to_avoid>
1. **Vague acceptance** — "should work" / "looks good" → ban these. Every requirement gets a shell command that returns 0 / non-zero.
2. **Missing negative constraints** — agent ends up refactoring 14 files outside scope. Always list "DO NOT touch" with the reason.
3. **Implicit environment** — agent assumes services running. Always declare `.env` keys, ports, docker services, CLI tools in the **Environment** subsection of State of the World.
4. **Forking the schema mid-spec** — if the thread sketches a schema, pin it in section 6 as a code block, then point to it from every slice that touches it.
5. **Looping on questions** — if 1 round of `AskUserQuestion` doesn't resolve it, write it as an **Assumption** and ship; the worker can flag it back at PR time.
6. **Skipping the codebase probe** — never write a spec without 2+ Explore-agent findings in section 4. The whole reason agents fail is unstated reality.
</failure_modes_to_avoid>

<success_criteria>
- Spec saved to `.planning/specs/<slug>/SPEC.md` (or `reports/specs/<slug>/SPEC.md` if no `.planning/`)
- All 11 sections present, in order
- Verification Protocol has at least one shell command per Vertical Slice
- Every Open Question is numbered and addressed to a named human (not "the team")
- The source thread URL and participants are quoted at the top
- If `--ao-spawn` was passed: a single `ao spawn` command is printed to the chat as the final line
</success_criteria>

<related>
- `gsd:spec-phase` — when there's no thread to digest
- `gsd:plan-phase` — to chunk this spec into multi-task plans
- `deep-interview` — when the thread is too thin and you need to interview the user
- `ao spawn` — the worker that consumes this spec
- `external-context` — when the thread references docs the agent hasn't read
</related>

<prior_art>
Adjacent public skills/templates that overlap. This skill is narrower: **threaded discussion → single agent-executable spec**. If a different shape fits better, route to it instead.

- **[anthropics/skills](https://github.com/anthropics/skills)** — task instruction examples, not engineering PRDs.
- **[Specky / SDD](https://skillsmp.com/skills/paulasilvatech-specky-skill-md)** — produces `SPECIFICATION.md` + `DESIGN.md` + `TASKS.md` + `HANDOFF_AGENT.md`. Heavier; assumes greenfield, not a thread digest.
- **[BMad OpenClaw](https://playbooks.com/skills/openclaw/skills/lb-bmad-skill)** — PRD + architecture + epics/stories pipeline. Use when the request spans multiple specs.
- **[Product Manager Skills (deanpeters)](https://mdgrok.com/repos/deanpeters/Product-Manager-Skills)** — human-PM-flavored PRD + user stories. Not agent-handoff-shaped by default.
- **[Writing Implementation Tasks](https://skillsmp.com/skills/mazrean-agent-skills-skills-writing-implementation-tasks-skill-md)** — turns an existing spec into atomic Claude Code slash commands with dependencies. Useful **after** this skill.
- **[Sagaflow `deep-design`](https://pypi.org/project/sagaflow/)** — broader mission-mode spec engine; overkill for a single feature debate.
- **[Devin prompting docs](https://docs.devin.ai/learn-about-devin/prompting)**, **[OpenHands prompting](https://docs.openhands.dev/openhands/usage/tips/prompting-best-practices)**, **[Cline rules](https://docs.cline.bot/customization/cline-rules)** — prompt guidance, not skills you can invoke.

**Why this skill exists despite the above:** none of them digest a multi-party ClickUp/Slack/Linear discussion thread into a verification-first spec that maps cleanly to `ao spawn`. They start blank; this one starts from the conversation.
</prior_art>
