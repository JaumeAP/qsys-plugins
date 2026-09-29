---
name: git-sync-and-merge
description: Use when the user says "sincronitza" or signals a session close, when integrating a working branch into the default branch, or when a push, pull request, or the close git sequence has to run without stalling on a missing remote or a conflict.
---

# Git sync and merge

## Overview

Branch integration here is **autonomous and goes through a pull request**. Open it,
merge it with a merge commit, clean up — no approval wait, no "should I merge it?".
The two moments that trigger it are the "sincronitza" command mid-session and a session
close. Both run the same sequence; only the surrounding work differs.

Core principle: **the sequence completes or the repo is left clean — never half-merged.**

## When to use

- The user says "sincronitza" / "sincronitzar".
- The user signals a session close and work has to be integrated.
- A branch is ready and needs to reach the default branch.
- A push fails or is refused and the chain must stop cleanly.
- A pull request cannot be merged because it conflicts.

Not for: deciding *whether* `docs/continuity-notes.md` should be rewritten. That is a
separate concern — see the `continuity-notes-rules` skill.

## Quick reference

| Question | Answer |
|---|---|
| Pull request or local merge? | Pull request, always: `gh pr create`, then `gh pr merge --merge`. Never a local merge into the default branch. |
| Merge flavor | `--merge` (merge commit), so the branch stays visible in history. Never squash, never rebase. |
| Default branch | Resolve it, do not assume — see below. |
| How many Bash calls | Two for the sequence itself. Inspection and local verification before, and verification after, are outside the cap. |
| No GitHub remote | Stop: commit on the working branch and tell the user. No merge. |
| Push runs and fails | Stop: no pull request without the pushed branch. Report it. |
| Nothing to commit | Guard the commit — a clean tree makes `git commit` exit 1 and kill the chain. |
| Remote CI | Not a merge gate when local verification covers the same checks. |
| Pull request conflicts | Cap suspended: leave the PR open, end on the working branch, tell the user. |
| Remote branch | Not deleted by this sequence. |

## Before the sequence

Inspect first — one call usually, more when a rung of the default-branch ladder answers
ambiguously. Inspection is **outside** the two-call cap — the cap covers the
integration sequence, not the reads that decide what the sequence contains. So is the
local verification, any verification call afterwards, and any call that was denied and
never executed.

The inspection resolves three things:

1. **The working branch** — `git rev-parse --abbrev-ref HEAD`. That is `<branch>` throughout;
   the sequence never invents one.
2. **Whether a GitHub remote exists** — `git remote -v`. Empty, or a remote that is not on
   GitHub, means a pull request is impossible: take the no-remote path below.
3. **The default branch** — in this order:
   - `git ls-remote --symref origin HEAD`, which answers even when the local
     `refs/remotes/origin/HEAD` was never set. **Empty output with exit 0 is not an answer** —
     it means the remote's own HEAD is a dangling symref (it names a branch that does not
     exist there). Treat empty as a fall-through to the next rung, never as "no default".
   - `git symbolic-ref --short refs/remotes/origin/HEAD` — only present in repos created by
     `clone` or fixed with `git remote set-head origin -a`. It fails with `fatal: ref ... is
     not a symbolic ref` in every other repo, which is the common case, not the exception.
   - `git ls-remote origin` and `git branch --list main master` — which branches actually
     exist, remote and local. This is the rung that answers when the two above go quiet.
     `git config --get init.defaultBranch` is a hint, not evidence: it happily returns `main`
     in a repo whose only branch is `master`. Confirm the branch you are about to target
     actually exists. A PR opened with the wrong `--base` fails, or worse, lands on the
     wrong branch.

Then verify locally that the project builds and its tests pass — the project's
`CLAUDE.md` names the exact commands when it names any. A change touching only
documentation or tooling runs neither. A failing build or test stops here: nothing is
pushed, and the user is told.

If the close being performed regenerates the continuity notes, write them **before** call 1, so
`git add -A` picks it up.

## The sequence

Exactly two Bash calls:

**Call 1** — isolated, alone:

```bash
git checkout <branch>
```

It is isolated because branch guards inspect git state at the moment of the call. A
`checkout` buried later in a chain leaves those guards reading the branch you were on,
not the one you will be on.

**Call 2** — everything else, chained with `&&`:

```bash
{ git add -A && git commit -m "<subject>" || echo "NOTHING TO COMMIT - continuing"; } \
  && git push -u origin <branch> \
  && { gh pr view <branch> --json number >/dev/null 2>&1 \
       || gh pr create --base <default> --head <branch> --title "<title>" --body "<body>"; } \
  && gh pr merge <branch> --merge --subject "merge: <branch> into <default>" \
  && git checkout <default> \
  && git pull --ff-only origin <default> \
  && git branch -d <branch>
```

The commit guard is load-bearing. `git commit` exits 1 on a clean tree, and a mid-session
"sincronitza" with everything already committed is an ordinary case, not an edge one — an
unguarded commit aborts the chain before the pull request is ever opened.

