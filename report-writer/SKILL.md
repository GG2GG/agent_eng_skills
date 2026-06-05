---
name: report-writer
description: Generate standalone HTML decision memos, audits, analyses, or comparison reports. Use when the user asks for a "report", "decision memo", "audit", "comparison", "analysis doc", "writeup", or any shareable document where rendering quality matters. Produces light-mode single-file HTML with a consistent structure (TL;DR → mental-model framing → side-by-side options → component breakdown → TCO/data tables → decision tree → recommendation → next steps).
triggers:
- make me a report
- write a report
- generate a report
- memo
- decision memo
- comparison memo
- vendor comparison
- compare options
- analysis
- analysis doc
- audit report
- writeup
- create a writeup
- shareable document
- present these options
- present this as a report
- can you put this in a report
- html report
---

# report-writer

Generates polished, single-file, light-mode HTML reports for decision memos, vendor comparisons, audits, and analyses. Optimized for non-technical stakeholders (founders, finance, ops leads).

## When to use

- User asks for a "report", "memo", "audit", "writeup", "comparison", or "analysis"
- User says "present these options" or "make this easier to understand"
- Output needs to be shareable with stakeholders outside the chat
- Multiple options/paths/vendors need side-by-side comparison
- A recommendation must be backed by structured reasoning

## When NOT to use

- Quick conversational answer (just answer inline)
- Code review output (`gsd-code-review` / `code-review`)
- Privileged cloud/infrastructure audits (use the private ops runbooks)
- AI/ML eval report (`gsd-eval-review`)
- A trivial summary that doesn't benefit from styling

## Conventions

- **HTML only.** Never Markdown for reports. HTML renders to stakeholders; Markdown does not.
- **Light mode by default.** White/light-gray backgrounds, dark text. Switch to dark only if user requests.
- **Single file.** All CSS inline in `<style>`. No external assets, no JS frameworks. Must work offline by double-clicking.
- **Output location:**
  - Cross-cutting / personal / no clear project home: `~/reports/<slug>/index.html`
  - Project-specific: `<project>/reports/<slug>/index.html`
  - If unsure or worktree-guarded: default to `~/reports/<slug>/index.html`
- **Open in browser** after writing: `open <path>` on macOS.

## Standard structure (use as a template)

The MDM comparison memo (2026-05-21) is the reference shape. Match this order:

1. **`<header class="hero">`** — eyebrow label, H1, lede (1–2 sentence framing of the question), meta row (date, context, decision owner)
2. **TL;DR callout** — 2–4 sentences max, the conditional recommendation ("X is right if... Y is right if...")
3. **Mental-model section** — the conceptual unlock that makes the decision tractable. Often a horizontal grid of 4–6 "layer" or "dimension" cards explaining the problem space.
4. **Side-by-side path cards** — 2–4 columns, one per option. Each card: badge, name, price, includes-list with check/cross icons, verdict footer. Highlight the recommended one with a heavier border.
5. **Component-by-component table** — for each ingredient/sub-feature/line-item: cost, "do you need it?" pill (high/med/low/have), and one-sentence rationale.
6. **TCO or sensitivity table** — annualized cost at 3 headcount/usage tiers, with a "what you give up" column.
7. **Decision tree** — 3–5 numbered yes/no questions that pressure-test the recommendation.
8. **Recommendation callout** — green or blue. State the call. Acknowledge the line items worth negotiating or stress-testing.
9. **Next steps** — numbered list, 4–8 concrete actions, each starting with a verb.
10. **Footer** — sources (channel IDs, doc paths, dates), caveats (estimation method, what's authoritative vs sensitivity), report location.

Not every report needs every section. Adapt to the question. But keep the *order* — TL;DR before detail, recommendation before next steps.

## Visual system

Use the CSS template at `template.html` (next to this skill file). It defines:

- **Tokens:** `--bg`, `--card`, `--ink`, `--ink-muted`, `--ink-faint`, `--border`, `--accent` (blue), `--green`, `--amber`, `--red`, and `-soft` variants for backgrounds.
- **Typography:** system-ui stack, 15px base, 1.55 line-height. H1 34px, H2 22px with bottom border, H3 17px.
- **Components:** `.callout` (with `.warn` / `.good` variants), `.layers` grid, `.paths` cards with `.path.recommended` highlight, `table.components` + `table.tco`, `.tree` with numbered `.q` items, `.need` pills (`.high` / `.med` / `.low` / `.have`).
- **Responsive:** breakpoints at 900px (layer grid collapses, paths stack) and 600px (compact padding, smaller H1).

Copy the template's `<style>` block verbatim into the new report. Override tokens or add components as needed, but don't introduce new fonts or external assets.

## Sourcing and honesty rules

- **Cite sources in the footer.** Channel IDs, doc paths, dates of any retrieved context. Lets the reader verify.
- **Mark estimates as estimates.** TCO figures should be labeled "sensitivity scenarios, not authoritative" if assumptions are uncertain.
- **Surface what you don't know.** A caveat paragraph beats false confidence.
- **No Co-Authored-By trailers** if the report ever gets committed (see global Hard Rules).
- **Don't fabricate vendor pricing.** Use only figures retrieved from real sources (channel context, vendor pages, prior research). When unsure, write "list pricing as of report date, verify against current quote."

## Output sequence (what you do)

1. Determine output path (project `reports/` vs `~/reports/`).
2. `mkdir -p` the directory.
3. Write `index.html` with the full structure + the template's CSS.
4. `open <path>` to verify it renders.
5. Tell the user the path + a one-paragraph summary of the structure + the honest take embedded in the recommendation.

## Reference

The 2026-05-21 MDM comparison memo at `~/reports/mdm-comparison/index.html` is the canonical example of this skill's output shape. Read it before generating a new report if you need a refresher on the visual rhythm.
