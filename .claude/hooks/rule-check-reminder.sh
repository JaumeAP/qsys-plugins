#!/bin/bash
# PostToolUse hook, two jobs:
#   1. On the very FIRST tool call, then every 15th one after that (per
#      session -- widened from every-5th 2026-07-20, a process audit found
#      the every-5th cadence firing so often it was pure noise most of the
#      time, repeating the same long skill/hook list with no real change
#      since the last firing), inject a reminder to actually re-Read
#      CLAUDE.md in full,
#      every skill under `.claude/skills/`, AND every hook under
#      `.claude/hooks/` (all listed fresh each firing, not hardcoded --
#      hooks included per user request 2026-07-16, right after this very
#      job's own hardcoded text was caught stale, see below; firing on
#      call #1 too was the same user's follow-up request, same day, so a
#      session doesn't wait until its 5th step for the first check) --
#      not a cached copy of rules text, since that copy can silently go
#      stale the moment the
#      real files change mid-session (exactly the failure this job is meant
#      to prevent: a static summary of the rules drifting out of sync with
#      the real files -- read the real files instead of repeating a frozen
#      claim). Counts Claude's own steps (tool calls), not user turns -- a
#      single user turn can chain many tool calls, so this catches drift
#      mid-turn instead of only at the next user message. Covers whatever
#      check-reply-format.sh's Stop hook does NOT mechanically enforce
#      (that hook only covers language/format/Rebut/lists -- economy of
#      tokens, tone, conditional length, verification-before-facts, and
#      multi-step action labels have no script check, this reminder is
#      their only remaining carrier, and re-reading the source files keeps
#      that carrier accurate instead of drifting).
#   2. Long-session-hygiene nudge, delivered ONCE per context compaction
#      (CLAUDE.md's "Long-session hygiene" rule). Detection is now event-
#      based, NOT a tool-call count: the count heuristic (previously "first
#      at 100, then every 50") was removed 2026-07-16 (user request) because
#      a raw step count can't actually tell whether the session has gone
#      lossy -- it fired on long-but-fine sessions and stayed silent on
#      short-but-compacted ones. The real, reliable signal is a context
#      compaction/summarization actually happening: the companion
#      PreCompact hook (precompact-hygiene-flag.sh) drops a per-session
#      pending flag when Claude Code is about to compact, and this job
#      consumes it on the next tool call -- so the nudge lands exactly when
#      the chat's own memory has just been compressed (the precise "lossy"
#      moment CLAUDE.md ties this rule to), and never otherwise. Fires once
#      per compaction (the flag is removed after reading). Non-blocking
#      (additionalContext, same as job 1), by design: whether to actually
#      start a fresh chat stays Claude's/the user's call, never forced.
# Counters/flags are per-session (keyed by session_id) so parallel/other
# sessions don't share or reset each other's state.
set -euo pipefail

input="$(cat)"
sid="$(echo "$input" | jq -r '.session_id // "default"' 2>/dev/null || echo "default")"

project_dir="${CLAUDE_PROJECT_DIR:-.}"

counter_file="/tmp/claude_rule_check_counter_${sid}"
count=$(( $(cat "$counter_file" 2>/dev/null || echo 0) + 1 ))
echo "$count" > "$counter_file"

msg=""
if (( count == 1 || count % 15 == 0 )); then
  skill_files="$(find "$project_dir/.claude/skills" -mindepth 2 -maxdepth 2 -name 'SKILL.md' 2>/dev/null | sed "s|^$project_dir/||" | sort | paste -sd ',' -)"
  hook_files="$(find "$project_dir/.claude/hooks" -maxdepth 1 -name '*.sh' 2>/dev/null | sed "s|^$project_dir/||" | sort | paste -sd ',' -)"
  msg="Recordatori automatic (pas #${count}): torna a llegir CLAUDE.md sencer, cada skill llistat (${skill_files:-cap skill trobat}), i cada hook llistat (${hook_files:-cap hook trobat}) -- no et fiïs d'un resum en cache d'aquest o d'un torn anterior, els fitxers reals poden haver canviat des d'aleshores dins la mateixa sessio. Un cop rellegit, reverifica que la resposta compleix el que diguin ara mateix, no el que dèiem fa uns passos."
fi

# Job 2: consume the PreCompact pending flag exactly once, if present.
compaction_flag="/tmp/claude_compaction_pending_${sid}"
if [ -f "$compaction_flag" ]; then
  rm -f "$compaction_flag"
  hygiene="Higiene de sessio llarga (CLAUDE.md): s'acaba de compactar el context d'aquest xat -- la memoria de la conversa s'ha comprimit i el detall antic pot haver quedat lossy. Valora proactivament continuar en un xat nou, sense esperar que t'ho demanin. Aquest avis salta nomes en una compactacio real, no per recompte de passes; fer-ho o no queda al teu/l'usuari criteri, mai forcat."
  if [ -n "$msg" ]; then
    msg="${msg}
${hygiene}"
  else
    msg="$hygiene"
  fi
fi

if [ -n "$msg" ]; then
  jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $msg}}'
else
  echo '{}'
fi
