---
paths:
  - "Developer/plugins/**"
  - "Developer/shared/**"
  - "*.qplug"
  - "*.qplugx"
  - ".github/workflows/build-qplug*.yml"
---

<!-- Split out of CLAUDE.md 2026-07-30 (explicit user request, following the
official path-scoped-rules mechanism at code.claude.com/docs/en/memory) to
keep the main CLAUDE.md under the ~200-line guidance and load this technical
reference only when Claude is actually touching plugin source or a build. -->

<!-- Cross-references in this file that say "above"/"below" may now point at
a sibling file after the 2026-07-30 split: CLAUDE.md (operative rules),
.claude/rules/repo-layout.md (directory tree),
.claude/rules/qsys-plugin-development.md (plugin/build reference), or
docs/continuity-notes.md (dated history). -->

### PLUGCC.exe `#include` resolution rules

**PLUGCC.exe `#include` resolution rules (confirmed by trial, 2026-07-29;
see the Continuity notes below for the full story):** (1) a relative
`#include` path always resolves against the *original* `plugin.lua`'s own
directory (the process cwd `PLUGCC.exe` is invoked from), never against
whichever file's own text contains the directive. (2) A NESTED `#include`
(one inside a file that itself got pulled in by another `#include`, as
opposed to one written directly in `plugin.lua`) is only recognized if it is
that file's first line. `Developer/shared/dolbyfader.lua`'s own `#include`
of `qknob.lua` and `Dolby Sweep/runtime.lua`'s own `#include` of
`shared/qknob.lua` both satisfy this; `Dolby CPSeries Control/plugin.lua`
avoids the question entirely by `#include`ing everything it needs directly
(all depth-1), since only `plugin.lua`'s own includes can appear anywhere in
the file with no first-line restriction.

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

Runtime side (current, since the 2026-07-29 PLUGCC.exe restructuring): a
guard at the bottom of `plugin.lua`, then one or more `#include`s:

```lua
if Controls then
	--[[ #include "runtime.lua" ]]
end
```

When Q-SYS runs the component, the global `Controls` table (and `Properties`)
exist, so execution falls through the guard and PLUGCC.exe has already
inlined the `#include`d file(s) at build time — nothing loads at runtime the
way `require` used to. All four plugins now use this same `if Controls
then ... end` guard style uniformly (before the restructuring, three of
the four used `if not Controls and Reflect then return end` plus a
`require "<module>"`, loading from the now-removed `Developer/Modules/`;
`MultiFlip-Flop` was always the `if Controls then` exception, and the other
three were switched to match it as part of the same restructuring).

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
"Repository layout" in `CLAUDE.md`) specifically to check that spec against
the real thing without re-deriving it from web search summaries: QSC's own
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
- **Breaking changes get a major version bump** (standard semver
  practice; no dedicated changelog skill governs this repo's own files
  any more, see `CLAUDE.md`'s "Portable skills" section), noted in the
  file header's version-history
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

All four plugins are built with QSC's own `PLUGCC.exe`
(`vendor/qsys-plugins/{BasePlugin,ExamplePlugin}/PluginCompile/PLUGCC.exe`, a
Windows binary), not a script in this repo — this repo's own
`build_distributable.sh` / `Developer/Modules/` convention was retired
2026-07-29 once all four plugins were restructured onto PLUGCC (see the
Continuity notes in `CLAUDE.md` for the migration history).

Typical loop:
1. Edit the plugin's own files under `Developer/plugins/<Name>/`
   (`plugin.lua` and its `#include`d siblings), or a shared file under
   `Developer/shared/` if the change affects more than one plugin.
2. Run `Developer/tests/run.sh`. Fast, catches syntax errors and logic
   regressions without leaving the terminal, but it only runs against the
   already-built root `.qplug` for the runtime-pass checks — it can't catch
   a PLUGCC `#include` resolution mistake, only step 4 does that.
3. Bump `BuildVersion` (and `Version` if it's a breaking change) in the
   plugin's own `info.lua`, and in `plugin.lua`'s own header-comment version
   history.
4. Dispatch `.github/workflows/build-qplug.yml` (`workflow_dispatch`, pick
   the plugin) — `windows-latest`, runs PLUGCC.exe, uploads the built
   `.qplug` as a workflow artifact AND echoes it in full to the job log
   (`get_job_logs`/`actions_get` with `download_workflow_run_artifact` —
   the artifact's own blob-storage download URL is blocked by this
   session's egress proxy, but the GitHub API job log isn't). Read the log
   back, check it's what you expect (no literal, unexpanded `--[[ #include
   ... ]]` comment left in the output — that means the nested-include
   first-line rule above was violated), and write it to the root `.qplug`
   — never hand-edit the root file directly, it gets silently discarded on
   the next rebuild.
5. Re-run `Developer/tests/run.sh` against the newly-written root file —
   this is the step that actually exercises the runtime pass end to end.
6. Load the plugin in Q-SYS Designer; test in the emulator
   (`System.IsEmulating` is true) or against a `Dolby CP Emulator/*.quc` on
   the bench. Steps 2-5 are a filter, not a substitute for this step.
7. If a `.qplugx` also needs updating, dispatch
   `.github/workflows/build-qplugx.yml` (`all` or a single plugin) the same
   way — same job-log-echo workaround, same "never hand-edit" rule.

### Conventions when editing

- **Preserve `PluginInfo.Id`** — it is the stable plugin UUID; changing it makes
  Designer treat the plugin as a different one. Bump `Version`/`BuildVersion`
  instead.
- Follow the "Plugin structure/naming convention" section above.
- Keep a plugin's own runtime logic in its `Developer/plugins/<Name>/` folder
  (`runtime.lua`, or inline in `plugin.lua`'s own `if Controls then` block for
  MultiFlip-Flop/CPSeries-style short chains); code shared by more than one
  plugin goes in `Developer/shared/` instead of being duplicated per plugin.
- Guard runtime code with `if Controls then ... end` so the definition pass
  never executes event logic — the sole exception is dead code, not a live
  convention choice: none of the four plugins here use the older `if not
  Controls and Reflect then return end` style any more.
- Comments and identifiers are English; keep it that way.
- After changing a shared file (`Developer/shared/*.lua`) or a plugin's own
  private files, verify every plugin that `#include`s it gets its root
  `.qplug` regenerated (it is easy to leave one stale) — check which
  plugins reference the changed file before assuming only one needs a
  rebuild.
