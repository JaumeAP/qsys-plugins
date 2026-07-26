# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of **QSC Q-SYS plugins** written in **Lua**, targeting Dolby
cinema audio processors (CP650 → CP950 series) and general utility components.
Plugins run inside **Q-SYS Designer** on QSC audio DSP cores. There is no build
system, package manager, or CI here — plugins are authored in Lua, tested in
Q-SYS Designer's emulator, and distributed as `.qplug` / `.qplugx` files.

Author/contact history in the sources: `james.puig@dolby.com` / Jaume Puig
(Barcelona).

## Repository layout

```
.
├── README.md                         Short plugin catalog
├── .gitmodules                       Developer/Modules/class → jonstoler/class.lua
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
        ├── class/                    git submodule: jonstoler/class.lua (OOP base)
        ├── qknob.lua                 QKnob class: text control ⇄ value/position/string sync
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

## How a Q-SYS plugin is structured

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

## Q-SYS runtime globals (available to plugin/module code)

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

## Key module patterns

- **`class/class`** (submodule): minimal Lua OOP. `QKnob = class()`,
  `obj = QKnob:new(...)`, `Class:init(...)`. Run `git submodule update --init`
  after cloning or module `require`s will fail.
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

## `.qplug` vs `.qplugx`

- `.qplug` — plaintext Lua source; the editable form.
- `.qplugx` — a **packaged** plugin: a JSON envelope with an encrypted/obfuscated
  `key` + payload produced by Q-SYS Designer's "Save as compiled plugin". Do
  **not** try to hand-edit `.qplugx`; regenerate it from the `.qplug` source in
  Designer.

## Developer workflow

Q-SYS Designer loads dev modules from the user's Modules folder. During local
development plugins prepend it to `package.path` (see `reference.lua`):

```
<USERPROFILE|HOME>/Documents/QSC/Q-Sys Designer/Modules/?.lua
//Mac/Home/Documents/QSC/Q-Sys Designer/Modules/?.lua   -- macOS/Parallels
```

Typical loop:
1. `git submodule update --init` (once) so `class/class` resolves.
2. Symlink/copy `Developer/Modules/*.lua` into the Q-SYS Designer `Modules`
   folder (or develop with the `package.path` prelude).
3. Edit the `.qplug` in `Developer/plugins/` and its module in
   `Developer/Modules/`.
4. Load the plugin in Q-SYS Designer; test in the emulator
   (`System.IsEmulating` is true) or against a `Dolby CP Emulator/*.quc` on the
   bench.
5. Bump `Version`/`BuildVersion` in `PluginInfo`, export the compiled
   `.qplug`/`.qplugx`, and update the root-level distributable copy.

## Conventions when editing

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

## Git

- AI-assisted changes land on a task-specific `claude/...` branch (named per
  session/PR); there is no single long-lived AI branch to target.
- The repo uses one submodule (`Developer/Modules/class`). Commit submodule
  pointer changes deliberately; don't bump it incidentally.
