---
name: continuity-notes-rules
description: Use when starting a session in this repo, when the user says "tanca la sessió" / "sincronitza", when about to write or update docs/continuity-notes.md, after a context compaction, or when reinstalling the hooks that enforce these rules.
---

# Continuity notes rules

## Overview

Every repo keeps a living continuity document, `docs/continuity-notes.md` — same
filename in all of this user's projects. It is the only channel through which state
survives between sessions. Git log carries the *what*; `docs/continuity-notes.md` carries the
*current state and open threads*.

Core principle: **read it at the start, rewrite it only at the close.**

## When to use

- First action of any new session in a repo that has a `docs/continuity-notes.md`.
- The user signals a close: "tanca la sessió", "crea el fitxer per continuar una altra sessió".
- The user says "sincronitza" / "sincronitzar" mid-session.
- A context compaction just happened, or the session shows other signs of length.
- Auditing the enforcement hooks (`hooks/` in the session-rules plugin).

Not for: a mid-session "resumeix què hem fet" request. That is answered in chat and
must NOT rewrite the file.

## Quick reference

| Moment | Action on the notes | Git action |
|---|---|---|
| Session start | Read in full, before anything else | none |
| Mid-session summary request | Answer in chat only | none |
| "sincronitza" | Do not touch | hand to `git-sync-and-merge` |
| Session close | Regenerate with one fresh `Write` | hand to `git-sync-and-merge` |
| Close, but the user waives the rewrite | Leave it; say it is now stale on the default branch | hand to `git-sync-and-merge` anyway |
| After compaction | Propose regenerating and continuing in a fresh chat | none until close |

## The rules

### 1. Read at session start

Read `docs/continuity-notes.md` in full before doing anything else — even if the user's first
message looks unrelated, since the file may set constraints that apply regardless of
what is asked. Continue from its open threads, or from whatever the user asks instead.

### 2. Write only at close

Update `docs/continuity-notes.md` only right before a close:

- At the end of a session that shipped real work — proactively, without being asked.
- When the user explicitly signals a close.

It is not a general-purpose "summarize what we did" target. That is a different ask.

