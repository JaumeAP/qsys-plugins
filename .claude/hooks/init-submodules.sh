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

# Recursive: a vendored submodule can itself declare nested submodules of
# its own, and --recursive is what actually reaches those (plain --init
# alone stops one level deep). Kept generic here on purpose -- any
# specific history behind why a particular repo needed this (duplicate
# vendoring avoided, a nested submodule's exact path, etc.) belongs in
# that repo's own CLAUDE.md Project-specific rules, not repeated in this
# portable hook's comments, since this file travels unchanged across
# repos via the config export bundle.
#
# Bounded with `timeout` so a stuck submodule fetch (dead remote, auth
# prompt with no TTY, etc.) can't hang the session start indefinitely.
# Raised from 60s to 180s 2026-07-30: a cold container cloning several
# submodules at once, one of which carries Windows binaries and DLLs, can
# plausibly exceed a minute, and the failure mode is silent -- `|| true`
# swallows it and the tree is left partially initialized.
#
# The exit status is captured rather than discarded (2026-07-30). Found by
# hitting the consequence: a whole session ran with both nested
# PluginCompile submodules uninitialized, so PLUGCC.exe -- the compiler the
# documented build workflow depends on -- was simply absent, while
# CLAUDE.md asserted a fresh clone gets it automatically. Re-running the
# very same command by hand fixed it in about a second, so the automatic
# attempt had failed or been cut short at session start without anything
# saying so.
init_rc=0
timeout 180s git submodule update --init --recursive >/dev/null 2>&1 || init_rc=$?

status="$(git submodule status --recursive 2>/dev/null || true)"

if ! grep -q '^-' <<<"$status"; then
  echo '{}'
  exit 0
fi

# The old message assumed one cause -- a private repo needing add_repo --
# and led with that remedy. That is the wrong first move for a public
# submodule whose clone merely got cut short, which is the case actually
# observed here. Lead with the plain retry, name add_repo only as the
# fallback for a genuinely inaccessible repo, and say which of the two the
# exit status points at.
case "$init_rc" in
  0)   why="l'ordre automatica ha retornat OK pero han quedat sense inicialitzar igualment" ;;
  124) why="l'ordre automatica ha superat el timeout de 180s i s'ha tallat a mitges" ;;
  *)   why="l'ordre automatica ha fallat (codi $init_rc)" ;;
esac
msg="Submoduls sense inicialitzar despres de l'intent automatic ($why). Prova primer el reintent directe, que sol ser suficient si nomes es va tallar: 'git submodule update --init --recursive'. Si un path concret segueix fallant, aleshores si que apunta a un repo inaccessible per aquesta sessio:"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  path="$(awk '{print $2}' <<<"$line")"
  name="$(git config -f .gitmodules --get-regexp '\.path$' 2>/dev/null | awk -v p="$path" '$2==p {print $1}' | sed -E 's/^submodule\.(.*)\.path$/\1/')"
  url="$(git config -f .gitmodules --get "submodule.$name.url" 2>/dev/null || echo "")"
  msg="$msg
- $path ($url): si el reintent no l'arregla, crida add_repo amb l'owner/repo d'aquesta URL i despres 'git submodule update --init $path'."
done < <(grep '^-' <<<"$status")

jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $msg}}'
