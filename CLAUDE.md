# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains **Q-Sys plugins** — Lua-based control components for the QSC Q-Sys networked audio platform. Plugins control external hardware (Dolby cinema processors) and provide utility components (fader emulation, sweep tone generator, flip-flop logic) within a Q-Sys design.

There is no build system, no package manager, and no automated test runner. Development and compilation is performed inside **Q-Sys Designer** (the proprietary QSC IDE). The `.qplug` source files are plain Lua loaded by Q-Sys at design time; `.qplugx` files are compiled plugin binaries.

## Repository Layout

```
Developer/plugins/       # Editable plugin source files (.qplug)
Developer/Modules/       # Shared Lua modules loaded via require()
Developer/Modules/class/ # Git submodule: jonstoler/class.lua (OOP base)
Dolby CP Emulator/       # Q-Sys emulator files (.quc) for CP650/CP750/CP850
*.qplug / *.qplugx       # Compiled/distributable plugin artifacts at root
```

Modules are installed at runtime by placing them in:
`~/Documents/QSC/Q-Sys Designer/Modules/` (Windows/macOS)

The `reference.lua` file sets up `package.path` to point there for local testing.

## Plugin File Structure

Every `.qplug` file is a Lua script that Q-Sys Designer executes in two phases:

**Design-time phase** — Q-Sys calls these global functions to build the UI:
- `PluginInfo` — name, version, GUID, description
- `GetColor(props)` — component color as `{R,G,B}`
- `GetPrettyName(props)` — display name (can be dynamic based on props)
- `GetProperties()` — list of user-configurable properties (`enum`, `integer`, `string`)
- `RectifyProperties(props)` — validate/hide/adjust properties before use
- `GetComponents(props)` — embedded Q-Sys sub-components (`stepper`, `sine`, `mixer`, etc.)
- `GetControls(props)` — list of exposed controls (`Button`, `Knob`, `Text`, `Indicator`)
- `GetControlLayout(props)` — returns `layout, graphics` tables defining positions/sizes/styles

**Runtime phase** — the script block (typically wrapped in `do...end`) runs on the Q-Sys core:
- Runs only when `Controls` is available (not nil at design time)
- Guard pattern: `if not Controls and Reflect then return end`
- Initializes event handlers on `Controls.*`, `sock`, and timers

## Key Modules

### `cpseries_class.lua` — CPSeries TCP Protocol Class
The core of the Dolby CP processor control. A manual OOP class (not using `class.lua`):
- `CPSeries.New(model)` — creates an instance; model is a `Model.*` constant
- `CPSeries:Start(sock)` — attaches a connected `TcpSocket`, starts 20ms poll timer
- `CPSeries:Stop()` — stops the poll timer
- `CPSeries:Action(control, value)` — sends a command: `"fader"`, `"mute"`, `"format"`, `"formname"`, `"reset"`
- `CPSeries.EventHandler(service, result)` — callback fired on state changes: `"ready"`, `"close"`, `"fader"`, `"mute"`, `"format"`, `"formname"`, `"formlist"`, `"reset"`

TCP ports: CP650 → 61412, CP750/CP850 → 61408.

The `CPServices` table maps action types to the protocol strings for each model. `setmeta()` enables named field access (`.index`, `.key`, `.value`) on ordered tables of single-key records — this is a local pattern used instead of a separate struct type.

### `cpseries.lua` — CPSeries Plugin Runtime Script
Wires the CPSeries class to Q-Sys controls. Included from `Dolby CPSeries Control V2.2.qplug` via `require "CPSeries"`. Manages TCP reconnection, status LED, address validation, and translates Q-Sys control events ↔ CPSeries actions.

### `dolbyfader.lua` — Dolby Fader Module
Creates a `QKnob` instance named `DKNob` (range 0–10) representing the Dolby level. Provides bidirectional conversion:
- `convertToDb(val)`: Dolby 0–10 → dB (piecewise: ≤4 maps to −90–−10 dB; >4 maps to −10–20 dB)
- `convertToDolby(dB)`: inverse mapping

Fires `DolbyFaderEventHandler(ctrl)` (a global hook) when the fader changes, allowing the CPSeries plugin to forward it to the hardware.

### `qknob.lua` — QKnob Class
Wraps a Q-Sys `Text` control into a knob with synchronized `Value` / `Position` / `String` properties. Uses `class.lua` (`require("class/class")`). Key behaviors:
- `QKnob:new(ctlName, Min, Max, numDecs)` — control name must be of type `"Text"` in `GetControls`
- `Value`, `Position`, `String` setters keep each other in sync (uses a `nested` guard to prevent recursion)
- Override `QKnob:SetString(val)` to customize the string representation (e.g., `dolbysweep.lua` appends `'s'`)
- A 1ms timer polls `ctrl.Position` for hardware-driven changes (knob turned from external source)

### `dolbysweep.lua` — Sweep Tone Generator
Logarithmic frequency sweep from 10 Hz to 22 kHz over a configurable period (1–8 seconds). Uses a `Sine` sub-component. The sweep step formula: `freq = 10 * 2^(step * OCTAVE / numloops)`.

### `strict.lua` — Strict Variable Mode
Sets `__newindex` on `_G` to error on undeclared globals. Include at the top of a script during development to catch typos. Do not ship in production without understanding which globals Q-Sys itself injects (`Controls`, `Properties`, `Timer`, `TcpSocket`, `System`, etc.).

## The `setmeta()` Pattern

Both `cpseries_class.lua` and `Dolby CPSeries Control V2.2.qplug` define a `setmeta(table)` helper that applies a metatable to a table of single-key records, enabling access by key name, positional index, or `.value`. For example:

```lua
Model = { {CP650='CP 650'}, {CP750='CP 750'}, {CP850='CP 850'} }
setmeta(Model)
-- Model.CP850.value  → 'CP 850'
-- Model.CP850.index  → 3
-- Model.CP850.key    → 'CP850'
```

This pattern is the main data-access idiom for `Model`, `Actions`, and `CP750` input lists.

## Model Constants

```lua
Model = { {CP650='CP 650'}, {CP750='CP 750'}, {CP850='CP 850'} }
```

Always use `Model.CP650`, `Model.CP750`, `Model.CP850` — never hardcode index numbers directly, as `setmeta` makes named access safe and self-documenting.

## Testing with Emulators

The `Dolby CP Emulator/` directory contains `.quc` (Q-Sys UCI) files that emulate CP650, CP750, and CP850 responses over TCP. Load these in Q-Sys Emulation mode to test the CPSeries plugin without physical hardware. When `System.IsEmulating` is true, the plugin accepts invalid IP addresses gracefully (sets status to "Emulation").

## Debugging

The CPSeries Control plugin has a `plugin_show_debug` property and a `TCP Log` property (`Command` or `All`). The `Print(show, ...)` local function gates output based on these:
- `show=true` → logs TX (commands sent)
- `show=false` → logs RX (responses received)  
- `show=nil` → logs only unexpected/changed RX data

Debug print statements in the source are commented with `-- *** FOR DEBUG ONLY ***` and can be uncommented to trace the poll/receive cycle.
