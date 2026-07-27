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

Author/contact history in the sources: `james.puig@dolby.com` / Jaume Puig
(Barcelona).

### Repository layout

```
.
├── README.md                         Short plugin catalog
├── .vscode/settings.json             Associates *.qplug with the Lua language
│
├── *.qplug / *.qplugx                Distributable plugins (repo root)
│   ├── DolbyFader.qplug              (v1.0 build — root copy)
│   ├── Dolby Sweep V1.04.qplug
│   ├── MultiFlip-Flop.qplug
│   └── Dolby CPSeries Control V2.2.qplugx   Packaged/encrypted (JSON envelope)
│
├── Dolby CP Emulator/                Q-SYS User Components (.quc) that emulate
│   ├── CP650 Emulator.quc            real Dolby processors for bench testing
│   ├── CP750 Emulator.quc
│   └── CP850 Emulator.quc
│
└── Developer/                        Working sources (edit here)
    ├── plugins/                      Plugin definition files (layout + skeleton)
    │   ├── DolbyFader V1.1.qplug
    │   ├── Dolby CPSeries Control V2.2.qplug
    │   ├── Dolby Sweep V1.1.qplug
    │   ├── MultiFlip-Flop V1.1.qplug
    │   └── reference.lua             Template/cheat-sheet of every component & control type
    └── Modules/                      Runtime logic pulled in by plugins via require()
        ├── qknob.lua                 QKnob class: text control ⇄ value/position/string sync (self-contained, plain metatables, no external OOP base)
        ├── strict.lua                Global-variable guard (errors on undeclared globals)
        ├── dolbyfader.lua            Dolby fader runtime (dB ⇄ 0.0-10.0 Dolby scale)
        ├── dolbysweep.lua            Sweep tone generator runtime
        ├── cpseries.lua             CPSeries TCP control runtime (network state machine)
        └── cpseries_class.lua        CPSeries class (per-model protocol definitions)
```

**`Developer/` holds the source of truth.** The root-level `.qplug`/`.qplugx`
files are exported/distributable snapshots and are often an older build than the
`Developer/plugins/` version (e.g. root `DolbyFader.qplug` is v1.0, the
Developer copy is v1.1). Make changes under `Developer/`, then export.

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
inline in the `.qplug` rather than a separate module.

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
- `TcpSocket` — `TcpSocket:New()`, `.WriteTimeout`, connect/read/write events
  (used by the CPSeries network control).
- `System.IsEmulating` — true in the Designer emulator; used to shorten loops.
- `Print(...)`, `Reflect` (definition-time reflection, `Reflect.Types.*`).

### Key module patterns

- **No external OOP base.** `qknob.lua` no longer depends on any `class()`
  library or submodule (the vendored `jonstoler/class.lua` used briefly on
  2026-07-27 was removed the same day). `QKnob` is defined directly in
  `qknob.lua` as a plain table with its own `__index`/`__newindex` metamethods:
  `QKnob:set(name, {value=, get=, set=})` declares a computed property backed
  by a private per-instance table, and `QKnob:new(...)` creates an instance and
  calls `obj:init(...)`. Same external API as before (`QKnob:new(...)`,
  `QKnob:set(...)`, `QKnob:SetString` override), just self-contained.
- **`qknob.lua`**: wraps a `Text` control as a first-class numeric knob. Keeps
  `Value`/`String`/`Position` in sync via `__index`/`__newindex` metatables and
  a 1 ms polling `Timer` that mirrors external position changes. Subclasses
  override `QKnob:SetString` for unit suffixes (e.g. dolbysweep appends `'s'`).
- **`strict.lua`**: installs a metatable on `_G` that raises on read/write of
  undeclared globals; declare intentional globals with `Global("name", ...)`.
  Not currently `require`d by any plugin — opt in if you need it while debugging.
- **`cpseries.lua` + `cpseries_class.lua`**: TCP client + per-model
  (`CP650`/`CP750`/`CP850`…) command protocol; `Model` enum built with
  `setmeta(Model)`; reuses `dolbyfader`'s `DKNob` and `DolbyFaderEventHandler`
  hook to push fader changes over the socket. Note: the plugin does
  `require "CPSeries"` (capitalized) against the file `cpseries.lua` — this only
  resolves on case-insensitive filesystems (Windows/macOS, where Designer runs);
  keep new `require`s in this module lowercase to match the filename.

The Dolby fader math (in `dolbyfader.lua`) maps the Dolby 0.0-10.0 scale ↔ dB:
`≤4 → val*20-90`, else `(val-7)*10/3` (and its inverse). Reference level = 7.0.

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
3. Load the plugin in Q-SYS Designer; test in the emulator
   (`System.IsEmulating` is true) or against a `Dolby CP Emulator/*.quc` on the
   bench.
4. Bump `Version`/`BuildVersion` in `PluginInfo`, export the compiled
   `.qplug`/`.qplugx`, and update the root-level distributable copy.

### Conventions when editing

- **Preserve `PluginInfo.Id`** — it is the stable plugin UUID; changing it makes
  Designer treat the plugin as a different one. Bump `Version`/`BuildVersion`
  instead.
- Match the existing (tab-heavy, deeply-indented) formatting of each file rather
  than reflowing it.
- Keep runtime logic in the `Developer/Modules/*.lua` module; keep the `.qplug`
  focused on `PluginInfo` + the `Get*` definition callbacks + the final
  `require`.
- Guard runtime code with `if not Controls and Reflect then return end` so the
  definition pass never executes event logic.
- Comments and identifiers are English; keep it that way.
- After changing anything a plugin `require`s, verify the corresponding
  distributable at the repo root is regenerated (it is easy to leave it stale).

### Git

- AI-assisted changes land on a task-specific `claude/...` branch (named per
  session/PR); there is no single long-lived AI branch to target.
- The repo no longer has a git submodule (`Developer/Modules/class` was
  removed). If one gets added back in the future, commit its pointer
  changes deliberately; don't bump it incidentally.
