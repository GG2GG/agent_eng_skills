# Global Claude Code Instructions

## Task Routing Decision Gate

Before touching any file, route the task correctly:

| Situation | Tool | Rationale |
|-----------|------|-----------|
| New project / greenfield | `/gsd-new-project` | Spec-driven lifecycle prevents context rot |
| Structured feature work | `/gsd-next`, `/gsd-plan-phase`, `/gsd-execute-phase` | Continues plan → execute → verify loop |
| Autonomous / unattended build | `gsd` → `/gsd auto` in terminal | GSD-2: fresh context per task, crash-safe, worktree isolation |
| Quick ad-hoc task (in GSD project) | `/gsd-quick` | Atomic commits + state tracking, lighter ceremony |
| Bug fix / investigation | `/gsd-debug` or `/gsd-do "fix..."` | Scientific method debugging with persistent state |
| Multi-file refactoring (no GSD) | Claude Flow swarm (Agent tool + MCP) | Parallel agents with worktree isolation |
| Latest docs / live data | `gemini -p "..."` in terminal | Real-time knowledge, CLI-only |
| Architecture / hard problem | `codex-smart exec ...` | Deep reasoning with o3, dual-account rotation |
| Simple single-file edit | Claude directly | No overhead needed |
| Unknown GSD command | `/gsd-do <description>` | Smart router dispatches automatically |
| **Any HTML report / deliverable** | **`html-reports` skill** | Pick the right archetype (Folio / Stage / Atlas / Field / Ledger / Timeline / Catalog) — never hand-roll bespoke HTML |
| **Any data chart / infographic / metrics visual** | **AntV infographic library** | Check template catalog first — ~200 built-in SVG templates (list, chart, sequence, compare, hierarchy, relation, word-cloud) |
| **Any UI animation / scroll effect / interactive design** | **GSAP skills** | Consult the matching GSAP skill (core, timeline, scrolltrigger, plugins, react, utils, performance) |

## Magic Keywords

Type one of these as the **first word** of your prompt to activate a mode:

| Keyword | Mode | What happens |
|---------|------|-------------|
| `ultrawork` / `ulw` | Parallel Swarm | Decomposes task, spawns 3-6 parallel agents simultaneously |
| `ultrathink` / `uth` | Deep Reasoning | Parallel research agents + deep synthesis before solution |
| `swarm` | Swarm | Claude Flow multi-agent coordination |
| `explore` / `search` | Parallel Explore | 3 agents searching from different angles simultaneously |
| `review` / `audit` | Multi-Review | 4 parallel reviewers: security, performance, quality, architecture |
| `debug` / `investigate` | Debug | 3 parallel investigation agents tracing from different angles |
| `ship` | Ship | Format → lint → test → commit → push → PR |

## GSD v1 Workflow (Claude Code slash commands)

**Lifecycle:** `new-project` → `discuss-phase` → `plan-phase` → `execute-phase` → `verify-work` → `ship`

**Critical rules:**
- **Never skip the plan.** Always discuss → plan → execute. Skipping causes hallucinations.
- **/clear between phases.** GSD spec files reconstruct context. Clear aggressively to prevent rot.
- **Route through GSD.** Even "just fix this bug" goes through `/gsd-do` or `/gsd-debug`.
- **`.planning/` is the source of truth.** STATE.md, ROADMAP.md, and phase PLANs persist across sessions.

**Entry points:**
- `/gsd-quick` — small fixes, doc updates, ad-hoc tasks
- `/gsd-debug` — investigation and bug fixing
- `/gsd-execute-phase` — planned phase work
- `/gsd-do <description>` — when unsure which command to use

Do not make direct repo edits outside a GSD workflow unless explicitly asked to bypass.

## GSD v2 (Autonomous CLI)

Install: `npm install -g gsd-pi@latest` | Launch: `gsd` | Re-run setup: `gsd config`

**Use GSD v2 when:**
- Running unattended / overnight builds — walk away, come back to a built project
- Multi-day milestones needing crash recovery, per-task cost tracking, and worktree isolation
- Fresh context per task is critical (large codebases, long accumulated sessions)
- Parallel milestone execution across multiple isolated worktrees

