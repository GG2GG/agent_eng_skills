#!/usr/bin/env bash
# goal-notify.sh — visible macOS notification + optional sound for goal-mode.
#
# Used by the `goal-mode` skill to surface progress while the native Claude
# Code `/goal` Stop-hook directive keeps the session working toward a
# completion condition. The skill calls this on each meaningful state change
# ("ping on each update") and on the ~5-minute periodic cadence.
#
# This is the ONLY visible-notification primitive verified on this machine:
#   osascript -e 'display notification "MSG" with title "TITLE" ...'
#
# Usage:
#   goal-notify.sh "<message>" [title] [subtitle] [sound]
#
# Defaults:
#   title    = "goal-mode"
#   subtitle = ""           (omitted from the AppleScript if empty)
#   sound    = "Glass"      (pass "none" to suppress the sound)
#
# Examples:
#   goal-notify.sh "Tests passing — 4/6 acceptance checks green"
#   goal-notify.sh "Build failed" "goal-mode" "needs attention" "Basso"
#   goal-notify.sh "Heartbeat: still working" "goal-mode" "5-min update" none
#
# Exit codes:
#   0  notification dispatched (or non-macOS no-op logged to stderr)
#   2  missing message argument

set -euo pipefail

MSG="${1:-}"
TITLE="${2:-goal-mode}"
SUBTITLE="${3:-}"
SOUND="${4:-Glass}"

if [ -z "$MSG" ]; then
  echo "goal-notify: message is required" >&2
  echo "usage: goal-notify.sh \"<message>\" [title] [subtitle] [sound]" >&2
  exit 2
fi

# Escape embedded double-quotes so the AppleScript string stays well-formed.
esc() { printf '%s' "$1" | sed 's/"/\\"/g'; }
MSG_E="$(esc "$MSG")"
TITLE_E="$(esc "$TITLE")"
SUBTITLE_E="$(esc "$SUBTITLE")"

# Build the AppleScript. Subtitle and sound clauses are optional.
script="display notification \"$MSG_E\" with title \"$TITLE_E\""
[ -n "$SUBTITLE_E" ] && script="$script subtitle \"$SUBTITLE_E\""
if [ -n "$SOUND" ] && [ "$SOUND" != "none" ]; then
  SOUND_E="$(esc "$SOUND")"
  script="$script sound name \"$SOUND_E\""
fi

if ! command -v osascript >/dev/null 2>&1; then
  # Non-macOS / no osascript — degrade gracefully so the skill still runs.
  echo "goal-notify (no osascript, stderr fallback): $TITLE — $MSG" >&2
  exit 0
fi

osascript -e "$script"
