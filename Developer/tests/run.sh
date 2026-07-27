#!/bin/bash
# Run the whole suite. Plain Lua 5.4, no test framework to install.
#
#   ./run.sh                 syntax-check every source, then run every test
#   ./run.sh --syntax-only   just the syntax pass
#
# Exits non-zero if anything fails, so it works as a pre-push check.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

LUA="${LUA:-lua5.4}"
LUAC="${LUAC:-luac5.4}"

command -v "$LUA"  >/dev/null || { echo "no $LUA on PATH (set LUA=...)"  >&2; exit 127; }
command -v "$LUAC" >/dev/null || { echo "no $LUAC on PATH (set LUAC=...)" >&2; exit 127; }

fails=0
pass() { printf '  \033[32mok\033[0m   %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fails=$((fails + 1)); }

echo "syntax"
while IFS= read -r -d '' f; do
	if "$LUAC" -p "$f" 2>/dev/null; then
		pass "${f#"$repo"/}"
	else
		fail "${f#"$repo"/}"
		"$LUAC" -p "$f" 2>&1 | sed 's/^/       /'
	fi
done < <(
	find "$repo/Developer/Modules" -name '*.lua' -print0
	find "$repo/Developer/plugins" -name '*.qplug' -print0
	find "$repo" -maxdepth 1 -name '*.qplug' -print0
)

[ "${1:-}" = "--syntax-only" ] && { echo; [ "$fails" -eq 0 ] && echo "syntax OK" || echo "$fails syntax failure(s)"; exit $((fails > 0)); }

echo
for t in test_modules test_plugin_defs test_dist_cpseries test_dist_fader; do
	echo "$t"
	if out=$("$LUA" "$here/$t.lua" 2>&1); then
		pass "$(printf '%s' "$out" | tail -1)"
	else
		fail "$t"
		printf '%s\n' "$out" | sed 's/^/       /'
	fi
done

# The format button must be accepted even with no format list reported yet:
# publishing an unresolvable format name used to crash the component.
echo
echo "wire trace"
if trace=$("$LUA" "$here/wire_trace.lua" --no-formlist 2>&1); then
	if printf '%s' "$trace" | grep -q CRASHED; then
		fail "format button before the format list arrives"
		printf '%s\n' "$trace" | grep CRASHED | sed 's/^/       /'
	else
		pass "format button before the format list arrives"
	fi
else
	fail "wire trace did not run"
	printf '%s\n' "$trace" | sed 's/^/       /'
fi

echo
if [ "$fails" -eq 0 ]; then echo "ALL OK"; else echo "$fails failure(s)"; fi
exit $((fails > 0))
