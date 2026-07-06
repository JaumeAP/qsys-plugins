# CLAUDE.md

Guidance for AI assistants working in this repository.

## What this repo is

A collection of **Q-SYS plugins** written in **Lua**. Q-SYS is QSC's audio/video/control
platform; plugins are custom components that run inside Q-SYS Designer / Q-SYS Cores. Most
plugins here control or emulate **Dolby cinema processors** (CP650 / CP750 / CP850 / CP950),
plus a couple of general-purpose utilities.

Plugins in this repo:

| Plugin | Purpose |
| --- | --- |
| **Dolby Fader** | Command component emulating a Dolby CP processor fader (Dolby scale 0.0–10.0 ⇄ dB) |
| **Dolby CP Series Control** | Controls all Dolby CP processors (CP650 → CP950) over TCP |
| **Dolby Sweep** | Log-sweep tone generator (10 Hz → 22 kHz) |
| **Multi Flip-Flop** | Multiple independent flip-flops (set/reset/toggle) in one component, optional exclusive mode |

## There is no build/test tooling — this is an embedded runtime

- Plugins run **inside the Q-SYS Lua sandbox**, not on a normal machine. You cannot execute,
  lint, or unit-test them here. There is no `package.json`, `Makefile`, CI, or test suite.
- The runtime exposes Q-SYS globals that do not exist in stock Lua: `Controls`, `Properties`,
  `Timer`, `TcpSocket`, `System`, `Print`, `Reflect`, and the components you declare
  (e.g. `Step`, `Sine`). Do not assume standard-library behavior beyond core Lua 5.x.
- "Verifying" a change means reasoning about it and, if possible, loading it in Q-SYS Designer's
  emulator — which is not available in this environment. Be careful and explicit about
  behavioral changes since they can't be run here.

## Repository layout

```
.
├── README.md
├── *.qplug                      # RELEASE builds — self-contained, distributable plugins
├── Dolby CPSeries Control V2.2.qplugx   # SIGNED/compiled binary plugin (encrypted, do not edit)
├── Dolby CP Emulator/*.quc      # Q-SYS user components emulating CP650/750/850 (for testing)
├── Developer/
│   ├── plugins/*.qplug          # DEV source — thin loaders that `require` modules
│   ├── plugins/reference.lua    # Template showing every plugin entry point + control type
│   └── Modules/*.lua            # Shared runtime logic, required by the dev plugins
│       └── class/               # git submodule: jonstoler/class.lua (OOP helper)
└── .vscode/settings.json        # associates *.qplug with the Lua language
```

### Two layers: `Developer/` source vs. root release builds

This is the single most important thing to understand about the repo.

- **`Developer/` is the real source.** A dev `.qplug` (e.g. `Developer/plugins/DolbyFader V1.1.qplug`)
  is a *thin loader*: it defines the plugin UI/metadata and ends with a `require "modulename"`.
  The actual runtime behavior lives in `Developer/Modules/*.lua`. During development these modules
  must be placed in the Q-SYS Designer modules folder (`~/Documents/QSC/Q-Sys Designer/Modules/`)
  so `require` can find them.
