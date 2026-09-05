---
name: github-rules
description: MUST consult whenever opening, updating, merging, or reasoning about PRs, or whenever GitHub conventions matter — mandatory background for all PR/GitHub work. Covers choosing between direct-to-default-branch and branch+PR workflows, reading pull_request_read results (status, mergeable_state, CI), and merge automation defaults. Explicit user instructions always override this.
---

# GitHub conventions

Portable reference for GitHub workflows across repos. General context, not a step-by-step checklist — apply judgment, and check the repo's own `CLAUDE.md` for project-specific rules.

**Precedence:** Explicit user instructions always override anything here.

**Git-absent repos:** if the working directory isn't a git work tree at all (check once, e.g. `git rev-parse --is-inside-work-tree`), none of this file applies — skip it entirely. There's no commit, branch, push, or PR to reason about; save/write files directly, plain and simple, no git or GitHub language in the response. Detect this once per session rather than assuming either way.

## Choosing a workflow

Two shapes exist. Pick based on the repo's actual risk profile, not habit — the point of a branch+PR cycle is a review gate, and it's only worth paying for when something is actually being gated.

**Default: push straight to the default branch, always (2026-08-01, explicit user request, permanent).** `git push -u origin <default>`, no task branch, no PR — including when the invoking task harness names/assigns a specific working branch for the session. A harness-assigned branch is an instruction, not a technical restriction: work on whatever local branch it hands you if that's how the session is set up, but land the result on the default branch directly (merge/rebase it there locally, then push the default branch) rather than opening a PR for it. This is the right default for solo/personal repos, low-risk config or documentation edits, and sessions doing many small iterative changes — a branch+PR cycle costs roughly 8 extra steps per change, and that overhead buys nothing when there's no second contributor and nothing to gate.

**Exception: branch + PR** (see "Branch+PR workflow" below). Reach for this only when any of the following actually apply: multiple contributors who'd otherwise collide, CI/tests that should gate a merge, production code where a review step catches real risk, or `git push` to the default branch is technically rejected (real branch protection on the remote, not merely a harness instruction naming a branch) — in that last case branch+PR is the only way the work can land at all, not a preference.

If it's genuinely unclear which shape fits, ask once at the start of the session rather than assuming — cheap up front, expensive to discover mid-session after work has already landed the wrong way.

## Push cadence (direct-to-default workflow)

**Default (2026-07-31, explicit user request): batch several commits locally before pushing, don't push after every single one.** Each logical unit of work still gets its own commit (one commit per unit, same as always — this is about push frequency, not commit granularity), but hold the push until a few related commits have accumulated, the same "batch, don't fragment" principle the branch+PR path already applies to PR cycles below.

**Exception: push right away when a single change is very large or significant** — a change substantial enough on its own that leaving it unpushed for long risks losing real work, or that other work depends on it landing first. Judgment call, not a fixed line count: a one-line typo fix waits for the next batch; a large refactor, a new module, or anything the user would be upset to lose pushes immediately on its own.

Applies to the direct-to-default path only — the branch+PR workflow already has its own batching rule ("Batch related edits into one PR cycle" below), which stays as-is.

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

**Multi-repo sessions (2026-07-31, explicit user request — minimum tokens, minimum interactions, never re-check the same thing twice):** a repo's own steps above are still per-repo, but the calls behind them aren't naturally sequential across repos, so don't run them that way.

- Per-repo GitHub API calls (`pull_request_read`, `list_pull_requests`, `merge_pull_request`) across *different* repos have no dependency on each other — issue them together in one message, not one per turn.
- Use `minimal_output: true` on `list_*`/`search_*` calls when only existence/state is needed, not the full payload (per that server's own tool instructions).
- If a PR's `mergeable_state` (or any other fact this session already pulled) was established earlier in the same turn and nothing has changed since, reuse it — don't query it again just because a later step also happens to need it.

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
