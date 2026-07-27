# CLAUDE.md — common rules (identical across all my projects)

Every section of this file is IDENTICAL in every one of my repos — copy it
verbatim into a new project, unchanged — EXCEPT the final "Project-specific
rules" section: that one holds this repo's own docs-to-read/coding
conventions and gets replaced with the new repo's own content, everything
above it stays untouched.

## Response style (always, every session)

**Always answer the user entirely in Catalan** — all chat replies, in full,
no exceptions, regardless of the language the request is written in. Chat
replies to the user are the ONLY Catalan output: everything written into the
repo is in English — source code, code comments, commit messages, changelog,
and docs (comments always English, even when editing files whose existing
comments are in another language). This translation duty covers anything
relayed into the chat reply regardless of where it originated — a subagent's
report, a hook message, a webhook/PR activity event, a search result, quoted
external text — translate it into Catalan before presenting it, not just
Claude's own generated sentences. Code, variable names, commands, paths, and
literal tool output are never translated, even inside an otherwise translated
reply.

Token economy top priority. Answer first, no preamble. Telegraphic, drop
articles/filler/nuance, fragments over sentences, minimum tokens preserving
info, compress aggressively, grammar may break if meaning holds. This compact
mode applies equally to Catalan replies — same terseness as English, no
looser. Code,
commands, paths, params stay literal. No bold, headers, tables, ellipses, em
dashes, decorative symbols; output may be read by TTS. Proper nouns/technical
terms: original language unless misleading, clarity over purism. No
servility, contradict directly when wrong, never agree to appease, challenge
politely if disagree, never invent, say if unsure. Assume technical
competence, no basic intros, preserve files/configs/decisions/params
literally, apply corrections immediately within session. Never claim
saved/done/completed without calling a tool first, show the tool result as
proof before confirming. Never rename an output file without explicit
request. One question per reply except technical tasks needing several. No
postamble, no unsolicited closing offers/summaries/tangents.

Conditional: length under fifty words unless code snippets, multi-step
technical tasks, or teaching requested, then expand as needed but stay
focused. Verify with search first for changing facts (prices, versions,
charges, events); verify before critical or irreversible actions.

Multi-step tool sequences (git commit/push, multi-file edits, test runs):
announce each step as a bare 1-3 word action, e.g. "Commit.", "Push.",
"Tests." No sentences, no explaining what the command does, why, or its
mechanism/internals — bare label only, before or after, not both.

First line of every reply to an order/instruction: confirm receipt with the
order summary itself in English, e.g. "Rebut: <order in English, a few
words>" — the "Rebut:" label stays Catalan, only the summarized order inside
it switches to English, and the rest of the reply stays Catalan — before
acting on it. Applies the same way when the order arrives through an
automated channel, not typed live by the user (a scheduled Routine firing,
a PR webhook event, a send_later message) — it's still an order to react
to, so it still gets its own "Rebut:" line.

Lists: always numbered — never unnumbered/bulleted, at every level. Nested
sub-items are numbered too (e.g. `3.1`, `3.2`), never dashes/bullets.

## Portable skills (installed with the config)

These generic skills travel with this file and the rest of the `.claude/`
config (see `.claude/config-export-import.md`). Pointers only, not summaries — same
drift-safety reason as above; each skill is the authority on its own topic,
invoke it when the task calls for it:

1. `changelog-rules` (`.claude/skills/changelog-rules/SKILL.md`) — how to
   write and maintain changelog entries (versioning, format, flush-on-push).
2. `github-rules` (`.claude/skills/github-rules/SKILL.md`) — portable GitHub
   PR conventions (workflow shape, reading `pull_request_read` results,
   merge mechanics); generalized 2026-07-27 from a qsys-plugins-specific
   skill of the same name. Must never encode a standing auto-merge policy —
   a portable file installs into every repo it's imported into, so a rule
   like that written here would silently apply everywhere, not just where
   someone actually agreed to it.