**State:** `.gsd/` directory (separate from `.planning/`)
**Global config:** `~/.gsd/PREFERENCES.md`
**Agent instructions:** `AGENTS.md` (or `CLAUDE.md`) at project root or `~/.gsd/`
**Durable project context:** `.gsd/KNOWLEDGE.md` — add domain terminology, architectural constraints, team conventions; pre-loads into every task dispatch

### How Auto Mode Works

Auto mode is a **file-driven state machine**: reads `.gsd/` state → dispatches the next task with a **fresh 200k-token context window** (pre-inlined plans, summaries, dependencies, decisions) → verifies → commits → repeats until done.

- **Tool policy enforcement** — planning units can read broadly but cannot edit project files; execution units have full access; enforced before tool calls, not just via prompt
- **Crash recovery** — lock files + session forensics enable resume with full context after any failure
- **Auto-fix retries** — verification failures trigger automatic fix attempts before escalating to human

### Core Commands

| Command | Purpose |
|---------|---------|
| `/gsd` or `/gsd next` | Step mode — one unit at a time with pauses |
| `/gsd auto` | Fully autonomous: research → plan → execute → verify → repeat |
| `Escape` | Pause auto-mode (preserves full state) |
| `/gsd stop` | Graceful shutdown |
| `/gsd status` | Real-time progress + cost dashboard (`Ctrl+Alt+G`) |
| `/gsd discuss` | Architecture discussion — safe to run in Terminal 2 alongside auto |
| `/gsd steer` | Modify plans mid-execution without stopping auto |
| `/gsd capture "text"` | Fire-and-forget idea capture; processed at next task boundary |
| `/gsd triage` | Manually process pending captures |
| `/gsd skip` | Prevent auto-dispatch of current unit |
| `/gsd undo` | Revert last completed work unit |
| `/gsd debug <issue>` | Persistent debug session (state saved in `.gsd/debug/sessions/`) |
| `/gsd forensics` | Post-mortem debugger for auto-mode failures |
| `/gsd doctor` | Validate + repair `.gsd/` integrity |
| `/gsd doctor --fix` | Auto-fix all detected issues |
| `/gsd parallel start` | Spawn parallel workers for eligible milestones |
| `/gsd parallel status` | Monitor parallel workers (costs, progress, health) |
| `/gsd parallel merge` | Merge completed milestones to main |
| `/gsd migrate` | Migrate `.planning/` (v1 phases/plans) → `.gsd/` (v2 slices/tasks) |
| `/gsd export --html` | Generate milestone HTML report |
| `gsd headless --timeout 600000` | CI / cron mode, no TUI |
| `gsd headless query` | Instant JSON state snapshot (~50ms, no LLM) |

### Two-Terminal Workflow

- **Terminal 1:** `gsd` → `/gsd auto` (builds autonomously)
- **Terminal 2:** `gsd` → `/gsd discuss` / `/gsd status` / `/gsd steer` (steer without interrupting)

### Configuration (`~/.gsd/PREFERENCES.md`)

Key settings to configure after install:

```yaml
models:
  research: claude-sonnet-4-6
  planning: claude-opus-4-6        # heavy reasoning for planning
  execution: claude-sonnet-4-6
  completion: claude-sonnet-4-6
token_profile: balanced             # budget | balanced | quality
budget_ceiling: 50.00               # USD hard stop for a session
git:
  isolation: worktree               # worktree (default) | branch | none
  auto_push: false
  auto_pr: false
dynamic_routing:
  enabled: true
  escalate_on_failure: true         # bump tier on retry
  budget_pressure: true             # auto-downgrade models near ceiling
parallel:
  enabled: false
  max_workers: 2                    # 1–4
  auto_merge: confirm               # auto | confirm | manual
```

**Token profiles:**
- `budget` — 40–60% savings; cheaper models, skip optional phases, minimal context inlining
- `balanced` — 10–20% savings; standard models + compression (default)
- `quality` — full context inlined; use for production-critical or architecturally complex work

**Git isolation modes:**
- `worktree` (default) — isolated checkout per milestone at `.gsd/worktrees/<MID>/`; squash-merges to main on completion
- `branch` — milestone branch in project root; better for submodule-heavy repos
- `none` — commits directly to current branch; for hot-reload workflows where worktrees break tooling

### Captures & Triage

During auto-mode, use `/gsd capture "text"` to log thoughts without interrupting. At the next task boundary GSD triages each capture into one of: **quick-task** (executes immediately), **inject** (merges into current task), **defer** (roadmap), **replan** (triggers strategy reconsideration), or **note** (logged only). Dashboard shows pending capture count.

