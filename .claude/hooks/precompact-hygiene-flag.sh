#!/bin/bash
# PreCompact hook: drop a per-session "compaction just happened" flag so the
# PostToolUse rule-check-reminder.sh can deliver the long-session-hygiene
# nudge (CLAUDE.md's "Long-session hygiene" rule) exactly once, right after
# the context is compacted.
#
# Why an event flag instead of a tool-call counter: a raw step count is only
# a crude proxy for "the session has gone lossy" -- it fires on long-but-fine
# sessions and stays silent on short-but-compacted ones. A context
# compaction/summarization ACTUALLY happening is the reliable signal that the
# chat's own memory has been compressed and early detail may have blurred --
# which is precisely the condition the hygiene rule exists for. This hook
# fires on both manual (/compact) and automatic (context-full) compaction;
# `trigger` in the input distinguishes them but the nudge is the same either
# way.
#
# Delivery is deferred to the next PostToolUse (rule-check-reminder.sh reads
# and removes the flag) rather than emitted here, because a PreCompact hook's
# own output is consumed by the compaction step, not surfaced as post-compact
# context -- the flag survives compaction (it is a /tmp file keyed by
# session_id, same container, same session) and reaches Claude on the first
# tool call of the resumed conversation.
set -euo pipefail

input="$(cat)"
sid="$(echo "$input" | jq -r '.session_id // "default"' 2>/dev/null || echo "default")"

touch "/tmp/claude_compaction_pending_${sid}"

echo '{}'