- **Root-level `*.qplug` are release builds.** They are a single self-contained file with all
  required modules **inlined** (see `DolbyFader.qplug` — after the layout functions it inlines
  `strict.lua`, `class.lua`, `qknob.lua`, and the plugin's own module). This is what ships, because
  end users don't have the separate module files.
- **`.qplugx`** (`Dolby CPSeries Control V2.2.qplugx`) is the **signed/encrypted binary** produced by
  Q-SYS Designer's "Save Plugin" export. It is not human-readable — do not attempt to edit it.
  Regenerate it from the source plugin in Q-SYS Designer.

When you change behavior, edit the module in `Developer/Modules/` (and/or the dev `.qplug`), then the
corresponding change must be **mirrored into the inlined root release build**. Keep both in sync — a
fix only in one layer will not reach users.

## Anatomy of a Q-SYS plugin

Every `.qplug` is a Lua script defining a fixed set of global functions and one global table.
`Developer/plugins/reference.lua` is the canonical template. The pieces:

- `PluginInfo` — table with `Name`, `Version`, `BuildVersion`, `Id` (stable UUID — never change it
  for an existing plugin; it identifies the plugin across versions), `Author`, `Description`,
  optional `Manufacturer`, and optional `Type`. Naming convention for the catalog is
  `"Vendor~Plugin Name"`, e.g. `"Dolby~CP Series Control"`.
- `GetColor(props)` → `{r,g,b}` schematic color.
- `GetPrettyName(props)` → display name (may interpolate a property, e.g. the selected model).
- `GetProperties()` → user-configurable properties (enums, integers with Min/Max, etc.).
- `RectifyProperties(props)` → adjust/hide properties reactively (e.g. hide a debug field unless
  `props.plugin_show_debug.Value` is set).
- `GetComponents(props)` → embedded Q-SYS DSP components the plugin instantiates
  (`gain`, `stepper`, `sine`, `mixer`, `flip_flop`, …). These become globals at runtime
  (a component named `"Step"` is accessed as `Step`).
- `GetControls(props)` → the pins/controls (Button, Knob, Text, Indicator…), with `Count` for
  arrays, `UserPin`/`PinStyle` for external pins.
- `GetControlLayout(props)` → returns `layout, graphics`: positions/sizes/styles of controls plus
  static graphics (GroupBox, Label, Text).

### Two-phase execution and the runtime guard

The same file is evaluated in **two contexts**:

1. **Definition/reflection phase** — Q-SYS calls `GetProperties`/`GetControls`/`GetControlLayout`
   to render the plugin. Here `Reflect` is defined and `Controls` is **not**.
2. **Runtime phase** — the plugin runs on the Core. Here `Controls` (and the declared components)
   are defined.

Plugins gate their runtime logic on this. The two idioms in the repo:

```lua
-- Loader plugins (dev): skip runtime code during reflection, then load the module
if not Controls and Reflect then return end
require "dolbyfader"
```

```lua
-- Self-contained plugins (e.g. Multi Flip-Flop): guard the event logic
if Controls then
  ... -- attach EventHandlers, run init
end
```

Runtime logic = attaching `Control.EventHandler` callbacks and running an init pass at the bottom.

## Key modules (`Developer/Modules/`)

- **`qknob.lua`** — `QKnob` class. Wraps a Text control so it behaves as a knob with synchronized
  `Value` / `String` / `Position`, clamping, decimal formatting, and change polling via a
  `Timer`. Uses property setters via `class.lua`. Override `QKnob:SetString` to append units
  (e.g. Dolby Sweep appends `"s"`).
- **`dolbyfader.lua`** — Dolby Fader logic. Converts the 0–10 Dolby scale ⇄ dB with a piecewise map
  (`convertToDb`/`convertToDolby`), wiring the knob, gain, ref, increase/decrease controls.
  Exposes `DKNob` and the `DolbyFaderEventHandler` hook so CP Series Control can reuse it.
- **`cpseries_class.lua`** — `CPSeries` class: the protocol/state engine. Polls the processor over
  TCP, encodes/decodes CP650/CP750/CP850 command dialects (fader, mute, format/macro, format list),
  and raises `EventHandler(service, result)` callbacks. Contains a `setmeta` helper giving
  "named enum" tables (`Model`, `Actions`, `CP750`) `.index/.key/.value` lookup via metatables.
- **`cpseries.lua`** — glue between `CPSeries` and the plugin controls: opens the `TcpSocket`,
  manages connect/disconnect/reconnect and the status LED, maps protocol events to controls and
  vice-versa. Reuses `dolbyfader` for the fader UI.
- **`dolbysweep.lua`** — log-frequency sweep generator driving the embedded `Sine` component via a
  `Timer`, with period/enable/trigger/mute controls.
- **`strict.lua`** — installs a `_G` metatable that errors on read/write of undeclared globals.
  `Global(...)` whitelists names. Inlined first in release builds so plugin globals must be
  declared with `Global(...)` before use.
- **`class/`** — git submodule `jonstoler/class.lua`, a lightweight OOP/`class()` implementation
  used by `QKnob`. Init with `git submodule update --init` if the directory is empty.

## Conventions to follow

- **Match the surrounding style.** These files use tab/space-mixed indentation and dense
  one-line table definitions in places (especially the CP Series files). Mirror the local style of
  the file you edit rather than reformatting.
- **Never change a plugin's `Id`.** It's the stable identity across versions. Bump `Version` and
  `BuildVersion` when releasing a change.
- **Keep dev source and release build in sync** (see the two-layer note above). Prefer editing the
  module, then re-inlining into the root `.qplug`.
- **Declare globals with `Global(...)`** when adding new top-level names to a release build, or
  `strict.lua` will throw at runtime.
- **Debug output** goes through the custom `Print(show, ...)` (in `cpseries_class.lua`), gated on the
  `plugin_show_debug` property and the `"TCP Log"` enum — not bare `print`. `assert(...)` is used
  liberally to fail fast on protocol invariants.
- **Emulation:** guard hardware-specific behavior with `System.IsEmulating` so the plugin behaves in
  Q-SYS Designer's emulator (see `cpseries.lua`'s address validation). The `Dolby CP Emulator/*.quc`
  components emulate real processors for testing without hardware.

## Git workflow

- Active development branch for this work: **`claude/claude-md-docs-m7fzvp`**. Develop, commit, and
  push there; never push to `main` without explicit permission.
- Do not open a pull request unless explicitly asked.