### Parallel Orchestration

Run multiple milestones simultaneously — each in its own worktree, branch, and context window:
- Enable with `parallel.enabled: true` and `max_workers: 2` in preferences
- Commands: `/gsd parallel start` → `/gsd parallel status` → `/gsd parallel merge`
- Workers check `dependsOn` metadata and file-overlap before spawning
- Coordinator enforces aggregate `budget_ceiling` across all workers
- Run `/gsd doctor --fix` to clean up orphaned parallel sessions

### Remote Control (Headless / Overnight)

Set up Telegram, Slack, or Discord to receive notifications and answer decision prompts while away:
- `/gsd remote telegram` — wizard sets up bot token + chat ID
- `/gsd remote slack` — wizard sets up `xoxb-...` bot token
- `/gsd remote discord` — wizard sets up bot credentials

**Telegram only:** live commands while auto runs — `/status`, `/progress`, `/budget`, `/pause`, `/resume`

Unanswered prompts default after configured timeout (GSD makes conservative decisions or pauses).

### Skills

GSD reads skills from `~/.agents/skills/` (global) and `.agents/skills/` (project-local, version-controlled). Install via `npx skills add`. Control discovery mode in preferences: `auto` (apply automatically), `suggest` (require confirmation), `off`. Monitor with `/gsd skill-health` — flags skills below 70% success rate or with rising token usage.

### Team Workflow

Set `mode: team` in `.gsd/PREFERENCES.md` — enables unique milestone IDs, branch pushes, and pre-merge checks.

**Plan-review workflow (recommended for teams):**
1. `/gsd discuss` → generates planning docs
2. Open docs-only PR for review (scope, architecture, slice dependencies)
3. After approval, `/gsd auto` executes in a separate implementation PR
4. `/gsd steer` during execution stays in the worktree — doesn't modify approved plans on main

### Recovery Procedures

```bash
/gsd doctor          # Validate .gsd/ structure
/gsd doctor --fix    # Auto-repair orphaned dirs, stale locks, bad refs
/gsd forensics       # Full failure debugger with telemetry
/gsd debug list      # List all persistent debug sessions
```

Stuck auto-mode: remove `.gsd/auto.lock` and `.gsd/completed-units.json` to restart from current disk state. For macOS iTerm2: set Left Option Key to "Esc+" for `Ctrl+Alt+G` dashboard shortcut.

## Git Worktrees (For Feature Branch Work)

Use git worktrees for any feature branch work to prevent context bleed and allow parallel development without stashing.

**When to use:**
- Starting any non-trivial feature or bug fix on a branch
- Running parallel workstreams on different branches simultaneously
- When the Agent tool uses `isolation: "worktree"` for subagents

**Workflow (invoke `/superpowers:using-git-worktrees` for full guidance):**
1. Create worktree: `git worktree add ../project-feature-name feature/branch-name`
2. Work inside the worktree directory — fully isolated from main checkout
3. Commit and push from within the worktree
4. Remove when done: `git worktree remove ../project-feature-name`

**Rules:**
- Never create a worktree inside the main repo directory — always use a sibling path (`../`)
- The Agent tool's `isolation: "worktree"` parameter handles this automatically for subagents
- List active worktrees: `git worktree list`
- Each worktree shares git history but has its own working directory and index

## Claude Flow Swarm (For Multi-File Work Outside GSD)

Use Claude Flow for complex multi-file work that is **not** inside a GSD project.

1. Init: `mcp__claude-flow__swarm_init` with `topology: "hierarchical"`, `maxAgents: 8`
2. Spawn ALL parallel agents in **one message** using Agent tool with `run_in_background: true`
3. Use `isolation: "worktree"` when agents edit overlapping files
4. After spawning, **STOP** — wait for completion notifications before synthesising
5. Review ALL agent results before reporting success

Never spawn agents sequentially when they can run in parallel. Parallel = faster + cheaper.

## QA & Verification Protocol

**Always enforced — no exceptions:**
- MUST run verification after every code change. Never claim completion based on reasoning alone.
- MUST NOT mark a task complete until all required checks pass.
- If verification can't run locally, state exactly what was not run and why.
- Never self-approve in the same context — use GSD's verifier or code-reviewer for final pass.

**Minimum verification for any code change:**

