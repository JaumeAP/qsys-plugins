---
name: github-rules
description: Reference context on general GitHub PR conventions for Claude Code sessions -- PR-based workflow via the GitHub MCP tools, the branch-restart-after-merge pattern, how to interpret pull_request_read results (including a repo having no CI configured), PR activity subscribe/unsubscribe habits, and merge_pull_request facts. Make sure to consult this whenever opening, updating, merging, or reasoning about a pull request in any repo, whenever deciding how/whether to push a branch, whenever a PR's CI status or check results look unexpected, and whenever GitHub conventions are relevant at all, even if the task doesn't explicitly mention "GitHub" or "PR." This is background knowledge, not a checklist to follow blindly -- it describes general conventions and how to read GitHub API results correctly, not commands to execute, and it never overrides an explicit instruction the user actually gives in the moment.
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

## Reading `pull_request_read get_status` correctly

Calling `mcp__github__pull_request_read` with `method: "get_status"` and
getting back `{"state": "pending", "total_count": 0}` simply means no commit
statuses are registered for that commit -- most commonly because the repo has
no CI configured at all. That's a normal, healthy result in a repo without
CI, not automatically a sign something is broken or misconfigured. Don't
assume a missing CI pipeline needs "fixing" just because this call came back
empty -- check whether the repo actually has (or is expected to have) CI
before treating an empty status as a problem. If Actions-based checks are
expected instead of classic commit statuses, `get_check_runs` is the more
relevant method to look at.

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

A couple of mechanical facts that come up when merging does happen:
- A draft PR needs `draft: false` (via `mcp__github__update_pull_request` or
  equivalent) before merging will succeed.
- `merge_pull_request`-style tools commonly support `merge`, `squash`, or
  `rebase` as the merge method -- which one fits depends on the repo's own
  history conventions, worth checking rather than assuming.

## Useful `pull_request_read` methods

`mcp__github__pull_request_read` (or equivalent tools) commonly take a
`method` parameter; ones that come up often:

1. `get` -- basic PR details
2. `get_diff` -- the diff
3. `get_status` -- combined commit status (see above for how to read an empty result)
4. `get_files` / `get_commits` -- what changed, and the commit list
5. `get_review_comments` / `get_reviews` / `get_comments` -- three different
   views of PR discussion; `get_review_comments` is for inline code-review
   threads specifically, `get_comments` for general PR-level comments
6. `get_check_runs` -- individual CI job results, relevant when Actions-style
   checks (rather than classic commit statuses) are in use
