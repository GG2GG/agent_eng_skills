---
name: goal-mode
description: |
  Run an autonomous work-until-done loop with periodic + per-update macOS notifications, layered on Claude Code's native `/goal` Stop-hook directive. Use when the user says "set a goal", "work until <X>", "keep working until <X>", "goal mode", "notify me every <N> minutes", "ping me on updates", or asks the agent to work toward a condition without pausing to ask what to do next. This skill does NOT shadow the built-in `/goal` command — it wraps it: it tells the agent to register the condition as a `/goal` directive AND wires the notification cadence the bare command does not provide.
argument-hint: "<completion-condition> [--every <minutes>] [--no-sound] | clear"
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
  - Glob
metadata:
  type: skill
  family: routing
  category: execution
  complements: "/goal (native Claude Code slash command)"
  notify_primitive: scripts/goal-notify.sh
---

<objective>
Make the agent work autonomously toward a measurable completion condition — without stopping to ask the user "what next?" — while surfacing visible progress on the user's Mac. Three behaviors, composed:

1. **Persistent autonomous work-until-done.** Register the condition as Claude Code's native `/goal <condition>` directive. `/goal` installs a session-scoped **Stop hook** that BLOCKS the session from stopping until the condition holds true (the evaluator judges *surfaced conversation evidence*), and auto-clears once met. The condition itself is the directive — keep working toward it, do not pause for instructions.
2. **Periodic progress notifications (~5 min).** A heartbeat update on a fixed cadence (default 5 minutes) so the user knows it is still alive even when nothing newsworthy happened.
3. **Ping on each update.** Whenever a *meaningful* state change occurs (a step completes, a test flips, a blocker appears), fire an immediate visible macOS notification — independent of the heartbeat.

This skill is the HOW that wires (2) and (3) onto (1). The bare `/goal` command gives you the work-until-done loop; it does not, on its own, send periodic or per-update desktop notifications.
</objective>

<when_to_use>
Trigger when the user expresses a durable, condition-gated work intent plus (often) a notification cadence:

- "set a goal: <condition>" / "goal mode"
- "work until <X>" / "keep working until <X>" / "don't stop until <X>"
- "notify me every <N> minutes" / "ping me on updates" / "tell me when something changes"
- "show me a notification on my computer when …"

Also use when the user wants the agent to drive toward an outcome *autonomously* (no "what should I do next?" check-ins).

DO NOT use for:
- One-shot tasks with a clear single deliverable and no "until" framing → just do the task.
- Recurring time-based polling with no completion condition (e.g. "check the deploy every 5 min forever") → use the `/loop` skill instead.
- Cron-style unattended scheduling across sessions → use the `/schedule` skill.
- Production SDLC code changes that warrant a PR → route to `ao spawn` per the global routing rules; goal-mode can *wrap* the wait-for-green condition but does not replace PR review.
</when_to_use>

<how_goal_works>
Authoritative facts (source: Claude Code docs — code.claude.com/docs/en/goal; do not cite non-Anthropic sources for `/goal` behavior):

- `/goal <condition>` is a **native, session-scoped, model-facing directive**. It registers a **Stop hook** that prevents the session from stopping until the condition is satisfied, then **auto-clears** on success.
- `/goal clear` clears the directive early.
- The evaluator judges **evidence surfaced in the conversation** — it does NOT independently read files or run commands. So the agent MUST surface proof (command output, test results, diffs) in-conversation for the condition to be judged met.
- A shell command CANNOT set, mutate, or clear `/goal` state. Only the agent, in-session, invokes `/goal`. (That is why this skill instructs the agent rather than scripting it.)
- One loop authority per session: `/goal` must not run concurrently with Ralph / autopilot / `/team` / another Stop-hook continuation loop. If one is already active, surface the conflict and ask which wins before registering `/goal`.
</how_goal_works>

<workflow>

## Step 0 — Parse the invocation
- If the argument is `clear` → run `/goal clear`, send a final "goal cleared" notification (`scripts/goal-notify.sh "Goal cleared" "goal-mode" "<condition>"`), stop the heartbeat, and exit.
- Otherwise the argument is the **completion condition** (the directive). Extract any `--every <minutes>` (default `5`) and `--no-sound` flag.
- Restate the condition back to the user in one line as a **measurable** statement. If it is vague ("make it better"), tighten it into something the evaluator can judge from surfaced evidence (e.g. "all tests in `make test` pass and `glab ci status` shows the pipeline green"). Surface the tightened wording; proceed without a second round of questions.

## Step 1 — Conflict check (one loop authority)
Before registering, confirm no other primary loop owns the session (Ralph, `:autopilot`, `:ultrawork`, `/team`, an existing `/goal`). If one is active, STOP and ask the user which authority should win — do not stack loops.

