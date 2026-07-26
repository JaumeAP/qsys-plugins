---
name: github-rules
description: Reference context on how this repo (qsys-plugins) actually works with GitHub -- PR-based workflow, branch-restart-after-merge convention, no CI configured here, PR activity subscribe/unsubscribe habits, and useful mcp__github__pull_request_read/merge_pull_request facts. Consult this whenever opening, updating, merging, or reasoning about a pull request in this repo, or when deciding whether/how to push a branch, so the approach matches what this repo already does instead of reinventing it each time. This is background knowledge, not a checklist to follow blindly -- it describes conventions observed in this repo, not commands to execute.
---

# GitHub conventions in this repo

This is context for working with GitHub on `qsys-plugins`, gathered from how
this repo has actually been used. It describes what's normal here, not a
procedure to execute step by step -- read it, then use judgment for the task
at hand.

## The shape of the workflow here

Work lands on a task-specific `claude/...` branch, pushed with
`git push -u origin <branch>`. From there a PR is opened through the GitHub
MCP tools (`mcp__github__create_pull_request`), not the `gh` CLI -- this repo
doesn't have `gh` available in the way some environments do, and the MCP path
is what's been reliable here. New PRs are opened as drafts; nothing in this
repo says a draft has to become non-draft or get merged automatically -- that
call is made per situation, usually because someone asked for it explicitly.

If a PR's branch already merged in an earlier session and there's follow-up
work to do, restarting the branch from the current default branch (rather
than stacking new commits on the merged history) has been the pattern:
`git fetch origin main && git checkout -B <branch> origin/main`. A merged PR
is a finished unit of work, not something to reopen or extend.

## No CI here, and that's expected

`qsys-plugins` has no CI configured. Calling
`mcp__github__pull_request_read` with `method: "get_status"` and getting back
`{"state": "pending", "total_count": 0}` is the normal, healthy result here,
not a sign something is broken or misconfigured. Don't go looking for a
missing GitHub Actions workflow to "fix" -- there isn't meant to be one
(unless someone asks to add one, which would be a different, deliberate
task).

## Watching PR activity

PRs opened here get a `subscribe_pr_activity` call right after creation, and
an `unsubscribe_pr_activity` call once they're merged or closed -- keeps the
webhook activity relevant to only what's still open. This mirrors how PR
review comments and CI failures get handled generally: investigate, then
either fix, ask, or note why no action is needed, rather than letting events
pile up unaddressed.

## Merging: no standing policy, by design

This repo does not have a fixed rule for whether PRs get merged automatically
or always wait for explicit approval. That's deliberate: an earlier imported
hook enforced "merge the branch locally, no pull request" as a blanket
policy, and it was removed because it kept nudging that behavior even after
the project decided to keep a PR-based workflow. The lesson from that: don't
let this skill (or any other file) reintroduce a standing auto-merge rule.
Whether a given PR should be merged, and how, is worth treating as an
in-the-moment decision informed by what's actually being asked, not something
to encode here as "always do X."

A couple of mechanical notes that come up when merging does happen:
- A draft PR needs `draft: false` (via `mcp__github__update_pull_request`)
  before `mcp__github__merge_pull_request` will succeed.
- `merge_pull_request` supports `merge`, `squash`, or `rebase` as the
  `merge_method` -- this repo has used plain `merge` so far, no particular
  reason to prefer one over another has come up yet.

## Useful `pull_request_read` methods

`mcp__github__pull_request_read` takes a `method` parameter; the ones that
have come up in this repo:

- `get` -- basic PR details
- `get_diff` -- the diff
- `get_status` -- combined commit status (expect `total_count: 0`, see above)
- `get_files` / `get_commits` -- what changed, and the commit list
- `get_review_comments` / `get_reviews` / `get_comments` -- three different
  views of PR discussion; `get_review_comments` is for inline code-review
  threads specifically, `get_comments` for general PR-level comments
- `get_check_runs` -- individual CI job results, relevant once/if CI exists
