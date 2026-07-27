#!/bin/bash
# SessionStart hook: when a new chat/session begins, initialize and update
# every git submodule first, before any other work happens, so the working
# tree is complete from the session's very first tool call. No-op (empty
# output) when the repo has no .gitmodules -- this repo doesn't today, but
# the hook stays generic so it keeps working the moment one gets added,
# without needing to be revisited. Exported: listed by name in
# export-config-skill.sh's hook allowlist, same as every other generic
# hook here.
#
# Generic uninitialized-submodule handling (2026-07-24): if any submodule is
# still uninitialized after the plain attempt (typically a private repo not
# yet accessible to this session), emit an actionable instruction --
# owner/repo looked up generically from .gitmodules (path + URL), never
# hardcoded to any particular project's submodules, since this hook is
# meant to travel unchanged across repos via the config export bundle. A
# target repo can layer its own standing CLAUDE.md rule on top to make
# acting on this fully automatic, and pre-approve `add_repo` in its own
# settings.json if it wants zero session-start friction -- neither of those
# is assumed or done here, that's a per-repo decision.
#
# Status checks use command substitution + a here-string for grep, NOT a
# live `cmd | grep -q` pipe: under `set -o pipefail`, `grep -q` closes its
# stdin as soon as it finds a match, so an upstream writer producing
# multiple lines with any gap between them (e.g. `git submodule status`
# over several paths) can get SIGPIPE (exit 141) even though grep matched
# correctly -- pipefail then reports the pipeline as failed. Capturing to a
# variable first sidesteps this (the writer already exited before grep
# ever runs).
set -euo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-.}"
cd "$project_dir"

if [ ! -f .gitmodules ]; then
  echo '{}'
  exit 0
fi

# Non-recursive deliberately (2026-07-27): a submodule this repo vendors as
# read-only reference material can itself declare its own nested submodules
# (its own build tooling, its own dependencies) that this repo has no use
# for -- and worse, a nested submodule can be the EXACT SAME repo this
# project already vendors directly elsewhere (found here: qsys-plugins/
# BasePlugin and qsys-plugins/ExamplePlugin both carry their own nested
# "PluginCompile" submodule, the identical repo this project also vendors
# at the top level as vendor/qsys-plugins/PluginCompile -- --recursive would
# have cloned it a second and third time). Plain `--init` only populates
# what THIS repo's own .gitmodules lists; a submodule's own nested
# submodules are left as empty, harmless gitlink placeholders. If a repo
# genuinely needs a vendored submodule's own nested content, that's a
# deliberate `git submodule update --init --recursive <path>` on the one
# path that needs it, not a blanket default here.
#
# Bounded with `timeout` so a stuck submodule fetch (dead remote, auth
# prompt with no TTY, etc.) can't hang the session start indefinitely.
timeout 60s git submodule update --init >/dev/null 2>&1 || true

status="$(git submodule status 2>/dev/null || true)"

if ! grep -q '^-' <<<"$status"; then
  echo '{}'
  exit 0
fi

msg="Alguns submoduls encara no estan inicialitzats despres de l'intent automatic (sovint un repo privat encara fora de l'abast d'aquesta sessio):"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  path="$(awk '{print $2}' <<<"$line")"
  name="$(git config -f .gitmodules --get-regexp '\.path$' 2>/dev/null | awk -v p="$path" '$2==p {print $1}' | sed -E 's/^submodule\.(.*)\.path$/\1/')"
  url="$(git config -f .gitmodules --get "submodule.$name.url" 2>/dev/null || echo "")"
  msg="$msg
- $path ($url): crida add_repo amb l'owner/repo d'aquesta URL, i despres 'git submodule update --init $path'."
done < <(grep '^-' <<<"$status")

jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $msg}}'
