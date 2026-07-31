# CLAUDE.md — common rules (identical across all my projects)

Every section of this file above "Project-specific rules" is IDENTICAL in
every one of my repos — copy it verbatim into a new project, unchanged. The
"Project-specific rules" section gets replaced with the new repo's own
content.

Kept under ~200 lines deliberately (2026-07-30): this file loads in full at
the start of every session regardless of task, and adherence drops as it
grows. Detail that isn't needed every session lives behind the pointers
below.

## Response style (always, every session)

Code, commands, paths, params stay literal — caveman only protects
"technical terms, code, API names, CLI commands... exact error strings",
never mentions paths/params by name, kept explicit here rather than assumed
covered. Proper nouns/technical terms: original language unless misleading,
clarity over purism — a real exception caveman doesn't have (caveman's own
exception is user-requested translation, not clarity; restored 2026-07-30
after a code review caught this specific clause as a silent behavior
change, not an actual duplicate).

No servility, contradict directly when wrong, never agree to appease,
challenge politely if disagree, never invent, say if unsure. Assume
technical competence, no basic intros, preserve files/configs/decisions/
params literally, apply corrections immediately within session. Never
rename an output file without explicit request. One question per reply
except technical tasks needing several. No unsolicited closing
offers/summaries/tangents.

Conditional: length under fifty words unless code snippets, multi-step
technical tasks, or teaching requested, then expand as needed but stay
focused. Verify with search first for changing facts (prices, versions,
charges, events); verify before critical or irreversible actions.

**Reply language, compression, and formatting defer to `caveman`**
(JuliusBrussee/caveman), 2026-07-30, explicit user request, reversing the
same day's earlier "this section wins" note. That skill replies in the
user's own dominant language, and there is no bold/em-dash/ellipsis/header/
table ban, and no mandatory leading "Rebut:" line — all removed from this
section for that reason. The hooks that used to enforce them
(`check-reply-format.sh`, `reply-format-preflight.sh`) were unregistered
from `settings.json` the same day; the scripts stay on disk, dead, with
their own retirement notes.

**Exception, same day, later, explicit user request: lists are always
numbered.** Overrides caveman on this one point only (caveman itself
imposes no list-format rule either way) — every list in a reply uses `1.
2. 3.` form, never bullets, regardless of intensity level or language.

**Second exception, same day, still later, explicit user request: announce
multi-step tool sequences.** For git commit/push, multi-file edits, and test
runs, announce each step as a bare 1-3 word action — "Commit.", "Push.",
"Tests." — no sentences, no explaining what the command does, why, or its
mechanism/internals, bare label only, before or after but not both. This
briefly deferred to caveman's "no tool-call narration" the same day as the
deferral above, then was carved back out as a second named exception once
that loss turned out not to be wanted — same pattern as the numbered-lists
exception just above, not a reversal of the broader deferral itself.
**Git-absent repos** (2026-07-31, explicit user request, auto-detected not
assumed): if the working directory has no git at all, "Commit."/"Push."
never apply — there is nothing to commit or push. Detect once per session
(e.g. `git rev-parse --is-inside-work-tree`); if absent, skip straight to
saving/writing files with no bare label for that non-step. Multi-file-edit
and test-run announcements are unaffected, they don't depend on git.

**Changelog-before-commit** (2026-07-31, explicit user request, auto-detected
not assumed): when git is present and `changelog-rules` is installed
(`.claude/skills/changelog-rules/` exists) and a file with a `## Changelog`
section needs an entry per that skill's own workflow, update the accumulated
entry as part of the same batch of edits, staged into the same commit —
right before running `git commit`, never after. **If `changelog-rules`
isn't installed in this repo, skip this step entirely, no error, proceed
straight to "Commit." as always** — this is an addition on top of the
normal flow, never a blocker for repos that don't carry the skill.

**Third exception, 2026-07-31, explicit user request (asked repeatedly
before being made permanent): collapse a skill suite to one line.** When a
skill is a suite (several sub-skills fetched from one `owner/repo`, e.g.
`caveman`, `superpowers`, `remotion`) and it comes up in a reply — a skill
list, an install summary, anything — give the suite's own name plus its
sub-skill names as one line/entry (`caveman (suite: caveman-commit,
caveman-compress, ...) -> owner/repo`), never one numbered list item per
sub-skill. Applies wherever a suite is mentioned, not just
`recommended-skills.txt`/`programming-optional-skills.txt` (which already
use this format).

## Portable skills (installed with the config)

