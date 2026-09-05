#!/bin/bash
# PostToolUse (Bash matcher) hook: fallback path for git-submodule
# initialization when init-submodules.sh's `git submodule update --init
# --recursive` fails (e.g. a git proxy blocking terminal-prompt auth on the
# submodule's own HTTPS clone -- the exact failure hit in this session).
#
# Fires after every Bash call; fast no-op unless the command is a `git
# clone` whose resulting origin URL matches a path registered in
# .gitmodules. When it matches, fetches this repo's pinned gitlink commit
# into the freshly cloned directory, checks it out, copies the tree into
# the registered submodule path, and absorbs its .git dir into the
# superproject.
#
# "AES67-ddriver" example dropped 2026-07-30: swept the whole repo
# (source, docs, continuity notes) for it and found nothing -- no
# submodule of that name has ever existed here. This hook is written
# generic on purpose (reads .gitmodules at runtime, not hardcoded), so
# the specific example was never load-bearing; it just doesn't belong to
# this repo's own history and risked being read as a false claim about
# it.
#
# Generic: reads .gitmodules at runtime, not hardcoded to any one
# submodule, so it keeps working if more submodules are added later.
set -euo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-.}"
cd "$project_dir"

[ -f .gitmodules ] || { echo '{}'; exit 0; }

input="$(cat)"
command="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"

case "$command" in
  *"git clone"*) ;;
  *) echo '{}'; exit 0 ;;
esac

exit_code="$(printf '%s' "$input" | jq -r '.tool_response.exitCode // .tool_response.exit_code // 0')"
[ "$exit_code" = "0" ] || [ "$exit_code" = "null" ] || { echo '{}'; exit 0; }

clone_dir="$(printf '%s' "$command" | grep -oE 'git clone[^&|;]*' | tail -1 | awk '{print $NF}')"
[ -n "$clone_dir" ] && [ -d "$clone_dir/.git" ] || { echo '{}'; exit 0; }

clone_url="$(git -C "$clone_dir" remote get-url origin 2>/dev/null || true)"
[ -n "$clone_url" ] || { echo '{}'; exit 0; }

norm() { printf '%s' "$1" | sed -E 's#^https?://##; s#\.git$##; s#/+$##' | tr '[:upper:]' '[:lower:]'; }
clone_url_norm="$(norm "$clone_url")"

declare -A sm_path sm_url
while read -r key value; do
  name="${key#submodule.}"
  case "$name" in
    *.path) sm_path["${name%.path}"]="$value" ;;
    *.url)  sm_url["${name%.url}"]="$value" ;;
  esac
done < <(git config -f .gitmodules --get-regexp 'submodule\..*\.(path|url)' 2>/dev/null || true)

match_path=""
for name in "${!sm_url[@]}"; do
  if [ "$(norm "${sm_url[$name]}")" = "$clone_url_norm" ]; then
    match_path="${sm_path[$name]:-}"
    break
  fi
done
[ -n "$match_path" ] || { echo '{}'; exit 0; }

pinned="$(git ls-tree HEAD -- "$match_path" 2>/dev/null | awk '{print $3}')"
[ -n "$pinned" ] || { echo '{}'; exit 0; }

emit() {
  jq -n --arg msg "$1" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $msg}}'
}

if ! git -C "$clone_dir" rev-parse -q --verify "${pinned}^{commit}" >/dev/null 2>&1; then
  if ! timeout 300s git -C "$clone_dir" fetch origin "$pinned" --depth 1 >/dev/null 2>&1; then
    emit "Avis: hook submodule-clone-fixup no ha pogut fer fetch del commit fixat ($pinned) per a $match_path des de $clone_dir -- revisa manualment."
    exit 0
  fi
fi
if ! git -C "$clone_dir" checkout -q "$pinned" 2>/dev/null; then
  emit "Avis: hook submodule-clone-fixup ha fet fetch de $pinned per a $match_path pero el checkout ha fallat -- revisa manualment a $clone_dir."
  exit 0
fi

target="$project_dir/$match_path"
if [ -e "$target" ]; then
  if [ -d "$target/.git" ] && current="$(git -C "$target" rev-parse -q --verify HEAD 2>/dev/null)" && [ "$current" = "$pinned" ]; then
    echo '{}'
    exit 0
  fi
  if [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
    emit "Avis: hook submodule-clone-fixup ha trobat contingut existent no buit a $match_path -- no l'ha tocat, revisa manualment abans de sobreescriure (clone llest a $clone_dir al commit $pinned)."
    exit 0
  fi
  rmdir "$target" 2>/dev/null || true
fi

if ! cp -a "$clone_dir" "$target"; then
  emit "Avis: hook submodule-clone-fixup no ha pogut copiar $clone_dir a $target -- revisa manualment."
  exit 0
fi
git -C "$project_dir" submodule absorbgitdirs -- "$match_path" >/dev/null 2>&1 || true

emit "Info: hook submodule-clone-fixup ha col.locat $match_path al commit fixat ($pinned) a partir del clone a $clone_dir i n'ha absorbit el .git."