(`git-rules` removed from the portable bundle 2026-07-25, explicit user
request — deleted from `.claude/skills/`, its `skillOverrides` entry
dropped from `settings.json`, and its path added to
`.claude/removed-files.txt` so future imports of an older bundle prune it
from target repos too. Git workflow now follows plain judgement +
the rest of this file's rules, not a dedicated skill.)

(`file-operations` is also bundled but needs no pointer here — its own
description triggers it by context when there's file I/O to do.)

**Which additional skills travel on export is defined in
`.claude/scripts/export-config-skill.sh`** — not repeated here, to avoid
two places that can drift out of sync. Anything installed here but not in
that script's copy list stays local; its name/source is kept in
`.claude/recommended-skills.txt` (plain list, one name per line,
updated by hand) for a target repo to fetch itself if wanted — that
file itself always travels on export.

**Find Skills**: `find-skills`, imported from `vercel-labs/skills`
(`skills/find-skills/SKILL.md`) — discovers and installs third-party
skills via the `npx skills` CLI, #1 by install count on skills.sh at
import time. Tracked in `skills-lock.json`. Note its own workflow can
install other skills straight from that ecosystem, bypassing this
repo's own skill-creator/config-ingest governance — worth keeping in
mind wherever it ends up.

**Skill creation/extension.** Any skill creation or extension (a new
`SKILL.md`, or a content/frontmatter change to an existing one — this
applies regardless of whether the skill itself is repo-specific or
portable) goes through the `skill-creator` skill's process, not a plain
manual edit (2026-07-20 standing rule). Mechanized best-effort by
`.claude/hooks/skill-creation-reminder.sh` — a non-blocking reminder on
every `Write`/`Edit` to a `SKILL.md`; it can't verify skill-creator was
actually invoked, so it can't hard-block, same honest limitation as
`config-ingest-reminder.sh`.

## Session continuity

**Long-session hygiene.** There's no reliable way to measure exact chat
length / token budget from inside a turn, so this is heuristic: when signs of
a long session appear (many turns, lots of accumulated work, or a
context summarization/compaction has clearly happened), proactively suggest
continuing in a fresh chat — don't wait to be asked. Rationale: long
sessions get lossy (early detail blurs on compaction).

## Project-specific rules

### What this repo is

A collection of **QSC Q-SYS plugins** written in **Lua**, targeting Dolby
cinema audio processors (CP650 → CP950 series) and general utility components.
Plugins run inside **Q-SYS Designer** on QSC audio DSP cores. There is no build
system, package manager, or CI here — plugins are authored in Lua, tested in
Q-SYS Designer's emulator, and distributed as `.qplug` / `.qplugx` files.

There *is* a small test suite under `Developer/tests/` (added 2026-07-27):
plain Lua 5.4, no framework, run with `Developer/tests/run.sh`. It stubs the
Q-SYS host globals so plugin logic can be driven from a terminal. It does not
replace testing in Designer — it only covers the plugins' own logic, not real
DSP behaviour, timing, or the Designer UI — but it catches regressions before
they reach the bench, and `wire_trace.lua` in there diffs two builds by the
bytes they put on the wire, which is the tool to use after any refactor.

Author/contact history in the sources: `james.puig@dolby.com` / Jaume Puig
(Barcelona).

### Repository layout

```
.
├── README.md                         Short plugin catalog
├── .vscode/settings.json             Associates *.qplug with the Lua language
│
├── *.qplug / *.qplugx                Distributable plugins (repo root), built by
│   │                                 Developer/tools/build_distributable.sh
│   ├── DolbyFader.qplug              (v2.0)
│   ├── Dolby Sweep V2.0.qplug
│   ├── MultiFlip-Flop.qplug          (v2.0)
│   ├── Dolby CPSeries Control V4.0.qplug
│   └── Dolby CPSeries Control V2.2.qplugx   Packaged/encrypted (JSON envelope) —
│                                     stale (last hand-compiled at v2.2); a
│                                     .qplugx can only be regenerated inside
│                                     Designer, never hand-edited
│
├── Dolby CP Emulator/                Q-SYS User Components (.quc) that emulate
│   ├── CP650 Emulator.quc            real Dolby processors for bench testing
│   ├── CP750 Emulator.quc
│   └── CP850 Emulator.quc
│
├── vendor/                            Read-only reference material (git submodules) —
│   │                                 `git submodule update --init` after cloning if
│   │                                 empty; never edit contents, it's all upstream's
│   ├── qsys-plugins/
│   │   └── BasePlugin/               github.com/qsys-plugins/BasePlugin — QSC's own
│   │                                 plugin template (added 2026-07-27)
│   └── q-sys-community/
│       └── q-sys-plugin-guide/       github.com/q-sys-community/q-sys-plugin-guide —
│                                     a third-party (Solo Works London / Carrier Labs)
│                                     template + guide, not QSC's own (added
│                                     2026-07-27). See "Plugin structure/naming
│                                     convention" below for what these two confirm
│                                     vs. what qsc-q-sys added on top.
│
└── Developer/                        Working sources (edit here)
    ├── plugins/                      Plugin definition files (layout + skeleton)
    │   ├── DolbyFader V2.0.qplug
    │   ├── Dolby CPSeries Control V4.0.qplug
    │   ├── Dolby Sweep V2.0.qplug
    │   ├── MultiFlip-Flop V2.0.qplug
    │   └── reference.lua             Template/cheat-sheet of every component & control type
    ├── Modules/                      Runtime logic pulled in by plugins via require()
    │   ├── qsys_enums.lua            Centralized ControlType/ButtonType/ControlUnit/etc.
    │   │                             enums; required BEFORE the runtime guard (needed at
    │   │                             design time by GetControls/GetControlLayout), unlike
    │   │                             every other module here
    │   ├── qknob.lua                 QKnob class: text control ⇄ value/position/string sync (self-contained, plain metatables, no external OOP base)
    │   ├── strict.lua                Global-variable guard (errors on undeclared globals)
    │   ├── dolbyfader.lua            Dolby fader runtime (dB ⇄ 0.0-10.0 Dolby scale)
    │   ├── dolbysweep.lua            Sweep tone generator runtime
    │   ├── cpseries.lua              CPSeries application layer (TCP connection lifecycle, Controls wiring)
    │   ├── cpseries_class.lua        CPSeries class (per-model protocol state machine)
    │   ├── cpseries_models.lua       Per-model wire config (TCP port, KEY=VALUE vs "param value")
    │   └── cpseries_protocol.lua     Per-model message formatting and GET framing
    ├── tools/
    │   └── build_distributable.sh    Builds a root distributable from a Developer/ head +
    │                                 named modules, pre-guard and post-guard (see below)
    └── tests/                        Lua 5.4 test suite, no framework (see its README)
        ├── run.sh                    Syntax pass over every source, then every test
        ├── qsys_stub.lua             Stand-in for the Q-SYS host globals
        ├── harness.lua               Path resolution + check counter
        ├── test_modules.lua          CPSeries class, straight from Modules/
        ├── test_plugin_defs.lua      Get* callbacks of the plugins/ definition files
        ├── test_dist_cpseries.lua    Root CP Series distributable, both host passes
        ├── test_dist_fader.lua       Root Dolby Fader distributable, both host passes
        ├── test_dist_sweep.lua       Root Dolby Sweep distributable, both host passes
        ├── test_dist_flipflop.lua    Root MultiFlip-Flop distributable, both host passes
        └── wire_trace.lua            Diffs two builds by the bytes they put on the wire
```

**`Developer/` holds the source of truth.** The root-level `.qplug` files are
single-file distributable builds with their `Developer/Modules/*.lua`
dependencies inlined and `require` stripped (built by
`Developer/tools/build_distributable.sh`, see "Developer workflow" below) —
never hand-edit them, or they drift from `Developer/` and the next rebuild
silently discards the hand edit. `Dolby CPSeries Control V2.2.qplugx` is the
one exception: it is a *packaged* (`.qplugx`) build that predates this
convention and can only be regenerated inside Designer.

### How a Q-SYS plugin is structured

A `.qplug` file is a Lua script the Q-SYS Designer host runs in two roles. It
declares a global `PluginInfo` table and a set of well-known callback functions
that the host calls to build the component, then `require`s a runtime module for
event logic.

Definition-side callbacks (all take/return the `props` table):

| Function | Purpose |
|---|---|
| `PluginInfo` (global table) | `Name` (`Manufacturer~Model`), `Version`, `BuildVersion`, `Id` (UUID), `Author`, `Description`, optional `Manufacturer`, `Type` |
| `GetColor(props)` | Component tint, `{r,g,b}` |
| `GetPrettyName(props)` | Display name (may interpolate props) |
| `GetProperties()` | User-configurable properties (integer/enum/…); drive channel counts, model selection |
| `RectifyProperties(props)` | Adjust/hide properties after a change (e.g. `props.plugin_show_debug.IsHidden = true`) |
| `GetControls(props)` | Pins/controls: `Button`/`Knob`/`Text`, `PinStyle`, `UserPin`, min/max… |
| `GetComponents(props)` | Embedded DSP blocks the plugin instantiates (`gain`, `sine`, `stepper`, `mixer`, `meter2`, `flip_flop`, `router`, `custom_controls`…) |
| `GetControlLayout(props)` | Returns `layout, graphics` — positions/sizes/styles for the schematic & UCI |
| `GetPins(props)` | (when present) external component pins, e.g. `{ Name, Direction }` |
| `GetWiring(props)` | (when present) internal wiring from an embedded component's pin to a plugin pin |

Runtime side: at the bottom of the file a guard then a `require`:

```lua
if not Controls and Reflect then return end   -- definition pass: stop here
require "dolbyfader"                            -- runtime pass: load event logic
```

When Q-SYS runs the component, the global `Controls` table (and `Properties`)
exist, so execution falls through to `require`, loading the matching module from
`Developer/Modules/`. `MultiFlip-Flop` is the exception — its runtime logic is
inline in the `.qplug`, guarded by `if Controls then ... end` instead (both
guard styles are valid; `MultiFlip-Flop` predates the other three plugins'
guard-then-`require` split and there was no reason to change a working,
self-contained file's shape just to match them).

One wrinkle since `qsys_enums.lua` (below): a design-time function
(`GetControls`/`GetControlLayout`) that reads an enum from it needs that
module loaded *before* the guard, not after — the guard returns early on the
definition pass, so anything `require`d only after it never runs then. Every
plugin now has `require "qsys_enums"` right after `PluginInfo`, unconditional,
ahead of the guard.

`reference.lua` is the canonical example: it enumerates every property type,
component type, control type and layout key, and shows the `package.path`
prelude used to locate modules during local development.

### Q-SYS runtime globals (available to plugin/module code)

These are provided by the Q-SYS host, not defined in this repo:

- `Controls` — table of the controls declared in `GetControls`. Each has
  `.Value`, `.String`, `.Position`, `.Color`, and an `EventHandler` you assign.
- `Properties` — resolved user properties.
- Embedded component handles by name (e.g. `Sine`, `Step`, `Gain`) with their
  own sub-controls (`Sine.frequency.Value`, `Step.value.Value`).
- `Timer` — `Timer.New()`, `:Start(interval)`, `:Stop()`, `Timer.CallAfter(fn,s)`.
- `TcpSocket` — `TcpSocket.New()` (dot notation — confirmed 2026-07-27 against
  three independent sources after the code and a reverse-engineered spec
  disagreed; `TcpSocket:New()` with a colon happened to still work in
  practice, since `New` doesn't dispatch on `self`, but it is not the
  documented construction syntax), `.WriteTimeout`, connect/read/write events;
  instance methods use colon (`sock:Connect(...)`, `sock:Write(...)`).
- `System.IsEmulating` — true in the Designer emulator; used to shorten loops.
- `Print(...)`, `Reflect` (definition-time reflection, `Reflect.Types.*`).

Both `Timer` and `TcpSocket` objects are documented as needing to stay
**global, never `local`** — a `local` one can be garbage-collected once
nothing else references it, silently killing a poll loop or a socket after
roughly 22 iterations. In practice every long-lived one in this repo (`sock`/
`DolbyCP` in `cpseries.lua`, `timer`/`period` in `dolbysweep.lua`, the private
`Timer.New()` inside `qknob.lua`) is also reachable through a closure chain
already rooted in a global `Controls.*.EventHandler` field, so none of them
were actually at risk of collection — but they're all global anyway now, per
the convention below, since it costs nothing and removes the doubt.

### Key module patterns

- **No external OOP base.** `qknob.lua` no longer depends on any `class()`
  library or submodule (the vendored `jonstoler/class.lua` used briefly on
  2026-07-27 was removed the same day). `QKnob` is defined directly in
  `qknob.lua` as a plain table with its own `__index`/`__newindex` metamethods:
  `QKnob:set(name, {value=, get=, set=})` declares a computed property backed
  by a private per-instance table, and `QKnob:new(...)` creates an instance and
  calls `obj:init(...)`. Same external API as before (`QKnob:new(...)`,
  `QKnob:set(...)`, `QKnob:SetString` override), just self-contained. These
  method names (`:new`, `:init`, `:set`) were deliberately left lowercase in
  the 2026-07-27 plugin-convention rewrite — they're this repo's own internal
  class API, not something the QSC-derived convention (below) governs, and
  renaming them would touch every plugin that uses `QKnob` for zero
  convention-compliance gain.
- **`qknob.lua`**: wraps a `Text` control as a first-class numeric knob. Keeps
  `Value`/`String`/`Position` in sync via `__index`/`__newindex` metatables and
  a 1 ms polling `Timer` that mirrors external position changes. Subclasses
  override `QKnob:SetString` for unit suffixes (e.g. dolbysweep appends `'s'`).
- **`strict.lua`**: installs a metatable on `_G` that raises on read/write of
  undeclared globals; declare intentional globals with `Global("name", ...)`.
  Not currently `require`d by any plugin — opt in if you need it while debugging.
- **`cpseries_models.lua` / `cpseries_protocol.lua`**: per-model wire config
  (TCP port, `KEY=VALUE` vs `"param value"` dialect) and message formatting/
  GET framing. Neither touches `Controls` — they're pure protocol logic,
  shared between `cpseries.lua` and `cpseries_class.lua`.
- **`cpseries_class.lua`**: the per-model (`CP650`/`CP750`/`CP850`/`CP950`/
  `CP950A`) protocol state machine. `Model` is a plain array with real
  `index`/`key`/`value` fields (the old `setmeta`/`searchelem` reflection hack
  was removed 2026-07-27 along with the CP950/CP950A bump); doesn't reference
  `Controls` at all.
- **`cpseries.lua`**: the application layer — owns the `TcpSocket`, the
  `CPSeries` instance, and all the `Controls.*` wiring; reuses `dolbyfader`'s
  `DKNob` and `DolbyFaderEventHandler` hook to push fader changes over the
  socket. Note: the plugin does `require "CPSeries"` (capitalized) against the
  file `cpseries.lua` — this only resolves on case-insensitive filesystems
  (Windows/macOS, where Designer runs); keep new `require`s in this module
  lowercase to match the filename.

The Dolby fader math (in `dolbyfader.lua`) maps the Dolby 0.0-10.0 scale ↔ dB:
`≤4 → val*20-90`, else `(val-7)*10/3` (and its inverse). Reference level = 7.0.

### Plugin structure/naming convention (mandatory, since 2026-07-27)

Every plugin in this repo was rebuilt on 2026-07-27 to a convention sourced
from a QSC-derived plugin spec (`components_emulator/docs/qsys-plugins.md` in
the separate `qsc-q-sys` repo — a reverse-engineering toolkit, not an
official QSC SDK; treat it as the best available reference, not ground truth
— the one point that mattered enough to verify independently, `TcpSocket`
construction syntax, was checked against three outside sources before being
applied, see above). Follow it for every new plugin and every edit that
touches an existing one's structure:

**Cross-checked against the real thing** (2026-07-27, same day): two
reference templates are vendored under `vendor/` (see "Repository layout"
above) specifically to make this checkable without re-deriving it from web
search summaries — `qsys-plugins/BasePlugin` (QSC's own) and
`q-sys-community/q-sys-plugin-guide` (third-party, Solo Works London /
Carrier Labs, not QSC, but a second independent data point). Reading their
actual files confirmed part of the list below as genuinely conventional and
identified the rest as `qsc-q-sys`'s own added style, layered on top rather
than reverse-engineered from either real template — each bullet below says
which:

- **Confirmed against both vendored templates**: PascalCase Controls/
  functions/globals/aliases (`BasePlugin`'s `runtime.lua` uses `Status =
  Controls.Status`, `ReportStatus`, `Connect`, `Connected`; the community
  template uses compound PascalCase control names like `IndicatorLed`,
  `IndicatorMeter`); plain string literals for `ControlType`/`IndicatorType`/
  etc. in `GetControls` (`ControlType = "Indicator"` in both — see the enums
  bullet below, this is the one place the two templates directly contradict
  what `qsc-q-sys` added).
- **Confirmed against `BasePlugin` only** (the community template's example
  is too short to show these): Timer/socket objects declared global, never
  local (`PollTimer = Timer.New()`); grouping runtime code into sections
  (aliases, variables/flags, sockets, timers/constants, helper functions,
  event handlers, initialization) — marked with plain `-- Section name`
  comments, not the decorated `--*** Name ***` banners below.
- **Not present in either vendored template, so `qsc-q-sys` house style, not
  a QSC mandate** — kept anyway since nothing here is wrong, just unproven
  as "official": enum tables in place of string literals (both real
  templates write the literal directly, e.g. `ControlType = "Indicator"`);
  the decorated `--*** Name ***` section banners; a `-- CHANGELOG` block
  embedded in the plugin file. If asked to strip this repo's convention down
  to only what's confirmed, these three are the ones to drop first — the
  enum-table one now has two independent templates contradicting it, not
  just an absence of confirmation.

**"Q-SYS Help"** (`q-syshelp.qsc.com`, mirrored at `help.qsys.com`) is QSC's
official documentation site — general web docs, not a repository, so
nothing from it is vendored as a submodule. Relevant pages found 2026-07-27:
Building a Plugin, Plugin Compiler, Basic Plugin Framework, Reserved
Functions, and the Code Examples section (TCPSocket, HTTPClient, SerialPort
Usage, Storing Secrets in Plugins, Dynamic Pages). Caveat: `WebFetch` to
both `q-syshelp.qsc.com` and `help.qsys.com` returns 403 from this
environment's outbound proxy at the gateway level (confirmed via the
proxy's own status endpoint, not just a failed request) — everything known
about these pages here came from search-engine summaries of them, not their
actual text, unlike the two vendored templates above, which were read
directly. Treat anything attributed to "Q-SYS Help" with that in mind; the
two submodules are the more reliable source where they overlap.

- **Mandatory section order** in every `.qplug`: file header comment →
  `PluginInfo` → (design-time-safe `require`s, e.g. `qsys_enums`) →
  Design-time Identity (`GetColor`/`GetPrettyName`) → Properties
  (`GetProperties`/`RectifyProperties`) → Controls (`GetControls`) → Layout
  (`GetControlLayout`) → Components/Pins/Wiring (`GetComponents`/`GetPins`/
  `GetWiring`, omit the section if none) → a `-- CHANGELOG` comment block →
  the runtime guard → the runtime `require`. Mark each section with a
  `--*** Name ***` comment.
- **Naming**: Controls (the `Name` field in `GetControls`/`GetControlLayout`
  keys/`Controls.*` accesses), functions, and globals/aliases are
  `PascalCase`. Locals are `camelCase`. Constants are `UPPER_SNAKE`. A
  socket/timer object is a `camelCase` noun (`sock`, `timer`) but still
  **global**, per the GC-safety note above — "socket/timer=camelCase-noun" is
  the one deliberate exception to "globals=PascalCase".
- **Property names may not contain spaces** — properties, not controls; a
  control's `Name` may have spaces (e.g. `Name = "TCP Log"` is fine), a
  property's may not (`GetProperties`'s own `{ Name = ..., Type = ... }`
  entries). `MultiFlip-Flop`'s "Input Count" property became `InputCount` for
  exactly this reason.
- **Enums, not string literals**, for anything `qsys_enums.lua` defines
  (`ControlType.BUTTON` not `"Button"`, `ButtonType.MOMENTARY` not
  `"Momentary"`, etc.) — require it unconditionally, before the guard, since
  `GetControls`/`GetControlLayout` need it at design time.
- **`_G["Name"]` for embedded components** — `Step`, `Sine`, and other
  `GetComponents`-declared handles are already global (Lua globals live in
  `_G`, so bare `Step` and `_G["Step"]` are the same value); the convention's
  own reference examples write `CompName = _G["CompName"]` as a documentation
  convention, not a functional requirement. This repo does not add that
  redundant self-assignment — a bare reference to the already-global name is
  enough, and inventing a second name for the same value would be dead
  weight for no behavioral gain.
- **`QKnob`'s own method names stay as they were** (`:new`, `:init`, `:set`,
  lowercase) — see "Key module patterns" above for why.
- **Breaking changes get a major version bump** (per the repo-wide
  `changelog-rules` skill) and a note in the `-- CHANGELOG` block. Renaming a
  `Controls` entry or a property is breaking: any Q-SYS design already wired
  to the old name needs those pins/properties reconnected after updating.
- **`PluginInfo.Id` is still preserved** across all of this — the naming
  convention changes identifiers inside the file, never the plugin's
  identity.

This mostly *supersedes* the older "match existing tab-heavy formatting"
habit for these four plugins (they're rebuilt to a consistent, more open
style now) — but don't use that as license to casually reflow files this
convention doesn't touch; it's still the right default for anything outside
the four `.qplug`/`Developer/Modules/*.lua` files this rewrite covered.

### `.qplug` vs `.qplugx`

- `.qplug` — plaintext Lua source; the editable form.
- `.qplugx` — a **packaged** plugin: a JSON envelope with an encrypted/obfuscated
  `key` + payload produced by Q-SYS Designer's "Save as compiled plugin". Do
  **not** try to hand-edit `.qplugx`; regenerate it from the `.qplug` source in
  Designer.

### Developer workflow

Q-SYS Designer loads dev modules from the user's Modules folder. During local
development plugins prepend it to `package.path` (see `reference.lua`):

```
<USERPROFILE|HOME>/Documents/QSC/Q-Sys Designer/Modules/?.lua
//Mac/Home/Documents/QSC/Q-Sys Designer/Modules/?.lua   -- macOS/Parallels
```

Typical loop:
1. Symlink/copy `Developer/Modules/*.lua` into the Q-SYS Designer `Modules`
   folder (or develop with the `package.path` prelude).
2. Edit the `.qplug` in `Developer/plugins/` and its module in
   `Developer/Modules/`.
3. Run `Developer/tests/run.sh`. Fast, catches syntax errors and logic
   regressions without leaving the terminal, but it is a filter, not a
   substitute for step 4.
4. Load the plugin in Q-SYS Designer; test in the emulator
   (`System.IsEmulating` is true) or against a `Dolby CP Emulator/*.quc` on the
   bench.
5. Bump `Version`/`BuildVersion` in `PluginInfo`, then rebuild the root
   distributable with `Developer/tools/build_distributable.sh <head.qplug>
   <output.qplug> [pre-guard modules...] -- <post-guard modules...>` — never
   hand-edit the root file, it's a single-file build with
   `Developer/Modules/*.lua` inlined and `require` stripped, so a hand edit
   just gets discarded on the next rebuild. `qsys_enums` (needed at design
   time) goes in the pre-guard group; everything else goes post-guard. See
   any of the four root `.qplug` files' build for the exact module list, or
   re-run the command from that plugin's own rewrite commit message.
   After rebuilding, re-run `Developer/tests/run.sh`: the `test_dist_*` files
   execute the built artifact, which is the only thing that catches a module
   inlined before something it depends on (that still compiles). If a
   `.qplugx` also needs updating, that step still only happens inside
   Designer — this script only produces `.qplug`.

### Conventions when editing

- **Preserve `PluginInfo.Id`** — it is the stable plugin UUID; changing it makes
  Designer treat the plugin as a different one. Bump `Version`/`BuildVersion`
  instead.
- Follow the "Plugin structure/naming convention" section above for the four
  rebuilt plugins; for anything else, match the existing (tab-heavy,
  deeply-indented) formatting of the file rather than reflowing it.
- Keep runtime logic in the `Developer/Modules/*.lua` module; keep the `.qplug`
  focused on `PluginInfo` + the `Get*` definition callbacks + the final
  `require`. `MultiFlip-Flop` is still the one exception (inline runtime).
- Guard runtime code with `if not Controls and Reflect then return end` so the
  definition pass never executes event logic (`MultiFlip-Flop`: `if Controls
  then ... end`, see above).
- Comments and identifiers are English; keep it that way.
- After changing anything a plugin `require`s, verify the corresponding
  distributable at the repo root is regenerated (it is easy to leave it stale).

### Git

- AI-assisted changes land on a task-specific `claude/...` branch (named per
  session/PR); there is no single long-lived AI branch to target.
- `Developer/Modules/class` (a vendored OOP base) was the last submodule and
  was removed; two new ones were added 2026-07-27 under `vendor/` —
  `qsys-plugins/BasePlugin` (QSC's own plugin template) and
  `q-sys-community/q-sys-plugin-guide` (third-party, not QSC) — both
  read-only reference material (see "Repository layout" and "Plugin
  structure/naming convention" above). Same rule as always: commit submodule
  pointer changes deliberately, don't bump one incidentally. `git submodule
  update --init` after cloning if either is empty (a `SessionStart` hook
  already does this automatically in a Claude Code session).