The push is deliberately **not** guarded: a pull request needs the pushed branch, so a
failed push must stop the chain. The `gh pr view` guard reuses a pull request already open
for the branch instead of failing on a duplicate `gh pr create`.

The PR title and body follow the repository's language rule (English). End the body with
the attribution lines the session provides, if any.

Agent contexts reset the working directory between calls: prefix each call with
`cd <repo> &&`. That does not split a call, so the cap is unaffected.

## After the sequence

Verify rather than trusting the command output: `gh pr view <branch> --json state,mergeCommit`
and `git log --oneline --graph -10`. This is outside the cap.

The run ends on the default branch with the local working branch deleted. After a
mid-session "sincronitza", further work starts on a new branch.

The remote branch is left alone. Do not try to delete it if the environment has no
permission for it, and if a deletion fails, do not retry it or report it.

If `refs/remotes/origin/HEAD` was missing during inspection, `git remote set-head origin -a`
usually fixes it once and spares the next run the fallback. It fails with
`error: Cannot determine remote HEAD` when the remote's HEAD itself dangles; the repair is
then on the remote, which is outside this skill's scope — report it rather than working
around it every run.

## Closing the window, at a session close only

A session close ends the session, so it ends the window too. After the sequence
has been verified and the reply is written -- the merge reported, anything that
failed reported -- the last call of the run closes it:

```bash
claude-session-close
```

That command belongs to the `new-session` plugin, which owns the windows;
nothing in the harness closes one, because a session close is a phrase the model
acts on and not a harness event. It does not kill the session: it queues `/exit`
in the window, which the harness submits when this turn ends, and a watcher
closes the window once the session has exited on its own. So the reply being
written right now does reach the user, and the command returns before the window
is gone -- it succeeding means the exit was queued, not that the window closed.
Still nothing follows it: the queued `/exit` ends the turn whatever is left in
it, so no question and no verification can come after. A window it cannot reach
(no iTerm2, no controlling terminal) is reported and left open, and so is a
window showing a menu, where the line would confirm the highlighted row instead
of being read: that answers 2, with nothing queued and no watcher armed.

**Only at a session close.** `sincronitza` is a mid-session command: the branch
is integrated and the work goes on, so the window stays. Closing there would
kill a session with work still in front of it.

## Failure paths

**No GitHub remote.** `git remote -v` came back empty, or pointing somewhere that is not
GitHub, during inspection. A pull request is impossible, so there is no merge. Commit the
pending work on the working branch (guarded, as in call 2), stay on it, and tell the user
the branch was not integrated and why. Never fall back to a local merge.

**Push runs and is rejected, or is refused before it runs.** The chain stops before the
pull request. Nothing reached the default branch. Report the failure; do not silently
swallow it.

**Nothing to commit.** The guard absorbs it and the chain continues to the push. Expected
whenever the work was already committed.

**Pull request conflicts.** `gh pr merge` refuses a PR that does not merge cleanly, and the
chain stops with HEAD still on the working branch. The two-call cap is suspended from that
point. Leave the pull request open, tell the user what conflicted, and ask which side wins.
Do not resolve it by picking a winner yourself.

**Merged remotely, local cleanup fails.** The integration is done; report which cleanup
step failed (`git pull --ff-only`, `git branch -d`) rather than retrying blindly.

**A call is denied.** A denied call changes no state. Re-issuing it corrected is not a
third call — only executed calls count against the cap.

## Commit subjects

Conventional Commits.

| Commit | Subject |
|---|---|
| Merge | `merge: <branch> into <default>` |
| Regenerated continuity notes at close | `docs: regenerate the continuity notes at session close` |
| Pending work swept up by a mid-session sync | `chore: sync pending work` |

## Common mistakes

| Mistake | Consequence |
|---|---|
| Merging locally into the default branch | Bypasses the pull request the integration rule requires. |
| Asking "should I merge it?" | Integration stalls waiting for an approval nobody needs to give. |
| Squashing or rebasing the PR | Loses the branch in history; explicitly forbidden. |
| Waiting for remote CI | Stalls on a check local verification already covered. |
| Guarding the push with `\|\| echo` | The chain goes on to open a PR for a branch that is not on the remote. |
| Putting the checkout inside the chain | Branch guards read stale state and fire on the wrong call. |
| Unguarded `git commit` in the chain | A clean tree exits 1 and kills the chain before the pull request. |
| Assuming the default branch is `main` | The PR targets a base that does not exist in a `master` repo. |
| Resolving a PR conflict by picking a side | Discards someone's intent without asking. |
| Retrying a failed remote-branch deletion | Noise; the remote branch is not this sequence's job. |
| Closing the window after `sincronitza` | Kills a session that was going to carry on working. |
| Closing the window before the reply is written | The session dies with what it still had to say; the user reads nothing. |
