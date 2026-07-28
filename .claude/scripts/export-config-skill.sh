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
# API upload path rejects more than one). This bundle carries FOUR
# skills as files: file-operations, github-rules, and find-skills are
# mandatory/blind-copy (each of the first two was briefly made an
# optional import choice on 2026-07-27, then moved back the same day by
# explicit user request -- github-rules first, file-operations shortly
# after; find-skills took a longer road -- optional, then deleted
# entirely, restored as optional, deleted again as fetch-on-demand only,
# then finally made mandatory/always-present again on 2026-07-28,
# explicit user request each step -- see config-export-import.md step
# 2.2); changelog-rules is the one remaining
# optional import choice (step 2.5) -- briefly removed from
# the bundle entirely on 2026-07-27 (explicit user request, part of a
# session-long audit that found it hadn't actually been invoked), then
# restored from git history and put back as optional on 2026-07-28 (also
# explicit user request) rather than staying deleted. Each skill has its
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
description: Portable Claude Code .claude/ configuration bundle, common CLAUDE.md rules, settings.json, every hook, the changelog-rules/file-operations/find-skills/github-rules skills, and the full export/import procedure, all packaged as one file. Use this skill whenever asked to export or import Claude Code configuration between repos, whenever the user says "exporta la configuració"/"importa la configuració" or the English equivalent, or when setting up a brand new repo's .claude/ tooling from an existing one. Also use it when a config bundle is pasted or uploaded with no explicit request, to recognize it and know how to apply it.
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
- `references/settings.json` -- the hook registrations, copied straight
  over the target's `.claude/settings.json`.
- `references/hooks/*.sh` -- every mechanized hook, copied straight into
  the target's `.claude/hooks/`.
- `references/recommended-skills.txt` -- optional skill packs a target
  repo can offer to fetch live via `npx skills add` (see
  `references/config-export-import.md` step 2.7), not bundled as files.
- `references/removed-files.txt` -- files retired from the mandatory
  bundle (hooks, scripts, skills, ...); on import, any of these paths
  still present under the target's `.claude/` get deleted (see
  `references/config-export-import.md` step 2.2), not installed.
- `references/00-START-HERE.md` -- the same "read config-export-import.md
  first, don't copy anything in blind" note the .zip export carries,
  kept here for parity even though this package's own SKILL.md now
  serves that role too.
- `references/skills-lock.json` -- trimmed to just `find-skills`' own
  entry, same as the .zip export.
- `references/scripts/merge-settings.sh` -- merges an incoming
  `settings.json` into a target's existing one without dropping the
  target's own project-specific hook registrations (see
  `references/config-export-import.md` step 2.2). Also gets installed
  into the target's own `.claude/scripts/`, not just used transiently.
- `references/scripts/export-config-skill.sh` -- this very script,
  installed into the target's own `.claude/scripts/` too, so the target
  repo can export its own bundle later instead of only ever being an
  import destination.
- `references/skills/<name>/<name>.md` -- four generic skills.
  `file-operations`, `github-rules`, and `find-skills` are
  mandatory/blind-copy (step 2.2). `file-operations`/`github-rules` were
  each briefly made an optional import choice on 2026-07-27, then moved
  back the same day (`github-rules` first, `file-operations` shortly
  after). `find-skills` had a longer round trip the same general period
  -- optional, deleted entirely, restored as optional, deleted again as
  fetch-on-demand only, then finally made mandatory/always-present again
  on 2026-07-28 -- explicit user request at every step, current state
  being: always present, not merely recommended. `changelog-rules` is
  the one remaining optional import choice (step 2.5) -- briefly removed
  from the bundle entirely on 2026-07-27, restored from git history and
  put back as optional on 2026-07-28. Each one's
  entry point is named `<name>.md` here
  instead of `SKILL.md`, because a `.skill` package may only contain one
  `SKILL.md` (this one) -- nesting more would fail validation on upload.
  **When actually installing one of these into a target repo's
  `.claude/skills/<name>/`, rename `<name>.md` back to `SKILL.md`** --
  that rename is what turns it back into a real, loadable skill.

## What to do

1. Read `references/config-export-import.md` in full.
2. Follow its numbered import steps (2.1 through 2.9) exactly, using the
   files under `references/` as the bundle content described there.
3. Narrate every step, per that file's own instruction.
EOF

sed '/^## Project-specific rules/,$d' CLAUDE.md > "$skill_dir/references/CLAUDE.md"
cp .claude/config-export-import.md "$skill_dir/references/"
cp .claude/recommended-skills.txt "$skill_dir/references/"
[ -f .claude/removed-files.txt ] && cp .claude/removed-files.txt "$skill_dir/references/"
cp .claude/settings.json "$skill_dir/references/"

# Same self-describing note the old export-config.sh used to include --
# kept here too for exact parity, even though this package's own
# top-level SKILL.md now also serves that "read this before touching
# anything" role.
cat > "$skill_dir/references/00-START-HERE.md" <<'EOF'
# Before touching any file in this bundle

This is a Claude Code config export: `CLAUDE.md`, `settings.json`,
`hooks/`, `skills/`, `config-export-import.md`, `recommended-skills.txt`,
and possibly `skills-lock.json`/`removed-files.txt`.

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

# Trim skills-lock.json to just find-skills' own entry -- the full file
# also tracks whatever else this repo happens to have installed right
# now, none of which is in this bundle.
if [ -f .claude/skills-lock.json ]; then
  jq '.skills |= {"find-skills": .["find-skills"]}' .claude/skills-lock.json > "$skill_dir/references/skills-lock.json"
fi

for hook in check-reply-format.sh config-ingest-reminder.sh \
  init-submodules.sh no-commit-on-main.sh \
  precompact-hygiene-flag.sh \
  rule-check-reminder.sh skill-creation-reminder.sh \
  submodule-clone-fixup.sh; do
  [ -f ".claude/hooks/$hook" ] && cp ".claude/hooks/$hook" "$skill_dir/references/hooks/"
done

for skill in changelog-rules file-operations find-skills github-rules; do
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
