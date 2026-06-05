# FORK provenance — `design`

Vendored from the **UI/UX Pro Max** bundle, not authored in-house.

| Field | Value |
|---|---|
| Upstream repo | https://github.com/nextlevelbuilder/ui-ux-pro-max-skill |
| Pinned commit | `b7e3af8` (PR #184) · bundle v2.5.0 |
| License | MIT (Copyright (c) 2024 Next Level Builder) |
| Vendored | 2026-05-29 |

## Why vendored instead of indexed in `marketplace/REFERENCE.md`

The bundle's published Claude Code plugin (`plugin.json`) registers **only**
`ui-ux-pro-max`. This skill ships in the bundle's git tree but has **no plugin
install path**, so `/plugin install` cannot deliver it — vendoring is the only
way to distribute it. `ui-ux-pro-max` itself is therefore indexed (not vendored)
in `marketplace/REFERENCE.md` per the "pin a marketplace, not a snapshot" rule;
these 6 design extras are the documented exception.

## Divergence from upstream

- No body changes to this skill's `SKILL.md`. **Opt-in deps:** the logo/icon/CIP generators need `GEMINI_API_KEY` + `pip install google-genai`; they read all key=value pairs from local `.env` files (incl. `~/.claude/.env`) into the process env but only use `GEMINI_API_KEY` and exfiltrate nothing.
- Dropped a committed `.coverage` binary from any `scripts/` dir.

## Re-sync

`git clone https://github.com/nextlevelbuilder/ui-ux-pro-max-skill` and copy
`.claude/skills/design/` over this directory, then re-check this FORK.md.