## Step 2 — Register the native directive
Invoke the native command in-session:

```
/goal <measurable completion condition>. Work autonomously toward this; do not pause to ask what to do next. Before claiming completion, surface evidence: <proof command(s)>, and the final review checkpoint.
```

The condition is now the directive. The Stop hook will block stopping until the evaluator judges the surfaced evidence sufficient.

## Step 3 — Open the notification loop
Fire a "goal armed" notification immediately, then arm a periodic heartbeat at the requested cadence. Two independent triggers:

- **Heartbeat (~every N min):** a "still working" ping with a one-line status, even when nothing changed. Drive it with a `Monitor` loop (preferred) or the `/loop` skill at the `--every` interval. Each tick calls `scripts/goal-notify.sh`.
- **On each update (event-driven):** whenever a *meaningful* state change happens — a sub-step completes, a test flips red↔green, a blocker is hit, the condition is met — fire an **immediate** notification, separate from the heartbeat.

Notification primitive (verified working on this machine — the ONLY one to use for a *visible* desktop alert):

```bash
scripts/goal-notify.sh "<message>" "goal-mode" "<short subtitle / condition>" "Glass"
# add "none" as the 4th arg, or pass --no-sound at invocation, to silence the sound
```

Under the hood that runs:
```bash
osascript -e 'display notification "MSG" with title "goal-mode" subtitle "SUB" sound name "Glass"'
```

Notification discipline:
- Heartbeat copy = current step + progress fraction if known ("3/6 acceptance checks green").
- Update copy = what changed ("CI turned green", "hit auth blocker — pausing for input").
- Keep messages short; the title is always `goal-mode`, the subtitle carries the condition or the event.

## Step 4 — Work the goal autonomously
Drive toward the condition. After each meaningful step, **surface the evidence in-conversation** (command output, test summary, diff) — this is what the `/goal` evaluator reads. Do NOT stop to ask "what next?"; the condition is the instruction. If you hit a true blocker that needs the user (credentials, an irreversible decision), fire an update notification describing the blocker and ask — that is the one legitimate reason to surface a question.

## Step 5 — Completion
When the condition holds:
- Surface the final proof evidence in-conversation so the evaluator can judge it met.
- The Stop hook auto-clears on success. Fire a final "goal met" notification with the proof one-liner.
- Stop the heartbeat loop.
- Give a short Recap: what was achieved, the evidence, anything left.

</workflow>

<hard_rules>
- NEVER claim the goal is complete on reasoning alone — surface the actual proof (command output / test result / diff) in-conversation; the `/goal` evaluator only judges surfaced evidence.
- NEVER stack loop authorities. One of `/goal`, Ralph, autopilot, `/team` per session. Resolve conflicts with the user first.
- NEVER use a shell command to try to set/clear `/goal` state — only the in-session `/goal` invocation does that.
- ALWAYS use `scripts/goal-notify.sh` (→ `osascript display notification`) for a *visible* desktop alert. It is the only verified-visible primitive on this machine. A terminal `echo` or a log line is NOT a visible notification.
- Heartbeat and per-update notifications are SEPARATE triggers — do not collapse them; the user asked for both.
- For production code changes that warrant a PR, the work itself still routes through `ao spawn`; goal-mode wraps the wait-until-condition, it does not bypass PR review.
- `/goal clear` (or invoking this skill with `clear`) must also tear down the heartbeat loop and send a final "cleared" notification.
</hard_rules>

<invocation_examples>
- `goal-mode all unit tests pass and the linter is clean --every 5` — register `/goal`, heartbeat every 5 min, ping on each test flip, macOS notification on completion.
- `goal-mode the CI pipeline on this branch is green --every 10 --no-sound` — silent heartbeats every 10 min, visible (soundless) banner on each status change.
- `goal-mode clear` — clear the directive, stop heartbeats, final notification.
- Natural language: "keep working until the migration applies cleanly and notify me every 5 minutes, ping me on each update, and show a notification on my computer" → same as the first example.
</invocation_examples>

<related>
- **`/goal`** (native Claude Code slash command) — the Stop-hook work-until-done primitive this skill wraps. Use bare `/goal` when you do NOT want desktop notifications.
- **`/loop`** — recurring interval runner with no completion condition; goal-mode can use it to drive the heartbeat, or use a `Monitor` loop.
- **`/schedule`** — cron-style unattended scheduling across sessions.
- **`agent-runbook`** — picks the execution mode; routes durable cross-session goal continuity to OMC `:ultragoal` / `.omc/ultragoal/`. goal-mode is the in-session notification-wrapped variant.
- **OMC `ultragoal`** — durable multi-goal ledger under `.omc/ultragoal/` that pairs with `/goal` for multi-session runs; use it when the goal spans days and needs an audit trail.
</related>
