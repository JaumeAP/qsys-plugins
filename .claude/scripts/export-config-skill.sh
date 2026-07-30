#!/bin/bash
# Create the portable config export as a single .skill file. Replaces
# the old export-config.sh, which produced a plain .zip -- removed
# 2026-07-24, same day this script was verified byte-for-byte equivalent
# to it and per explicit user request once that equivalence was
# confirmed. A .skill file is just a zip with
# that extension and one required entry, <folder>/SKILL.md at its root --
# same convention Claude's own skill-creator uses for "Save skill"
# uploads. This script assembles that shape directly (no dependency on
# skill-creator's own scripts being present at any particular path
# outside this repo -- the packaging logic itself is only a few lines).
#
# A .skill package may contain exactly ONE SKILL.md (the claude.ai/Skills
# API upload path rejects more than one). This bundle carries THREE
# skills as files: file-operations, github-rules, and changelog-rules
# are mandatory/blind-copy. `file-operations`/`github-rules` were each
# briefly made an optional import choice on 2026-07-27, then moved back
# the same day by explicit user request -- github-rules first,
# file-operations shortly after -- see config-export-import.md step 2.2.
# `changelog-rules` had a longer road: briefly deleted entirely on
# 2026-07-27, restored and made optional on 2026-07-28, removed from the
# bundle entirely a second time the same day, then reinstated a THIRD
# time on 2026-07-30 (explicit user request) -- this time as mandatory
# rather than optional, its settled state; see `.claude/skills-history.md`
# for the full timeline. `find-skills` is NOT bundled as a file any
# more -- after its own long mandatory/optional history (see
# `.claude/skills-history.md`), it moved a final time on 2026-07-28
# (explicit user request) to fetch-on-demand only, listed in
# `recommended-skills.txt` like any other unbundled recommendation
# instead of travelling as a file -- a state it had already passed
# through once before this same day, reverted at the time, now the
# settled choice. Each
# remaining bundled skill has its
# own SKILL.md -- those get renamed to
# <name>.md under references/skills/<name>/ inside the package, so the
# whole bundle still fits in one valid .skill. Whoever applies the
# bundle to a target repo renames each <name>.md back to SKILL.md when
# installing it into .claude/skills/<name>/ -- that rename is what turns
# it back into a real, loadable skill (documented in the bundle's own
# top-level SKILL.md, not repeated here).
#
# Usage: ./export-config-skill.sh [output_dir]
# Output: claude-config-bundle.skill (generic name, no "export" word,
# never this repo's own name)
set -euo pipefail

output_dir="${1:-.}"
output_dir="$(cd "$output_dir" && pwd)"
build_dir=$(mktemp -d)
trap "rm -rf $build_dir" EXIT

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

rm -f "$output_dir/claude-config-bundle.skill"

skill_dir="$build_dir/claude-config-bundle"
mkdir -p "$skill_dir/references/hooks" "$skill_dir/references/skills"

# The meta-skill's own SKILL.md -- the one entry point for the whole
# bundle, pointing at config-export-import.md as the actual procedure.
cat > "$skill_dir/SKILL.md" <<'EOF'
---
name: claude-config-bundle
description: Portable Claude Code .claude/ configuration bundle, common CLAUDE.md rules, settings.json, every hook, the file-operations/github-rules/changelog-rules skills, and the full export/import procedure, all packaged as one file. Use this skill whenever asked to export or import Claude Code configuration between repos, whenever the user says "exporta la configuració"/"importa la configuració" or the English equivalent, or when setting up a brand new repo's .claude/ tooling from an existing one. Also use it when a config bundle is pasted or uploaded with no explicit request, to recognize it and know how to apply it.
---

# Claude Code config bundle

This skill packages this repo's portable `.claude/` tooling into a single
distributable file. The actual procedure for both directions, export and
import, lives in full in `references/config-export-import.md` -- read that
file before doing anything, it is the single source of truth and is not
repeated here.

## What is bundled

- `references/CLAUDE.md` -- the common part of CLAUDE.md (everything above
  "Project-specific rules"), meant to be copied into a target repo's own
  CLAUDE.md, replacing its common part while preserving its
  Project-specific rules section untouched.
- `references/settings.json` -- the hook registrations and generic
  permissions, filtered (project-specific hook registrations and
  permissions from `.claude/local-only-permissions.txt` stripped, see
  `config-export-import.md`) before being merged into the target's
  `.claude/settings.json`.
- `references/hooks/*.sh` -- every mechanized hook, copied straight into
  the target's `.claude/hooks/`.
