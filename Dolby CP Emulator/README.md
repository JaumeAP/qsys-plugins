# Dolby CP Emulator

Q-SYS User Components (`.quc`) that fake a real Dolby cinema processor for
bench-testing the "Dolby CPSeries Control" plugin without hardware. Drop one
into a Q-SYS design, wire the plugin to `127.0.0.1:<port>`, and it answers
like the real thing.

## The three existing `.quc` files

`CP650 Emulator.quc`, `CP750 Emulator.quc`, `CP850 Emulator.quc` — one
model each, hand-written, each covering only the handful of params it was
built to exercise at the time (fader/mute/format, no `sysinfo.version`-style
extras). **No CP950 / CP950A emulator exists in this format** — those two
models were added to the plugin later (v3.0) and never got a `.quc`
counterpart.

## CP Series Emulator — the newer, complete alternative

The root `CP Series Emulator.qplug` (source: `Developer/plugins/CP Series
Emulator/`) is a from-scratch replacement covering **all five** defined
models (CP650/CP750/CP850/CP950/CP950A) from one plugin, modeling the exact
wire vocabulary the real plugin sends and expects (`CPServices` in
`Developer/plugins/Dolby CPSeries Control/commlib.lua`) — the readiness
handshake, fader, mute, format/macro selection (both the CP650 numeric and
CP750 keyword dialects, and the CP850/950/950A macro-preset + macro-name +
macro-list burst), and CP650's raw-echo-before-reply behavior.

Unlike the three `.quc` files above, it's a normal plugin: add it to a
design like any other component, pick the processor from its **Model**
property, and its **Status** indicator shows whether "Dolby CPSeries
Control" (or any TCP client) is currently connected. No copy-pasting into a
Control Script, no per-model file. Built via PLUGCC.exe the same way as
every other plugin in this repo (`.github/workflows/build-qplug.yml`) and
covered by `Developer/tests/test_dist_cpseriesemulator.lua` (37 checks,
part of `Developer/tests/run.sh`), driven against the actual built
`.qplug`.

The macro list (`sys.macros`) and CP750 format keywords it ships with are
illustrative bench-test values, not verified against a real processor —
edit `MACROS`/`CP750_FORMATS` in `Developer/plugins/CP Series
Emulator/protocol.lua` if you need specific values to match a real unit
you're testing against.

(A standalone Control Script version of this existed briefly, for pasting
directly into Designer with no build step — removed 2026-07-31 once this
plugin covered the same job with less to maintain; see
`docs/continuity-notes.md` if you're looking for it in history.)
