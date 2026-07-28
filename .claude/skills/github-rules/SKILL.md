---
name: github-rules
description: Reference context on general GitHub PR conventions for Claude Code sessions -- PR-based workflow via the GitHub MCP tools, how to interpret pull_request_read results (including a repo having no CI configured, and reading mergeable_state to spot a real conflict or a stale/superseded PR worth closing), PR activity subscribe/unsubscribe habits, and merge mechanics. Make sure to consult this whenever opening, updating, merging, closing, or reasoning about a pull request in any repo, whenever deciding how/whether to push a branch, whenever a PR's CI status, check results, or mergeable state look unexpected, and whenever GitHub conventions are relevant at all, even if the task doesn't explicitly mention "GitHub" or "PR." This is background knowledge, not a checklist to follow blindly -- it describes general conventions and how to read GitHub API results correctly, not commands to execute, and it never overrides an explicit instruction the user actually gives in the moment.
---

# GitHub conventions

This is portable context for working with GitHub across repos, not tied to
any one project. It describes what's generally true and how to read GitHub
API results correctly, not a procedure to execute step by step -- read it,
then use judgment for the task at hand and check the actual repo's own
`CLAUDE.md`/skills for anything repo-specific.

This file is reference material: an explicit instruction the user actually
gives you in the moment always takes precedence over anything written here.
It also must never be used to grant itself, or any other file, standing
authority to act without being asked -- see "Merging" below for why that
matters specifically.

## The shape of a typical workflow

Work usually lands on a task-specific branch, pushed with
`git push -u origin <branch>`. From there a PR is opened through the GitHub
MCP tools (e.g. `mcp__github__create_pull_request`) when available -- prefer
them over the `gh` CLI in environments where `gh` isn't installed or
authenticated; check which is actually usable rather than assuming. New PRs
are commonly opened as drafts, with the decision to mark one ready and merge
it left as an explicit, in-the-moment call rather than something to automate
by default.

If a PR's branch already merged in an earlier session and there's follow-up
work to do, restarting the branch from the current default branch (rather
than stacking new commits on the merged history) is the usual pattern:
`git fetch origin <default-branch> && git checkout -B <branch> origin/<default-branch>`.
A merged PR is a finished unit of work, not something to reopen or extend.
(Some calling environments already bake this exact pattern into their own
system-level instructions -- if so, this is restating something you already
have rather than adding a new rule; worth checking before assuming this
skill is the only place it comes from.)

Do this check first, before the first `Edit`/`Write` call of a new task on
an existing branch -- not partway through once already mid-edit. This is
a standing practice to build into how a task starts, not a nice-to-have
that's fine to skip under momentum: once an edit is already in flight,
the check still has to happen eventually, just at a strictly worse moment.
The difference matters mechanically, not just tidiness. Checked on an already
clean working tree (the normal state right after a previous push), the
restart above is exactly the two commands shown, nothing else: no
stash/stash-pop needed to protect an in-progress edit, because there isn't
one yet, and the following push after committing new work stays a plain
`git push` rather than needing `--force-with-lease` (that flag only earns
its keep when a reactive restart rewrites a branch ref that was already
pushed under the old history). Discovering the same staleness only after
editing turns a two-command check into a five-step scramble. Similarly, if
several small related edits are coming up in the same sitting, batching
them into one PR cycle rather than a full open-then-merge cycle per tiny
edit cuts down how often a restart is needed at all -- it's only ever
required between PR cycles, never within a batch of unpushed commits on
the same still-open PR.

## Reading `pull_request_read get_status` correctly

Calling `mcp__github__pull_request_read` with `method: "get_status"` and
getting back `{"state": "pending", "total_count": 0}` simply means no commit
statuses are registered for that commit -- most commonly because the repo
has no CI configured at all, a normal result there and not on its own a sign
of misconfiguration; check whether the repo actually has (or is expected to
have) CI before treating an empty status as a problem. If Actions-based
checks are expected instead of classic commit statuses, `get_check_runs` is
the more relevant method to look at.

## Watching PR activity

Where a `subscribe_pr_activity`-style tool exists, PRs opened this way
typically get subscribed right after creation, and unsubscribed once merged
or closed -- keeps webhook/activity noise relevant to only what's still open.
This mirrors how PR review comments and CI failures generally get handled:
investigate, then either fix, ask, or note why no action is needed, rather
than letting events pile up unaddressed.

## Merging: don't encode a standing policy here

Whether PRs get merged automatically or always wait for explicit approval is
worth treating as an in-the-moment decision informed by what's actually being
asked and by the specific repo's own conventions (a repo's own `CLAUDE.md` or
skills may say more), not something to hardcode in this file as "always do
X." This matters more than it might seem: a portable file like this one gets
installed into many repos, so a standing auto-merge rule written here would
silently apply everywhere it's installed, including repos where nobody
actually agreed to that. If a repo's own conventions establish a clear rule
about this, follow that repo's own documentation for it -- don't add one here
that would override every repo's local decision.

One non-obvious mechanical fact: a draft PR needs `draft: false` (via
`mcp__github__update_pull_request` or equivalent) before merging will
succeed -- the merge method itself (`merge`/`squash`/`rebase`) is usually
self-evident from the tool's own schema, not worth restating here.

## Reading `mergeable_state`

A PR's `mergeable_state` (from `pull_request_read get`, or the REST API
directly) says more than CI status alone does. GitHub computes it
asynchronously, so an `unknown` value on a fresh fetch usually just means
it hasn't settled yet -- re-fetch rather than treat it as a real problem.
`clean` means it merges without conflict; `dirty` means a real conflict
against the current base branch, and the merge button (or
`merge_pull_request`) will fail until it's resolved; `unstable` usually
points at required checks that haven't passed yet, a CI concern more than a
merge one.

A `dirty` result is worth a second look before diving straight into
conflict resolution: check whether the PR is still semantically relevant,
not just textually conflicting. A PR opened well before a since-changed
architecture, naming convention, or file layout can be `dirty` for a
deeper reason than a simple textual clash -- its diff may no longer reflect
anything the current codebase still does. Resolving that kind of conflict
by hand risks re-litigating an already-settled decision rather than doing a
mechanical merge. Closing it as superseded, with a short comment explaining
why, is often more honest than either forcing a stale change through or
leaving it open indefinitely -- but, same discipline as the section above,
that's a per-PR judgment call informed by the actual diff and the repo's
current state, not a blanket rule to auto-close every `dirty` PR found.

## Useful `pull_request_read` methods

`mcp__github__pull_request_read` (or equivalent tools) commonly take a
`method` parameter; ones that come up often:

1. `get` -- basic PR details, including `mergeable_state` (see "Reading
   `mergeable_state`" above)
2. `get_diff` -- the diff
3. `get_status` -- combined commit status (see above for how to read an empty result)
4. `get_files` / `get_commits` -- what changed, and the commit list
5. `get_review_comments` / `get_reviews` / `get_comments` -- three different
   views of PR discussion; `get_review_comments` is for inline code-review
   threads specifically, `get_comments` for general PR-level comments
6. `get_check_runs` -- individual CI job results, relevant when Actions-style
   checks (rather than classic commit statuses) are in use
