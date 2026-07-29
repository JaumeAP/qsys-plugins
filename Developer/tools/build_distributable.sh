#!/bin/bash
# Build a root-level single-file plugin distributable from its Developer/
# sources: the plugin definition head (PluginInfo + Get* callbacks), then
# every module it require()s pasted inline in dependency order, with the
# require lines stripped -- a distributed plugin resolves no module path,
# so it has to be one self-contained file.
#
# Usage: build_distributable.sh [--bump ver_maj|ver_min|ver_fix|ver_dev] <head.qplug> <output.qplug> [pre...] -- <post...>
#   --bump LEVEL   optional; bumps head.qplug's own BuildVersion octet
#                  in place, before building, mirroring QSC's own
#                  PluginCompile (vendor/qsys-plugins/BasePlugin/PluginCompile)
#                  ver_maj/ver_min/ver_fix/ver_dev build arguments: ver_maj
#                  -> N+1.0.0.0, ver_min -> maj.N+1.0.0, ver_fix ->
#                  maj.min.N+1.0, ver_dev -> maj.min.fix.N+1 (each level
#                  zeroes everything after it). ver_maj/ver_min also update
#                  the public Version field's major.minor to match, same as
#                  PluginCompile's own documented behavior. Omit to leave
#                  the version untouched (the previous, still-supported
#                  default -- bump by hand, then build).
#   <head.qplug>   Developer/plugins/*.qplug source (defines PluginInfo,
#                  Get* callbacks, ends with the runtime guard)
#   <output.qplug> where to write the built file (repo root, normally)
#   [pre...]       Developer/Modules/<name>.lua modules inlined BEFORE the
#                  runtime guard -- for a module a design-time function
#                  (GetControls/GetControlLayout/...) reads, e.g. qsys_enums.
#                  Optional; omit if the plugin has none.
#   --             separator, always required if <post...> is non-empty
#   <post...>      Developer/Modules/<name>.lua modules inlined AFTER the
#                  runtime guard, i.e. runtime-only (qknob, dolbyfader, ...)
# Within each group, order matters the way require() order would: a module
# used by a later one goes first.
#
# Three things this has to get right, found the hard way building the
# CPSeries and DolbyFader distributables:
#   * pre-guard vs. post-guard placement. A module inlined only after the
#     guard never runs during the definition pass (Controls is nil, so the
#     guard returns before reaching it) -- fine for runtime-only modules,
#     wrong for one a design-time Get* function reads, which needs to be
#     defined during BOTH passes.
#   * the guard-line pattern must tolerate a trailing CR -- some Developer
#     heads are CRLF (DolbyFader's is; CPSeries's is not), so a bare
#     '$'-anchored match silently fails on those and sed copies the WHOLE
#     file instead of just the head, dragging the closing require() into
#     the build. Guarded against below with an explicit check, not just a
#     tolerant pattern, because a silent failure here is worse than a loud
#     one.
#   * output line endings follow the head's own (CRLF in, CRLF out; LF in,
#     LF out) rather than always normalizing to one or the other, so a
#     mixed-EOL head doesn't produce a mixed-EOL build.
set -euo pipefail

bump=""
if [ "${1:-}" = "--bump" ]; then
	bump="$2"; shift 2
	case "$bump" in
		ver_maj|ver_min|ver_fix|ver_dev) ;;
		*) echo "ERROR: --bump must be one of ver_maj|ver_min|ver_fix|ver_dev (got '$bump')" >&2; exit 1 ;;
	esac
fi

if [ "$#" -lt 2 ]; then
	echo "usage: $0 [--bump ver_maj|ver_min|ver_fix|ver_dev] <head.qplug> <output.qplug> [pre...] -- <post...>" >&2
	exit 1
fi

head_src="$1"; out="$2"; shift 2

pre=(); post=(); seen_sep=0
for a in "$@"; do
	if [ "$a" = "--" ]; then seen_sep=1; continue; fi
	if [ "$seen_sep" -eq 0 ]; then pre+=("$a"); else post+=("$a"); fi