| Step | Python | JS/TS |
|------|--------|-------|
| 1. Format | `ruff format .` | `pnpm format` |
| 2. Lint | `ruff check .` | `pnpm lint && pnpm typecheck` |
| 3. Test | `pytest -q <test_file>` | `pnpm test --runInBand` |
| 4. Diff Review | Scan for accidental changes, dead code, debug prints, placeholders | same |

**Anti-hallucination checks (must pass before claiming done):**
- No unresolved imports, names, or references in changed files
- No fake files, commands, or env vars in code or docs
- No placeholder code: `TODO`, `FIXME`, `pass`, `raise NotImplementedError`, stub returns
- Any new dependency must exist in repo config or lockfile
- Claimed test passes must come from actual executed command output, not reasoning

**Layered quality gates:**

| Layer | What | When |
|-------|------|------|
| CLAUDE.md | Tells Claude the rules | Always loaded |
| PostToolUse hook | Auto-format + lint on every Edit/Write | Immediate |
| Pre-commit | Format, lint, secret scan | At commit time |
| TaskCompleted hook | Full verification: lint + placeholders + debug code | Before marking done |
| Stop hook | Final lint gate — blocks if modified Python has errors | Before session end |
| CI pipeline | Full suite, integration, e2e | On push/MR |

## Coding Discipline

- **Surface ambiguity before coding.** Present multiple interpretations, don't pick silently.
- **Push back when warranted.** If a simpler approach exists, say so.
- **Goal-driven execution.** Transform tasks into verifiable goals with success criteria before starting.
- **Clean up only YOUR orphans.** Don't touch pre-existing dead code unrelated to the task.
- Don't add features, refactor code, or make "improvements" beyond what was asked.
- Don't add error handling for scenarios that can't happen — trust internal framework guarantees.
- Three similar lines of code is better than a premature abstraction.
- Don't add docstrings, comments, or type annotations to code you didn't change.

## HTML Report Generation

**Any time you generate an HTML report, deliverable, dashboard, memo, deck, comparison, or single-file HTML document, you MUST use the `html-reports` skill.** No bespoke hand-rolled HTML, no ad-hoc inline styles, no CDN imports, no "I'll just write something quick."

Source of truth: `/Users/wiko/agentic-engineering/stack/skills/universal/html-reports/`

### Mandatory workflow

1. **Invoke the `html-reports` skill** via the Skill tool before writing any HTML.
2. **Pick the archetype by shape, not topic** — read `SKILL.md` and the archetype `README.md` to choose:
   - **Folio** — book / TOC + sections (scorecards, audits, framework refs)
   - **Stage** — slides (readouts, decks, kickoffs)
   - **Atlas** — dashboard (KPIs + filterable cards)
   - **Field** — editorial long-read (post-mortems, case studies, strategy memos)
   - **Ledger** — comparison matrix (vendor bake-offs, A/B reads, before/after)
   - **Timeline** — chronological with deltas (incident reviews, growth narratives)
   - **Catalog** — search-first faceted list (directories, registries)
3. **Render via Jinja2** using the archetype's `template.html.j2` + `styles.css`. Don't fork the template inline unless explicitly asked.
4. **Single-file output.** Inline `<style>` + `<script>`, no external URLs (SVG/base64 only), light mode default, system fonts only.
5. **Date-stamp the filename and the page.** `reports/<topic>/<slug>-YYYY-MM-DD.html` AND a visible `Report date: YYYY-MM-DD` near the header.

### When in doubt

- If unsure which archetype fits, ask once — present the top 2 candidates with their tradeoff.
- If the request truly doesn't fit any archetype (rare), say so explicitly and propose adding a new archetype rather than reaching for bespoke HTML.
- Sibling skills that emit HTML (`report-writer`, `slides`, `morning-briefing`, `competitor-deep-dive`, `dreaming`, etc.) should target an `html-reports` archetype as their shape — don't reinvent the shell.

### Hard rules (non-negotiable)

- No CDN / external font / external image URLs in output
- No dark mode default; no build tools; no JSX/TS
- WCAG AA contrast, semantic HTML, `prefers-reduced-motion` respected
- Print stylesheet must work (chrome hides, content reflows)
- Never name a generated report `index.html` — reserve that for galleries

## AntV Infographic Components

