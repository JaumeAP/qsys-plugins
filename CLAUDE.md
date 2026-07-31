# CLAUDE.md — common rules (identical across all my projects)

Every section of this file above "Project-specific rules" is IDENTICAL in
every one of my repos — copy it verbatim into a new project, unchanged. The
"Project-specific rules" section gets replaced with the new repo's own
content.

Kept under ~200 lines deliberately (2026-07-30): this file loads in full at
the start of every session regardless of task, and adherence drops as it
grows. Detail that isn't needed every session lives behind the pointers
below — full dated history/reasoning for every rule in this file lives in
`.claude/skills-history.md`, not restated here.

## Response style (always, every session)

Code, commands, paths, params stay literal — caveman only protects
"technical terms, code, API names, CLI commands... exact error strings",
never mentions paths/params by name, kept explicit here rather than assumed
covered. Proper nouns/technical terms: original language unless misleading,
clarity over purism — a real exception caveman doesn't have.

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
(JuliusBrussee/caveman) — that skill replies in the user's own dominant
language; no bold/em-dash/ellipsis/header/table ban, no mandatory leading
"Rebut:" line.

**Exception: lists are always numbered** (`1. 2. 3.` form, never bullets,
regardless of intensity level or language) — overrides caveman on this one
point only.

**Exception: announce multi-step tool sequences.** For git commit/push,
multi-file edits, and test runs, announce each step as a bare 1-3 word
action — "Commit.", "Push.", "Tests." — no explanation, before or after but
not both. **Git-absent repos:** if the working directory has no git at all
(detect once per session, e.g. `git rev-parse --is-inside-work-tree`),
"Commit."/"Push." never apply; multi-file-edit and test-run announcements
are unaffected.

**Changelog-before-commit:** when git is present, `changelog-rules` is
installed (`.claude/skills/changelog-rules/` exists), and a file with a
`## Changelog` section needs an entry per that skill's own workflow, update
the accumulated entry and stage it into the same commit — right before
running `git commit`, never after. Skip entirely, no error, if
`changelog-rules` isn't installed in this repo.

**Exception: collapse a skill suite to one line.** When a skill is a suite
(several sub-skills fetched from one `owner/repo`, e.g. `caveman`,
`superpowers`, `remotion`) and it comes up in a reply, give the suite's own
name plus its sub-skill names as one line/entry (`caveman (suite:
caveman-commit, caveman-compress, ...) -> owner/repo`), never one numbered
list item per sub-skill.

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
2. `changelog-rules` (`.claude/skills/changelog-rules/SKILL.md`) — bundled,
   mandatory, installed in all three repos. How to write/maintain entries:
   format, semantic versioning, the accumulate-in-memory-until-commit
   workflow, retention/dedup, exempt files.
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
per session (mechanizing the "Git-absent repos" exception above, so it
isn't left as prose alone). Full rationale in both hooks' own comments and
`.claude/skills-history.md` — not restated here.

Everything else installed locally is listed by name/source in
`.claude/recommended-skills.txt` (fetch-on-demand, updated by hand). What
actually travels on export is defined in
`.claude/scripts/export-config-skill.sh` — not repeated here, to avoid two
lists that drift apart.

**Skill creation/extension:** plain manual edits to any `SKILL.md` are fine
(repo-specific and portable alike) — no mandatory skill-creator process.
`skill-creator` remains available; invoke it by choice when trigger
accuracy or behavioral output genuinely needs evaluating, not for
reference-doc content edits. Full history of why the earlier "always
mandatory" rule was tried and dropped: `.claude/skills-history.md`.

## Session continuity

**Long-session hygiene.** No reliable way to measure token budget from inside
a turn, so this is heuristic: when signs of a long session appear (many
turns, lots of accumulated work, or a compaction has clearly happened),
proactively suggest continuing in a fresh chat. Long sessions get lossy.

**"Tanca" always means end the session.** Full routine (git status/log, PR
merge check, git-absent fallback, continuity notes) lives in
`.claude/rules/session-close.md` — always loaded alongside this file, same
mechanism.

## Project-specific rules — read `PROJECT.md`

This repo's project-specific documentation, conventions, and rules live in
`PROJECT.md` at the repo root. See that file for: what this repo is, where
docs live, detail on path-scoped rules, continuity notes, open threads, and
git conventions. Read `PROJECT.md` before editing anything project-specific
to this repo.
