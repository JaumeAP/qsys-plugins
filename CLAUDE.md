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
numbered-lists-only rule, no bold/em-dash/ellipsis/header/table ban, and no
mandatory leading "Rebut:" line — all removed from this section for that
reason. The hooks that used to enforce them (`check-reply-format.sh`,
`reply-format-preflight.sh`) were unregistered from `settings.json` the
same day; the scripts stay on disk, dead, with their own retirement notes.

## Portable skills (installed with the config)

These travel with this file and the rest of `.claude/`. `file-operations` and
`github-rules` are the only two still bundled as files — import mechanics
(blind-copy, merge rules, everything else in that process) live solely in
`.claude/config-export-import.md`, not restated here. Pointers only here,
never summaries — each skill is the authority on its own topic, and a
summary in this file just drifts out of sync with it:

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

## Project-specific rules

### What this repo is

A collection of **QSC Q-SYS plugins** written in **Lua**, targeting Dolby
cinema audio processors (CP650 → CP950 series) and general utility
components. Plugins run inside **Q-SYS Designer** on QSC audio DSP cores.
Authored in Lua, tested in Designer's emulator, distributed as `.qplug` /
`.qplugx`. `Developer/` holds the source of truth; the root `.qplug` files
are built artifacts and must never be hand-edited.

Test suite: `Developer/tests/run.sh`, plain Lua 5.3 (matching Designer's own
embedded version, not 5.4), no framework. `.claude/hooks/ensure-lua53.sh`
(SessionStart) installs `lua5.3` if missing so a fresh container can run it.
It stubs the Q-SYS host globals so plugin logic can be driven from a
terminal. It does NOT replace testing in Designer — it covers plugin logic
only, not real DSP behaviour, timing, or the Designer UI — but it catches
regressions before the bench, and `wire_trace.lua` diffs two builds by the
bytes they put on the wire, which is the tool to reach for after any
refactor.

Author/contact history in the sources: `james.puig@elcine.com` / Jaume Puig
(Barcelona) -- changed from `@dolby.com` 2026-07-30, all root `.qplug`/
`.qplugx` rebuilt the same day, nothing left pending on this.

### Where the detail lives

Split out 2026-07-30 (explicit user request) per the official guidance at
code.claude.com/docs/en/memory: path-scoped `.claude/rules/*.md` files load
only when Claude touches a matching file, instead of unconditionally every
session. Content is unchanged, only relocated.

1. `.claude/rules/qsys-plugin-development.md` — PLUGCC `#include` resolution
   rules, the plugin definition/runtime API, the full Q-SYS Lua extension API
   table, module patterns, the mandatory structure/naming convention,
   `.qplug` vs `.qplugx`, the build workflow, and edit-time conventions.
   Scoped to `Developer/plugins/**`, `Developer/shared/**`, root
   `*.qplug`/`*.qplugx`, `build-qplug*.yml`. Read it before editing plugin
   source.
2. `.claude/rules/repo-layout.md` — the annotated directory tree. Scoped to
   `Developer/**`, `vendor/**`, `Dolby CP Emulator/**`, `*.qplug`/`*.qplugx`,
   `.github/workflows/**`.
3. `docs/continuity-notes.md` — dated institutional memory: why past
   decisions were made, what was tried and reverted, the full reasoning
   behind anything summarized here. NOT auto-loaded. Read it before
   re-deriving something that looks settled, and append new dated entries
   there rather than here.

Native auto memory (`MEMORY.md`) does not substitute for any of this in this
repo: it is machine-local under `~/.claude/projects/<project>/memory/`, and
sessions here run in ephemeral containers that get reclaimed. Anything that
must survive has to be committed. Verify before trusting it:
`ls ~/.claude/projects/*/memory/` (empty/absent = still unused) or `/context`
in-session. Content there never survived from a prior session here — it's
this session's own scratch state, not persistence.

### Open threads

The one part of the continuity record that has to stay in context every
session — knowing what is unfinished is what keeps a session from
re-deriving or silently skipping it. Keep this list short and current:
close an item by deleting its line here, and put the full story in
`docs/continuity-notes.md`.

1. 20 stale, merged `origin/claude/*` branches (17 audited + 3 found
   2026-07-30) can't be deleted from any session: git proxy 403s ref
   deletion, no delete-branch MCP tool, retried again 2026-07-30, still
   blocked. Names in continuity notes. Needs the user, from the GitHub UI.
2. `Developer/host-emulator/components/` pin lists for `gain`,
   `filter_lowpass`, and `equalizer_parametric` are NOT independently
   confirmed against an official source — they mirror the numbered-pin
   convention and match what SubharmonicSynth ships. Re-verify these first
   if a real host ever disagrees about wiring.
3. Root cause of item 1 (2026-07-30 investigation, see continuity notes),
   needs the user via GitHub web UI, no session can do it: enable
   "Automatically delete head branches" in Settings > General > Pull
   Requests. Server-side, applies on every merge regardless of proxy
   restrictions -- without it, item 1 keeps growing by ~1 branch/session.

### Git

- Commit submodule pointer changes deliberately; never bump one incidentally.
  `vendor/` holds four top-level read-only reference submodules per
  `.gitmodules` (`BasePlugin`, `ExamplePlugin`, `PluginEncryptionTool`,
  and third-party `q-sys-community/q-sys-plugin-guide`) -- corrected
  2026-07-30, was miscounted as five/four before the top-level
  `PluginCompile` duplicate below was removed. `BasePlugin` and
  `ExamplePlugin` each also carry their own nested `PluginCompile`
  submodule, six total counting those.
- **No duplicate submodule vendoring.** `BasePlugin` and `ExamplePlugin` each
  declare their own nested `PluginCompile` submodule at the same commit, so
  there is no top-level copy; `.claude/hooks/init-submodules.sh` runs
  `git submodule update --init --recursive` and both nested paths get the
  content. Don't re-add a third top-level copy.
- **`qsc-q-sys` is off-limits.** Do not call `add_repo` for it and do not ask
  about it, in this or any future session, unless the user brings it up first
  (2026-07-29 standing instruction; the submodule was deliberately removed).
- The full commit/push/PR/merge automation default lives in the portable
  `github-rules` skill, not here. Note the calling environment can layer its
  own "do not create a PR unless asked" gate on top of it, independent of
  anything this repo states — when that gate is live, ask for authorization
  once, early, and treat it as standing for the session.
