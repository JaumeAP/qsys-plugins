#!/bin/bash
# Stop hook: checks the last chat-text reply against mechanically checkable
# CLAUDE.md rules and blocks (forcing a rewrite) if violated:
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
# stop_hook_active guards against infinite loops: if this hook already
# forced one retry, it steps aside on the next Stop instead of blocking
# again, even if still non-compliant.
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

last_text="$(jq -rs '
  [.[] | select(.type=="assistant") | select(.message.content | map(.type=="text") | any)]
  | if length>0 then (.[-1].message.content | map(select(.type=="text").text) | join("\n")) else "" end
' "$transcript_path" 2>/dev/null || echo "")"

if [ -z "$last_text" ]; then
  echo '{}'
  exit 0
fi

problems=()
first_line="$(printf '%s\n' "$last_text" | head -1)"
if ! printf '%s' "$first_line" | grep -q '^Rebut:'; then
  problems+=("no comenca per 'Rebut:'")
fi
if printf '%s' "$last_text" | grep -qE '\*\*|—|…|\.\.\.|^#{1,6}[[:space:]]|\|.+\|.+\|'; then
  problems+=("format prohibit (negreta/guio llarg/el.lipsis/taula/capcalera)")
fi
if printf '%s' "$last_text" | grep -qE '^[[:space:]]*[-*][[:space:]]'; then
  problems+=("llista amb pics/guionets en lloc de numeracio")
fi

total_words=$(printf '%s' "$last_text" | wc -w)
en_count=$(printf '%s' "$last_text" | grep -oiE '\b(the|is|are|this|that|will|would|should|have|has|been|with|from|your|what|when|where|because|please|thanks|here|there|and|for|not|but|can)\b' | wc -l || true)
ca_count=$(printf '%s' "$last_text" | grep -oiE '\b(que|es|amb|per|els|les|una|del|dels|pero|tambe|mes|aquest|aquesta|com|quan|perque|si|ja|fet|vols|pots|puc|aqui|no|el|la|un|de|i|a)\b' | wc -l || true)
if [ "$total_words" -ge 15 ] && [ "$en_count" -ge 3 ] && [ "$en_count" -gt "$ca_count" ]; then
  problems+=("sembla estar en angles, no en catala (heuristica de paraules)")
fi

if [ ${#problems[@]} -gt 0 ]; then
  joined="$(IFS='; '; echo "${problems[*]}")"
  reason="La teva resposta anterior incompleix regles de CLAUDE.md: ${joined}. Torna a escriure-la corregint-ho."
  jq -n --arg reason "$reason" '{decision: "block", reason: $reason}'
else
  echo '{}'
fi