These travel with this file and the rest of `.claude/`. Full status history
and reasoning for every skill below: `.claude/skills-history.md` — pointers
only here, current state only, never summaries or backstory:

1. `github-rules` (`.claude/skills/github-rules/SKILL.md`) — bundled,
   mandatory. Portable GitHub PR conventions: workflow shape, reading
   `pull_request_read` results, merge mechanics. Carries one dated,
   attributed standing authorization (2026-07-29) to open a PR at session
   close when the branch has unmerged commits and none exists, then merge
   it once clean. Anything BEYOND that one authorization still needs its
   own named source and date — a policy written into a portable file
   without one silently applies to every repo that imports the bundle,
   which is the thing to refuse.
2. `changelog-rules` (`.claude/skills/changelog-rules/SKILL.md`, where
   installed) — bundled, OPTIONAL per repo: install only where a repo
   actually maintains a changelog. How to write/maintain entries: format,
   semantic versioning, accumulate-in-memory-until-push workflow,
   retention/dedup, exempt files.
3. `file-operations` (`.claude/skills/file-operations/SKILL.md`) — bundled,
   mandatory. Triggers by context on any file I/O; no pointer needed beyond
   its own description.
4. `caveman` (JuliusBrussee/caveman) — mandatory, fetch-on-demand (listed in
   `.claude/recommended-skills.txt`, not bundled as a file). Compression,
   terseness, token economy in replies; applies to any project regardless
   of language or domain.

**"Mandatory" is enforced, not just stated.** Two mechanisms back it, per
skill's own tooling: `.claude/hooks/file-operations-enforcement.sh`
(`PreToolUse`/`Bash`, hard block) gates `file-operations`' narrowest,
safety-relevant case; `rule-check-reminder.sh` names the currently-mandatory
skills by name on its own firings, and separately checks git presence once
per session (mechanizing the "Git-absent repos" exception below, so it
isn't left as prose alone). Full rationale in both hooks' own comments and
`.claude/skills-history.md` — not restated here.

Everything else installed locally is listed by name/source in
`.claude/recommended-skills.txt` (fetch-on-demand, updated by hand). What
actually travels on export is defined in
`.claude/scripts/export-config-skill.sh` — not repeated here, to avoid two
lists that drift apart.

**Skill creation/extension — mandatory skill-creator process RETIRED
(2026-07-31, explicit user request).** From 2026-07-20 through 2026-07-31
this section required every `SKILL.md` create/edit to go through
`skill-creator`'s full interview/eval/benchmark process, never a plain
manual edit. Reversed the same day it was tightened into a "no shortcuts,
ever" clause: tested once for real on a content edit to `github-rules`
(a reference-doc skill, no subjective/behavioral triggering to evaluate) —
4 subagents, ~210k tokens, a real bug in the eval-viewer tooling itself,
and a measured **0% behavioral difference** between the old and new skill
content. The user's own verdict, directly: not spending that cost on
something that doesn't work. Plain manual edits to any `SKILL.md` are fine
again, repo-specific and portable alike. `skill-creator` itself is still
available and still useful for what it's actually suited to — a new skill,
or a change to one where trigger accuracy or behavioral output is the
question — invoke it by choice when that's the situation, not by
default. `writing-skills` (obra/superpowers) remains removed regardless
(2026-07-30, unrelated reason — a competing TDD-based process for the same
action).
`.claude/hooks/skill-creation-reminder.sh` mechanized the retired mandate
and is unregistered from `settings.json` as of this same reversal — see
that script's own header for the retirement note (same pattern as
`check-reply-format.sh`/`reply-format-preflight.sh`: left on disk, dead).

## Session continuity

**Long-session hygiene.** No reliable way to measure token budget from inside
a turn, so this is heuristic: when signs of a long session appear (many
turns, lots of accumulated work, or a compaction has clearly happened),
proactively suggest continuing in a fresh chat. Long sessions get lossy.

**"Tanca" always means end the session.** Full routine (git status/log, PR
merge check, git-absent fallback, continuity notes) now lives in
`.claude/rules/session-close.md` — always loaded alongside this file, same
mechanism, moved out 2026-07-31 to keep this file near its own ~200-line
target.

## Project-specific rules — read `PROJECT.md`

This repo's project-specific documentation, conventions, and rules live in
`PROJECT.md` at the repo root. See that file for: what this repo is, where
docs live, detail on path-scoped rules, continuity notes, open threads, and
git conventions. Read `PROJECT.md` before editing anything project-specific
to this repo.
