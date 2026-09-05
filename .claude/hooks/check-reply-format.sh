#!/bin/bash
# RETIRED 2026-07-30 (explicit user request): unregistered from the Stop
# hook in settings.json because the rules it enforced (mandatory leading
# "Rebut:" line, Catalan-only, no bold/em-dash/ellipsis/headers/tables,
# numbered-lists-only) were removed from CLAUDE.md's Response style
# section the same day in favor of deferring to the `caveman` skill. Left
# on disk, unregistered, rather than deleted, in case that decision is
# ever reversed. Body below is now dead code -- do not re-wire it into
# settings.json without first checking CLAUDE.md still wants these rules.
#
# Stop hook: checks the current turn's chat-text reply against mechanically
# checkable CLAUDE.md rules and blocks (forcing a rewrite) if violated:
#   1. First line starts with "Rebut:" (applied to every reply, not just
#      replies to orders -- a shell script can't reliably tell the two
#      apart, so this is broader than the literal CLAUDE.md wording).
#      EXCEPTION: system-reminder messages that explicitly say "ignore if
#      not applicable" do NOT require a reply at all; do not respond to them.
#   2. No forbidden formatting: bold (**), em dash (—), ellipsis (…/...),
#      markdown headers (##), tables (|...|...|), or bullet/dash lists.
#   3. Reply is in Catalan, not English -- HEURISTIC ONLY (word-count of
#      common Catalan vs English stopwords). A shell script cannot actually
#      understand language; this catches only a reply that is CLEARLY,
#      overwhelmingly English prose. Requires a minimum word count and a
#      clear English majority to avoid false positives on short replies or
#      Catalan text that legitimately contains English code/commands/paths
#      (verified: a Catalan reply full of git commands still scores
#      correctly as Catalan since technical tokens aren't counted).
#
# Fixed 2026-07-28 (found by actually hitting this in a real session): a
# single turn commonly produces MULTIPLE separate assistant text blocks --
# an opening "Rebut: ..." acknowledgment, then tool calls, then a closing
# summary once the work is done. The old version only ever looked at the
# LAST text block in the whole transcript, so a turn that correctly said
# "Rebut: ..." once at the start still got blocked because its final
# summary block didn't repeat the prefix -- forcing a near-duplicate
# resend, exactly the kind of repeated-looking answer CLAUDE.md's "First
# line of every reply" rule was never meant to require twice per turn.
# Now: gather every assistant text block since the last REAL user message
# (a "user"-type transcript entry is only a genuine human turn if its
# content is a plain string, or an array whose types don't include
# "tool_result" -- a tool_result IS recorded as a "user" entry in Claude
# Code's transcript format, so that check is what actually finds the turn
# boundary instead of the most recent tool result). The "Rebut:" check
# runs against the FIRST such block (the true first line of the reply);
# the formatting/language checks run against all of them joined, so a
# violation anywhere in the turn still gets caught.
#
# stop_hook_active guards against infinite loops: if this hook already
# forced one retry, it steps aside on the next Stop instead of blocking
# again, even if still non-compliant.
#
# Fixed 2026-07-29 (found by actually hitting this in a real session, a
# second time after the 2026-07-28 fix above): a blocked turn's generic
# "reescriu NOMES el fragment assenyalat" reason never said WHICH fragment
# -- it only reported that the turn AS A WHOLE scored English. The retry
# had to guess, guessed wrong (picked the wrong block to touch), and ended
# up re-sending an already-correct closing block verbatim instead of fixing
# the one narration line that had actually slipped into English -- exactly
# the duplicate-looking reply this rule exists to prevent. Now: the
# language heuristic runs per block (scored by en-stopword-count minus
# ca-stopword-count, not the old fixed word-count threshold, since a short
# narration block like "Now committing." never reached the old >=15-word
# minimum on its own) and any block that scores net-English is quoted
# VERBATIM in the block reason, so the retry has a literal target instead
# of a guess. The first block is always excluded from this scoring: it is
# the "Rebut: <order in English>" acknowledgment, and CLAUDE.md requires
# that specific line to contain an English summary by design -- scoring it
# as a violation would tell a compliant reply to mistranslate its own
# mandatory-English part. Excluding it also fixes a related false-positive
# risk: on a short turn, the Rebut line's English words could dominate the
# old whole-turn word count and flag an otherwise all-Catalan reply.
set -euo pipefail

