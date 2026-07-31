# Session close ("Tanca") routine

<!-- Split out of CLAUDE.md's "Session continuity" section 2026-07-31
(explicit user request) to trim CLAUDE.md toward its own ~200-line target.
Portable: travels on export like CLAUDE.md itself (see
export-config-skill.sh's explicit rules-file allowlist — NOT a blind copy
of the whole .claude/rules/ directory, since that also holds
project-specific files like repo-layout.md that must NOT travel). Always
loaded alongside CLAUDE.md, same mechanism, per rule-check-reminder.sh's
own job 1 comment. -->

**"Tanca" always means end the session.** A bare "tanca" (no other object
attached) always means "tanca sessió" — never "drop this topic". Detect git
once before running the routine (e.g. `git rev-parse --is-inside-work-tree`;
`rule-check-reminder.sh` also surfaces this fact once per session, job 3):

- **Git present:** before signaling closed, run plain `git status` (not
  `--short`; it reports branch and clean/dirty together, so a separate
  `git branch --show-current` adds nothing), then `git log --oneline -1`.
  Say plainly what's left uncommitted/unpushed. Also check whether the
  current branch has an open PR at `mergeable_state: clean` and merge it as
  part of the same routine, per `github-rules`' merge-automation default —
  don't leave it for the user to ask separately.
- **Git absent** (2026-07-31, explicit user request): skip the `git
  status`/`git log`/PR-merge checks entirely, they don't apply. Instead
  state plainly which files were created/edited this session, from your
  own turn history — that's the closest equivalent of "what's left
  unsaved," since there's no commit/push state to report.

Unfinished work or an open question worth a future session picking up gets
a dated entry in this repo's continuity notes first —
`docs/continuity-notes.md`, created there if the repo doesn't have one yet
(this file is portable, so don't assume `docs/continuity-notes.md` already
exists). This applies regardless of git presence — continuity notes are
plain files.
