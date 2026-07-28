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
config (see `.claude/config-export-import.md`). `file-operations` and
`github-rules` are mandatory/blind-copy on import into another repo
(each was briefly made optional 2026-07-27, then moved back the same
day, both explicit user request). `changelog-rules` and `find-skills`
are optional choices on import instead: made optional 2026-07-27, then
deleted from the bundle entirely later the same day (a session-long
audit found neither had actually been invoked that session), then
restored from git history and put back as optional 2026-07-28 (explicit
user request) rather than staying deleted. This repo itself always
keeps and uses all four regardless — except `changelog-rules`, disabled
locally the same day via `skillOverrides: {"changelog-rules": "off"}`
in `.claude/settings.local.json` (gitignored, explicit user request:
keep the `SKILL.md` on disk so it still exports/bundles normally as
optional, but don't use it in this repo's own sessions; kept out of
`.claude/settings.json` specifically so the override doesn't travel
into the export bundle and silently disable it in a target repo too —
`export-config-skill.sh` only ever copies `settings.json`, never
`settings.local.json`). Pointers
only, not summaries — same
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

(`changelog-rules` and `find-skills` briefly removed from the portable
bundle 2026-07-27, explicit user request, then restored from git history
2026-07-28, also explicit user request, and put back as optional rather
than mandatory this time. `removed-files.txt` no longer lists them —
they're back, not gone.)

(`file-operations` needs no pointer here beyond the numbered list above
— its own description triggers it by context when there's file I/O to
do.)

**Find Skills**: `find-skills`, imported from `vercel-labs/skills`
(`skills/find-skills/SKILL.md`) — discovers and installs third-party
skills via the `npx skills` CLI, #1 by install count on skills.sh at
import time. Tracked in `skills-lock.json`. Note its own workflow can
install other skills straight from that ecosystem, bypassing this
repo's own skill-creator/config-ingest governance — worth keeping in
mind wherever it ends up.

**Which additional skills travel on export is defined in
`.claude/scripts/export-config-skill.sh`** — not repeated here, to avoid
two places that can drift out of sync. Anything installed here but not in
that script's copy list stays local; its name/source is kept in
`.claude/recommended-skills.txt` (plain list, one name per line,
updated by hand) for a target repo to fetch itself if wanted — that
file itself always travels on export.

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

**"Tanca" always means end the session.** A user message that is just
"tanca" (bare, no other object attached) always means "tanca sessió" — end
the current session — never "close/drop this topic/investigation" or
anything else. Before signaling the session is closed: check `git status`
is clean (or say plainly what's left uncommitted/unpushed), confirm the
current branch/last commit, and if there's an open question or unfinished
work worth a future session picking up, save a note of it in this file's
Project-specific rules section first (as its own dated entry) so the next
session doesn't have to re-derive it from scratch.

## Project-specific rules

### What this repo is

A collection of **QSC Q-SYS plugins** written in **Lua**, targeting Dolby
cinema audio processors (CP650 → CP950 series) and general utility components.
Plugins run inside **Q-SYS Designer** on QSC audio DSP cores. There is no build
system, package manager, or CI here — plugins are authored in Lua, tested in
Q-SYS Designer's emulator, and distributed as `.qplug` / `.qplugx` files.

There *is* a small test suite under `Developer/tests/` (added 2026-07-27):
plain Lua 5.3 — matching Q-SYS Designer's own embedded Lua version, not 5.4
(confirmed 2026-07-27 against Q-SYS Help, which points to the Lua 5.3
Reference Manual for native Lua support) — no framework, run with
`Developer/tests/run.sh`. `.claude/hooks/ensure-lua53.sh` (SessionStart,
added 2026-07-28) checks for `lua5.3`/`luac5.3` on `PATH` and installs the
`lua5.3` package via `apt-get` if missing, best-effort, so a fresh
container has it before `run.sh` is ever invoked; this hook is
project-specific (installs a runtime only this repo's own test suite
needs) and deliberately not part of the portable `.claude/` bundle, per
`config-export-import.md`'s own example of what stays out of the export.
It stubs the
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
│   ├── DolbyFader.qplugx
│   ├── Dolby Sweep V2.0.qplug
│   ├── Dolby Sweep V2.0.qplugx
│   ├── MultiFlip-Flop.qplug          (v2.0)
│   ├── MultiFlip-Flop.qplugx
│   ├── Dolby CPSeries Control V4.0.qplug
│   └── Dolby CPSeries Control V4.0.qplugx   Packaged/encrypted (JSON envelope);
│                                     all four .qplugx built 2026-07-27 via
│                                     .github/workflows/build-qplugx.yml
│                                     (GitHub Actions, windows-latest),
│                                     replacing the old stale
│                                     "Dolby CPSeries Control V2.2.qplugx"
│                                     (last hand-compiled at v2.2, now removed).
│                                     Never hand-edited; regenerate via the
│                                     workflow (or Designer's "Save as
│                                     compiled plugin") after any .qplug rebuild.
│
├── Dolby CP Emulator/                Q-SYS User Components (.quc) that emulate
│   ├── CP650 Emulator.quc            real Dolby processors for bench testing
│   ├── CP750 Emulator.quc
│   └── CP850 Emulator.quc
│
├── vendor/                            Read-only reference material (git submodules) —
│   │                                 `git submodule update --init --recursive` after
│   │                                 cloning if empty; never edit contents, it's all
│   │                                 upstream's
│   ├── qsys-plugins/                  QSC's own org (confirmed: support contact
│   │   │                             qsyscontrolfeedback@qsc.com in each README)
│   │   ├── BasePlugin/               Plugin template (added 2026-07-27); its own
│   │   │   └── PluginCompile/         nested submodule, the VS Code compile-to-.qplug
│   │   │                             tool -- compiles multiple Lua files into one
│   │   │                             .qplug, base64-encodes PNG/JPEG/JPG/SVG assets,
│   │   │                             generates a GUID if missing, auto-increments the
│   │   │                             version on each build, and copies the result into
│   │   │                             the Designer plugin folder (confirmed reading
│   │   │                             Q-SYS Help's Plugin Compiler page, 2026-07-27) --
│   │   │                             no longer vendored a second time at the top
│   │   │                             level, see "Git" below
│   │   ├── ExamplePlugin/             Filled-in example (Mixer + Video Switcher UI);
│   │   │   └── PluginCompile/         same nested submodule as BasePlugin's, same commit
│   │   │                             ExamplePlugin.qplug is a full worked build
│   │   └── PluginEncryptionTool/      plugin_tool_release.exe — standalone .qplug ->
│   │                                 .qplugx encryption, Windows binary
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
    │   ├── qknob.lua                 QKnob class: text control ⇄ value/position/string sync (self-contained, plain metatables, no external OOP base)
    │   ├── strict.lua                Global-variable guard (errors on undeclared globals)
    │   ├── dolbyfader.lua            Dolby fader runtime (dB ⇄ 0.0-10.0 Dolby scale)
    │   ├── dolbysweep.lua            Sweep tone generator runtime
    │   ├── cpseries.lua              CPSeries application layer (TCP connection lifecycle, Controls wiring)
    │   ├── cpseries_commlib.lua      CPSeries class (per-model protocol state machine)
    │   ├── cpseries_models.lua       Per-model wire config (TCP port, KEY=VALUE vs "param value")
    │   └── cpseries_protocol.lua     Per-model message formatting and GET framing
    ├── tools/
    │   └── build_distributable.sh    Builds a root distributable from a Developer/ head +
    │                                 named modules (see below). Supports a pre-guard /
    │                                 post-guard module split for a plugin that needs a
    │                                 module at design time, not just runtime -- none of
    │                                 the four plugins here currently need that group
    └── tests/                        Lua 5.3 test suite, no framework (see its README)
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
silently discards the hand edit. The four root `.qplugx` files are packaged
builds produced from those same `.qplug` files by
`.github/workflows/build-qplugx.yml` (or Designer's own "Save as compiled
plugin") — also never hand-edited; regenerate the same way after any `.qplug`
rebuild. (Until 2026-07-27 only a stale `Dolby CPSeries Control V2.2.qplugx`
existed, hand-compiled and predating this convention; it's been replaced by
a current `V4.0.qplugx` built via the workflow, alongside `.qplugx` builds
for the other three plugins.)

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
| `GetPages(props)` | (when present) multiple UI pages, returns a table of page-name objects; confirmed official (Reserved Functions doc, read directly 2026-07-27) but not used by any of the four plugins here — none need a multi-page UI |
| `GetControls(props)` | Pins/controls: `Button`/`Knob`/`Text`, `PinStyle`, `UserPin`, min/max… |
| `GetComponents(props)` | Embedded DSP blocks the plugin instantiates (`gain`, `sine`, `stepper`, `mixer`, `meter2`, `flip_flop`, `router`, `custom_controls`…) |
| `GetControlLayout(props)` | Returns `layout, graphics` — positions/sizes/styles for the schematic & UCI |
| `GetPins(props)` | (when present) external component pins, e.g. `{ Name, Direction }` |
| `GetWiring(props)` | (when present) internal wiring from an embedded component's pin to a plugin pin |

The Reserved Functions doc also lists a set of *runtime* function names as a
common convention (not reserved words, just what QSC's own device plugins
tend to call things): `SetupDebugPrint()`, `Send()`, `ClearVariables()`,
`Connect()`, `Disconnected()`, `GetDeviceInfo()`, `PollDevice()`,
`ParseResponse()`, `Initialization()`. `cpseries.lua` and the other modules
here don't follow this exact set of names and there's no need to rename them
to match it — it's a convention some QSC-authored plugins use, not something
Q-SYS enforces.

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
  documented construction syntax; re-confirmed same day by reading the
  official TCPSocket Code Example page directly, not just a search summary
  — see "Q-SYS Help" below), `.ReadTimeout`, `.WriteTimeout`,
  `.ReconnectTimeout`, connect/read/write events; instance methods use colon
  (`sock:Connect(...)`, `sock:Write(...)`).
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

### Full Q-SYS Lua extension API (reference, confirmed 2026-07-27)

The host's Lua environment adds 36 extension objects beyond native Lua, all
documented on the official "Q-SYS Extensions to Lua" index page and its 36
sub-pages (`help.qsys.com/Content/Control_Scripting/Using_Lua_in_Q-Sys/`),
each read directly this session, not from a search-engine summary. Only
`Controls`, `Timer`, `TcpSocket`, and `System.IsEmulating` are used anywhere
in this repo today (see above) — the rest are listed here purely as a
reference for future plugins, none of it in use:

| Class | Purpose | Constructor | Key methods/properties/events |
|---|---|---|---|
| `ChannelGroup` | Identifies which Channel Group a Control Script sits in | none (direct access) | `.Index` — current group number, 0 if none |
| `Component` | Reference a Named Component (Code Name + Script Access enabled) | `Component.New(name)` | `.GetComponents()`, `.GetControls()` |
| `Controls` (I/O) | Read/write a Control Script's own connected input/output pins | none (`Controls.Inputs`/`Controls.Outputs`) | Inputs: `.Value`/`.Position`/`.String`/`.Boolean`/`.EventHandler` (ro); Outputs: same plus `.RampTime`, `.Legend`, `:Trigger()` (rw) |
| `Crypto` | Base64/CRC16/HMAC/MD5/PBKDF2 and block cipher helpers | none (static) | `Base64Encode/Decode`, `CRC16Compute`, `Digest`, `Encrypt/Decrypt`, `GetRandomBytes`, `HMAC`, `MD5Compute`, `PBKDF2`; `Crypto.Cipher`/`Crypto.Hash` type tables |
| `Dante` | GPIO control/monitoring of Dante devices | `DanteBrowser.New()`, `DanteDevice.New(name)` | Browser: `.Browse`; Device: `:SetGpio()`, `:GetGpio()`, `.Gpio`, `.Response`, `.EventHandler` |
| `Design` | Design/platform/redundancy status and device inventory | none | `Design.GetStatus()`, `Design.GetInventory()` |
| `dir` (Directory) | List/create/remove folders under `media/` or `design/` | none | `dir.get(path)`, `dir.create(path)`, `dir.remove(path)` |
| `Email` | Send email from a script | none | `Email.Send(table)`, handler `function(table, error)` |
| `EzSVG` | Build SVG images dynamically (status/level visualization) | `EzSVG.Document(w,h)`, `.Path(props)`, `.Circle(x,y,r)`, `.Line(x1,y1,x2,y2)` | `toString()`, `add()`, `setStyle()`, `moveToA()`, `lineToA()`, `archToA()` |
| `HttpClient` | HTTP(S) requests, TLS 1.0-1.3 | none (direct calls) | `Download`, `Upload`, `Get`, `Post`, `Put`, `Patch`, `Delete`, `CreateUrl`, `EncodeParams`, `EncodeString`, `DecodeString` |
| `JSON` | Lua table ⇄ JSON string | `require("json")` | `json.encode`, `json.decode`, `json.null` (docs recommend RapidJSON for large data) |
| `Log` | Write to the Core's system log | none | `Log.Message`, `Log.Error` |
| `LPeg` | Parsing Expression Grammar pattern matching | `require("lpeg")` | `match`, `type`, `version`, `P`, `B`, `R`, `S`, `V`, `locale`, `C`, `Carg`, `Cb`, `Cc`, `Cf`, `Cg`, `Cp`, `Cs`, `Ct` |
| `Lua bitstring` | Binary/hex packing for protocol work | `require "bitstring"` | `pack`, `unpack`, `compile`, `bindump`, `hexdump`, `binstream`, `hexstream`, `frombinstream`, `fromhexstream` |
| `LuaDate` | Gregorian date/time arithmetic and formatting | `require "date"` | per-instance `add*`/`get*`/`set*`/`span*`/`tolocal`/`toutc`/`fmt`/`copy`; module `date.diff`, `date.epoch`, `date.isleapyear` |
| `LuaXML` | XML ⇄ Lua table mapping | `require("LuaXML")` | `xml.new`, `.append`, `.children`, `.decode`, `.encode`, `.load`, `.save`, `.eval`, `.tag`, `.str`, `.find`, `.registerCode` |
| `Mixer` | Control a named Mixer component | `Mixer.New(name)` | `SetCrossPointGain/Mute/Solo/Delay`, `SetInputGain/Mute/Solo/CueEnable/CueAfl`, `SetOutputGain/Mute`, `SetCueGain/Mute`, `GetMixerCrossPoints` |
| `NamedControl` | Read/set any Named Control by name | none (static) | `SetString/GetString`, `SetPosition/GetPosition`, `SetValue/GetValue`, `Trigger` |
| `Network` | Host/interface info | none | `Network.GetHostByName()`, `Network.Interfaces()` |
| `Notifications` | Pub/sub between scripts on the same Core | none (static) | `Notifications.Subscribe/Publish/Unsubscribe` |
| `Ping` | Reachability check for a host | `Ping.New(host)` | `start`, `stop`, `setTimeoutInterval`, `setPingInterval`, `EventHandler`, `ErrorHandler` |
| `QRCode` | Generate a QR code SVG for a URL | none | `QRCode.GenerateSVG(url, mode)` |
| `RapidJSON` | Fast JSON encode/decode, schema validation | `require("rapidjson")` | `encode`, `decode`, `load`, `dump`, `null`, `object()`, `array()`, `Document()`, `SchemaDocument()`, `SchemaValidator()` |
| `SerialPorts` | RS-232 via a wired Inventory component | auto-created by wiring | `.EventHandler`, `.IsOpen`, `.BufferLength`, `:Open/Close/Write/Read/ReadLine/Search`; events `Connected`/`Reconnect`/`Data`/`Closed`/`Error`/`Timeout` |
| `SerialServerPorts` | Emulate a hardware serial port over the network | accessed by index, e.g. `SerialServerPorts[1]` | `.IsOpen`, `.BufferLength`, `:Event`, `:Write`, `:Read`, `:ReadLine`, `:Search`, `.OnOpen`, `.OnClose`, `.Data` |
| `Snapshot` | Load/save Q-SYS snapshots at runtime | none | `Snapshot.GetNames()`, `.Load(name, bank, ramp)`, `.Save(name, bank)` |
| `SNMP` | Act as an SNMP Manager (v2c/v3) | `SNMPSession.New(SNMP.SessionType.v2c\|v3)` | `setHostName`, `setAuthType/Prot`, `setPrivProt`, `setUserName`, `setPassPhrase`, `setPrivPassPhrase`, `setCommunity`, `startSession`, `getRequest`, `setRequest`, `EventHandler`, `ErrorHandler` |
| `SNMPTrap` | Receive SNMP traps | `SNMPTrap.New(name)` | `startSession()`, `EventHandler`, `ErrorHandler` |
| `Ssh` | SSH client (like `TcpSocket` plus auth/PKI) | `Ssh.New()` | `Connect`, `Disconnect`, `Write`, `Read`, `ReadLine`, `Search`, `*Timeout` props, `IsConnected`, `IsInteractive`, `PublicKey`/`PrivateKey`/`Certificate`; events incl. `LoginFailed` |
| `System` | Core/runtime environment info | none | `.BuildVersion`, `.LockingId`, `.IsEmulating`, `.MajorVersion`, `.MinorVersion`, `.Version` |
| `TcpSocket` | Client TCP/IP, event-based, reconnecting | `TcpSocket.New()`, `.NewTls()` | see "Q-SYS runtime globals" above |
| `TcpSocketServer` | Listen for inbound TCP connections | `TcpSocketServer.New()` | `Listen(port)`, `Close()`, `EventHandler` (fires with a new socket instance per connection) |
| `Timer` | Delays/scheduled events | `Timer.New()` | `EventHandler`, `Start(sec)`, `Stop()`, `IsRunning()`, `Timer.CallAfter(fn, delay)`, `Timer.Now()` |
| `Uci` | Control User Control Interfaces | none (static) | `GetLayerVisibility`, `GetUcis`, `GetUciPages`, `GetUciPageLayers`, `GetVariable/SetVariable`, `SetLayerVisibility`, `SetPage`, `SetScreen`, `SetSharedLayerVisibility`, `SetUCI`, `LogOff`, `ShowDialog` |
| `UDPSocket` | Send/receive UDP, incl. multicast | `UdpSocket.New()` | `Open(ip, port)`, `Close()`, `Send(ip, port, data)`, `JoinMulticast(addr, localIp)`, `EventHandler`/`Data`, `MulticastTtl` |
| `WebSocket` | Two-way framed messaging over ws/wss | `WebSocket.New()` | `Connect()`, `Write()`, `Close()`, `Ping()`; events `Connected`/`Data`/`Error`/`Closed`/`Pong` |

`Timer`, `TcpSocket`, `Ssh`, `SerialPorts`/`SerialServerPorts`, and `UDPSocket`
all share the same "keep it global, never `local`" GC-safety requirement
noted above for `Timer`/`TcpSocket` specifically — the same closure-chain
reasoning applies to any of them if a future plugin uses one.

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
  Provenance (confirmed 2026-07-27): a variant of the canonical
  `http://www.lua.org/extras/5.1/strict.lua`, the same base LuaJIT,
  cheat-engine, Penlight, and lua-stdlib all fork — not from any QSC/Q-SYS
  repo. Two deliberate deviations from that original: (1) the original's
  `__newindex` allows an undeclared global to self-declare when the
  assignment happens directly in a chunk's main body (`debug.getinfo`
  `what == "main"`); this copy drops that exemption, so every custom global
  needs an explicit `Global(...)` call regardless of where it's first
  assigned — stricter, not looser, and every plugin wired to it below
  already declares its globals explicitly, so nothing here depends on the
  dropped exemption. (2) the explicit `Global(name, ...)` declare function
  itself isn't in the lua.org original at all (it relies solely on the
  main-chunk exemption); a similar lowercase `global()` helper shows up in
  some community write-ups (e.g. the lua-users wiki), but this repo's
  version capitalizes it to match its own globals-are-PascalCase convention.
  Wired into `DolbyFader V2.0.qplug`, `Dolby Sweep V2.0.qplug`, and
  `Dolby CPSeries Control V4.0.qplug` (2026-07-27) as a dev-only safety net:
  `require "strict"` plus a `Global(...)` call sits right after the runtime
  guard, before the plugin's own `require`. This placement is deliberate —
  everything after the guard line in a Developer head file is dropped by
  `build_distributable.sh` in favor of the explicitly inlined module list
  (see "Developer workflow" below), so strict-mode is active whenever the
  plugin loads straight from `Developer/plugins/` (Designer, bench-testing)
  but never ships in the root distributable. Each plugin declares only the
  custom globals its own require chain creates on first write (host globals
  like `Controls`/`Properties`/`Timer`/`TcpSocket`/`System` already exist
  before the plugin's code runs, so they never need declaring):
  `DolbyFader`/`Dolby Sweep` both pull in `QKnob` (from `qknob.lua`);
  `DolbyFader` adds `DKNob`, `DolbyFaderEventHandler`; `Dolby Sweep` adds
  `period`, `timer`; `CPSeries` adds `DKNob`, `DolbyFaderEventHandler`
  (via its own `require "dolbyfader"`), `CPSeries`, `CPModels`,
  `CPProtocol`, `DolbyCP`, `sock`, and `Print` (declared defensively, even
  though `Print` is normally already host-provided, so `cpseries_commlib.lua`'s
  override — see below — never depends on load order). Verified by loading
  each Developer head file's runtime pass under a stubbed host (2026-07-27);
  the repo's own `Developer/tests/` doesn't exercise this path (its
  dist tests run the already-built root files, which never see these
  lines), so this was checked by hand, not by `run.sh`.
  `MultiFlip-Flop` is NOT wired up: it has no custom globals to protect
  (its runtime block only ever writes into the existing `Controls`/
  `Properties` tables) and, more importantly, its root `.qplug` is a plain
  copy of the Developer source with no build-script stripping step (see
  "Developer workflow" below) — so unlike the other three, there is no
  automatic mechanism to keep a `require "strict"` here from shipping to
  production. Add it only alongside a real removal step if that changes.
- **`cpseries_models.lua` / `cpseries_protocol.lua`**: per-model wire config
  (TCP port, `KEY=VALUE` vs `"param value"` dialect) and message formatting/
  GET framing. Neither touches `Controls` — they're pure protocol logic,
  shared between `cpseries.lua` and `cpseries_commlib.lua`.
- **`cpseries_commlib.lua`** (renamed from `cpseries_class.lua` 2026-07-27,
  explicit user request; `require("cpseries_class")` in `cpseries.lua` and
  `Developer/tests/test_modules.lua` updated to match, no behavior change):
  the per-model (`CP650`/`CP750`/`CP850`/`CP950`/
  `index`/`key`/`value` fields (the old `setmeta`/`searchelem` reflection hack
  was removed 2026-07-27 along with the CP950/CP950A bump); doesn't reference
  `Controls` at all. It also reassigns the global `Print` (no `local`) to a
  debug-gated wrapper — `Print = function(show, ...)` — that checks
  `Properties.plugin_show_debug.Value` and the `"TCP Log"` property
  (`Command` vs `All`) before calling the real Lua `print(...)`. This
  shadows the host-provided `Print` global documented under "Q-SYS runtime
  globals" above, for every module loaded after this one; `cpseries.lua`
  relies on the override, always calling `Print(true, ...)` with the
  boolean as a debug-level flag, not a message argument. Confirmed
  intentional and consistently used (2026-07-27 audit), just not previously
  documented here.
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

Every plugin in this repo was rebuilt on 2026-07-27, twice, same day. The
first pass applied a convention sourced from a separate `qsc-q-sys` repo's
own reverse-engineered plugin spec (`components_emulator/docs/
qsys-plugins.md`) — a personal reverse-engineering toolkit, not an official
QSC SDK. Five reference repos were then vendored under `vendor/` (see
"Repository layout" above) specifically to check that spec against the real
thing without re-deriving it from web search summaries: QSC's own
`qsys-plugins/{BasePlugin,ExamplePlugin,PluginCompile,PluginEncryptionTool}`
and the third-party `q-sys-community/q-sys-plugin-guide`. Reading their
actual files split the original convention into two piles — confirmed by at
least one real template, and present only in `qsc-q-sys`'s own house style
with no confirmation anywhere else. The second 2026-07-27 pass stripped the
unconfirmed pile back out. What follows is the confirmed pile only; treat it
as mandatory for every new plugin and every edit that touches an existing
one's structure:

- **Naming**: Controls (the `Name` field in `GetControls`/`GetControlLayout`
  keys/`Controls.*` accesses), functions, and globals/aliases are
  `PascalCase` (`BasePlugin`'s `runtime.lua`: `Status = Controls.Status`,
  `ReportStatus`, `Connect`, `Connected`; `ExamplePlugin`: `EQBypass`,
  `EQFrequency`, `ChannelName`; the community template: `IndicatorLed`,
  `IndicatorMeter`) — not absolute, though: `ExamplePlugin.qplug` itself has
  one lowercase control, `Name = "code"`, alongside dozens of PascalCase
  ones, so treat this as the strong default, not a rule Q-SYS enforces.
  Locals are `camelCase`. Constants are `UPPER_SNAKE`. A socket/timer object
  is a `camelCase` noun (`sock`, `timer`) but still **global**, never
  `local` (`BasePlugin`: `PollTimer = Timer.New()`) — per the GC-safety note
  above, this is the one deliberate exception to "globals=PascalCase".
- **String literals, not enum tables**, for `ControlType`/`ButtonType`/
  `IndicatorType`/etc. — write `ControlType = "Indicator"` directly. All
  three real templates do this; a `qsys_enums.lua` module centralizing them
  as `ControlType.BUTTON`-style tables was tried and reverted the same day
  (2026-07-27) once three independent templates turned up writing the
  literal directly, none using a table.
- **Property names CAN contain spaces — retracted 2026-07-27.** The earlier
  claim here ("property names may not contain spaces... it's how Q-SYS
  itself behaves") is wrong, disproved by QSC's own vendored template:
  `vendor/qsys-plugins/ExamplePlugin/properties.lua` lines 20 and 28 declare
  `Name = "Button Styles"` and `Name = "Serial Pin"` inside the manufacturer's
  own real `GetProperties()`, spaces and all. There is no platform
  constraint — a spaced property name just needs bracket-notation access
  (`Properties["Button Styles"]`) instead of dot notation
  (`Properties.ButtonStyles`), same as any Lua table with a non-identifier
  key. `MultiFlip-Flop`'s "Input Count" → `InputCount` rename (still 2026-07-27)
  was cosmetic, not a fix: `Developer/plugins/MultiFlip-Flop V2.0.qplug`
  reads it as `Properties["InputCount"]` both before and after, bracket
  notation either way, so the rename bought nothing. `cpseries`'s "TCP Log"
  property (`Developer/plugins/Dolby CPSeries Control V4.0.qplug`, read via
  `Properties["TCP Log"]` in `Developer/Modules/cpseries_commlib.lua`) was
  never renamed and was never broken — proof the constraint never existed.
  Leave "TCP Log" as-is; do not "fix" it, and do not rename other spaced
  property names on this basis alone.
- **Section comments, plain, not decorated** — group runtime code loosely
  into aliases, variables/flags, objects (sockets/timers), constants, helper
  functions, event handlers, initialization, each marked with a plain
  `-- Section name` line (confirmed against `BasePlugin`'s `runtime.lua`).
  The decorated `--*** Section Name ***` banner style and a `-- CHANGELOG`
  comment block embedded in the plugin file were both `qsc-q-sys` additions
  with no confirmation in any real template — also reverted 2026-07-27, back
  to plain comments and per-version prose in the file header (matching what
  `ExamplePlugin.qplug` and `BasePlugin` both do; version history otherwise
  lives in git log / commit messages, not restated in-file).
- **`_G["Name"]` for embedded components** — `Step`, `Sine`, and other
  `GetComponents`-declared handles are already global (Lua globals live in
  `_G`, so bare `Step` and `_G["Step"]` are the same value); a bare
  reference to the already-global name is enough, no need to introduce a
  second name for the same value.
- **`QKnob`'s own method names stay as they were** (`:new`, `:init`, `:set`,
  lowercase) — see "Key module patterns" above for why.
- **Breaking changes get a major version bump** (per the repo-wide
  `changelog-rules` skill), noted in the file header's version-history
  prose. Renaming a `Controls` entry or a property is breaking: any Q-SYS
  design already wired to the old name needs those pins/properties
  reconnected after updating.
- **`PluginInfo.Id` is still preserved** across all of this — the naming
  convention changes identifiers inside the file, never the plugin's
  identity.

A styling choice with no template evidence either way, kept anyway on
general Lua hygiene grounds, not a QSC mandate: `ExamplePlugin.qplug`'s
`GetProperties()`/`GetControls()` assign `props = {}` / `ctrls = {}` with no
`local` — global, but not dead code, since the function goes on to
`table.insert` into that same table and return it. This repo still prefers
`local` for a table with no reason to escape the function; that's different
from the two real bugs fixed in this repo's own `GetProperties()` calls
(DolbyFader, Dolby Sweep) — those built and returned a *separate* literal
table while leaving an actually-unused `props = {}` behind, genuine dead
code, not a live global either way.

**"Q-SYS Help"** (`q-syshelp.qsc.com`, mirrored at `help.qsys.com`) is QSC's
official documentation site — general web docs, not a repository, so
nothing from it is vendored as a submodule. Relevant pages found 2026-07-27:
Building a Plugin, Plugin Compiler, Basic Plugin Framework, Reserved
Functions, and the Code Examples section (TCPSocket, HTTPClient, SerialPort
Usage, Storing Secrets in Plugins, Dynamic Pages). Update, same day: the
earlier 403 was not universal — `WebFetch` against `help.qsys.com` (the
`.qsc.com` domain was not retested) succeeded this session, reading
Reserved Functions, the TCPSocket Code Example, and Storing Secrets in
Plugins directly rather than via search-engine summary; see the
`GetPages(props)` table row and the `TcpSocket` bullet above for what that
confirmed. Update, same day: `HttpClient` and `SerialPorts` were later
fetched directly too, along with the other 34 Q-SYS Lua extension pages —
see "Full Q-SYS Lua extension API" above for the complete result. Dynamic
Pages remains unconfirmed — only seen as a Code Examples topic listing via
search-engine summary, no direct fetch attempted, no further detail known.
Storing Secrets in Plugins' documented pattern:
keep the secret in a hidden embedded Custom Controls component (its controls
are only reachable from the plugin they're embedded in, and persist with the design
state), copy user input into it on `EventHandler`, and mask the visible
control with `ctrl.String:gsub(".", "*")` — not used by any plugin in this
repo today (none of the four handle credentials), but the pattern to reach
for if one ever does. Treat anything attributed to "Q-SYS Help" that has
*not* been re-fetched this way with the original caveat in mind; the
vendored submodules remain the more reliable source where they overlap.

This mostly *supersedes* the older "match existing tab-heavy formatting"
habit for these four plugins (they're rebuilt to a consistent, more open
style now) — but don't use that as license to casually reflow files this
convention doesn't touch; it's still the right default for anything outside
the four `.qplug`/`Developer/Modules/*.lua` files this rewrite covered.

### `.qplug` vs `.qplugx`

- `.qplug` — plaintext Lua source; the editable form.
- `.qplugx` — a **packaged** plugin: a JSON envelope with an encrypted/obfuscated
  `key` + payload. Two ways to produce one, both QSC's own, neither of them
  hand-editing: Designer's own "Save as compiled plugin", or the standalone
  `plugin_tool_release.exe encrypt input.qplug output.qplugx` CLI now
  vendored at `vendor/qsys-plugins/PluginEncryptionTool/release/` (Windows
  binary + DLLs — not runnable from this Linux dev environment directly, but
  real and official; confirmed via its own README, `vendor/qsys-plugins/
  PluginEncryptionTool/README.md`). Do **not** try to hand-edit `.qplugx`
  with either path available.
- **CI alternative (added 2026-07-27, explicit user request):**
  `.github/workflows/build-qplugx.yml` runs that same `plugin_tool_release.exe`
  on a `windows-latest` GitHub Actions runner instead — manual trigger
  (`workflow_dispatch`) only, picks one root `.qplug` or `all`, uploads the
  resulting `.qplugx` as a workflow artifact. The workflow itself never
  commits the `.qplugx` back to the repo; downloading and adding it is a
  separate, deliberate step. This is the repo's first CI workflow.
  First real run, same day: triggered with `all` against `main` right after
  merging the workflow (needed there for GitHub to register it as
  dispatchable at all), producing all four `.qplugx` — those were then
  downloaded and committed to the repo root as the deliberate follow-up
  step above, replacing the old stale `Dolby CPSeries Control V2.2.qplugx`.

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
   <output.qplug> -- <module1> <module2> ...` — never hand-edit the root
   file, it's a single-file build with `Developer/Modules/*.lua` inlined and
   `require` stripped, so a hand edit just gets discarded on the next
   rebuild. The leading `--` (empty pre-guard group) is currently right for
   all four plugins here — none of them need a module loaded before the
   runtime guard, only a plugin whose `GetControls`/`GetControlLayout` reads
   something from an external module at design time would need that group.
   See any of the four root `.qplug` files' build for the exact module list,
   or re-run the command from that plugin's own rewrite commit message.
   `MultiFlip-Flop` is the exception: it has no Modules/ dependency at all,
   so its root file is a plain copy of the Developer source, no build script
   needed.
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

- `Developer/Modules/class` (a vendored OOP base) was the last submodule and
  was removed; five new ones were added 2026-07-27 under `vendor/` — four
  from QSC's own `qsys-plugins` org (`BasePlugin`, `ExamplePlugin`,
  `PluginCompile`, `PluginEncryptionTool`) and one third-party
  (`q-sys-community/q-sys-plugin-guide`, not QSC) — all read-only reference
  material (see "Repository layout" and "Plugin structure/naming
  convention" above). Same rule as always: commit submodule pointer changes
  deliberately, don't bump one incidentally.
- **No duplicate submodule vendoring (revised 2026-07-27, same day as the
  original fix).** `BasePlugin` and `ExamplePlugin` each declare their own
  nested `PluginCompile` submodule (confirmed via `git submodule status
  --recursive`, same commit both places). This repo first "fixed" that by
  vendoring `PluginCompile` a third time at the top level
  (`vendor/qsys-plugins/PluginCompile`) and keeping submodule init
  non-recursive so the nested copies stayed empty placeholders — that
  avoided the clone cost but kept three separate `.gitmodules`-visible
  copies of the same repo. Superseded same day: the top-level
  `vendor/qsys-plugins/PluginCompile` submodule was removed entirely: it
  contributed nothing `BasePlugin`'s and `ExamplePlugin`'s own nested
  copies don't already provide, once the whole tree is initialized
  recursively. `.claude/hooks/init-submodules.sh` now runs `git submodule
  update --init --recursive`, so a fresh clone gets `PluginCompile`'s
  content solely through the two nested paths
  (`vendor/qsys-plugins/BasePlugin/PluginCompile` and
  `vendor/qsys-plugins/ExamplePlugin/PluginCompile`) — one fewer top-level
  `.gitmodules` entry, same content reachable, no duplication either way.

### Continuity notes

(Moved back here 2026-07-27 from a short-lived `HANDOFF.md` split: a
separate file isn't auto-loaded at session start the way CLAUDE.md is, so
it's a worse fit for exactly this purpose — `HANDOFF.md` deleted.)

- **Button control `.Value` type, unresolved (2026-07-27):** unclear if a
  Button's `.Value` is boolean or numeric during a live EventHandler read,
  vs. only defaulting to `false` untouched. 8+ numeric-comparison sites
  across `dolbyfader.lua`/`cpseries.lua`/`dolbysweep.lua`/`MultiFlip-Flop
  V2.0.qplug` were audited and left unchanged (QSC's own Roku/ShureAxient
  plugins didn't settle it either way; fixing without proof risked a
  regression). Resolves with one check, `type(Controls.SomeButton.Value)`
  from a live EventHandler on real Designer or a CP Emulator bench — neither
  available so far.
- **Two unactioned review findings (2026-07-27):** (1)
  `MultiFlip-Flop V2.0.qplug`'s `Toggle_N` handler writes a boolean to
  `State_N.Value` then reads it back numeric (`== 1`) in the same
  synchronous call, no host round-trip — a more fragile instance of the
  item above. (2) `cpseries_commlib.lua:406`'s `readData(self,true)` call
  passes an argument `readData` (only takes `self`) always ignores —
  harmless, just misleading. Neither fixed.