**Any time you build a section with data, metrics, KPIs, charts, flows, timelines, comparisons, hierarchies, or network diagrams — check the AntV infographic template catalog FIRST.**

Full catalog: `~/.claude/projects/-Users-wiko/memory/reference_antvis_infographic.md`  
Repo: https://github.com/antvis/infographic  
Install: `npm install @antv/infographic`

### Decision table — pick the template category by shape

| Visual shape | Category | Example templates |
|---|---|---|
| Pie / bar / column / line / word cloud | **chart-*** | `chart-pie-compact-card`, `chart-bar-plain-text`, `chart-column-simple`, `chart-wordcloud` |
| Grid / row / column of cards | **list-grid / list-row / list-column** | `list-grid-circular-progress`, `list-row-horizontal-icon-arrow` |
| Ranked / pyramid | **list-pyramid** | `list-pyramid-badge-card`, `list-pyramid-compact-card` |
| Radial / sector / circular | **list-sector** | `list-sector-simple`, `list-sector-half-plain-text` |
| Waterfall / cascade | **list-waterfall** | `list-waterfall-compact-card` |
| Ordered steps / process | **sequence-steps** | `sequence-steps-badge-card`, `sequence-steps-simple-illus` |
| Timeline / roadmap | **sequence-timeline / sequence-roadmap-vertical** | `sequence-timeline-badge-card`, `sequence-roadmap-vertical-pill-badge` |
| Snake / winding path | **sequence-snake-steps** | `sequence-snake-steps-compact-card` |
| Funnel | **sequence-funnel** | `sequence-funnel-simple` |
| Pyramid (ranked growth) | **sequence-pyramid** | `sequence-pyramid-simple` |
| Staircase / ascending | **sequence-ascending-steps / sequence-stairs** | `sequence-ascending-stairs-3d-simple`, `sequence-stairs-front-compact-card` |
| Cyclical / circular flow | **sequence-circular / sequence-circle-arrows** | `sequence-circular-simple`, `sequence-circle-arrows-indexed-card` |
| 3D visual | **sequence-cylinders-3d / sequence-zigzag-pucks-3d** | `sequence-cylinders-3d-simple`, `sequence-zigzag-pucks-3d-indexed-card` |
| Swim lanes / interactions | **sequence-interaction** | `sequence-interaction-badge-card-*` |
| Pros vs cons / A vs B | **compare-binary-horizontal** | `compare-binary-horizontal-badge-card-fold`, `compare-binary-horizontal-simple-vs` |
| SWOT / 2×2 matrix | **compare-swot / compare-quadrant** | `compare-swot`, `compare-quadrant-quarter-simple-card` |
| Multi-column compare | **compare-hierarchy-row** | `compare-hierarchy-row-letter-card-compact-card` |
| Org chart / decision tree | **hierarchy-tree** | `hierarchy-tree-*` (many edge styles) |
| Mind map | **hierarchy-mindmap** | `hierarchy-mindmap-*` (branch / level gradient) |
| Directed graph / flow diagram | **relation-dagre-flow** | `relation-dagre-flow-*` (TB / LR / animated) |
| Network / node graph | **relation-network** | `relation-network-icon-badge` |

### Workflow

1. Match the visual shape above → get the template prefix
2. Check the full catalog file for the exact template key
3. Use the template key with `@antv/infographic` renderer
4. Apply themes via `themeConfig.colorPrimary` or palette string

### Hard rules

- Never hand-roll SVG charts or metrics cards if a matching AntV template exists
- For HTML reports using the `html-reports` archetypes: embed the AntV SVG output inline — it satisfies the "no external URLs" rule
- Check the catalog even for "simple" metrics — `list-grid-circular-progress` or `list-grid-progress-card` covers most KPI card patterns

---

## GSAP Animations

**Any time you add animation, transitions, scroll effects, draggable interactions, SVG morphing, text effects, or any motion to a web deliverable, report, or UI component — consult the GSAP skills first.**

Full catalog: `~/.claude/projects/-Users-wiko/memory/reference_gsap_animations.md`  
Repo: https://github.com/greensock/gsap-skills  
Install: `npm install gsap` (all plugins included and free — no auth tokens, no Club GSAP needed)

### Skill selection table

