#!/bin/bash
# RETIRED (2026-07-31, explicit user request) -- unregistered from
# settings.json. The mandate this reminded about (every SKILL.md
# create/edit must go through skill-creator's full process) was itself
# reversed the same day: tried once for real on a doc-only skill edit, cost
# ~210k tokens across 4 subagents plus a real tooling bug, measured 0%
# behavioral difference. See CLAUDE.md's "Portable skills" section for the
# full reversal note. Left on disk rather than deleted, same as
# check-reply-format.sh/reply-format-preflight.sh before it -- dead, not
# maintained, do not re-register without a fresh standing rule to mechanize.
#
# Everything below is the original script, preserved for the record only.
#
# PreToolUse hook (matcher Write|Edit): mechanizes the "Skill creation/
# extension" rule in CLAUDE.md's "Portable skills" section -- any skill
# creation or extension (a new SKILL.md, or a content/frontmatter change to
# an existing one) must go through the skill-creator skill's process, not a
# plain manual edit.
#
# Citation fixed 2026-07-30: this said "Project-specific convention 5", and
# both halves were wrong -- the rule has always lived under "Portable
# skills", not "Project-specific rules", and no numbered convention 5 exists
# anywhere in CLAUDE.md, so the pointer resolved to nothing. Cited by section
# name only now; ordinals drift as soon as a list above them changes.
#
# Honest limitation, same shape as config-ingest-reminder.sh's: there is no
# hook event for "the skill-creator skill is currently active in this
# conversation" -- hooks only see the tool call itself, not which skill
# invoked it. So this CANNOT be a hard permission deny: blocking every
# Write/Edit to a SKILL.md file would also block skill-creator's own
# legitimate edits (it needs to write SKILL.md as part of doing its job),
# and a shell script has no way to tell the two cases apart. What IS
# mechanizable: a non-blocking reminder (additionalContext, same pattern as
# rule-check-reminder.sh/config-ingest-reminder.sh) fired every time a
# Write/Edit targets any SKILL.md, repo-specific or portable -- so the rule
# surfaces at the exact moment it could be skipped, even though enforcing it
# is still Claude's own judgment call, not a mechanical gate.
set -euo pipefail

input="$(cat)"
tool_name="$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"
file_path="$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")"

if [ "$tool_name" != "Write" ] && [ "$tool_name" != "Edit" ]; then
  echo '{}'
  exit 0
fi

case "$file_path" in
  *SKILL.md)
    msg="Recordatori de la regla 'Skill creation/extension' (CLAUDE.md, seccio 'Portable skills'): tota creacio o extensio d'una skill (SKILL.md nou, o canvi de contingut/frontmatter en un existent) ha de passar pel proces de la skill skill-creator, no una edicio manual directa. Si aquesta escriptura no ve d'una invocacio de skill-creator, atura't i invoca-la primer."
    jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $msg}}'
    ;;
  *)
    echo '{}'
    ;;
esac
