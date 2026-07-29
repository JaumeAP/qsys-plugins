#!/bin/bash
# Build a root-level single-file plugin distributable by running QSC's own
# PLUGCC.exe inliner (vendor/qsys-plugins/BasePlugin/PluginCompile) against
# the Developer/ sources, instead of build_distributable.sh's explicit
# pre/post module list. No manual module list: this script walks the
# require("X") calls already in the head file and (recursively) in every
# Developer/Modules/*.lua file they pull in, computes a topological order
# over that dependency graph, and hands PLUGCC.exe a flat, deduplicated
# sequence of `--[[ #include "X.lua" ]]` blocks -- one per module, each
# appearing exactly once, after all of its own dependencies.
#
# Flattening (rather than converting each require in place to a nested
# #include, and letting PLUGCC's own recursive #include resolution handle
# it -- confirmed 2026-07-29 to work, but only tried first) is necessary
# because PLUGCC's #include is pure textual substitution with no
# require()-style load-once caching: two modules that both depend on a
# third (cpseries_commlib and cpseries_protocol both require
# cpseries_models) would each carry their own #include of it, so a naive
# nested conversion pastes cpseries_models.lua's body in twice. Flattening
# to a single per-module block, in dependency order, is exactly what
# build_distributable.sh's manual pre/post list already did by hand; this
# script just computes that list instead of taking it as an argument.
#
# The dev-only `require "strict"` + `Global(...)` block (see CLAUDE.md's
# "Key module patterns") is dropped, not converted -- same as
# build_distributable.sh's guard-line truncation: strict-mode must never
# ship to production.
#
# Usage: build_distributable_plugcc.sh <head.qplug> <output.qplug>
#
# Requires the vendored PLUGCC.exe (a Windows .NET Framework 4.8 binary)
# plus something to run it: PLUGCC_RUNNER env var (default "mono"); set it
# to the empty string on native Windows (e.g. a windows-latest GitHub
# Actions runner using `shell: bash`) to invoke PLUGCC.exe directly instead.
# Override the binary path with PLUGCC_EXE.
#
# Known limitations (none hit by the four plugins here today, 2026-07-29):
#   * every require() in the head, wherever it sits, is treated as
#     post-guard -- unlike build_distributable.sh, this script has no
#     concept of the pre-guard module group (a module a design-time
#     Get*/GetControlLayout function needs, not just the runtime). A future
#     plugin needing that would get silently wrong load-order behaviour,
#     not an error.
#   * require() only ever means "a Developer/Modules/*.lua file" here -- a
#     require of a genuine Q-SYS host library extension (require("json"),
#     require("rapidjson"), require("lpeg"), ...) fails the build loudly
#     (no file under Developer/Modules/ matches), it is not passed through.
#   * only the head's own `require "strict"` + `Global(...)` lines are
#     stripped; a `Global(...)` call inside a Developer/Modules/*.lua file
#     itself would ship as-is and fail at runtime (`Global` is undefined
#     outside of strict.lua). No module currently has one.
set -euo pipefail

if [ "$#" -ne 2 ]; then
	echo "usage: $0 <head.qplug> <output.qplug>" >&2
	exit 1
fi

head_src="$1"; out="$2"

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mods="$repo/Developer/Modules"
plugcc_exe="${PLUGCC_EXE:-$repo/vendor/qsys-plugins/BasePlugin/PluginCompile/PLUGCC.exe}"
plugcc_runner="${PLUGCC_RUNNER:-mono}"

[ -f "$head_src" ] || { echo "ERROR: no such file '$head_src'" >&2; exit 1; }
[ -f "$plugcc_exe" ] || { echo "ERROR: PLUGCC.exe not found at '$plugcc_exe'" >&2; exit 1; }

crlf=0
if LC_ALL=C grep -q $'\r$' "$head_src"; then crlf=1; fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# Strip \r before matching below (CRLF would otherwise break the regexes);
# CRLF is restored on the final combined output only, matching
# build_distributable.sh's own head-driven convention, not per source file.
strip_cr() { sed 's/\r$//' "$1"; }

