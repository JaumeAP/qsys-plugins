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
  Say plainly what's left uncommitted/unpushed. Also apply `github-rules`'
  own merge-automation default as part of the same routine — don't leave it
  for the user to ask separately.
- **Git absent** (2026-07-31, explicit user request): skip the `git
  status`/`git log`/PR-merge checks entirely, they don't apply. Instead
  state plainly which files were created/edited this session, from your
  own turn history — that's the closest equivalent of "what's left
  unsaved," since there's no commit/push state to report.

**Multi-repo sessions (2026-07-31, explicit user request — minimum tokens, minimum interactions, never check the same place twice):** when closing a session that touched more than one repo, run the git-present checks above for ALL of them inside ONE Bash call (a shell loop over the repo paths), not one Bash call per command per repo — N repos × 2 commands is N × 2 facts, not N × 2 tool calls. Fire the independent per-repo PR-merge checks (`pull_request_read`/`merge_pull_request`) together in one message too, not one per turn — see `github-rules`' own "Multi-repo sessions" section for the GitHub-API side of this. If a repo's git status or a PR's `mergeable_state` was already established earlier in this same turn and nothing has changed since, reuse it instead of re-running the identical check again at close.

Unfinished work or an open question worth a future session picking up gets
a dated entry in this repo's continuity notes first —
`docs/continuity-notes.md`, created there if the repo doesn't have one yet
(this file is portable, so don't assume `docs/continuity-notes.md` already
exists). This applies regardless of git presence — continuity notes are
plain files.
