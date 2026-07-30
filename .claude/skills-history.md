# Portable skills/config history

<!-- Split out of CLAUDE.md's "Portable skills" section 2026-07-30 (explicit
user request) to bring the main memory file under the ~200-line guidance.
Lives inside .claude/ so it travels with the portable bundle on export, but
is NOT auto-loaded (only CLAUDE.md and .claude/rules/*.md are). Read it when
you need the reasoning behind a skill's bundled/optional/removed status. -->

<!-- Cross-references in this file that say "above"/"below" may now point at
a sibling file after the 2026-07-30 split: CLAUDE.md (operative rules),
.claude/rules/repo-layout.md (directory tree),
.claude/rules/qsys-plugin-development.md (plugin/build reference), or
docs/continuity-notes.md (dated history). -->

## Portable skills (installed with the config)

These generic skills travel with this file and the rest of the `.claude/`
config (see `.claude/config-export-import.md`). `file-operations` and
`github-rules` are mandatory/blind-copy on import into
another repo — the only two skills still bundled as files at all.
`find-skills` moved to fetch-on-demand only 2026-07-28 (explicit user
request), after its own longer mandatory/optional/bundled history
below: no longer bundled as a file, listed instead in
`.claude/recommended-skills.txt` (`find-skills -> vercel-labs/skills`)
like any other unbundled recommendation, fetched live via
`npx skills add vercel-labs/skills -s find-skills` by whoever wants it —
a state it had already passed through once before this same day,
reverted at the time, now the settled choice (see the history note
below). This repo's own local copy of `find-skills` was deleted
outright 2026-07-29 (explicit user request) — `.claude/skills/
find-skills/` removed from disk, repo-local only, deliberately NOT
added to `.claude/removed-files.txt` (that would mechanize pruning it
from every other repo importing this bundle in the future, which
wasn't asked for and isn't warranted here — `find-skills` already
isn't shipped as a bundled file per the paragraph above, so there's
nothing export-side this deletion needed to affect). It had been meant
to stay on disk but disabled via a `skillOverrides: {"find-skills":
"off"}` entry in `.claude/settings.local.json` (gitignored) — but that
settings file was never actually present in this checkout, so the
local copy was live (not disabled) the whole time until this deletion.
Pointers
only, not summaries — same
drift-safety reason as above; each skill is the authority on its own topic,
invoke it when the task calls for it:

1. `github-rules` (`.claude/skills/github-rules/SKILL.md`) — portable GitHub
   PR conventions (workflow shape, reading `pull_request_read` results,
   merge mechanics); generalized 2026-07-27 from an earlier repo-specific
   skill of the same name. Originally: must never encode a standing
   auto-merge policy, since a portable file installs into every repo it's
   imported into, so a rule like that written here would silently apply
   everywhere, not just where someone actually agreed to it. Relaxed
   2026-07-29, explicit user request, after being shown that exact
   consequence and choosing it anyway: the skill now carries a dated,
   attributed standing authorization to open a PR at session close when
   the branch has unmerged commits and none exists, then merge it once
   clean. The reasoning behind the original prohibition is unchanged and
   still applies to anything BEYOND that one authorization — a policy
   written there without a named source and date, or one covering more
   than the routine open/merge cycle, is still the thing to refuse. What
   made this case different is that the authorization is recorded rather
   than self-granted, which is also what lets it satisfy (not bypass) a
   calling environment's own PR-creation gate.

(`git-rules` removed from the portable bundle 2026-07-25, explicit user
request — deleted from `.claude/skills/`, its `skillOverrides` entry
dropped from `settings.json`, and its path added to
`.claude/removed-files.txt` so future imports of an older bundle prune it
from target repos too. Git workflow now follows plain judgement +
the rest of this file's rules, not a dedicated skill.)

(`changelog-rules` and `find-skills` briefly removed from the portable
bundle 2026-07-27, explicit user request, then restored from git history
2026-07-28, also explicit user request. `changelog-rules` stayed optional
from there on, disabled locally alongside `find-skills` once that one
also went optional later 2026-07-28 — until `changelog-rules` was
deleted from the portable bundle entirely a second and final time, also
2026-07-28, also explicit user request: same treatment as `git-rules`
above (`.claude/skills/changelog-rules/` deleted, its now-moot
`skillOverrides` entry dropped from `settings.local.json`, its path
added to `.claude/removed-files.txt`). Changelog work now follows the
repo-wide conventions stated directly where needed, not a dedicated
skill — see the version-history/breaking-change note under "Plugin
structure/naming convention" below.
`find-skills` took a longer road of its own — removed from the
bundle again the same day as a `recommended-skills.txt` fetch-on-demand
entry, then, after weighing whether that was actually worth it, made
mandatory/always-present again the same day, then superseded later the
same day, also explicit user request: moved to optional (still a
bundled file at that point) instead. Superseded once more, also
2026-07-28, also explicit user request: moved off the bundled-file path
entirely, back to fetch-on-demand-only via `recommended-skills.txt` —
ending up back where its first fetch-on-demand attempt left off. Its
local copy went one step further 2026-07-29, also explicit user
request: deleted outright rather than kept disk-side and disabled, see
above.)

**Find Skills**: `find-skills`, imported from `vercel-labs/skills`
(`skills/find-skills/SKILL.md`) — discovers and installs third-party
skills via the `npx skills` CLI, #1 by install count on skills.sh at
import time. Note its own workflow can
install other skills straight from that ecosystem, bypassing this
repo's own skill-creator/config-ingest governance — worth keeping in
mind wherever it ends up. Fetch-on-demand only now (see above), not a
bundled file — no longer tracked in `skills-lock.json` in the export
either, since that file existed specifically to carry `find-skills`'
own installation provenance along with the bundled copy; a target repo
fetching it fresh via `npx skills add` generates its own lock entry
instead.

(`file-operations` needs no pointer here beyond the numbered list above
— its own description triggers it by context when there's file I/O to
do.)

**Which additional skills travel on export is defined in
`.claude/scripts/export-config-skill.sh`** — not repeated here, to avoid
two places that can drift out of sync. Anything installed here but not in
that script's copy list stays local; its name/source is kept in
`.claude/recommended-skills.txt` (plain list, one name per line,
updated by hand) for a target repo to fetch itself if wanted — that
file itself always travels on export.

**Skill creation/extension.** Any skill creation or extension (a new
`SKILL.md`, or a content/frontmatter change to an existing one — this
applies regardless of whether the skill itself is repo-specific or
portable) goes through the `skill-creator` skill's process, not a plain
manual edit (2026-07-20 standing rule). Mechanized best-effort by
`.claude/hooks/skill-creation-reminder.sh` — a non-blocking reminder on
every `Write`/`Edit` to a `SKILL.md`; it can't verify skill-creator was
actually invoked, so it can't hard-block, same honest limitation as
`config-ingest-reminder.sh`. The `writing-skills` skill (from the
`obra/superpowers` bundle) was installed 2026-07-30 alongside the rest
of that bundle, then removed the same day (explicit user request) once
it turned out to prescribe a competing TDD-based process for this same
action, conflicting with `skill-creator`; also dropped from
`recommended-skills.txt`. `skill-creator` remains the sole mandated
process here.
