# What the other two repositories know, for these plugins

Written 2026-10-24 (explicit user request: bring what `JaumeAP/CPSeries` and
`JaumeAP/Q-Sys` hold into the Dolby plugins). Only what bears on the plugins
is here; the full detail stays in those repositories.

## JaumeAP/CPSeries (the Dolby CP650-CP950A toolkit)

Python, Lua and C++ code for the live control channel, plus the `.dac`
parser and the equalizer model. Ground truth for parameter and protocol
behaviour is `docs/specs/` there (the Cinema Control spec, split by section).

1. Models and wire config (`cpx50.comms.models`):

   | Model | Port | Dialect | Documented max connections |
   |---|---|---|---|
   | CP650 | 61412 | `KEY=VALUE` | 1 |
   | CP750 | 61408 | `param value`, `cp750.*` | 20 |
   | CP850, CP950, CP950A | 61408 | `param value`, `sys.*` | 20 |

   The connection limits and the CP950A "SOAP 2.0" label are unverified
   against hardware. Port 61408 and the `sys.*` format are confirmed by the
   CP950/CP950A manual (Issue 9, section 10.2, Table 18).
2. Framing. `sys.*` models query with `param ?` (confirmed by the manual).
   For the CP650 the toolkit uses `KEY?`, its own unverified convention. This
   plugin family uses `KEY=?` and calls it Dolby-verified, so `KEY=?` stays
   here. The toolkit's simulators did not understand `KEY=?` (checked 2026-10-24:
   the C++ one echoed `MASTER=?` and never answered); fixed the same day in
   `JaumeAP/CPSeries` PR 57, they now accept both framings.
3. The CP650 echoes the raw command line before its real response.
4. Number text. Whole floats print as integers with every digit
   (`70.0` -> `70`, `1e20` -> `100000000000000000000`); other floats print as
   the shortest string that round-trips (`0.1`, `1e-05`). The shortest string
   is not always the correctly rounded one: `2^-24` is
   `5.960464477539063e-08`. `Dolby CPSeries Control`'s `CPProtocol.FormatValue`
   follows this since 4.0.0.13.
5. The toolkit rejects a non-ASCII byte or an embedded CR/LF in a param or
   value. Only the CR/LF rule is kept here: Q-SYS sockets are byte-clean, and
   a macro name with an accent must still reach the wire.
6. CP750 key parameter ranges (dB, ms, Hz). The processor clips a SET to them
   silently. `ch_level_*` and `eq_*` are wildcard families.

   | Parameter | Range |
   |---|---|
   | `cp750.sys.master_level` | 0 to 96 |
   | `cp750.sys.ch_level_*` | -96 to 12 |
   | `cp750.sys.mute` | 0 to 1 |
   | `cp750.sys.surround_delay` | 0 to 150 |
   | `cp750.sys.subwoofer_filter` | 50 to 100 |
   | `cp750.sys.eq_*` | -60 to 60 |
   | `cp750.sys.mute_fade_out_time` | 200 to 5000 |

   In the plugin: `CPModels.CP750_PARAM_RANGES`, `RangeOf`, `ValidateRange`,
   `ClipToRange`; the emulator carries its own copy.
7. Evidence tiers. Decoded and derived values there are tagged by confidence,
   from byte-pinned fields down to Tier D (inferred names). Do not treat a
   Tier 2 claim as hardware-verified.
8. Simulators. `cpp/processor_sim.cpp` (C++17, Linux and macOS) is the full
   fake processor: both dialects, the CP650 echo, range clipping, and the
   options `--latency`, `--drop-after`, `--silent`, `--partial-response`,
   `--no-clip`, `--seed`, `--seed-list` (multi-line replies such as
   `sys.macros`), `--profile` (seeds everything Dolby CPSeries Control polls),
   `--serial`, `--fd`, `--log` (timestamped trace), `--control` (stdin
   commands), and SIGUSR1 to drop connections. `lua/sim_server.lua` takes the
   same options, except `--serial` and `--fd`. The `CP Series Emulator` plugin takes its behaviour
   from them (v1.0.0.3): any param is stored and read back, CP750 SETs clip,
   numbers are stored canonically, the CP650 answers `KEY=?` and `KEY?`.
   What it does not do: fault injection, a connection limit, the `--serial`
   transport. Fader, mute, format and macros keep their special handling.

## JaumeAP/Q-Sys (Q-SYS work monorepo)

1. `packages/CP850-QSys`: a Q-SYS Designer design (`.qsys`) that imitates the
   CP850/CP950 equalizer with native components, in four modules (arrays,
   crossover and bass mixer, FIR, profile). Its oracle is `EqualizerApplication`
   in `JaumeAP/CPSeries` (`docs/equalizer-signal-chain.md`). The `.dac` file
   decides channel names, counts, crossovers and gains; nothing is fixed to
   one installation.
2. `packages/Q-Sys-CP850-eq-emulator-`: the older equalizer-emulation plugin
   (`CP850EQ.qplug`) and its build and test scripts.
3. `docs/phenomena-*.md`: installation notes for one cinema in Barcelona. The
   CP850 sends eight AES67 streams of eight channels; the Q-SYS design
   subscribes to the first five (forty channels) through `AtmosReceiver`
   components into a 38-channel gain. Also Atmos headroom after the -27 dBFS
   reference change, and DTS player levels and calibration. Specific to that
   installation, not general rules.
4. `packages/Eines` and `packages/CPSeries` are submodules of the repositories
   of those names.

## What changed in the plugins because of this

1. `Dolby CPSeries Control` 4.0.0.13: float formatting, CP750 ranges,
   connection limits. Wire framing unchanged.
2. `CP Series Emulator` 1.0.0.3: generic stateful params, clipping, both CP650
   query framings.
3. Tests: `Developer/tests/test_modules.lua` (formatting, ranges) and
   `Developer/tests/test_emulator_source.lua` (the emulator source, not the
   built file).
4. The root `.qplug` files are not rebuilt. Dispatch the build workflow for
   both plugins; until then `test_dist_*` still run the previous builds.
