#!/bin/bash
# PreToolUse/Bash hook: skill-security-auditor gate reminder.
#
# Fires at the actual install moment -- a Bash command running
# `npx skills add ...` -- rather than tying the reminder to an edit of
# recommended-skills.txt/programming-optional-skills.txt (2026-08-01,
# explicit user correction: catching the catalog-file edit misses any
# install that never gets recorded there; the catalog edit is a side
# effect, installing is the actual action to gate on).
#
# Non-blocking (additionalContext), same reason skill-security-auditor's
# own catalog note says "highly recommended, not mandatory": this hook can
# check whether a "security-audited" note ALREADY exists for the
# owner/repo being installed, but it cannot verify that note reflects a
# real audit rather than a rubber-stamp -- so it can only ever remind,
# never hard-block, unlike file-operations-enforcement.sh's PreToolUse/Bash
# gate for a different, mechanically-verifiable case.
set -euo pipefail

input="$(cat)"
command="$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"

if ! echo "$command" | grep -qE 'npx +skills +add'; then
  echo '{}'
  exit 0
fi

repo="$(echo "$command" | grep -oE 'npx +skills +add +[^ ]+' | head -1 | awk '{print $NF}')"
project_dir="${CLAUDE_PROJECT_DIR:-.}"

# Guard against false positives from prose that merely CONTAINS the text
# "npx skills add owner/repo" (e.g. this very hook's own commit message,
# a doc edit, a heredoc) rather than a real shell invocation of it: a
# genuine owner/repo argument is bare alnum/./-/_ with exactly one slash,
# no markdown backticks, angle brackets, or newlines. Caught in the wild
# 2026-08-01: this hook fired on its own introducing commit because the
# commit message's `npx skills add <owner/repo> ...` example text matched
# the old unanchored pattern.
if [ -z "$repo" ] || ! echo "$repo" | grep -qE '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
  echo '{}'
  exit 0
fi

already_audited=0
for catalog in "$project_dir/.claude/recommended-skills.txt" "$project_dir/.claude/programming-optional-skills.txt"; do
  if [ -f "$catalog" ] && grep -E -- "-> ${repo}\$" "$catalog" 2>/dev/null | grep -qi "security-audited"; then
    already_audited=1
  fi
done

if [ "$already_audited" -eq 1 ]; then
  echo '{}'
  exit 0
fi

msg="Estas a punt d'instal.lar un skill via 'npx skills add' ('${repo}') sense nota 'security-audited' a cap catalog (recommended-skills.txt/programming-optional-skills.txt). Invoca skill-security-auditor (els 3 escaners: prompt_injection_scanner, code_scanner, supply_chain_checker) abans de deixar-lo instal.lat, i registra el veredicte al catalog corresponent segons la regla vigent 2026-08-01."
jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $msg}}'
