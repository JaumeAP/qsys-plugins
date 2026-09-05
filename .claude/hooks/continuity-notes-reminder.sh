#!/bin/bash
# SessionStart hook: surface docs/continuity-notes.md at session open.
#
# Added 2026-08-01, explicit user request: the "Tanca" close routine
# (rules/session-close.md) WRITES pending work into
# docs/continuity-notes.md, but nothing mechanized ever READ it back at
# the start of the next session -- a fresh chat only saw it if the user
# pointed at it. This closes that loop: if the file exists, inject a
# reminder naming its most recent entry (entries are appended, so the
# last "## " heading is the newest) and instruct reading the file before
# starting work. Portable and self-silencing: a repo without
# docs/continuity-notes.md gets no output at all.
set -euo pipefail

# Consume stdin (hook contract) even though this hook doesn't need it.
cat > /dev/null

project_dir="${CLAUDE_PROJECT_DIR:-.}"
notes="$project_dir/docs/continuity-notes.md"

if [ ! -f "$notes" ]; then
  echo '{}'
  exit 0
fi

latest="$(grep -E '^## ' "$notes" | tail -1 || true)"

msg="Aquest repo te docs/continuity-notes.md amb feina pendent o context de sessions anteriors. Llegeix-lo ABANS de comencar cap tasca."
if [ -n "$latest" ]; then
  msg="${msg} Entrada mes recent: '${latest#\#\# }'."
fi

jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $msg}}'
