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
same day's earlier "this section wins" note — includes tool-call
narration: caveman's "No tool-call narration" wins over this file's former
"announce each step" rule, dropped 2026-07-30 for that reason. That skill
replies in the user's own dominant language, and there is no
bold/em-dash/ellipsis/header/table ban, and no mandatory leading "Rebut:"
line — all removed from this section for that reason. The hooks that used
to enforce them (`check-reply-format.sh`, `reply-format-preflight.sh`) were
unregistered from `settings.json` the same day; the scripts stay on disk,
dead, with their own retirement notes.

**Exception, same day, later, explicit user request: lists are always
numbered.** Overrides caveman on this one point only (caveman itself
imposes no list-format rule either way) — every list in a reply uses `1.
2. 3.` form, never bullets, regardless of intensity level or language.

## Portable skills (installed with the config)

These travel with this file and the rest of `.claude/`. Two skills are
bundled as files — `file-operations` and `github-rules`. Two additional
mandatory skills — `caveman` and `karpathy-guidelines` — fetch on-demand
from remote (not bundled locally), but are obligatory for all target repos.
Import mechanics (blind-copy, merge rules, everything else in that process)
live solely in `.claude/config-export-import.md`, not restated here. Pointers
only here, never summaries — each skill is the authority on its own topic:

1. `github-rules` (`.claude/skills/github-rules/SKILL.md`) — portable GitHub
   PR conventions: workflow shape, reading `pull_request_read` results, merge
   mechanics. Carries one dated, attributed standing authorization
   (2026-07-29) to open a PR at session close when the branch has unmerged
   commits and none exists, then merge it once clean. Anything BEYOND that
   one authorization still needs its own named source and date — a policy
   written into a portable file without one silently applies to every repo
   that imports the bundle, which is the thing to refuse.
2. `file-operations` — triggers by context on any file I/O; no pointer needed
   beyond its own description.

Mandatory fetch-on-demand (listed in `.claude/recommended-skills.txt`):

3. `caveman` (JuliusBrussee/caveman) — compression, terseness, and token
   economy in replies; applies to any project regardless of language or domain.
4. `karpathy-guidelines` (forrestchang/andrej-karpathy-skills) — thinking
   principles and behavioral guidelines applicable to any project.

Everything else installed locally is listed by name/source in
`.claude/recommended-skills.txt` (fetch-on-demand, updated by hand). What
actually travels on export is defined in
`.claude/scripts/export-config-skill.sh` — not repeated here, to avoid two
lists that drift apart. Why any given skill is bundled, optional, or removed:
`.claude/skills-history.md`.

**Skill creation/extension.** Any new `SKILL.md`, or any content/frontmatter
change to an existing one, goes through the `skill-creator` skill's process,
not a plain manual edit (2026-07-20 standing rule; repo-specific and portable
skills alike). `writing-skills` (obra/superpowers) prescribes a competing
TDD-based process for the same action and was removed 2026-07-30 for that
reason — `skill-creator` is the sole mandated process.
`.claude/hooks/skill-creation-reminder.sh` reminds on every `Write`/`Edit` to
a `SKILL.md` but can't verify the skill was actually invoked, so it can't
hard-block.

## Session continuity

**Long-session hygiene.** No reliable way to measure token budget from inside
a turn, so this is heuristic: when signs of a long session appear (many
turns, lots of accumulated work, or a compaction has clearly happened),
proactively suggest continuing in a fresh chat. Long sessions get lossy.

**"Tanca" always means end the session.** A bare "tanca" (no other object
attached) always means "tanca sessió" — never "drop this topic". Before
signaling closed: run plain `git status` (not `--short`; it reports branch
and clean/dirty together, so a separate `git branch --show-current` adds
nothing), then `git log --oneline -1`. Say plainly what's left
uncommitted/unpushed. Also check whether the current branch has an open PR at
`mergeable_state: clean` and merge it as part of the same routine, per
`github-rules`' merge-automation default — don't leave it for the user to ask
separately. Unfinished work or an open question worth a future session
picking up gets a dated entry in this repo's continuity notes first —
`docs/continuity-notes.md`, created there if the repo doesn't have one yet
(this section is portable, so don't assume the file already exists).

## Project-specific rules — read `PROJECT.md`

This repo's project-specific documentation, conventions, and rules live in
`PROJECT.md` at the repo root. See that file for: what this repo is, where
docs live, detail on path-scoped rules, continuity notes, open threads, and
git conventions. Read `PROJECT.md` before editing anything project-specific
to this repo.