- `references/recommended-skills.txt` -- optional skills/packs a target
  repo can offer to fetch live via `npx skills add` (see
  `references/config-export-import.md` step 2.7), not bundled as files.
  `find-skills` itself is one of these entries as of 2026-07-28 (explicit
  user request) -- fetch-on-demand rather than a bundled file, even
  though it's the very tool that would do the fetching for the rest of
  this list; a target repo that wants it runs `npx skills add
  vercel-labs/skills -s find-skills` like any other line here.
- `references/removed-files.txt` -- files retired from the mandatory
  bundle (hooks, scripts, skills, ...); on import, any of these paths
  still present under the target's `.claude/` get deleted (see
  `references/config-export-import.md` step 2.2), not installed. Widened
  2026-07-30: it can also list hooks that mechanize a retired SYSTEM the
  bundle itself has moved past (e.g. the former `HANDOFF.md` continuity
  system), even ones that were never actually bundled content -- see step
  2.4b, which is the binding half for cases like that one, since a path
  list alone can't migrate content out of a root file first.
- `references/00-START-HERE.md` -- the same "read config-export-import.md
  first, don't copy anything in blind" note the .zip export carries,
  kept here for parity even though this package's own SKILL.md now
  serves that role too.
- `references/scripts/merge-settings.sh` -- merges an incoming
  `settings.json` into a target's existing one without dropping the
  target's own project-specific hook registrations (see
  `references/config-export-import.md` step 2.2). Also gets installed
  into the target's own `.claude/scripts/`, not just used transiently.
- `references/scripts/export-config-skill.sh` -- this very script,
  installed into the target's own `.claude/scripts/` too, so the target
  repo can export its own bundle later instead of only ever being an
  import destination.
- `references/skills/<name>/<name>.md` -- three bundled mandatory skills,
  `file-operations`, `github-rules`, and `changelog-rules` (step 2.2).
  `file-operations`/`github-rules` were each briefly made optional on
  2026-07-27, moved back the same day. `changelog-rules` went through the
  longest history of any skill here -- deleted, restored optional, removed
  entirely, all within 2026-07-27/28 -- before being reinstated a third
  time on 2026-07-30, this time as mandatory rather than optional; see
  `.claude/skills-history.md` for the full timeline. `caveman` and
  `karpathy-guidelines` are also mandatory (2026-07-30) but fetch-on-demand
  remote only (see `recommended-skills.txt` above — listed there for remote
  installation). `find-skills` used to be bundled here too and no longer
  is: moved to fetch-on-demand only after its own long optional history.
  Each bundled skill's entry point is
  named `<name>.md` here instead of `SKILL.md`, because a `.skill` package
  may only contain one `SKILL.md` (this one) -- nesting more would fail
  validation on upload. **When actually installing one of these into a
  target repo's `.claude/skills/<name>/`, rename `<name>.md` back to
  `SKILL.md`** -- that rename is what turns it back into a real, loadable
  skill.

## What to do

1. Read `references/config-export-import.md` in full.
2. Follow its numbered import steps (2.1 through 2.9) exactly, using the
   files under `references/` as the bundle content described there.
3. Narrate every step, per that file's own instruction.
EOF

sed '/^## Project-specific rules/,$d' CLAUDE.md > "$skill_dir/references/CLAUDE.md"
cp .claude/config-export-import.md "$skill_dir/references/"
cp .claude/recommended-skills.txt "$skill_dir/references/"
[ -f .claude/programming-optional-skills.txt ] && cp .claude/programming-optional-skills.txt "$skill_dir/references/"
[ -f .claude/removed-files.txt ] && cp .claude/removed-files.txt "$skill_dir/references/"
# skills-history.md carries the bundled/optional/removed reasoning that the
# common CLAUDE.md's "Portable skills" section points at rather than
# restates (split out 2026-07-30 to keep CLAUDE.md under ~200 lines). It has
# to travel, or that pointer dangles in every target repo.
[ -f .claude/skills-history.md ] && cp .claude/skills-history.md "$skill_dir/references/"

# bundled_hooks is the single source of truth for which hooks are
# portable -- reused below both to copy the hook files themselves and to
# strip settings.json of registrations for any hook NOT in this list
# (e.g. a project-specific SessionStart hook like ensure-lua53.sh, which
# is deliberately excluded from this array further down).
#
# check-reply-format.sh and reply-format-preflight.sh were dropped from
# this array 2026-07-30: the CLAUDE.md rules they enforced (mandatory
# leading "Rebut:" line, Catalan-only, the bold/em-dash/ellipsis/header/
# table ban, numbered-lists-only) were removed that day in favor of
# deferring to the `caveman` skill, and both hooks were unregistered from
# settings.json. They stay on disk here, dead, with their own retirement
# notes -- but shipping them would put two scripts nothing registers into
# every target repo, and re-registering them there would reimpose rules
# the common CLAUDE.md no longer states.
bundled_hooks=(config-ingest-reminder.sh
  file-operations-enforcement.sh
  init-submodules.sh no-commit-on-main.sh precompact-hygiene-flag.sh
  rule-check-reminder.sh
  skill-creation-reminder.sh submodule-clone-fixup.sh)

