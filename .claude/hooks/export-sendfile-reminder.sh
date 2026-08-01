#!/bin/bash
# PostToolUse hook reminder: when SendUserFile is called without an obvious
# preceding export-creation pattern, remind that export configs should ALWAYS
# be delivered via SendUserFile, not left in scratchpad only.
# Fired on every SendUserFile call; looks for "export" or "config" keywords
# in recent context to detect likely export deliveries and confirm they're
# using this mechanism (best-effort).
set -euo pipefail

input="$(cat)"
tool_name="$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")"

if [ "$tool_name" != "SendUserFile" ]; then
  echo '{}'
  exit 0
fi

# Extract file path from tool input (may contain export/config in filename)
file_path="$(echo "$input" | jq -r '.tool_input.files[0] // ""' 2>/dev/null || echo "")"
caption="$(echo "$input" | jq -r '.tool_input.caption // ""' 2>/dev/null || echo "")"

# Check if this looks like an export delivery
if printf '%s %s' "$file_path" "$caption" | grep -qi 'export\|config'; then
  # Confirm: exports MUST use SendUserFile delivery (this is it).
  # Silent pass -- the rule is already being followed.
  echo '{}'
  exit 0
fi

# Non-export SendUserFile call, no reminder needed
echo '{}'
