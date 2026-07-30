#!/bin/bash
# PreToolUse hook (matcher Bash): hard block on raw shell file-mutation
# commands (cp/mv/rm/dd/tee/coreutils install, or `sed -i`) that touch a
# repo file -- the file-operations skill (.claude/skills/file-operations/)
# says "MUST use... mandatory for all file operations. Do NOT use native
# open(), shutil, or shell commands", but that's documentation, not
# enforcement: nothing actually stops a session from reaching for cp/sed -i
# anyway. Added 2026-07-30 after a full-session audit found this exact gap
# -- dozens of qualifying commands (building/writing .qplug and .qplugx
# files pulled from CI logs, bumping a version string with sed -i) ran as
# plain Bash the entire session, file-operations was never invoked once.
# Same reasoning as no-commit-on-main.sh: a reminder-only hook wouldn't
# have caught any of those, since nothing about them looked unusual on
# its own -- this needs a hard gate.
#
# Scratch-only commands are exempt: this hook protects the repo's own
# files, not ad hoc work in the scratchpad (CLAUDE.md's own scratch
# directory, always under /tmp) or elsewhere under /tmp generally -- that
# area was never file-operations' concern, and blocking it would only add
# friction with no real protection behind it.
#
# Deliberately conservative in the other direction too: read-only commands
# (plain `sed` with no `-i`, `cat`, `grep`, `ls`, ...) are never touched --
# only the specific mutating verbs below trigger the classifier at all.
set -euo pipefail

input="$(cat)"
tool_name="$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"

if [ "$tool_name" != "Bash" ]; then
  echo '{}'
  exit 0
fi

command="$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")"

if [ -z "$command" ]; then
  echo '{}'
  exit 0
fi

# Fast pre-filter in bash: only hand off to the (slower, more careful)
# Python classifier if a mutating verb appears as its own word anywhere in
# the command. `git mv`/`git rm` are excluded here (word immediately
# preceded by "git " is a git subcommand, not the raw coreutil) -- git's
# own permission allowlist in settings.json already governs those.
if ! echo "$command" | grep -qE '(^|[;&|]|\s)(cp|mv|rm|dd|tee|install)(\s|$)' \
   && ! echo "$command" | grep -qE '(^|[;&|]|\s)sed\s+.*-i\b'; then
  echo '{}'
  exit 0
fi

# The pre-filter above matches "rm"/"mv" even inside "git rm"/"git mv" --
# the Python classifier is what actually tells those apart (it skips any
# sub-command whose head token is "git"), so a lone `git mv`/`git rm`
# still passes through to `echo '{}'` at the end, just one step later.
#
# Classifier lives in lib/file_ops_classifier.py, not inline here (moved
# 2026-07-30, second bugfix round): a code-reviewer subagent, asked to
# review the FIRST rewrite of this classifier, actually ran constructed
# inputs against it rather than just reading the code, and found the
# glued-operator fix didn't cover `for x in a b; do <cmd>; done` on one
# line (the single most common loop shape, and the exact case this hook's
# own commit message claimed to fix) or a lone `&` backgrounding operator
# -- both silently let a dangerous command through. Extracting the
# classifier into its own importable module is what makes a real,
# committed regression suite (test_file_ops_classifier.py, same
# directory) possible instead of hand-verifying cases that turn out not
# to be the ones that matter.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
verdict="$(python3 "$script_dir/lib/file_ops_classifier.py" "$command")"

if [[ "$verdict" == OK* ]]; then
  echo '{}'
  exit 0
fi

reason="${verdict#BLOCK: }"
jq -n --arg reason "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: ("Bloquejat (file-operations mandatory): " + $reason + ". Fes servir el tool Write/Edit per a fitxers de codi/text, o .claude/skills/file-operations/scripts/fileops.py per copia/moviment/esborrat/streaming -- mai cp/mv/rm/dd/tee/sed -i en cru contra fitxers del repo. Zona /tmp/ (scratchpad) exempta.")}}'
