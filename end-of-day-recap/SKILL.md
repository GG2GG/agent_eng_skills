---
name: end-of-day-recap
description: Produce a punchy ~2-paragraph end-of-day work recap with ~5 numbered bullets of what was completed, linking repos and merge requests where relevant. Pulls evidence from git/MRs AND ClickUp (task closures, comments, time entries, chat) because most work happens outside the codebase. Use for "EOD recap", "wrap up my day", "what did I do today", "daily summary", "end of day report".
triggers:
- eod recap
- end of day recap
- end of day summary
- wrap up my day
- recap my day
- what did i do today
- daily recap
- daily summary
---

# end-of-day-recap

Turn a day of scattered activity — commits, MRs, closed tickets, comments, ops — into a recap someone can read in fifteen seconds.

This is a read-only synthesis skill. It gathers evidence, clusters it by work item, and writes a tight recap. It never invents work, never closes tickets, never pushes. **Most people using this are not only writing code** — they live in ClickUp, meetings, and ops — so git is one input, not the input.

## The output (this is the whole point)

Exactly this shape. Two short paragraphs, then ~5 numbered bullets. No preamble, no "Here's your recap," no filler adjectives.

```
<One sentence: the day's theme.> <One sentence: impact or the handoff for tomorrow.>

<Optional second paragraph ONLY if there's a real blocker, decision, or thing the reader must act on. Otherwise stop at one.>

1. <Outcome verb + what + link.> e.g. Shipped the onboarding import fix — [MR !412](url), [CU-8a1](url).
2. ...
3. ...
4. ...
5. ...
```

Rules for the prose:
- **Cut every word that isn't load-bearing.** "Worked on improving the" → "improved the."
- **Lead each bullet with the outcome verb**, not the artifact. `Closed`, `Shipped`, `Merged`, `Unblocked`, `Reviewed`, `Triaged`, `Drafted`, `Decided`. Then the what, then the link.
- **One bullet = one work item**, not one tool action. Roll small things up: "Cleared three billing-ops follow-ups."
- **Link repos and MRs** as markdown links. Link the ClickUp task when it's the anchor.
- Order by impact: shipped/closed → unblocked → reviewed/coordinated → planned. ~5 bullets; never pad to hit a count, never let it sprawl past ~7.

## Accuracy — never hallucinate the day

The fastest way to make this useless is to claim work that didn't ship.

- **Every bullet traces to evidence**: a commit, MR URL, closed task, authored comment, time entry, or an explicit note the user gave you. No evidence → drop it or ask.
- **Activity ≠ completion.** A commit or comment means work *happened*, not that it *shipped*. Reserve "shipped/closed/merged" for terminal states (merged MR, task moved to a done status). Otherwise use "advanced," "worked through," "followed up on."
- **Separate completed from progressed from unblocked.** Don't blur them to sound productive.
- Keep a private evidence map while drafting; it never appears in the output, but you should be able to point at the source of every line.

## Gather evidence (automatic), then ask one question

Run the cheap structured pulls first. Default window: today, local timezone (state it if asked). Resolve the person across git author email, GitLab/GitHub handle, and ClickUp member id before querying.

### Code

```bash
git log --since="6am" --author="$(git config user.email)" --oneline --all
git branch --show-current
# MRs touched today (GitLab):
glab mr list --author=@me --updated-after="$(date +%F)" 2>/dev/null
```

For GitLab MRs, link as `https://<your-gitlab-host>/<group>/<repo>/-/merge_requests/<iid>`.

### ClickUp — first-class, not supplementary

Git explains code delivery; **ClickUp explains everything else** — closures, coordination, planning, ops. Treat it as a primary source. See the `clickup-api` skill for endpoint quirks. Workspace id `9011399348`.

Signals that mean "work done today," strongest first:
- **Time entries** in the day window (`clickup_get_time_entries`) — the best signal for where time actually went.
- **Tasks that moved to a done/closed status** (`clickup_filter_tasks` by assignee + updated-today, then inspect status).
- **Comments the user authored today** (`clickup_get_task_comments` on candidate tasks — keep only their own, in-window) — decisions, handoffs, cleared blockers.
- **Tasks created/moved/reprioritized** by the user.
- **Chat messages the user sent** (`clickup_get_chat_channel_messages` on their active channels) — noisy and the v3 Chat API is experimental, so tolerate missing data and summarize, don't transcribe.

Pull recipe:
1. `clickup_get_time_entries` for the user + day window.
2. `clickup_filter_tasks` — assignee = user, updated today.
3. For each candidate task, `clickup_get_task_comments`; keep only the user's, in-window.
4. Optionally sweep their work channels with `clickup_get_chat_channel_messages`, author-filtered.

### Then ask exactly one gap-fill question

Tools miss meetings, Slack DMs, verbal unblocks, planning. After gathering, ask once:

> Anything from meetings, Slack, planning, or unblock work that won't show up in git or ClickUp?

Fold the answer in as user-confirmed evidence. Don't interrogate further.

## Merge into one recap — no double-counting

The same work shows up in multiple tools. Collapse it.

- **Cluster by canonical work item.** Prefer the ClickUp task id as the grouping key; attach MRs/commits to it when the branch, MR title, commit message, or task description references the id.
- **Task closed + MR merged for it → one bullet:** "Shipped X" with both links.
- **Time tracked but nothing closed → "advanced X,"** not "completed."
- **Comment/chat that only discussed a task** = supporting detail under that task's bullet, not its own bullet.
- A meeting is "completed work" only if it produced a decision or artifact the user names — otherwise it's context, not a bullet.

## Completion criteria

Done when the recap: is two paragraphs (or one) + ~5 numbered bullets; leads every bullet with an outcome verb; links repos/MRs/tasks; every line traces to evidence; and contains zero filler. If evidence was thin, say so in one line rather than padding.