input="$(cat)"
stop_hook_active="$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
if [ "$stop_hook_active" = "true" ]; then
  echo '{}'
  exit 0
fi

sid="$(echo "$input" | jq -r '.session_id // ""' 2>/dev/null || echo "")"
transcript_path="$(echo "$input" | jq -r '.transcript_path // ""' 2>/dev/null || echo "")"

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
  # Fallback: Claude Code stores transcripts at
  # ~/.claude/projects/<sanitized-cwd>/<session_id>.jsonl (cwd's "/" -> "-")
  sanitized="$(printf '%s' "${CLAUDE_PROJECT_DIR:-}" | sed 's/\//-/g')"
  transcript_path="$HOME/.claude/projects/${sanitized}/${sid}.jsonl"
fi

if [ -z "$sid" ] || [ ! -f "$transcript_path" ]; then
  echo '{}'
  exit 0
fi

turn_blocks_json="$(jq -rs '
  to_entries
  | (map(select(.value.type=="user" and ((.value.message.content|type)=="string" or (.value.message.content|map(.type)|index("tool_result")|not))))
     | if length>0 then last.key else -1 end) as $lastUserKey
  | [.[] | select(.key > $lastUserKey and .value.type=="assistant")
     | select(.value.message.content | map(.type=="text") | any)
     | (.value.message.content | map(select(.type=="text").text) | join("\n"))]
' "$transcript_path" 2>/dev/null || echo "[]")"

block_count="$(echo "$turn_blocks_json" | jq 'length' 2>/dev/null || echo 0)"
if [ "$block_count" -eq 0 ]; then
  echo '{}'
  exit 0
fi

first_block="$(echo "$turn_blocks_json" | jq -r '.[0]')"
all_text="$(echo "$turn_blocks_json" | jq -r 'join("\n")')"
# Everything except the mandatory-English "Rebut:" acknowledgment -- see the
# 2026-07-29 note above for why this block is excluded from the language
# scoring, both for the pass/fail decision and for offender-quoting.
rest_text="$(echo "$turn_blocks_json" | jq -r 'if length>1 then .[1:] | join("\n") else "" end')"

EN_WORDS='\b(the|is|are|this|that|will|would|should|have|has|been|with|from|your|what|when|where|because|please|thanks|here|there|and|for|not|but|can)\b'
CA_WORDS='\b(que|es|amb|per|els|les|una|del|dels|pero|tambe|mes|aquest|aquesta|com|quan|perque|si|ja|fet|vols|pots|puc|aqui|no|el|la|un|de|i|a)\b'
EN_WORDS_JQ='(?i)\b(the|is|are|this|that|will|would|should|have|has|been|with|from|your|what|when|where|because|please|thanks|here|there|and|for|not|but|can)\b'
CA_WORDS_JQ='(?i)\b(que|es|amb|per|els|les|una|del|dels|pero|tambe|mes|aquest|aquesta|com|quan|perque|si|ja|fet|vols|pots|puc|aqui|no|el|la|un|de|i|a)\b'

problems=()
missing_rebut=0
lang_flag=0
format_flag=0
list_flag=0
first_line="$(printf '%s\n' "$first_block" | head -1)"
if ! printf '%s' "$first_line" | grep -q '^Rebut:'; then
  problems+=("no comenca per 'Rebut:'")
  missing_rebut=1
fi
if printf '%s' "$all_text" | grep -qE '\*\*|—|…|\.\.\.|^#{1,6}[[:space:]]|\|.+\|.+\|'; then
  problems+=("format prohibit (negreta/guio llarg/el.lipsis/taula/capcalera)")
  format_flag=1
fi
if printf '%s' "$all_text" | grep -qE '^[[:space:]]*[-*][[:space:]]'; then
  problems+=("llista amb pics/guionets en lloc de numeracio")
  list_flag=1
fi

total_words=$(printf '%s' "$rest_text" | wc -w)
en_count=$(printf '%s' "$rest_text" | grep -oiE "$EN_WORDS" | wc -l || true)
ca_count=$(printf '%s' "$rest_text" | grep -oiE "$CA_WORDS" | wc -l || true)
if [ "$total_words" -ge 15 ] && [ "$en_count" -ge 3 ] && [ "$en_count" -gt "$ca_count" ]; then
  problems+=("sembla estar en angles, no en catala (heuristica de paraules)")
  lang_flag=1