# Q-SYS require() resolves case-insensitively on the Windows/macOS
# filesystems Designer actually runs on -- e.g. `require "CPSeries"` against
# `cpseries.lua` (see CLAUDE.md's cpseries.lua note). This container's
# filesystem is case-sensitive, so every module reference below is resolved
# through this lowercase-name -> real-name lookup rather than trusting the
# require call's own casing.
declare -A mod_real_name
for mod in "$mods"/*.lua; do
	real="$(basename "$mod" .lua)"
	mod_real_name["${real,,}"]="$real"
done

# Every caller of resolve_module runs inside a `< <(...)` process
# substitution subshell (list_requires, below); `exit 1` there only kills
# that subshell, never the parent script (confirmed 2026-07-29 -- a
# require() of a name with no matching Modules/ file, e.g. a typo, or a
# perfectly legitimate host-library require like require("json"), was
# silently swallowed: the ERROR line printed, but the build carried on and
# wrote out a truncated .qplug with exit code 0). An error sentinel file is
# the fix: written here, checked by the caller once it's back in the main
# shell.
errfile="$workdir/ERROR"
resolve_module() {
	local name="$1" src="$2"
	local real="${mod_real_name[${name,,}]:-}"
	if [ -z "$real" ]; then
		echo "ERROR: require \"$name\" in '$src' matches no file under '$mods'" >> "$errfile"
		exit 1
	fi
	printf '%s' "$real"
}

check_errfile() {
	if [ -s "$errfile" ]; then
		cat "$errfile" >&2
		exit 1
	fi
}

# Every non-strict module name a file require()s, in order, real-cased.
list_requires() {
	local src="$1"
	local line name
	while IFS= read -r line || [ -n "$line" ]; do
		if [[ "$line" =~ ^[[:space:]]*require[[:space:]]*\(?[\"\']strict[\"\']\)?[[:space:]]*$ ]]; then
			continue
		fi
		if [[ "$line" =~ require[[:space:]]*\(?[\"\']([A-Za-z0-9_]+)[\"\']\)? ]]; then
			name="${BASH_REMATCH[1]}"
			[ "${name,,}" = "strict" ] && continue
			resolve_module "$name" "$src"
			printf '\n'
		fi
	done < <(strip_cr "$src")
}

# Topological order (dependencies before dependents) over the transitive
# closure of $head_src's own requires, via post-order DFS.
declare -A visited
order=()
visit() {
	local n="$1"
	[ -n "${visited[$n]:-}" ] && return
	visited[$n]=1
	local d
	while IFS= read -r d; do
		[ -n "$d" ] && visit "$d"
	done < <(list_requires "$mods/$n.lua")
	order+=("$n")
}
while IFS= read -r root; do
	[ -n "$root" ] && visit "$root"
done < <(list_requires "$head_src")
check_errfile   # see resolve_module's comment -- a failure in the traversal
                # above only killed a subshell, this is what actually stops
                # the build on an unresolved require()

# Head: strip the dev-only strict/Global block and every require line
# (each module require in the head now moot -- covered by the flattened
# block below); emit the flattened, deduplicated #include sequence at the
# position of the FIRST require line the head had.
convert_head() {
	local src="$1" dst="$2"
	local emitted=0 line
	: > "$dst"
	while IFS= read -r line || [ -n "$line" ]; do
		if [[ "$line" =~ ^[[:space:]]*require[[:space:]]*\(?[\"\']strict[\"\']\)?[[:space:]]*$ ]]; then
			continue
		fi
		if [[ "$line" =~ ^[[:space:]]*Global[[:space:]]*\( ]]; then
			continue
		fi
		if [[ "$line" =~ require[[:space:]]*\(?[\"\']([A-Za-z0-9_]+)[\"\']\)? ]]; then
			if [ "$emitted" -eq 0 ]; then
				local m
				for m in "${order[@]}"; do
					printf 'do -- %s\n--[[ #include "%s.lua" ]]\nend\n' "$m" "$m" >> "$dst"
				done
				emitted=1
			fi
			continue
		fi
		printf '%s\n' "$line" >> "$dst"
	done < <(strip_cr "$src")
}

# Module copies fed to PLUGCC: strip internal require lines entirely (no
# #include either) -- the head's flattened block already guarantees every
# dependency has run by the time it's needed, same as
# build_distributable.sh's own `grep -v` stripping.
convert_module() {
	local src="$1" dst="$2"
	local line
	: > "$dst"
	while IFS= read -r line || [ -n "$line" ]; do
		if [[ "$line" =~ ^[[:space:]]*require[[:space:]]*\(?[\"\'][A-Za-z0-9_]+[\"\']\)?[[:space:]]*$ ]]; then
			continue
		fi
		printf '%s\n' "$line" >> "$dst"
	done < <(strip_cr "$src")
}

convert_head "$head_src" "$workdir/plugin.lua"
for name in "${order[@]}"; do
	convert_module "$mods/$name.lua" "$workdir/$name.lua"
done

basename_arg="$(basename "$out" .qplug)"
if [ -n "$plugcc_runner" ]; then
	( cd "$workdir" && "$plugcc_runner" "$plugcc_exe" "$basename_arg" "$workdir/plugin.lua" )
else
	# Native execution (Windows CI): set PLUGCC_RUNNER="" to skip mono.
	( cd "$workdir" && "$plugcc_exe" "$basename_arg" "$workdir/plugin.lua" )
fi

built="$workdir/$basename_arg.qplug"
[ -f "$built" ] || { echo "ERROR: PLUGCC did not produce '$built'" >&2; exit 1; }

if [ "$crlf" -eq 1 ]; then
	sed -e 's/\r$//' -e 's/$/\r/' "$built" > "$out"
else
	sed 's/\r$//' "$built" > "$out"
fi

LUAC="${LUAC:-luac5.3}"
if command -v "$LUAC" >/dev/null; then
	"$LUAC" -p "$out"
fi
echo "Built: $out ($(wc -l < "$out") lines) via PLUGCC.exe -- modules: ${order[*]}"
