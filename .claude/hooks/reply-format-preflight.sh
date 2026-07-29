#!/bin/bash
# UserPromptSubmit hook: fires BEFORE any assistant text of the turn exists,
# which is the only moment a reminder about the turn's FIRST text block can
# still change the outcome.
#
# Why this exists (measured, not hypothetical). The companion Stop hook
# check-reply-format.sh enforces CLAUDE.md's "first line of every reply is
# 'Rebut: <order>'" rule by checking the turn's FIRST assistant text block.
# A turn that opens with mid-turn narration ("Ara aplico els tres canvis a
# runtime.lua.") fails that check even when a perfectly good "Rebut:"-led
# summary follows later. The Stop hook then blocks, the reply gets rewritten,
# and the user reads the same closing summary twice -- the exact duplicated
# answer CLAUDE.md's terseness rules exist to avoid. Replaying this session's
# own transcript through the Stop hook's own turn-splitting logic found 9 of
# 47 turns opening with narration rather than Rebut, so this was the dominant
# failure mode, not an occasional slip.
#
# The other three carriers all fire too late or too rarely to prevent it:
# rule-check-reminder.sh is PostToolUse (first tool call has usually already
# happened after the opening text), CLAUDE.md itself is read once at session
# start and competes with everything else in context, and the Stop hook only
# speaks up once the damage is done. This one lands at the start of every
# turn, unconditionally, which is what the rule itself demands.
#
# Deliberately short: a reminder repeated every single turn earns its place
# only by staying cheap. It restates the two mechanically-checked rules that
# actually get broken, not the whole style guide -- CLAUDE.md remains the
# authority, this is just the alarm clock.
set -euo pipefail

# UserPromptSubmit delivers the prompt as JSON on stdin; drain it even though
# this reminder is unconditional, so the writer never sees a closed pipe.
cat >/dev/null

msg="Recordatori de format (abans d'escriure res en aquest torn): el PRIMER bloc de text ha de comencar per 'Rebut: <ordre resumida en angles>'. Cap narracio, cap etiqueta de pas i cap crida a eina abans d'aquesta linia. Les etiquetes de pas de seqüencies multi-pas (Commit. Push. Tests.) van DESPRES, i son de 1-3 paraules, no frases. Prohibits a tot el torn: el.lipsis, negreta, guio llarg, capcaleres, taules i llistes amb pics."

jq -n --arg msg "$msg" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $msg}}'
