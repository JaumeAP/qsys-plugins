#!/bin/bash
# Three-way mechanization (best-effort) of the config-ingest/export rule
# defined in .claude/config-export-import.md -- CLAUDE.md carries no
# pointer section for it at all (removed 2026-07-24); this script is now
# the only place the rule gets surfaced, so it stays in sync with that
# file by construction instead of by two texts needing to agree.
#
# Honest limitation, stated up front: there is no hook event for "the user
# uploaded a file to me" -- the hook system only sees tool calls and prompt
# submissions. This CANNOT be a hard block the way no-commit-on-main.sh
# is, because applying the real rule (diff contents, summarize differences,
# decide conflict winner, ask permission) requires judgment a shell script
# cannot perform. What IS mechanizable, three moments (registered under
# three different hook events in settings.json, same script):
#   1. PROMPT side (UserPromptSubmit): the user's message itself looks like
#      an explicit "exporta"/"importa la configuracio" request -- the one
#      trigger with no tool call to hook into, since nothing has been
#      read/written yet at that point.
#   2. READ side (PostToolUse, matcher Read): Claude just read a file that
#      LOOKS like an incoming config artifact -- named settings.json, or
#      living under a hooks/ or skills/ directory -- that is NOT already
#      part of this repo's own tracked .claude/ tree. Reminds of the
#      config-export-import.md ingest steps before anything gets applied.
#   3. WRITE side (PreToolUse, matcher Write|Edit): Claude is about to
#      Write/Edit a path INSIDE this repo's own `.claude/hooks/` or
#      `.claude/settings.json` -- the self-overwrite moment itself, catching
#      the case job 2 can't see (an already-open file being overwritten in
#      place needs no fresh Read first).
# All three are nudges (additionalContext), not gates -- same non-blocking
# pattern as rule-check-reminder.sh, and deliberately NOT a permission deny,
# since legitimate hook development (like this repo's own sessions building
# these very hooks) needs to write here constantly without being blocked.
#
# The actual export/import procedure (what gets bundled, delivery format,
# mandatory vs optional skills) lives ONLY in config-export-import.md --
# not restated here, so there is exactly one place it can drift out of
# date.
set -euo pipefail

input="$(cat)"

# Job 1: UserPromptSubmit has a "prompt" field and no "tool_name" -- handle
# it first and exit, before the tool-oriented jobs 2/3 below assume a
# tool_name/file_path shape that a prompt event doesn't have.
prompt="$(echo "$input" | jq -r '.prompt // ""' 2>/dev/null || echo "")"
if [ -n "$prompt" ]; then
  lower="$(echo "$prompt" | tr '[:upper:]' '[:lower:]')"
  matched=0
  if echo "$lower" | grep -qE '(export|import)(a|ar|ació|acio|s)?[^.]{0,20}config'; then
    matched=1
  fi
  if echo "$lower" | grep -qE 'config[^.]{0,20}(export|import)'; then
    matched=1
  fi
  if [ "$matched" -eq 1 ]; then
    msg="Aixo sembla una peticio d'exportar/importar la configuracio de .claude/. Llegeix .claude/config-export-import.md sencer abans d'actuar -- porta el procediment complet, no repetit aqui."
    jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $msg}}'
  else
    echo '{}'
  fi
  exit 0
fi

tool_name="$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"
file_path="$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")"
project_dir="${CLAUDE_PROJECT_DIR:-}"
# tool_response is only present on PostToolUse calls -- the only reliable way
# to tell the two registrations of this same script apart (this script is
# wired into BOTH the unscoped PostToolUse group, which sees every tool
# including Write/Edit, AND the PreToolUse group scoped to Write|Edit). Without
# this check, a Write/Edit would double-fire the self-protection message
# (once correctly from PreToolUse, once incorrectly re-labeled from
# PostToolUse) instead of exactly once.
is_post="$(echo "$input" | jq 'has("tool_response")' 2>/dev/null || echo false)"

if [ -z "$file_path" ]; then
  echo '{}'
  exit 0
fi

if { [ "$tool_name" = "Write" ] || [ "$tool_name" = "Edit" ]; } && [ "$is_post" = "false" ]; then
  case "$file_path" in
    "$project_dir"/.claude/hooks/*|"$project_dir"/.claude/settings.json)
      msg="Autoproteccio de la regla d'ingesta: estas a punt d'escriure sobre la propia configuracio d'aquest repo ('${file_path}'), el moment exacte de sobreescriptura. Si aquest canvi ve d'un fitxer pujat des de fora, assegura't d'haver seguit ja els passos de .claude/config-export-import.md ABANS d'aquesta escriptura, no despres."
      jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $msg}}'
      exit 0
      ;;
    *)
      echo '{}'
      exit 0
      ;;
  esac
fi

if [ "$tool_name" != "Read" ]; then
  echo '{}'
  exit 0
fi

case "$file_path" in
  "$project_dir"/.claude/*)
    # Already inside this repo's own tracked config -- routine read, not an
    # incoming upload. Never nag on this (would fire constantly).
    echo '{}'
    exit 0
    ;;
esac

looks_like_config=0
case "$file_path" in
  *.skill) looks_like_config=1 ;;
  *settings.json) looks_like_config=1 ;;
  */hooks/*) looks_like_config=1 ;;
  */skills/*) looks_like_config=1 ;;
  *config-export-import.md) looks_like_config=1 ;;
  *00-START-HERE.md) looks_like_config=1 ;;
  *recommended-skills.txt) looks_like_config=1 ;;
esac

if [ "$looks_like_config" -ne 1 ]; then
  echo '{}'
  exit 0
fi

msg="Recordatori de la regla d'ingesta de configuracio: acabes de llegir un fitxer que sembla configuracio pujada des de fora d'aquest repo ('${file_path}'). Llegeix .claude/config-export-import.md (o la copia inclosa al bundle) per al procediment complet abans de fer res -- no el repeteixo aqui perque no quedi desincronitzat amb aquell fitxer."
jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $msg}}'