done

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mods="$repo/Developer/Modules"
tmp="$(mktemp)"
trap 'rm -f "$tmp" "$tmp.head"' EXIT

if [ -n "$bump" ]; then
	old_line="$(grep -m1 -E '^[[:space:]]*BuildVersion[[:space:]]*=[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"' "$head_src")" || {
		echo "ERROR: no BuildVersion = \"N.N.N.N\" line found in '$head_src'" >&2
		exit 1
	}
	old_ver="$(echo "$old_line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')"
	IFS='.' read -r maj min fix dev <<<"$old_ver"
	case "$bump" in
		ver_maj) maj=$((maj + 1)); min=0; fix=0; dev=0 ;;
		ver_min) min=$((min + 1)); fix=0; dev=0 ;;
		ver_fix) fix=$((fix + 1)); dev=0 ;;
		ver_dev) dev=$((dev + 1)) ;;
	esac
	new_ver="$maj.$min.$fix.$dev"
	sed -i -E "s/BuildVersion[[:space:]]*=[[:space:]]*\"$old_ver\"/BuildVersion = \"$new_ver\"/" "$head_src"
	if [ "$bump" = "ver_maj" ] || [ "$bump" = "ver_min" ]; then
		sed -i -E "s/Version[[:space:]]*=[[:space:]]*\"[0-9]+\.[0-9]+\"/Version = \"$maj.$min\"/" "$head_src"
	fi
	echo "Bumped BuildVersion: $old_ver -> $new_ver" >&2
fi

crlf=0
if LC_ALL=C grep -q $'\r$' "$head_src"; then crlf=1; fi

sed -n '1,/^if not Controls and Reflect then return end\r\?$/p' "$head_src" > "$tmp.head"

if ! tail -1 "$tmp.head" | grep -qE '^if not Controls and Reflect then return end\r?$'; then
	echo "ERROR: '$head_src' has no 'if not Controls and Reflect then return end' guard line" >&2
	exit 1
fi

REQUIRE_RE='^[[:space:]]*require[[:space:]]*\(?["'"'"']'

emit_module() {
	local name="$1" mod="$mods/$1.lua"
	[ -f "$mod" ] || { echo "ERROR: no such module '$mod'" >&2; exit 1; }
	printf '\ndo  -- %s\n' "$name" >> "$tmp"
	grep -v -E "$REQUIRE_RE" "$mod" >> "$tmp"
	printf 'end\n' >> "$tmp"
}

# Everything up to (not including) the guard line, with the guard's own
# require()s of pre-guard modules stripped -- those modules are inlined
# below in their place instead.
head -n -1 "$tmp.head" | grep -v -E "$REQUIRE_RE" > "$tmp"
for name in "${pre[@]+"${pre[@]}"}"; do emit_module "$name"; done
tail -1 "$tmp.head" >> "$tmp"   # the guard line itself, last
rm -f "$tmp.head"

if grep -qE "$REQUIRE_RE" "$tmp"; then
	echo "ERROR: head extraction overran the guard line in '$head_src' -- got a require() in the head" >&2
	exit 1
fi

cat >> "$tmp" <<'EOF'

-- ============================================================
-- Inlined modules (single-file build, no require / no package.path).
-- Generated from Developer/plugins/ + Developer/Modules/ -- edit there,
-- not here, then rebuild this file (Developer/tools/build_distributable.sh).
-- ============================================================
EOF

for name in "${post[@]+"${post[@]}"}"; do emit_module "$name"; done

if [ "$crlf" -eq 1 ]; then
	sed -e 's/\r$//' -e 's/$/\r/' "$tmp" > "$out"
else
	cp "$tmp" "$out"
fi

LUAC="${LUAC:-luac5.3}"
if command -v "$LUAC" >/dev/null; then
	"$LUAC" -p "$out"
fi
echo "Built: $out ($(wc -l < "$out") lines)"
