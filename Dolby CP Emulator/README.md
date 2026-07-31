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

`Developer/cp-series-emulator/cp-series-emulator.lua` (source of truth,
edited as plain text) is a from-scratch replacement covering **all five**
defined models (CP650/CP750/CP850/CP950/CP950A) from one script, modeling
the exact wire vocabulary the real plugin sends and expects (`CPServices` in
`Developer/plugins/Dolby CPSeries Control/commlib.lua`) — the readiness
handshake, fader, mute, format/macro selection (both the CP650 numeric and
CP750 keyword dialects, and the CP850/950/950A macro-preset + macro-name +
macro-list burst), and CP650's raw-echo-before-reply behavior. It is
exercised against the plugin's own real `CPSeries`/`CPModels`/`CPProtocol`
classes — not a separate, possibly-diverging idea of the protocol — by
`Developer/tests/test_cp_series_emulator.lua` (55 checks, part of
`Developer/tests/run.sh`).

**This repo cannot produce a `.quc` file directly** — it's a serialized
.NET object Q-SYS Designer writes, not a text format, and no generator for
it exists outside Designer itself. To actually use CP Series Emulator on
the bench:

1. In Q-SYS Designer, add a new **Control Script** component to a design.
2. Open its code editor and paste in the full contents of
   `Developer/cp-series-emulator/cp-series-emulator.lua`.
3. Edit the `local MODEL = 'CP750'` line near the top to the processor you
   want to emulate (`CP650` / `CP750` / `CP850` / `CP950` / `CP950A`) — one
   instance per model, same convention as the three `.quc` files above.
4. Save the component. If you want it to persist as a standalone `.quc`
   file (to check into this folder, matching the other three), use
   Designer's own "Save Control Script as..." / export flow and drop the
   result here as `CP<model> Emulator.quc`.

The macro list (`sys.macros`) and CP750 format keywords the script ships
with are illustrative bench-test values, not verified against a real
processor — edit `MACROS`/`CP750_FORMATS` in the script if you need
specific values to match a real unit you're testing against.
