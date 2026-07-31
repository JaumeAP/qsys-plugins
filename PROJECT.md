# This repo — qsys-plugins

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

## Where the detail lives

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

## Open threads

The one part of the continuity record that has to stay in context every
session — knowing what is unfinished is what keeps a session from
re-deriving or silently skipping it. Keep this list short and current:
close an item by deleting its line here, and put the full story in
`docs/continuity-notes.md`.

1. 20 stale, merged `origin/claude/*` branches (17 audited + 3 found
   2026-07-30) can't be deleted from any session: git proxy 403s ref
   deletion, no delete-branch MCP tool, retried again 2026-07-30, still
   blocked. Names in continuity notes. Needs the user, from the GitHub UI.
2. Root cause of item 1 (2026-07-30 investigation, see continuity notes),
   needs the user via GitHub web UI, no session can do it: enable
   "Automatically delete head branches" in Settings > General > Pull
   Requests. Server-side, applies on every merge regardless of proxy
   restrictions -- without it, item 1 keeps growing by ~1 branch/session.

## Git

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
