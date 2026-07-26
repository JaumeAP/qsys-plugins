#!/bin/bash
# PreToolUse hook (matcher Bash): hard block on `git commit` while HEAD is
# on `main` -- never commit directly on main, work happens on a branch.
# Added 2026-07-24 after a real incident: a session-close merge
# ended with `git checkout main && git merge <branch> && git push origin
# main` and no trailing checkout back to the branch, so the NEXT commit
# in the same session landed on `main` directly instead of the branch.
# A reminder-only hook wouldn't have caught it (nothing about that commit
# looked unusual on its own) -- this needs a hard gate, same tier as
# require-handoff-read.sh, not a nudge.
#
# Exception: a `git commit` while a merge is in progress (MERGE_HEAD
# exists) is legitimate even on `main` -- that's finishing a conflicted
# merge from a branch into main, not fresh work being committed directly
# on main. Only a commit with no merge in progress is blocked.
set -euo pipefail

input="$(cat)"
tool_name="$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"

if [ "$tool_name" != "Bash" ]; then
  echo '{}'
  exit 0
fi

command="$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"

if ! echo "$command" | grep -qE '(^|[;&|]|\s)git\s+(-C\s+\S+\s+)?commit\b'; then
  echo '{}'
  exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-.}"

if ! git -C "$project_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

branch="$(git -C "$project_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
if [ "$branch" != "main" ]; then
  echo '{}'
  exit 0
fi

git_dir="$(git -C "$project_dir" rev-parse --git-dir 2>/dev/null || echo "")"
if [ -n "$git_dir" ] && [ -f "$git_dir/MERGE_HEAD" ]; then
  echo '{}'   # finishing a conflicted merge -- legitimate even on main
  exit 0
fi

jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "Bloquejat: no es pot fer git commit directament a main. Canvia a la branca de treball primer (git checkout <branca>) i fes el commit alla."}}'