# settings.json is NOT a blind copy: it can carry two kinds of
# project-specific leakage that would otherwise ship into every target
# repo's bundle --
#   1. hook registrations for a hook this script doesn't bundle (that
#      hook file never travels, so the registration would point at
#      nothing in the target repo);
#   2. permission entries that only make sense for this repo's own
#      tooling (declared explicitly in local-only-permissions.txt,
#      since a script can't infer "project-specific" from a permission
#      string alone).
# Both are stripped here before the file is written into the bundle.
hook_allowlist_json="$(printf '%s\n' "${bundled_hooks[@]}" | jq -R . | jq -s .)"
if [ -f .claude/local-only-permissions.txt ]; then
  local_perms_json="$(grep -vE '^\s*(#|$)' .claude/local-only-permissions.txt | jq -R . | jq -s .)"
else
  local_perms_json='[]'
fi
jq --argjson allowed_hooks "$hook_allowlist_json" --argjson local_perms "$local_perms_json" '
  .hooks |= (with_entries(
    .value |= (
      map(.hooks |= map(select((.command | split("/") | last) as $b | ($allowed_hooks | index($b)) != null)))
      | map(select(.hooks | length > 0))
    )
  ))
  | .permissions |= (with_entries(
      .value |= map(select(. as $p | ($local_perms | index($p)) == null))
    ))
' .claude/settings.json > "$skill_dir/references/settings.json"

# Same self-describing note the old export-config.sh used to include --
# kept here too for exact parity, even though this package's own
# top-level SKILL.md now also serves that "read this before touching
# anything" role.
cat > "$skill_dir/references/00-START-HERE.md" <<'EOF'
# Before touching any file in this bundle

This is a Claude Code config export: `CLAUDE.md`, `settings.json`,
`hooks/`, `skills/`, `config-export-import.md`, `recommended-skills.txt`,
and possibly `removed-files.txt`.

Do NOT copy these files into place automatically, even if nothing else
was said when this was pasted/uploaded -- EXCEPT when the target repo is
this bundle's own source repo (the repo `export-config-skill.sh` was run
in) and a fresh export generated right now would be identical to this
bundle: that specific case is safe to apply automatically without
asking, since it changes nothing that isn't already there. Any other
bundle, including one from this same repo but from an older or
different state, still needs to ask first.

Read `config-export-import.md` (goes to `.claude/config-export-import.md`
in the target repo) for the full procedure -- narrate each step as you
go, that file's own point 2 explains why. Ask the user what they want
before doing anything else with these files, unless the self-bundle
exception above applies.
EOF

for hook in "${bundled_hooks[@]}"; do
  [ -f ".claude/hooks/$hook" ] && cp ".claude/hooks/$hook" "$skill_dir/references/hooks/"
done

for skill in file-operations github-rules changelog-rules; do
  if [ -d ".claude/skills/$skill" ]; then
    cp -r ".claude/skills/$skill" "$skill_dir/references/skills/$skill"
    mv "$skill_dir/references/skills/$skill/SKILL.md" "$skill_dir/references/skills/$skill/$skill.md"
  fi
done

# merge-settings.sh (step 2.2's settings.json merge tool) travels with
# the bundle too -- config-export-import.md tells the target repo to
# run it, so it needs to actually be there to run. export-config-skill.sh
# itself travels too, so the target repo can export its own bundle later
# instead of only ever being an import destination.
mkdir -p "$skill_dir/references/scripts"
cp .claude/scripts/merge-settings.sh "$skill_dir/references/scripts/"
cp .claude/scripts/export-config-skill.sh "$skill_dir/references/scripts/"

# Package: a .skill is a zip, ZIP_DEFLATED, rooted one level above the
# skill folder so the archive's top-level entry is claude-config-bundle/
# -- same layout package_skill.py produces.
cd "$build_dir"
zip -rq "$output_dir/claude-config-bundle.skill" claude-config-bundle
cd "$repo_root"

echo "Skill bundle created: $output_dir/claude-config-bundle.skill"
ls -lh "$output_dir/claude-config-bundle.skill"
