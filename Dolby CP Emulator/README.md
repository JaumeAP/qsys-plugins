# Dolby CP Emulator

This folder used to hold three hand-written Q-SYS User Components (`.quc`)
that faked a Dolby cinema processor for bench-testing the "Dolby CPSeries
Control" plugin without hardware — `CP650 Emulator.quc`, `CP750
Emulator.quc`, `CP850 Emulator.quc`, one model each, each covering only a
handful of params, no CP950/CP950A. **Deleted 2026-07-31** (explicit user
request), fully superseded by the plugin below.

## CP Series Emulator — use this instead

The root `CP Series Emulator.qplug` (source: `Developer/plugins/CP Series
Emulator/`) covers **all five** defined models (CP650/CP750/CP850/CP950/
CP950A) from one plugin, modeling the exact wire vocabulary the real plugin
sends and expects (`CPServices` in `Developer/plugins/Dolby CPSeries
Control/commlib.lua`) — the readiness handshake, fader, mute, format/macro
selection (both the CP650 numeric and CP750 keyword dialects, and the
CP850/950/950A macro-preset + macro-name + macro-list burst), and CP650's
raw-echo-before-reply behavior.

It's a normal plugin: add it to a design like any other component, pick the
processor from its **Model** property, and its **Status** indicator shows
whether "Dolby CPSeries Control" (or any TCP client) is currently
connected. Built via PLUGCC.exe the same way as every other plugin in this
repo (`.github/workflows/build-qplug.yml`) and covered by
`Developer/tests/test_dist_cpseriesemulator.lua` (37 checks, part of
`Developer/tests/run.sh`), driven against the actual built `.qplug`.

The macro list (`sys.macros`) and CP750 format keywords it ships with are
illustrative bench-test values, not verified against a real processor —
edit `MACROS`/`CP750_FORMATS` in `Developer/plugins/CP Series
Emulator/protocol.lua` if you need specific values to match a real unit
you're testing against.

(A standalone Control Script version of this plugin also existed briefly,
for pasting directly into Designer with no build step — removed the same
day once the plugin covered the same job with less to maintain; see
`docs/continuity-notes.md` for the full history of both removals.)
