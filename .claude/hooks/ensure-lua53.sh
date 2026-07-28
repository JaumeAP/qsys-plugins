#!/bin/bash
# SessionStart hook: make sure lua5.3 (and luac5.3) are on PATH before any
# other work happens, since Developer/tests/run.sh needs them and this
# repo's own convention is Lua 5.3 specifically (matching Q-SYS Designer's
# embedded Lua version, not 5.4 -- see CLAUDE.md's "What this repo is").
# A fresh container/session may not have it installed at all (confirmed
# 2026-07-27: this exact gap required a manual `apt-get install lua5.3`
# mid-session before the test suite could run).
#
# Project-specific, NOT part of the portable bundle (per
# config-export-import.md's own example of what stays out of the export:
# "a hook that installs a language runtime or interpreter only this
# repo's own test suites need") -- not added to export-config-skill.sh's
# hook-copy list, deliberately.
#
# Best-effort only: if apt-get isn't usable (no network, no privileges),
# this stays silent rather than blocking session start -- the test suite
# itself already fails loudly and specifically ("no lua5.3 on PATH") if
# it's still missing when actually needed.
set -euo pipefail

if command -v lua5.3 >/dev/null 2>&1 && command -v luac5.3 >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

if timeout 120s apt-get update >/dev/null 2>&1 && timeout 120s apt-get install -y lua5.3 >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

jq -n '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: "lua5.3 no es al PATH i la instal.lacio automatica (apt-get install lua5.3) ha fallat o no era possible -- cal instal.lar-lo a ma abans de Developer/tests/run.sh."}}'
