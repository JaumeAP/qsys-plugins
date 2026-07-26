#!/bin/bash
# PreToolUse hook (matcher Write|Edit): mechanizes CLAUDE.md's Project-
# specific convention 5 -- any skill creation or extension (a new SKILL.md,
# or a content/frontmatter change to an existing one) must go through the
# skill-creator skill's process, not a plain manual edit.
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
    msg="Recordatori de la convencio 5 (CLAUDE.md, Project-specific rules): tota creacio o extensio d'una skill (SKILL.md nou, o canvi de contingut/frontmatter en un existent) ha de passar pel proces de la skill skill-creator, no una edicio manual directa. Si aquesta escriptura no ve d'una invocacio de skill-creator, atura't i invoca-la primer."
    jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $msg}}'
    ;;
  *)
    echo '{}'
    ;;
esac
