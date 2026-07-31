---
name: github-rules
description: MUST consult whenever opening, updating, merging, or reasoning about PRs, or whenever GitHub conventions matter — mandatory background for all PR/GitHub work. Covers choosing between direct-to-default-branch and branch+PR workflows, reading pull_request_read results (status, mergeable_state, CI), and merge automation defaults. Explicit user instructions always override this.
---

# GitHub conventions

Portable reference for GitHub workflows across repos. General context, not a step-by-step checklist — apply judgment, and check the repo's own `CLAUDE.md` for project-specific rules.

**Precedence:** Explicit user instructions always override anything here.

## Choosing a workflow

Two shapes exist. Pick based on the repo's actual risk profile, not habit — the point of a branch+PR cycle is a review gate, and it's only worth paying for when something is actually being gated.

**Default: push straight to the default branch.** `git push -u origin <default>`, no task branch, no PR. This is the right default for solo/personal repos, low-risk config or documentation edits, and sessions doing many small iterative changes — a branch+PR cycle costs roughly 8 extra steps per change, and that overhead buys nothing when there's no second contributor and nothing to gate.

**Exception: branch + PR** (see "Branch+PR workflow" below). Reach for this when any of the following actually apply: multiple contributors who'd otherwise collide, CI/tests that should gate a merge, production code where a review step catches real risk, or the calling environment restricts direct pushes to the default branch.

If it's genuinely unclear which shape fits, ask once at the start of the session rather than assuming — cheap up front, expensive to discover mid-session after work has already landed the wrong way.

## Branch+PR workflow (when the exception applies)

1. Work lands on task-specific branch: `git push -u origin <branch>`
2. Open PR via GitHub MCP tools when available (prefer over `gh` CLI)
3. Open as non-draft if it's production-ready, else as draft
4. When `mergeable_state: clean` and not draft, merge it (see "Merging" below)
5. After merge, restart branch from current default before new work: `git fetch origin <default> && git checkout -B <branch> origin/<default>` then `git push origin <branch> --force-with-lease`

**Batch related edits into one PR cycle** — single cycle costs ~8 steps; separate PRs for related changes waste overhead.

**Check branch staleness first on new task** (before first Edit/Write call), not mid-edit. On a clean tree, it's two commands; mid-edit requires five-step scramble.

## Reading pull_request_read status

`get_status` returning `{"state": "pending", "total_count": 0}` means no commit statuses registered — usually because repo has no CI configured (normal). Check whether CI is expected. For Actions-style checks, use `get_check_runs` instead.

## PR activity subscriptions

Only subscribe when PR will stay open after this turn (still draft, checks pending, review waited on). For routine fast-merge cycles (see below), skip subscription — PR merges before webhook events arrive.

## Merging: the default is full automation

**Core rule (2026-07-29, explicit user authorization):**
- When PR's `mergeable_state: clean` AND not draft → merge it immediately
- Don't ask first; same as pushing or opening the PR itself
- Applies at end-of-session close: check if branch has unmerged commits or clean open PR, merge both

**Exceptions (stay untouched):**
- Draft PRs (need `draft: false` before merging)
- PRs that aren't clean (`dirty`, `unstable`, `unknown`)
- Destructive git ops (force-push, reset --hard, branch -D) — always confirm first
- Calling environment's "ask before PR" gate (if present) — request authorization once, treat as standing

**Precedence (2026-07-30):** `finishing-a-development-branch` skill's "present options" step loses to this automatic merge on clean PRs. Rest of that skill's steps (test suite, worktree detection, cleanup) still apply.

**Performance tip:** On routine PRs opened seconds ago with nothing uncertain, skip `pull_request_read` status check before merging. Merge directly; only read status if merge fails.

## Reading mergeable_state

| Value | Meaning |
|-------|---------|
| `clean` | Merges without conflict |
| `dirty` | Real conflict vs. base branch |
| `unstable` | Required checks haven't passed (CI issue) |
| `unknown` | Still computing (new PR); re-fetch |

**On `dirty`:** Check if PR is still semantically relevant (architecture changed, file layout changed?). Closing stale PRs as superseded often better than forcing old changes through.

## Useful pull_request_read methods

1. `get` — PR details + `mergeable_state`
2. `get_diff` — diff content
3. `get_status` — combined commit status (see above for empty result)
4. `get_files` / `get_commits` — what changed + commit list
5. `get_review_comments` / `get_reviews` / `get_comments` — PR discussion (inline vs. general)
6. `get_check_runs` — individual CI job results (Actions-style)