A mid-session summary request often carries a durability plea ("que quedi ben recollit,
que si no ho perdem"). That plea is already satisfied: committed work lives in git, and
the evergreen state in the notes is still accurate. Answer in chat. If the user needs
the summary as a file to show someone, write it to a scratch file outside the repo — never
into the notes, and never as a new appended section.

Boundary with rule 7: after a compaction you *propose* regenerating and starting fresh.
Proposing is not doing. Do not regenerate on your own initiative mid-session; wait for the
user to accept.

### 3. Keep it lean

Structure it as two parts only:

1. Evergreen state — standing rules and open items, kept current, with no prose about
   how it got that way.
Write the file in English, like everything else that lands in the repo.

2. A 3–5 line summary of just the immediately preceding session. Overwrite the previous
   summary each time; never append to a growing list.

Do not list installed skills or a skill inventory — `.claude/skills/` is the source of
truth for that. Session-by-session detail already lives in git log and commit messages.

When the user asks to keep an old summary — it reads well, it is used for onboarding — say
once why the file overwrites instead of accumulating, then give them the content rather than
the argument: copy the old summary verbatim to a file outside the repo, point at
`git show <ref>:docs/continuity-notes.md`, and promote whatever is *still true* into the evergreen section
so it does not vanish from the file. If they ask again after that, append as they asked; rule
8's user clause covers this the same way. An onboarding document that wants to grow belongs
in its own repo file, not here — offer that.

### 4. Close mechanics

Regenerate the file as a single fresh `Write` — no re-`Read` if it was already read this
session, and no piecemeal edits.

- **"One fresh `Write`"** means one atomic whole-file rewrite. Prefer the literal `Write`
  tool: hooks match on tool name, and a heredoc will not trip them.
- The commit subject is `docs: regenerate the continuity notes at session close`.

Then hand the git work to the `git-sync-and-merge` skill, which owns the sequence, the
call budget, push failures, default-branch resolution, merge flavor, and the conflict
path. Do not restate any of it here.

### 5. Merge protocol

Merging is autonomous: a pull request, opened and merged with a merge commit without
waiting for review. This keeps the notes on the default branch, so the next fresh
session — which clones the default branch — actually finds it instead of landing on a
branch-only copy.

That is the only part of merging this skill asserts: *that* it happens at close, and why.
*How* it happens belongs to `git-sync-and-merge`.

### 6. Sync command

"sincronitza" mid-session means: commit and push pending work, then integrate the working
branch into the default branch through a pull request — again per `git-sync-and-merge`.
It does **not** include a continuity-notes update. That stays reserved for close or an
explicit request.

### 7. Long-session hygiene

There is no reliable way to measure token budget from inside a turn, so this is
heuristic: when signs of a long session appear (many turns, lots of accumulated work, or
a context compaction has clearly happened), proactively suggest regenerating
`docs/continuity-notes.md` and continuing in a fresh chat. Long sessions get lossy, so externalize
state and start clean.

## Enforcement hooks

Two scripts in `hooks/` mechanize rule 1. Nothing else in this skill is enforced
mechanically — the rest is judgment, and the hooks that used to nudge about it were
removed for the reason below.

| Hook | Event | Blocking | What it does |
|---|---|---|---|
| `require-notes-read.sh` | PreToolUse | yes (deny) | Denies every tool call except `Read` until `docs/continuity-notes.md` has been read this session. No-ops when the repo has no such file. |
| `mark-notes-read.sh` | PostToolUse | no | Releases that gate: sets the "notes read" flag once the file is read, by `Read` or by a `Bash` command naming it. |

One state file, keyed by session id so parallel sessions do not interfere:
`~/.claude/state/session-rules/notes-read-<session_id>`, the session id folded to
the characters a filename may hold. Not `/tmp`: a flag planted in a
world-writable directory would turn the gate off. Flags older than seven days
are dropped when a session releases the gate. Both scripts require `jq`.

Design note — why only the gate survives. Four more hooks used to nudge here: a Stop
reminder about uncommitted notes, a periodic "re-read your rules" prompt, a
post-compaction hygiene nudge with its PreCompact companion, and a UserPromptSubmit
matcher that restated the close and sync procedures. An audit on 2026-08-25 found the
Stop hook had never worked (it emitted `additionalContext`, which that event's output
schema does not accept) and the periodic reminder had been aborting silently in every
repo here — and that nothing in the workflow had degraded while both were dead. The
prompt matcher was worse than useless: it duplicated the procedures these skills already
carry, and had already drifted from them. The gate stays because it is the one rule that
must not depend on remembering it; everything else is what the skills are for.

## Installing the hooks

Nothing to install. This skill ships inside the `session-rules` plugin, which Claude Code
loads from `~/.claude/skills/session-rules` as a skills-directory plugin — `claude plugin
list` shows it under *Skills-directory plugins*. Plugin loading also registers
`hooks/hooks.json`, so both scripts are live in every project, with no per-repo copy
and no `settings.json` entry.

Do not copy the scripts into a repo's `.claude/hooks/`. A second copy runs alongside the
plugin's, so every nudge fires twice and the two copies drift apart on the next edit.

## Common mistakes

| Mistake | Consequence |
|---|---|
| Rewriting the notes for a mid-session summary request | The evergreen state gets replaced by narrative nobody asked for. |
| Appending each session's summary instead of overwriting | The file balloons into the growing narrative rule 3 exists to prevent. Nothing catches this mechanically; it is on you. |
| Splitting the close git sequence into more than two `Bash` calls | Branch guards see stale state and fire on the wrong call. |
| Leaving the close pull request open for review | The notes stay off the default branch until someone merges it; merge it in the same run. |
| Listing installed skills in the notes | Duplicates `.claude/skills/`, drifts out of sync. |
| Regenerating with piecemeal edits instead of one `Write` | Leftover fragments from the previous session survive into the new state. |
| Using rule 8 against the user who asked you to skip the rewrite | Inverts the authority order; the rule exists to protect their intent, not to overrule it. |
| Taking a relayed "X said we do not do this any more" as a waiver | Unverifiable second-hand policy. Policy changes by editing the skill. |