fi

if [ ${#problems[@]} -gt 0 ]; then
  joined="$(IFS='; '; echo "${problems[*]}")"
  # The retry instruction is per-problem, not one-size-fits-all. The old
  # blanket "torna a escriure-la corregint-ho" caused the very thing these
  # rules exist to prevent: on a missing-Rebut-only block, the reply's own
  # content was already correct and already on screen, so "rewrite it" got
  # read as "resend all of it", and the user read the same closing summary
  # twice. Measured on this session's transcript before the fix: every
  # missing-Rebut block produced a near-verbatim duplicate. Blocking is
  # still right -- the rule holds -- but the repair has to be scoped to
  # what actually broke.
  if [ "$missing_rebut" -eq 1 ] && [ ${#problems[@]} -eq 1 ]; then
    fix="El contingut que ja has escrit es correcte i l'usuari JA l'ha llegit: l'unic que falta es la linia inicial. Escriu NOMES 'Rebut: <ordre resumida en angles>' i prou. NO reenviïs el resum anterior ni cap fragment seu -- repetir-lo es pitjor que la infraccio que estas corregint."
  else
    # Quote the actual offending text so the retry has a literal target
    # instead of a guess (2026-07-29 fix, see the note above this section).
    quotes=""
    if [ "$lang_flag" -eq 1 ]; then
      lang_offenders="$(echo "$turn_blocks_json" | jq -r --arg en "$EN_WORDS_JQ" --arg ca "$CA_WORDS_JQ" '
        .[1:][] | select(
          (([scan($en)] | length) as $e | ([scan($ca)] | length) as $c | $e > $c)
        )
      ' 2>/dev/null || echo "")"
      if [ -n "$lang_offenders" ]; then
        quotes="${quotes}Bloc(s) en angles (tradueix NOMES aquests, al catala):
$(printf '%s' "$lang_offenders" | sed 's/^/  > /')
"
      fi
    fi
    if [ "$format_flag" -eq 1 ]; then
      format_offenders="$(printf '%s' "$all_text" | grep -nE '\*\*|—|…|\.\.\.|^#{1,6}[[:space:]]|\|.+\|.+\|' || true)"
      if [ -n "$format_offenders" ]; then
        quotes="${quotes}Linia(es) amb format prohibit (numero de linia dins el torn):
$(printf '%s' "$format_offenders" | sed 's/^/  > /')
"
      fi
    fi
    if [ "$list_flag" -eq 1 ]; then
      list_offenders="$(printf '%s' "$all_text" | grep -nE '^[[:space:]]*[-*][[:space:]]' || true)"
      if [ -n "$list_offenders" ]; then
        quotes="${quotes}Linia(es) amb llista de pics (numero de linia dins el torn):
$(printf '%s' "$list_offenders" | sed 's/^/  > /')
"
      fi
    fi
    # Only re-demand the "Rebut:" line when it was ACTUALLY missing
    # (missing_rebut=1). If it was already present and correct in the
    # first block, telling the retry to prepend it again makes the
    # correction read as a whole second reply -- a duplicated-looking
    # "Rebut: ..." opening line is exactly what a user sees as a double
    # message. Fixed 2026-07-29 after this exact case was hit in a real
    # session: a lone em-dash violation (Rebut already fine) still forced
    # a fresh 'Rebut: ...' line onto the correction.
    if [ "$missing_rebut" -eq 1 ]; then
      rebut_note="Comenca per 'Rebut: <ordre resumida en angles>' i tot seguit NOMES la traduccio/correccio d'aquests fragments concrets, res mes."
    else
      rebut_note="La linia 'Rebut: ...' ja hi era i ja era correcta -- NO la repeteixis. Escriu NOMES la traduccio/correccio d'aquests fragments concrets, sense cap linia 'Rebut:' nova."
    fi
    if [ -n "$quotes" ]; then
      fix="Reescriu NOMES els fragments citats a sota -- mai la resta del torn, ja llegida i ja correcta:
${quotes}${rebut_note}"
    else
      fix="Reescriu NOMES el fragment assenyalat, no tot el torn: l'usuari ja ha llegit la resta i repetir-la es un defecte per si mateix. ${rebut_note}"
    fi
  fi
  reason="La teva resposta anterior incompleix regles de CLAUDE.md: ${joined}. ${fix}"
  jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
else
  echo '{}'
fi
