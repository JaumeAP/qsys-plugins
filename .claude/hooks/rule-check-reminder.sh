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
#      mid-turn instead of only at the next user message.
#
#      Scope narrowed 2026-07-30, for two reasons that both landed the same
#      day. First, this used to enumerate every SKILL.md under
#      .claude/skills/; that list went from 3 entries to 29 when the
#      recommended-skills set was installed, and an instruction to re-read
#      29 files every 15 tool calls is one nobody follows -- it reads as
#      noise and takes the genuinely load-bearing part (CLAUDE.md) down
#      with it. Skills self-trigger by description anyway, so they are
#      explicitly excluded now. Second, it used to describe itself as
#      covering "whatever check-reply-format.sh's Stop hook does not
#      mechanically enforce"; that hook was retired the same day, so the
#      division of labor it named no longer exists. What this reminder
#      carries now: CLAUDE.md's own always-on rules (token economy, tone,
#      conditional length, verify-before-asserting, multi-step action
#      labels), the always-loaded .claude/rules/*.md files, and the hooks
#      actually registered in settings.json. Nothing mechanically checks
#      any of those, which is exactly why re-reading the source is the
#      whole point.
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
  # Always-loaded rule files: CLAUDE.md plus any .claude/rules/*.md. These
  # are the ones a stale cached summary actually misleads about.
  # paste -sd ', ' would alternate the two delimiter chars, not use both;
  # join with an explicit ", " instead.
  # The trailing `|| true` is load-bearing under `set -euo pipefail`: with
  # no .claude/rules/ directory, find exits 1, pipefail propagates that
  # through the pipeline, and the assignment itself then fails and takes
  # the whole hook down -- silently, since a hook that dies prints nothing.
  # (The same latent trap predates this rewrite: the old skill_files line
  # had the identical shape and would have died the same way in a repo with
  # no .claude/skills/.) 2>/dev/null only hides find's stderr, not its
  # status, which is what made this easy to miss.
  rule_files="$(find "$project_dir/.claude/rules" -maxdepth 1 -name '*.md' 2>/dev/null | sed "s|^$project_dir/||" | sort | paste -sd ',' - | sed 's/,/, /g' || true)"
  # Hooks are read from settings.json, not globbed off disk: a retired hook
  # can sit unregistered in .claude/hooks/ (check-reply-format.sh and
  # reply-format-preflight.sh both do, as of 2026-07-30), and telling
  # Claude to re-read dead scripts is worse than saying nothing.
  hook_files="$(jq -r '[.hooks // {} | .[][]?.hooks[]?.command | split("/") | last] | unique | join(", ")' "$project_dir/.claude/settings.json" 2>/dev/null || echo "")"
  msg="Recordatori automatic (pas #${count}): torna a llegir CLAUDE.md sencer"
  # if/then, NOT `[ -n ... ] && msg=...`: under `set -e` a failing test as
  # the head of an AND-list takes the whole script down with it. Caught by
  # actually running this in a scratch repo with no .claude/rules/ -- the
  # source repo has one, so the bug was invisible here and would only have
  # fired after the hook travelled somewhere else.
  if [ -n "$rule_files" ]; then
    msg="${msg}, els fitxers de regles sempre carregats (${rule_files})"
  fi
  if [ -n "$hook_files" ]; then
    msg="${msg}, i els hooks registrats a settings.json (${hook_files})"
  fi
  msg="${msg} -- no et fiïs d'un resum en cache d'aquest o d'un torn anterior, els fitxers reals poden haver canviat des d'aleshores dins la mateixa sessio. Els skills sota .claude/skills/ NO entren en aquesta llista: son molts i es carreguen sols per descripcio quan toca; llegeix el que calgui per la tasca actual, no tots. Un cop rellegit, reverifica que la resposta compleix el que diguin ara mateix, no el que dèiem fa uns passos."
  # Exception carved out 2026-07-30, narrow and deliberate -- doesn't
  # revert the "skills self-trigger by description" call above. A
  # full-session audit found the four skills CLAUDE.md called "mandatory"
  # at the time (file-operations, github-rules, caveman, karpathy-
  # guidelines) were invoked exactly zero times across dozens of tool
  # calls that squarely matched their own trigger descriptions --
  # "self-trigger by description" alone wasn't enough for these
  # specifically, unlike the merely-recommended ones this hook correctly
  # stopped enumerating. file-operations now also has a real mechanical
  # gate (file-operations-enforcement.sh, PreToolUse/Bash, hard block) for
  # its narrowest, most safety-relevant case; this reminder is what
  # covers the rest, which have no equivalent tool-level chokepoint to
  # gate on. `changelog-rules` briefly joined this named list 2026-07-30
  # (bundled+mandatory that day), was removed again the same session once
  # it went back to optional per repo, then rejoined for good 2026-07-31
  # (explicit user request, mandatory again in all three repos) -- see
  # CLAUDE.md's "Portable skills" section and `.claude/skills-history.md`
  # for the full flip-flop history, not repeated here.
  # karpathy-guidelines removed from this named list 2026-07-31 (explicit
  # user request): moved out of CLAUDE.md's mandatory set into
  # programming-optional-skills.txt, no longer obligatory for every repo.
  # `superpowers` joined this named list 2026-08-01 (explicit user
  # request): promoted from merely-recommended to mandatory, same
  # fetch-on-demand treatment as `caveman` -- see CLAUDE.md's "Portable
  # skills" item 5 and config-export-import.md step 2.2/2.7.
  msg="${msg} Excepcio (nomes els mandatory, no els recomanats): file-operations, github-rules, caveman, changelog-rules i superpowers son 'mandatory' segons CLAUDE.md -- invoca'ls de veritat amb el tool Skill quan la tasca hi encaixi (fitxers, treball amb PR/GitHub, canvi a un fitxer amb seccio de changelog, procés de treball, o sempre per estil/compressio de resposta), no nomes com a referencia de fons."
fi

# Job 3, added 2026-07-31 (explicit user request): mechanize the git-presence
# check CLAUDE.md's "Commit./Push." exception and "Tanca" routine ask for,
# instead of leaving it as pure prose the model has to remember to run each
# time -- the exact self-enforcement gap job 1's own comment already names
# as the reason CLAUDE.md text alone doesn't stick. Fires once, on the
# session's first tool call only (count==1) -- git presence doesn't change
# mid-session, so a one-time fact is enough; repeating it at every-15th
# would just be noise like the skill-list enumeration job 1 already trimmed
# away. Also checks changelog-rules' presence in the same breath, since
# CLAUDE.md's "Changelog-before-commit" rule needs the same yes/no fact.
if (( count == 1 )); then
  if git -C "$project_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_fact="Aquest repo TE git -- 'Commit.'/'Push.' i la rutina de Tanca amb git status/log/PR apliquen normalment."
    if [ -f "$project_dir/.claude/skills/changelog-rules/SKILL.md" ]; then
      git_fact="${git_fact} changelog-rules esta instal.lada -- actualitza l'entrada acumulada just abans de cada git commit, dins el mateix commit."
    fi
  else
    git_fact="Aquest repo NO te git -- salta 'Commit.'/'Push.' i la rutina de Tanca amb git status/log/PR (CLAUDE.md, excepcions 'Git-absent repos'); desa fitxers directament, i a Tanca informa dels fitxers tocats en lloc de l'estat de git."
  fi
  if [ -n "$msg" ]; then
    msg="${msg}
${git_fact}"
  else
    msg="$git_fact"
  fi
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
