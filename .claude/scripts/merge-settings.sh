#!/bin/bash
# Merge an incoming settings.json (from a config bundle import, step 2.2
# in config-export-import.md) with a target repo's existing
# settings.json, without dropping the target's own project-specific hook
# registrations. A plain overwrite would silently lose any hook group
# that mixes a bundle hook with a project-specific one, or that only
# registers project-specific hooks -- those files stay on disk (2.9
# already protects them) but with nothing left registering them, which
# is just as broken as deleting them.
#
# Rule: any hook group in the target whose commands are ALL among this
# bundle's known hook names is dropped (the incoming version replaces
# it). Any group containing at least one command NOT in the bundle's
# list is kept whole and appended under its event key.
#
# Fixed 2026-07-25: the membership test used to be `any($c | test(.))`,
# which piping `$c` into `test(.)` rebinds `.` to `$c` itself before the
# regex argument is evaluated -- so it was testing $c against ITSELF as
# a regex, not against each bundle_hooks pattern. Every real hook command
# here is of the form `$CLAUDE_PROJECT_DIR/.claude/hooks/name.sh`; the
# literal `$` mid-string breaks the self-match (jq's regex engine reads
# it as an end-of-line anchor), so the test was always false, so every
# already-bundle-covered hook group was wrongly kept as "extra" --
# duplicating every hook group on every past import. Fixed by binding
# the loop pattern to a named variable ($p) before piping $c into test,
# so `.` is never ambiguous between the two values.
#
# `permissions` merges too (added 2026-07-25): a target's own
# project-specific `permissions.allow`/`deny`/`ask` entries (e.g. a
# `Bash(git submodule *)` rule added for a repo-specific workflow) used
# to be silently dropped by this script, since it only ever emitted a
# `hooks` key. Now `allow`/`deny`/`ask`/`additionalDirectories` are
# unioned (deduped) between target and incoming, and `defaultMode`
# prefers the target's own value, falling back to the incoming one.
#
# `skillOverrides` merges too (added 2026-07-25, same day a target's own
# `skillOverrides.git-rules: "user-invocable-only"` entry would otherwise
# have been silently dropped by the very next import): target and
# incoming are shallow-merged per skill name, incoming's value winning
# for any skill name both sides set (same "incoming wins for its own
# entries" principle as `hooks`), target's own entries for any OTHER
# skill name preserved untouched. Omitted from the output entirely if
# both sides are empty, same as the optional `permissions` sub-keys.
#
# Usage: ./merge-settings.sh <target-settings.json> <incoming-settings.json> <hook1.sh> [hook2.sh ...]
# Output: merged settings.json on stdout
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <target-settings.json> <incoming-settings.json> <hook1.sh> [hook2.sh ...]" >&2
  exit 1
fi

target="$1"
incoming="$2"
shift 2
bundle_hooks_json="$(printf '%s\n' "$@" | jq -R . | jq -s .)"

jq -s --argjson bundle_hooks "$bundle_hooks_json" '
  .[0] as $target | .[1] as $incoming |
  ($incoming.hooks) as $inc |
  ($target.hooks // {}) as $tgt |
  ($target.permissions // {}) as $tp |
  ($incoming.permissions // {}) as $ip |
  (($target.skillOverrides // {}) + ($incoming.skillOverrides // {})) as $so |
  {
    hooks: (
      $inc + (
        $tgt | to_entries | map({
          key: .key,
          value: (.value | map(select(
            (.hooks // []) | any(.command as $c | ($bundle_hooks | any(.[]; . as $p | $c | test($p))) | not)
          )))
        }) | map(select(.value | length > 0))
        | reduce .[] as $entry
            ({}; .[$entry.key] = (.[$entry.key] // []) + $entry.value)
      ) as $extra |
      (($inc | keys) + ($extra | keys) | unique) as $all_keys |
      reduce $all_keys[] as $k
        ({}; .[$k] = (($inc[$k] // []) + ($extra[$k] // [])))
    ),
    permissions: (
      (
        {
          allow: (($ip.allow // []) + ($tp.allow // []) | unique),
          deny: (($ip.deny // []) + ($tp.deny // []) | unique),
          ask: (($ip.ask // []) + ($tp.ask // []) | unique),
          additionalDirectories: (($ip.additionalDirectories // []) + ($tp.additionalDirectories // []) | unique)
        } | with_entries(select(.value | length > 0))
      ) + (
        if ($tp.defaultMode) then {defaultMode: $tp.defaultMode}
        elif ($ip.defaultMode) then {defaultMode: $ip.defaultMode}
        else {} end
      )
    )
  } + (if ($so | length) > 0 then {skillOverrides: $so} else {} end)
' "$target" "$incoming"