| Need | Use |
|------|-----|
| Basic fade / move / scale / rotate | **gsap-core** — `gsap.to()`, `gsap.from()`, `gsap.fromTo()` |
| Multi-step choreographed sequence | **gsap-timeline** — `gsap.timeline()`, position parameter |
| Scroll-triggered / parallax / pinned sections | **gsap-scrolltrigger** — `ScrollTrigger`, `scrub`, `pin` |
| Flip layout transitions, draggable, SplitText, MorphSVG, DrawSVG, text scramble | **gsap-plugins** — register each plugin once |
| React / Next.js integration | **gsap-react** — `useGSAP()` hook, `@gsap/react` |
| Vue / Nuxt / Svelte / SvelteKit | **gsap-frameworks** — `gsap.context(scope)`, `ctx.revert()` on unmount |
| Math helpers (clamp, mapRange, snap, random, wrap) | **gsap-utils** — `gsap.utils.*` |
| Performance / 60fps / reducing jank | **gsap-performance** — transforms only, `gsap.quickTo()`, `will-change` |

### Hard rules

- Always animate **transforms** (`x`, `y`, `scale`, `rotation`) and `opacity` — never `left`/`top`/`width`/`height` for motion
- Register plugins once at app level before first use: `gsap.registerPlugin(ScrollTrigger, Flip, ...)`
- Always clean up: use `useGSAP()` in React, `ctx.revert()` in Vue/Svelte, `ScrollTrigger.kill()` on unmount
- Remove `markers: true` from ScrollTrigger before shipping
- Use `gsap.quickTo()` for high-frequency updates (mouse followers, drag handlers) — never create new tweens per frame
- For HTML reports: GSAP can be inlined as a `<script>` tag (it's ~75KB) — satisfies the no-CDN rule by bundling locally

---

## Security & Credential Hygiene

- Tokens live in `.env` files only. Never hardcode, commit, echo, or log secrets.
- Load credentials via Python `python-dotenv`. NEVER use `source .env` — shell expansion corrupts values.
- SSH-only for GitLab/GitHub clones unless a specific repo requires HTTPS + OAuth.
- Commit prefix convention: `feat:` / `fix:` / `docs:` / `chore:` / `refactor:`
- Ruff linter must run on all Python projects after every modification.
- NEVER run `git push --force` to main/master. Warn if requested.
- NEVER skip hooks (`--no-verify`) unless explicitly asked.

## Python Environment

- Python venv: `~/.venvs/datascience` — activate for all data analysis / scripting work
- Linter: `ruff` (not flake8, not pylint)
- Formatter: `ruff format`
- Dependency management: `pip` into venv; never install globally

## Token Optimization

**Decision flow at session start:**
1. Check for `.claude/codebase-map.md` in the repo root — generated by `~/.claude/scripts/generate-codebase-map.py`
2. If it exists and is fresh (same commit hash) → **read it before any Glob/Grep**
3. If stale or missing → the `codebase-map-loader.sh` SessionStart hook auto-regenerates it
4. Only fall back to direct Glob/Grep for targeted lookups (known paths, specific symbols)

**Rules:**
- Never scan the full codebase with Glob/Grep when a map exists — map is faster and cheaper
- `/clear` between GSD phases — `.planning/` artifacts reconstruct context; never carry stale context forward
- Delegate open-ended exploration to the Explore subagent — isolated window, returns a summary
- Read only the lines needed from large files (`offset` + `limit` params on Read)
- Batch independent file reads into a single parallel tool call

**GSD intel tools:**
- `/gsd-map-codebase` — generate/refresh `.claude/codebase-map.md` for any repo
- `/gsd-intel` — query the intel layer (architecture, stack, conventions) without reading source
- `/gsd-scan` — rapid codebase assessment before planning a new feature

**Context budget rules:**
- If context fills up mid-task, `/clear` and re-enter via GSD — spec files reload what matters
- Never load entire large files speculatively — read the relevant section first, expand only if needed
- Subagents run in isolated windows — use them to offload research, not to save one tool call

## Service Integrations

- **Linear** — project management (MCP configured); issue IDs use `XXXX-NNN` format
- **ClickUp** — chat/DMs and task tracking (MCP configured)

## Model Routing

| Model | Use Case |
|-------|----------|
| haiku | Quick lookups, small verifications, low-stakes tasks |
| sonnet | Standard work, most tasks (default) |
| opus | Architecture, deep analysis, security review, large refactors |

Use the lightest-weight model that preserves quality. Reserve opus for tasks that genuinely need deep reasoning.
