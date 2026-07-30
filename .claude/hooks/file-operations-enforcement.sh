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
# the Python classifier below is what actually tells those apart (it skips
# any sub-command whose head token is "git"), so a lone `git mv`/`git rm`
# still passes through to `echo '{}'` at the end, just one step later.
verdict="$(python3 - "$command" <<'PYEOF'
import re, shlex, sys

cmd = sys.argv[1]

DANGEROUS = {"cp", "mv", "rm", "dd", "tee", "install"}

def is_scratch(path):
    return path.startswith("/tmp/")

def looks_like_path(tok):
    if tok.startswith("-"):
        return False
    if "/" in tok:
        return True
    # bare filename with a dotted extension, no flag prefix
    return bool(re.search(r"\.[A-Za-z0-9]{1,8}$", tok)) or tok not in {"", "|", "&&", "||", ";"}

try:
    tokens = shlex.split(cmd)
except ValueError:
    # Unbalanced quotes or similar -- can't safely classify, block rather
    # than silently let something unparseable slip through.
    print("BLOCK: could not parse the command to check its file targets")
    sys.exit(0)

# Split on shell operators (;, &&, ||, and pipe |) into independent
# sub-commands (shlex.split already tokenized quoting correctly; operators
# survive as their own tokens since they aren't inside quotes in any real
# invocation). Pipe matters here specifically because `echo x | tee
# repo-file` is exactly the shape file-operations exists to replace.
subcommands, current = [], []
for tok in tokens:
    if tok in (";", "&&", "||", "|"):
        if current:
            subcommands.append(current)
        current = []
    else:
        current.append(tok)
if current:
    subcommands.append(current)

for sub in subcommands:
    if not sub:
        continue
    head = sub[0]
    if head == "git":
        continue  # git's own allowlist governs this, not this hook
    is_sed_i = head == "sed" and any(
        a == "-i" or a.startswith("-i") or a in ("--in-place",) for a in sub[1:]
    )
    if head not in DANGEROUS and not is_sed_i:
        continue
    args = sub[1:]
    if is_sed_i:
        # sed's own script argument ('s/a/b/', an -e value, ...) routinely
        # contains '/' and would otherwise misclassify as a path. Skip the
        # first non-flag argument (the script) before collecting real file
        # targets -- covers the common `sed -i 'script' file...` form this
        # repo's own hooks and this session both use; an -e/-f script is
        # still a flag argument here and correctly never skipped as a
        # "target".
        skipped_script = False
        args_for_targets = []
        for a in args:
            if not skipped_script and not a.startswith("-"):
                skipped_script = True
                continue
            args_for_targets.append(a)
        args = args_for_targets
    targets = [a for a in args if looks_like_path(a)]
    outside_scratch = [t for t in targets if not is_scratch(t)]
    if outside_scratch:
        print(
            "BLOCK: '%s' touches a repo path outside /tmp (%s)"
            % (" ".join(sub), ", ".join(outside_scratch))
        )
        sys.exit(0)

print("OK")
PYEOF
)"

if [[ "$verdict" == OK* ]]; then
  echo '{}'
  exit 0
fi

reason="${verdict#BLOCK: }"
jq -n --arg reason "$reason" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: ("Bloquejat (file-operations mandatory): " + $reason + ". Fes servir el tool Write/Edit per a fitxers de codi/text, o .claude/skills/file-operations/scripts/fileops.py per copia/moviment/esborrat/streaming -- mai cp/mv/rm/dd/tee/sed -i en cru contra fitxers del repo. Zona /tmp/ (scratchpad) exempta.")}}'
