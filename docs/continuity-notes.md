# Continuity notes

<!-- Split out of CLAUDE.md 2026-07-30 (explicit user request) to bring the
main memory file under the ~200-line guidance. This is chronological
institutional memory, not per-session rules: it is NOT auto-loaded. Read it
when you need the history behind a decision, or before re-deriving something
that looks already-settled. Append new dated entries here, not to CLAUDE.md. -->

<!-- Cross-references in this file that say "above"/"below" may now point at
a sibling file after the 2026-07-30 split: CLAUDE.md (operative rules),
.claude/rules/repo-layout.md (directory tree),
.claude/rules/qsys-plugin-development.md (plugin/build reference), or
docs/continuity-notes.md (dated history). -->

(History of where this section lives. Moved back into CLAUDE.md 2026-07-27
from a short-lived `HANDOFF.md` split, on the reasoning that a separate file
isn't auto-loaded at session start the way CLAUDE.md is — `HANDOFF.md`
deleted. Split back out again 2026-07-30, explicit user request, with that
tradeoff accepted deliberately rather than overlooked: 546 lines of dated
history loading unconditionally every session is the larger cost, and the
pointer in CLAUDE.md plus this file's own name make it findable when the
history actually matters.)

- **`qsys_stub.lua`'s `Timer.CallAfter` silently swallowed errors, fixed
  (2026-07-29):** was `function(fn) pcall(fn) end` with the `pcall` result
  never checked, so any exception thrown inside a callback scheduled via
  `Timer.CallAfter` (real usage: CPSeries's `connect`/`refreshCNX` retry
  chain, Dolby Sweep's `Start`) vanished silently instead of failing the
  test that triggered it. Now `function(fn) fn() end` -- errors propagate
  like a direct call would, same as a real host wouldn't eat a plugin's
  exception either. No test currently throws through this path, so nothing
  newly failed; `Developer/tests/run.sh` stays green, 152 checks unchanged.
  Separately noted, not fixed (a test-coverage gap, not a stub-modeling
  one -- the stub already supports it structurally): `sock.Closed`/
  `.Timeout`/`.Error`/`.Reconnect` are real socket lifecycle handlers
  `Dolby CPSeries Control/runtime.lua` wires up, but no test file ever
  calls them (only `wire_trace.lua` calls `sock.Connected()`) -- a test
  could invoke any of them today the same way, nothing in the stub blocks
  it, they just aren't exercised yet.
- **`qsys_stub.lua`'s Trigger/Meter control-type gap, fixed (2026-07-29,
  explicit user request — implemented, not just documented).** `M.control`
  now takes an optional `kind` ("trigger", "meter", or the default): a
  Trigger-type Button gets no `.Value`/`.String`/`.Position`/`.Boolean` at
  all (only `:Trigger()`/`.EventHandler`), matching Q-SYS Help's Controls IO
  page; a Meter-type Indicator gets `.Values` (plural) instead of `.Value`.
  `M.install(opts)` grew `opts.trigger_controls` (a name list) to construct
  the right controls as trigger-kind. Every genuine Trigger control across
  the three affected test files is now marked: MultiFlip-Flop's
  `Set_N`/`Reset_N`/`Toggle_N`, CPSeries's `Refresh`, Dolby Sweep's
  `Trigger`. `test_dist_flipflop.lua`'s old blanket
  `for _, c in pairs(env.controls) do c.Trigger = function() end end` (added
  `:Trigger()` to every control regardless of type) is gone, replaced by the
  properly-typed construction. Verified directly: `qsys.control(nil,
  "trigger").Value` is now `nil`, `qsys.control(nil, "meter").Values` is a
  table. No plugin currently reads `.Value`/`.Boolean` on a Trigger control
  or uses `.Values`, so this changed no test outcomes — full
  `Developer/tests/run.sh` still green, all 152 checks unchanged.
- **`qsys_stub.lua` split into its own `Developer/host-emulator/` module
  (2026-07-29, explicit user request).** Previously lived in
  `Developer/tests/`, alongside `harness.lua` and the `test_*.lua` files
  that use it. Moved out on its own so it reads as a standalone unit — the
  Q-SYS Designer host stub — distinct from `Dolby CP Emulator/`, which
  emulates the Dolby processors themselves, a different target entirely.
  `harness.lua` stayed in `Developer/tests/`: it's test-runner plumbing
  (path resolution, the check counter), not part of the emulator. Every
  `test_*.lua`/`wire_trace.lua` file's `package.path` line now adds
  `Developer/host-emulator/` alongside its own directory
  (`test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;"`) so
  `require("qsys_stub")` still resolves; `require("harness")` is
  unaffected, it never moved. `Developer/tests/README.md` updated to
  match. `PLUGIN_GLOBALS` inside `qsys_stub.lua` was also fixed the same
  session (see git history) — a real, pre-existing gap: `Dolby Sweep`'s
  `period`/`timer` and `Dolby CPSeries Control`'s `DolbyCP`/`sock` globals
  were never in the list, so `M.clear()` never reset them between test
  runs.
- **GetComponents/GetPins/GetWiring gained test coverage, previously zero
  (2026-07-29, explicit user request).** Before this, no test file in this
  repo called any of the three definition-pass functions that build a
  plugin's audio path -- a component rename in `GetComponents` that
  `GetWiring`'s own string literals were never updated to match would
  compile fine (`luac -p` sees a table literal, not a mismatch) and every
  existing test would still pass, since none of them ever looked. Added
  `M.check_wiring(comps, pins, wiring)` (moved to `qsys_stub.lua` the same
  day -- see the follow-up note right after this one): validates that
  every `GetComponents` entry has `Name`/`Type`, every `GetPins` entry has
  a valid `Direction`, and every `GetWiring` endpoint resolves to either a
  declared plugin pin or `"<ComponentName> <PinName>"` for a declared
  component -- Q-SYS's own convention, confirmed against a real
  `GetWiring` example (`"main_mixer Input 1"`/`"main_mixer Output 1"`,
  gdyr/qsys-plugin-docs) since Q-SYS Help itself 403'd both mirrors this
  session (transient, same as noted elsewhere in this file). Verified the
  check actually catches a break, not just a vacuous pass: corrupted a
  copy of the built `SubharmonicSynth.qplug`'s own wiring string and
  confirmed the new check fails with the exact bad endpoint named, then
  discarded the copy. Wired into the definition pass of every
  `test_dist_*.lua` that has an audio path (`sweep`, `subharmonic`, each
  across every dynamic pin-count case sweep's own `Type` property
  produces) and, for the two control-only plugins (`fader`, `cpseries`),
  an explicit assertion that `GetPins`/`GetWiring` are correctly absent
  rather than silently unchecked. `MultiFlip-Flop` has none of the three
  and needs no addition. Confirmed independently and specifically: the
  Sine Generator component exposes a single unnumbered `"Output"` pin
  (matches Dolby Sweep's pre-existing `"Sine Output"` wiring exactly);
  `gain`/`filter_lowpass`/`equalizer_parametric` were not independently
  re-confirmed against an official source this session (inherited
  unverified from the external SubharmonicSynth contribution, consistent
  with the mixer convention above but not separately proven) -- if this
  ever needs settling, `vendor/qsc-q-sys` likely has it, but that
  submodule is still uninitialized in this session (see its own item
  below) and wasn't added for this, since the user didn't ask for that
  specifically. Also fixed a real gap surfaced while adding this:
  `qsys_stub.lua`'s `PLUGIN_GLOBALS` never included `GetPins`/`GetWiring`/
  `GetPages`, so `M.clear()` never reset them between plugins -- harmless
  until a test loads two full distributables in one process AND calls
  either function across that boundary (`test_stress.lua` does the
  former for its runtime checks, not yet the latter), fixed the same way
  the `period`/`timer`/`DolbyCP`/`sock` gap was fixed earlier this
  session. Suite total: 224 -> 245 checks, all green.
- **`check_wiring` relocated from `harness.lua` to `qsys_stub.lua`, same day
  (2026-07-29, explicit user request).** First written into `harness.lua`
  alongside `M.check`/`M.section`, which was a category mistake caught
  after the fact: `harness.lua`'s own charter (see the host-emulator split
  note below) is test-runner plumbing -- path resolution, the check
  counter -- explicitly NOT anything about Q-SYS itself, while
  `check_wiring` encodes a real piece of Q-SYS platform behavior (how a
  `GetWiring` endpoint string resolves to a pin), the same category as the
  Trigger/Meter split or the `.Value`/`.Boolean` split the stub already
  owns. Moved with its doc comment; call sites in `test_dist_sweep.lua`
  and `test_dist_subharmonic.lua` updated from `h.check_wiring` to
  `qsys.check_wiring`. No behavior change -- `Developer/tests/run.sh`
  stays at 245 checks, all green.
- **`Developer/host-emulator/components/` added: one file per Q-SYS
  component Type, exact pin lists instead of prefix matching (2026-07-29,
  explicit user request, same day as the relocation above).** Before this,
  `check_wiring` only checked that a wiring endpoint's component-name
  prefix matched a declared `GetComponents` entry -- `"Mix Output 2"`
  passed even though `Mix` is declared `n_outputs = 1` and has no such
  pin. New per-Type files (`mixer.lua`, `sine.lua`, `gain.lua`,
  `filter_lowpass.lua`, `equalizer_parametric.lua`, `stepper.lua`), each
  `return function(props) ... end` returning the exact pin-name list for
  that Type given its own `Properties`. `qsys_stub.lua` resolves its own
  directory via `debug.getinfo(1, "S").source` (not `arg[0]` -- this file
  is always `require()`'d, never the top-level chunk -- and not
  `package.path`, so callers that never touch wiring never need to extend
  their own path for it) and `loadfile`s the matching component file
  lazily, cached, the first time a `Type` is looked up. An unregistered
  `Type` returns `nil` and `check_wiring` falls back to its original
  prefix-only check for that component -- an unmodeled Type is a gap to
  fill, not a reason to fail every plugin using it. Verified the
  stricter check actually bites: took a copy of `SubharmonicSynth.qplug`,
  changed its own `GetWiring`'s `"Mix Output 1"` to `"Mix Output 2"`
  (invalid for a 1-output mixer), and confirmed the new per-Type check
  fails with that exact endpoint named where the old prefix-only version
  passed it -- then discarded the copy. Confirmation status carried
  per file, not asserted uniformly: `mixer.lua` and `sine.lua` are
  independently confirmed (see the relocation note above for `mixer`;
  `sine.lua` from a Q-SYS Help search summary matching Dolby Sweep's own
  pre-existing wiring); `gain.lua`/`filter_lowpass.lua`/
  `equalizer_parametric.lua` are NOT independently confirmed (Q-SYS Help
  403'd both mirrors this session) and say so in their own header comment
  -- they mirror the numbered-pin convention and match what
  SubharmonicSynth already ships, but are marked as the thing to
  re-verify first if a real host ever disagrees, not settled fact.
  `stepper.lua` returns no pins, confirmed by absence (DolbyFader/CPSeries
  both use it with no `GetPins`/`GetWiring` at all). No behavior change to
  the checks that were already exact-verifiable; `run.sh` stays at 245.
- **Stress/fuzz suite added, covering all five plugins (2026-07-29,
  explicit user request).** `Developer/tests/test_stress.lua`, registered
  in `run.sh`, 49 checks, runs in well under a second. Deliberately a
  different kind of test from the rest of the suite: the `test_dist_*`
  files assert exact values for known-good inputs, this one asserts only
  the invariants that must survive abuse — nothing throws, nothing
  publishes a nil, and every value a plugin writes stays inside its
  declared range. Sections: CP Series wire fuzzing across all five models
  (267 junk lines per model, three passes, one-at-a-time and bulk-drained
  through `readData`), sustained polling driven 9000 ticks to cross the
  `npoll % 0x2000` wraparound, the no-data watchdog's own close path,
  Dolby Fader driven well past both ends of its dB range plus junk typed
  into the `Level` text control and out-of-band stepper positions, Dolby
  Sweep run 3000 ticks with mid-sweep control chatter, SubharmonicSynth
  given 1500 rounds of out-of-range parameters, and MultiFlip-Flop at
  InputCount=8 under 4000 random operations. Two design points worth
  keeping if it's ever extended: `math.randomseed` is a fixed constant, so
  a failure reproduces instead of vanishing on the next run; and several
  sections carry an explicit anti-vacuity check. That second one is not
  theoretical — the first working version of the corpus passed every CP
  650 and CP 750 invariant while those two models silently rejected every
  line before it reached their own fader/format handlers (their dialects
  are `fader_level=` and `cp750.sys.*`, and the corpus was all `sys.*`).
  Measured with a throwaway probe, then fixed by adding per-dialect
  parseable-but-extreme lines and a permanent "the corpus actually reached
  the parser" check per model. The same reasoning added "the storm did run
  while bypassed" (SubharmonicSynth) and "multiple simultaneous instances
  are reachable with Exclusive off" (MultiFlip-Flop) — without the latter,
  the interlock invariant would also hold for a component that simply
  never lets two instances be set at all. No plugin bug was found by any
  of this; the guards in `commlib.lua` (documented in its own v3.0 header)
  already cover what the fuzzing throws at them. `Developer/tests/README.md`
  gained a "Stress and fuzz" section, and its Layout table was corrected
  at the same time — it still listed the retired `test_plugin_defs.lua`
  and pointed `test_modules.lua` at the deleted `Developer/Modules`.
- **SubharmonicSynth incorporated as a 5th plugin (2026-07-29, explicit
  user request, uploaded as `SubharmonicSynth_v0_6.qplug`):** a bass
  enhancement / subharmonic-style boost for LFE/Sub channels, restructured
  onto this repo's own convention rather than dropped in as-is. Split into
  `Developer/plugins/SubharmonicSynth/{plugin,info,controls,layout,
  runtime}.lua` (no `properties.lua` — `GetProperties()` returns `{}`
  directly in `plugin.lua`, same pattern as DolbyFader), built via
  PLUGCC.exe into the root `SubharmonicSynth.qplug` (no `.qplugx` yet).
  Controls renamed to PascalCase (`DryLevel`/`SubLevel`/`SubGain`/
  `QFactor`/`Cutoff`/`Bypass`, were `dry_level`/`sub_level`/`sub_gain`/
  `q_factor`/`cutoff`/`bypass`) — breaking only relative to the original
  upload, nothing in this repo was ever wired to the old names. Found and
  fixed a real latent bug in the uploaded source: its per-control
  `DefaultValue` field is not a real Q-SYS `GetControls` key (confirmed
  against Q-SYS Help and the vendored templates — none of the other four
  plugins use one either), so `SubGain`/`QFactor`/`Cutoff`'s intended
  defaults (9 dB / 1.0 / 80 Hz) never actually applied on a fresh
  instantiation; replaced with a guarded one-time `runtime.lua` init
  (`if Controls.Cutoff.Value == 0 then ... end`, mirroring the pattern
  already used by `cpseries.lua`/`dolbysweep.lua`). Also dropped the
  original's `AddEventHandler` chaining helper (every control here has
  exactly one handler, so the indirection bought nothing) in favor of
  this repo's plain `Controls.X.EventHandler = function` style, and gated
  `PrintFormat` on `Properties.plugin_show_debug.Value` like the rest of
  this repo's debug output (was unconditional in the original). New
  `Developer/tests/test_dist_subharmonic.lua` (23 checks: both host
  passes, the one-time init, bypass routing, cutoff re-tune without
  re-init) registered in `run.sh` and `harness.lua`'s `M.DIST`; embedded
  components (`Lpf`/`Peq`/`GainSub`/`GainDry`/`Mix`) built ad hoc in the
  test the same way Dolby Sweep's own test builds `Sine`, no stub changes
  needed — `filter_lowpass`/`equalizer_parametric`/`gain`/`mixer` were
  already covered component-type shapes. Full suite green afterward
  (175 checks total, no regressions in the other four plugins).
- **Button control `.Value` type, resolved (2026-07-29):** confirmed via
  the newly-vendored `vendor/qsc-q-sys` submodule's reverse-engineered docs
  (`components_emulator/docs/qsys-plugins.md`, cross-checked against its own
  official-QRC-sourced `Component.GetControls` section) — `.Value` is
  **always numeric**, on every control type including Button; the boolean
  accessor is the separate `.Boolean` property, reading `Value~=0` and
  writing `Value=1/0`. This means every prior `.Value == 1`/`== 0`
  comparison in this repo was already correct; the real bugs were the
  handful of sites comparing `.Value` against the *Lua literals* `true`/
  `false` (never equal, wrong type) or assigning a Lua boolean expression
  into `.Value` (a numeric-only field) — both fixed 2026-07-29:
  `cpseries.lua`'s and `dolbysweep.lua`'s one-time-init guards (previously
  `Value == false`, silently dead code on every first compile) and
  `dolbysweep.lua`'s `mute.EventHandler`/`MultiFlip-Flop`'s `Toggle_N`
  handler (previously assigning a boolean into `.Value`). Every other
  Button/Toggle read across `dolbyfader.lua`/`cpseries.lua`/
  `dolbysweep.lua`/`MultiFlip-Flop V2.0.qplug` was also converted to
  `.Boolean` for the clearer, now-confirmed idiom, even where the old
  `== 1`/`== 0` form wasn't actually broken. `cpseries.lua`'s own `Start`
  control has no declared `ControlType` (unlike DolbySweep/MultiFlip-Flop's
  explicitly-`Button` `Start`), so its fix stayed numeric (`Value == 0`/
  `= 1`) rather than risking unconfirmed `.Boolean` support — worth
  revisiting if that omission itself turns out to be a dropped field from
  the v4.0 rewrite. `Developer/tests/qsys_stub.lua`'s control mock was
  extended with a metatable syncing `.Value`/`.Boolean` onto the same
  underlying number, matching this confirmed behavior (it previously stored
  `.Value` as a literal Lua boolean for `Start`, encoding the same wrong
  assumption). BuildVersion bumped on all four plugins
  (DolbyFader 2.0.0.1, CP Series Control 4.0.0.2, Dolby Sweep 2.0.0.1,
  MultiFlip-Flop 2.0.0.1); all four root `.qplug` distributables rebuilt;
  `Developer/tests/run.sh` passes (ALL OK, all suites). The four root
  `.qplugx` files are now stale relative to their `.qplug` — regenerate via
  `.github/workflows/build-qplugx.yml` (`all`) once this lands.
- **`cpseries_commlib.lua`'s (now `Developer/plugins/Dolby CPSeries
  Control/commlib.lua`) stray `readData(self,true)` argument, fixed
  (2026-07-29, reconciling this note with the `.Value`/`.Boolean` pass
  above):** `readData` only takes `self` (line ~288); the extra `true` was
  silently discarded by Lua on every call, always. Confirmed genuinely
  harmless before touching it — `test_modules.lua`'s "CP 850: macro list
  drains the n:name lines" case already exercises this exact call path (the
  CP850/CP950/CP950A macro-list branch of the `formlist` handler) and was
  already green — this was dead/misleading code, not a disguised functional
  bug. Dropped the stray argument, rebuilt the CPSeries root distributable
  via PLUGCC.exe.
- **Two parallel sessions independently restructured onto PLUGCC.exe,
  reconciled by merge (2026-07-29):** this branch (`claude/test-umx9nt`)
  took a non-invasive approach — `Developer/plugins/*.qplug` and
  `Developer/Modules/*.lua` left untouched, still using plain `require`, an
  auto-generated `#include` form produced only in a throwaway temp dir at
  build time (`build_distributable_plugcc.sh`), specifically to keep
  `Developer/plugins/*.qplug` directly loadable in Designer via the
  `package.path` prelude. A separate session (`claude/next-vawkbf`,
  PR #50, merged first) took the more thorough route reflected above: a
  real physical split into `plugin.lua` + `info.lua`/`controls.lua`/
  `layout.lua`/`runtime.lua` per plugin, with genuine `#include` markers
  written directly in the source, shared code under `Developer/shared/`,
  and `Developer/Modules/`/`build_distributable.sh` deleted outright. That
  session also independently found and definitively resolved the Button
  `.Value`/`.Boolean` ambiguity (the entry above) — a real research result
  this branch's own equivalent fix (assigning explicit `1`/`0` instead of a
  Lua boolean into `MultiFlip-Flop`'s `Toggle_N`) never had. Reconciling:
  the `claude/next-vawkbf` restructuring and its `.Value`/`.Boolean` fix
  were kept as-is (confirmed superior — resolves the ambiguity for every
  call site, not just `Toggle_N`); this branch's own PLUGCC-specific work
  (`build_distributable_plugcc.sh`, `.github/workflows/
  build-qplug-plugcc.yml`, the auto-`#include`-generation approach, the
  `Developer/plugins/*.qplug` direct-Designer-load tradeoff) was dropped as
  superseded; this branch's one genuinely independent fix (`readData`,
  above) was carried over via `git merge`'s rename detection, which matched
  `Developer/Modules/cpseries_commlib.lua` against its new home at
  `Developer/plugins/Dolby CPSeries Control/commlib.lua` and applied the
  diff cleanly. All four root `.qplug` files were rebuilt from the merged
  tree via `mono` + the vendored `PLUGCC.exe` (mirroring
  `build-qplug.yml`'s own invocation) to fold the `readData` fix into the
  CPSeries distributable; `Developer/tests/run.sh` passes in full
  afterward.
- **`qsc-q-sys` submodule blocked, not added (2026-07-28):** the user
  asked to add their own `qsc-q-sys` repo (referenced in "Plugin
  structure/naming convention" above as the source of the original,
  since-partly-reverted plugin convention) as a new `vendor/` submodule,
  same pattern as the five submodules already there. `add_repo` for
  `JaumeAP/qsc-q-sys` consistently fails with `MCP error -32003: MCP
  tool call requires approval`, even after the user confirmed/retried
  multiple times and checked `github.com/settings/installations` for
  the GitHub App's repo access. Ruled out this session: Claude Code's
  own local permission gate (already pre-allowlisted in
  `settings.json`), a bad repo name, general GitHub auth (other
  `mcp__github__*` tools work fine in the same session), and plain
  `git clone` (fails the same way, proxy requires the repo added
  first). Deliberately NOT worked around with the environment's own
  `GITHUB_TOKEN` -- that would bypass the exact access-check `add_repo`
  itself documents doing. Still unresolved: where this connector's own
  approval surface actually lives for this session type. Next session:
  retry `add_repo` first in case it was fixed out-of-band; if not,
  this needs investigating outside the chat entirely (Anthropic/Claude
  Code Remote side), not more retries here.
  **Update (2026-07-29): resolved.** A later-session retry of `add_repo`
  for `JaumeAP/qsc-q-sys` succeeded with no code change on this side --
  whatever blocked it was fixed out-of-band. Added as
  `vendor/qsc-q-sys` (PR #41). Its reverse-engineered docs are what
  resolved the `.Value`/`.Boolean` question above.
  **Update (2026-07-29, same day, explicit user request): removed
  again.** A later session in the same day found `vendor/qsc-q-sys`
  present in `.gitmodules` but still uninitialized on its own branch
  (private-repo access not in scope for that session either), and
  `add_repo` for `JaumeAP/qsc-q-sys` was offered again -- the user
  denied it and asked for the pending submodule addition to be deleted
  outright, with a standing instruction not to attempt or ask again.
  Deregistered: `git rm` on `vendor/qsc-q-sys` plus its section removed
  from `.gitmodules`. Standing rule from here on: do not call `add_repo`
  for `qsc-q-sys` and do not ask about it, in this or any future
  session, unless the user brings it up first.
- **PLUGCC.exe rebuild of all four plugins, complete (started 2026-07-29,
  explicit user request, repeatedly confirmed; finished same day).**
  Replaced this repo's own `Developer/tools/build_distributable.sh` with
  QSC's official `PLUGCC.exe` (`vendor/qsys-plugins/{BasePlugin,
  ExamplePlugin}/PluginCompile/PLUGCC.exe`), run via a manual-dispatch
  `.github/workflows/build-qplug.yml` (`windows-latest`, same pattern as
  `build-qplugx.yml`). Each plugin's `Developer/plugins/<Name>.qplug` was
  split into `Developer/plugins/<Name>/{plugin,info,properties,controls,
  layout,runtime}.lua`, `plugin.lua` being the PLUGCC entry point,
  `--[[ #include "file.lua" ]]` Lua-comment directives pulling the rest
  in. Code shared by more than one plugin (`qknob.lua`, `dolbyfader.lua`)
  moved to a new `Developer/shared/`. All four verified byte-for-byte (or
  logically equivalent, for CPSeries's reflowed formatting) against actual
  CI output, each with a full local `Developer/tests/run.sh` pass
  afterward: MultiFlip-Flop (BuildVersion 2.0.0.2, no shared-file
  dependency, simplest case), Dolby Sweep (2.0.0.2, one level of shared
  indirection via its own `runtime.lua`), DolbyFader (2.0.0.2, reuses
  `shared/dolbyfader.lua` + `shared/qknob.lua`, hit the `#include`
  resolution puzzle below), Dolby CPSeries Control (4.0.0.3, the hardest
  case -- `models.lua`/`protocol.lua`/`commlib.lua`, formerly
  `Developer/Modules/cpseries_{models,protocol,commlib}.lua`, moved into
  the plugin's own folder as private files with their `require()` calls
  dropped, alongside `shared/dolbyfader.lua`/`shared/qknob.lua`; sidesteps
  the nested-include first-line rule entirely by `#include`ing everything
  directly from `plugin.lua`, all depth-1). `Developer/Modules/` and
  `Developer/tools/build_distributable.sh` had no remaining consumer once
  CPSeries landed and were deleted the same day (explicit user
  confirmation); `test_modules.lua` (37 checks, direct CPSeries-class
  protocol coverage) was migrated to `loadfile()` the new
  `Developer/plugins/Dolby CPSeries Control/{models,protocol,commlib}.lua`
  in `plugin.lua`'s own load order instead of `require()`-ing from
  `Developer/Modules`. `test_plugin_defs.lua` (tested Developer-side
  definition files directly via `loadfile()`, no longer possible once
  every plugin's source became `#include`-based) was retired; its checks
  moved into each plugin's own `test_dist_*.lua`, run against the compiled
  root distributable instead -- same pattern already used for DolbyFader,
  extended to CPSeries. All four root `.qplugx` files regenerated via
  `.github/workflows/build-qplugx.yml` (fixed the same day: `submodules:
  recursive` was trying to clone the private `vendor/qsc-q-sys` and
  failing on the runner's default token, same root cause `build-qplug.yml`
  already worked around -- switched to `submodules: false` plus a scoped
  init of just `vendor/qsys-plugins/PluginEncryptionTool`). Both
  `build-qplug.yml` and `build-qplugx.yml` also print their build output
  in full to the job log, not just the workflow artifact -- the artifact's
  own blob-storage download URL is blocked by this session's egress
  proxy, but GitHub's own job-log API isn't.
  **`#include` resolution rules, confirmed by trial (2026-07-29):**
  (1) a relative `#include` path always resolves against the *original*
  `plugin.lua`'s own directory (the process cwd `PLUGCC.exe` is invoked
  from via `Push-Location`), never against whichever file's own text
  contains the directive -- so a shared file's own internal `#include`
  has to be written as the path seen from the *including plugin's*
  folder, not from the shared file's own folder. (2) A NESTED
  `#include` -- one inside a file that itself got pulled in by another
  `#include`, as opposed to one written directly in `plugin.lua` -- is
  only recognized if it is that file's first line; the same directive
  placed a few lines down (even just past a header comment) is left as
  a literal, unexpanded comment, no error, no log line, silently
  dropping whatever it was supposed to pull in. Both rules were only
  isolated after two wrong turns: a nesting-depth theory (only 2 levels
  of `#include` ever expand) looked right on the first failure but was
  disproved by a second attempt at the same depth; a paths-only fix
  (correct path, still not line 1) also silently failed before the
  line-position rule was spotted by diffing against Dolby Sweep's own
  already-working `runtime.lua` (its `#include` of `shared/qknob.lua`
  sits on line 1 there too, which is what made it work by accident, not
  by design, before this was understood). `Developer/shared/dolbyfader.lua`
  and `Dolby Sweep/runtime.lua` both now lead with their `#include` line
  for exactly this reason; `Dolby CPSeries Control/plugin.lua` avoids the
  question by never nesting an `#include` at all.
- **Repo audit cleanup (2026-07-29, explicit user request).** Removed
  four unnecessary items found by a full-repo sweep: (1)
  `.plugcc-include-test/` and `.github/workflows/probe-plugcc-include.yml`
  -- the throwaway probe from the `#include` resolution investigation
  right above; its own header comment said to delete both once the
  question was answered, and it now is. (2) `.claude/skills-lock.json`
  -- orphaned metadata left over from when `find-skills` was a bundled
  skill; its local copy was deleted 2026-07-29 (see "Portable skills"
  above) but this lock file wasn't cleaned up with it, and
  `config-export-import.md` already documented it as no longer part of
  the export. (3) `.agents/skills/karpathy-guidelines/` and the
  root-level `skills-lock.json` -- an exact duplicate of
  `.claude/skills/karpathy-guidelines/`, installed via a separate,
  undocumented mechanism (PR #48) that doesn't match this repo's own
  `.claude/skills/` convention; the `.claude/` copy was kept. No other
  file referenced any of the four removed paths.
  **Correction (2026-07-30): item (3) was wrong and broke the skill for a
  day.** `.claude/skills/karpathy-guidelines` was never "the copy that was
  kept" -- it was a *symlink* (`-> ../../.agents/skills/karpathy-guidelines`)
  pointing into the directory that audit deleted. Deleting the target left a
  dangling link, so the skill stopped loading entirely: it was absent from
  the Skill tool's available list for every session after that audit, which
  is what eventually gave it away. Fixed by removing the dead link and
  reinstalling from its recorded source
  (`npx skills add forrestchang/andrej-karpathy-skills --skill
  karpathy-guidelines --agent claude-code`), which lands a real directory
  this time; confirmed by the skill reappearing in the available list.
  Lesson worth keeping: `ls` on a symlinked skill directory looks identical
  to a real one, so a de-duplication audit has to check `-xtype l` (or just
  `test -e <dir>/SKILL.md`) before deciding which of two paths is the real
  copy. A `find .claude/skills -maxdepth 1 -xtype l` sweep at the same time
  found no other broken links.
- **Remote branch deletion blocked, cleanup left half-done (2026-07-29):**
  18 stale `origin/claude/*` branches were audited against their PRs;
  17 were confirmed safe to delete (PR merged, PR closed-without-merge,
  or already an ancestor of `main`) and the user approved deleting all
  17, keeping only `claude/next-vawkbf` (PR#41, still open, tracks the
  `qsc-q-sys` submodule attempt above). `git push origin --delete
  <branch>` failed on every one of the 17 with `RPC failed; HTTP 403`
  from this session's own git proxy (`127.0.0.1:<port>/git/...`), while
  plain pushes and the PR merge earlier in the same session worked fine
  — the proxy specifically denies ref deletion, not push in general.
  There is also no `mcp__github__delete_branch`-equivalent tool available
  (only `create_branch` exists in this session's GitHub MCP toolset).
  Deliberately not worked around with a raw API call using the
  environment's own token, same reasoning as the `qsc-q-sys` item above.
  Still pending, branch names unchanged since this audit: `bootstrap-
  build-qplug`, `check-gh5uhs`, `claude-md-docs-5kvq1u`, `claude-md-docs-
  Ehgoa`, `claude-md-docs-m7fzvp`, `claude-md-docs-qd0h3m`, `continua-
  pc6eq1`, `learning-archive-policy-o4denr`, `probe-plugcc-include`,
  `probe-plugcc-include-cleanup`, `probe-plugcc-include-fix`, `qsc-qsys-
  a44799`, `remove-class-submodule`, `revisio-iirycs`, `test-coverage-
  analysis-49cewy`, `test-osx0oe`, `todo-implementation-vbd57a`. Next
  session: retry the push-based delete first in case the proxy policy
  changed; otherwise this needs the user deleting them by hand from the
  GitHub UI (PR page's "Delete branch" button, or Settings > Branches),
  or investigating the proxy/connector side directly, not more retries
  from inside a session.
  **Update (2026-07-30): three more accumulated since this audit, same
  situation.** `git branch -r` now also lists `neteja-ot19wo` (PR #47-49),
  `qsys-zyijbo` (PR #55), and `test-umx9nt` (PR #51-54) -- all three
  confirmed merged into `main` (`git merge-base --is-ancestor` true for
  each), never included in the 17-branch count above because those PRs
  merged after that audit ran. Same blocker applies (proxy 403s on ref
  deletion); not retried this session, just recorded so the pending count
  stays accurate. `claude/next-vawkbf` (PR #41, the one branch the
  original audit deliberately kept) no longer appears in `git branch -r`
  at all -- PR #41 merged later the same day the audit ran, and the
  branch is gone, most likely GitHub's own delete-on-merge, not anything
  done from inside a session.
- **`check-reply-format.sh`'s block reason made block-scoped, not just
  Rebut-scoped (2026-07-29, explicit user request, root-caused after a
  real recurrence in this exact session).** The 2026-07-28 fix above
  scoped the repair message for a missing-Rebut-only violation, but a
  language or formatting violation still got the old generic "reescriu
  NOMES el fragment assenyalat" wording, WITHOUT ever saying which
  fragment -- the retry had to guess. It guessed wrong this session: the
  actual English text was a one-line narration ("All tests pass ...
  Now committing."), but the retry instead re-sent the already-correct
  closing summary verbatim, producing exactly the duplicate-looking reply
  the rule exists to prevent. Two real bugs, both fixed: (1) the language
  heuristic ran on the WHOLE joined turn text, including the mandatory-
  English "Rebut: <order in English>" line -- scoring that line as English
  is correct by design, but it also meant the Rebut line's own English
  words could push a short, otherwise-compliant turn over the old
  `en_count>=3` threshold; the language check now runs against every block
  EXCEPT the first (Rebut) one. (2) once an offending block search was
  added (score each block by en-stopword-count minus ca-stopword-count,
  quote any block that scores net-English), the jq `--arg` regex variables
  were built with a doubled backslash (`'(?i)\\b(...)\\b'`) on the mistaken
  assumption they needed the same escaping as a regex written inline in jq
  program source -- `--arg` passes the literal bytes straight through with
  no re-escaping, so the pattern oniguruma actually saw was "match a
  literal backslash then the letter b", which silently matched nothing,
  ever. Fixed to a single backslash. Both fixes verified against synthetic
  transcripts built by hand (no real session data touched): a genuine
  English narration block is now quoted verbatim in the block reason and
  the Rebut line is excluded from scoring either way; an all-Catalan turn
  with a normal English Rebut summary no longer risks a false block; the
  existing missing-Rebut-only scoped message is unchanged. Format/list
  violations were extended the same way -- the offending line (with its
  line number in the joined turn text) is now quoted too, not just named.
- **`check-reply-format.sh` re-demanded a fresh 'Rebut:' line even when it
  was already present and correct, fixed (2026-07-29, explicit user
  request, reported live as "Doble missatge" after hitting it in this
  exact session).** The quoted-fragment retry branch (added in the fix
  right above) unconditionally appended "Comenca igualment per 'Rebut:
  ...'" to the repair instruction, regardless of whether `missing_rebut`
  was actually set. Real case: a reply's first block already opened with
  a correct "Rebut: ..." line; a later block had a lone em-dash violation.
  The hook still told the retry to prepend a fresh 'Rebut: ...' line to
  the correction, so the user saw two separate "Rebut: ..."-opening
  blocks in the same turn -- reading as a duplicated second reply, the
  exact symptom the block-scoping fix above was meant to eliminate. Fixed:
  the "Comenca per 'Rebut: ...'" instruction is now conditional on
  `missing_rebut=1`; when Rebut was already fine, the fix text instead
  says explicitly not to repeat it ("La linia 'Rebut: ...' ja hi era i ja
  era correcta -- NO la repeteixis"). Verified against three synthetic
  transcripts (no real session data): Rebut-already-correct +
  format-only violation no longer demands a new Rebut line; Rebut-missing
  + format violation still correctly demands one; the pre-existing
  Rebut-missing-only path is unchanged. Same file, same day as the fix
  above it -- this is the second bug found in the same retry-instruction
  logic, both from actually hitting them live rather than from review.
- **`build-qplug.yml` moved off `windows-latest` onto `ubuntu-latest` +
  mono (2026-07-30, explicit user request).** PLUGCC.exe is a PE32
  Mono/.NET assembly (`file` reports "Mono/.Net assembly"), so mono runs
  it natively on Linux -- no Windows runner needed. Verified before
  switching, not assumed: installed `mono-runtime`, built MultiFlip-Flop
  with `mono PLUGCC.exe MultiFlip-Flop plugin.lua` from the plugin's own
  directory, and `cmp`'d the result against the root
  `MultiFlip-Flop.qplug` produced by the old windows-latest job --
  byte-identical, line endings included. The `cd` into the plugin
  directory stays load-bearing (PLUGCC resolves relative `#include`s
  against its cwd), same role the old job's `Push-Location` had.
  **This does NOT generalize to `build-qplugx.yml`.** Its
  `plugin_tool_release.exe` is a PE32+ native x86-64 Windows binary
  linking MSVC/OpenSSL DLLs, not a .NET assembly: mono refuses it
  outright (`File does not contain a valid CIL image`, confirmed by
  running it, not inferred). `wine64` DOES run it -- `version` returns
  `1.0.0.0` and `encrypt` produces a structurally correct envelope
  (same `data`/`iv`/`key` keys, `iv_len=24`, `key_len=344` as the
  committed windows-built `.qplugx`) -- but that was deliberately NOT
  adopted, for two reasons worth keeping if this is revisited: the tool
  has no `decrypt` command (only `version`/`encrypt`), so there is no
  round-trip check available, and each run emits a fresh random IV, so a
  wine-built `.qplugx` cannot be byte-compared against a Windows-built
  one either. That leaves Q-SYS Designer as the only way to confirm a
  wine-built `.qplugx` actually loads.
  **Update, same day: superseded.** User explicitly asked to always use
  wine64, accepting the no-round-trip/no-byte-compare caveats above as a
  known, accepted gap rather than a blocker. Before switching,
  double-checked whether wine64 could also replace mono for
  `build-qplug.yml` (for one consistent runtime instead of two) -- it
  cannot: plain `wine64 PLUGCC.exe ...` fails with "Application could
  not be started, or no application associated with the specified
  file", since running a .NET assembly under Wine needs the separate
  Wine Mono package, not available via `apt-cache search wine-mono` on
  this runner. So the two workflows stay on two different runtimes by
  necessity, not oversight: `build-qplug.yml` on `ubuntu-latest` + native
  `mono` (the only thing that runs PLUGCC.exe here), `build-qplugx.yml`
  now also on `ubuntu-latest` + `wine64` (the only thing that runs
  plugin_tool_release.exe here) instead of `windows-latest`. Manual
  Designer verification of a wine-built `.qplugx` is still outstanding --
  this switch proceeds without it per explicit instruction, not because
  the gap was closed.
  **Update, same day: reverted.** User asked to put everything back on
  `windows-latest`/GitHub-hosted runners. Both `build-qplug.yml` and
  `build-qplugx.yml` restored verbatim to their pre-mono/wine versions
  (`windows-latest`, `pwsh` steps, PLUGCC.exe / plugin_tool_release.exe
  invoked directly, no mono/wine install step). The mono and wine64
  findings above stay recorded as-is -- both binaries were confirmed
  runnable on Linux (mono for PLUGCC.exe, wine64 for
  plugin_tool_release.exe, plain wine64 without Wine Mono canNOT run
  PLUGCC.exe) -- in case a Linux-runner approach is wanted again later,
  but neither workflow uses it now.

- **Git-section history trimmed out of CLAUDE.md (2026-07-30, explicit user
  request), kept verbatim here.** The operative rules survive in CLAUDE.md's
  own Git section; what follows is the reasoning behind them:

  - **Standing automation authorization (2026-07-28, explicit user request,
    superseded same day).** Originally recorded here as a repo-only rule:
    full git/PR cycle pre-authorized without per-step confirmation. Same day,
    the user confirmed (after being shown the tradeoff) that they want this
    as the default everywhere, not just this repo -- so it now lives in the
    portable `github-rules` skill's own "Merging: the default is full
    automation" section instead, which every repo importing the bundle gets.
    This repo follows that shared default; nothing repo-specific left to
    state here (the skill's own exclusions -- force-push, `reset --hard`,
    `branch -D`, rewriting published history -- already cover what would
    otherwise be restated).
  - **PR creation can still be gated per-session despite the above
    (2026-07-28, explicit user request, moved same day).** Observed
    directly this session: PR #28 wasn't opened until the user said
    "ObrePr", even though the shared automation default above already
    covers PR creation -- the calling environment can layer its own gate
    on top, independent of anything this repo states. Generalized the
    same day into `github-rules`' own "Merging" section (the
    mirror-image case of a repo overriding the skill's default: here the
    environment overrides it instead) rather than kept repo-local, since
    nothing about it is specific to this repo.

- **Open Threads item 1 corrected: "all four .qplugx stale" was wrong,
  DolbyFader's isn't (2026-07-30).** Checked by comparing each root
  `.qplug`/`.qplugx` pair's last-touching commit. `f8eb707` ("Regenerate
  all four .qplugx from the rebuilt .qplug sources", 2026-07-29 09:06:55)
  built `DolbyFader.qplugx` from `DolbyFader.qplug`@`0604fb4` (08:39:50,
  the same day, earlier) -- nothing has touched `DolbyFader.qplug` since,
  so `DolbyFader.qplugx` is current. Dolby Sweep, MultiFlip-Flop, and
  Dolby CPSeries Control were all rebuilt again later that same day
  (14:38, 14:38, 15:43) by the PLUGCC restructuring and its Button
  `.Value`/`.Boolean` fixes, which is what actually left those three
  `.qplugx` stale. The Open Threads item previously said "all four"
  without checking; narrowed to the three that are actually stale, plus
  SubharmonicSynth's still-missing one.

- **Root-cause investigation: why stale branches keep accumulating
  (2026-07-30, explicit user request).** Cross-referenced all 59 merged
  PRs against their head branches (search_pull_requests is:merged for
  merged_at, list_pull_requests for head.ref, joined by PR number) and
  checked each unique branch name against `git branch -r` and
  `git merge-base --is-ancestor origin/<branch> origin/main`. Pattern: a
  branch name gets reused across many consecutive PRs while one session
  is actively working (`revisio-iirycs` x10, `test-osx0oe` x13,
  `qsc-qsys-a44799` x4, `neteja-ot19wo` x4, `test-umx9nt` x4, this
  session's own `delete-old-pr-avxj9x` x5 and counting) via the
  restart-same-branch-name pattern `github-rules` documents for
  follow-up work. That pattern has no closing step: `github-rules`'
  workflow section only ever says to restart a branch, never to delete
  one once a session's work is genuinely finished. Combined with the git
  proxy's HTTP 403 on `git push --delete` (see the entry above), every
  branch a session finishes with is abandoned permanently -- not a one-
  time cleanup gap, an ongoing rate of roughly one orphaned branch per
  finished session.
  Only 3 of the 20 stale branches have ever actually been deleted at any
  point (`claude-md-docs-25dexu`, `next-vawkbf`, `test-s5crir`), with no
  pattern that explains why those three and not the others -- notably
  not "single-PR branches get cleaned up": `qsys-zyijbo` was also a
  single-PR branch and is still present. No tool in this session's
  toolset can read the repository's own settings (checked: no
  get_repository/repo-settings equivalent among the github MCP tools),
  so the setting itself couldn't be confirmed directly, but this
  irregular pattern -- some merges deleting the branch, most not, with
  no correlation to merge method, branch reuse, or timing -- is the
  known signature of GitHub's per-repo "Automatically delete head
  branches" setting being toggled on for only part of the repo's
  history (on for a window, off the rest) rather than anything a
  session did differently. Recommendation given to the user (CLAUDE.md
  Open Threads item 4): turn it on permanently. Unlike branch deletion
  itself, this setting change happens server-side on GitHub's end at
  merge time, so it isn't subject to the git proxy's ref-deletion block
  at all -- it would apply automatically to every future merge_pull_request
  call from any session, closing the gap for good without needing any
  new session-side capability.

- **The four "mandatory" skills were never actually invoked, and the fix is
  only partly mechanical (2026-07-30).** A full-session audit, prompted by the
  user asking whether the repo's skills were really being obeyed, found
  `file-operations`, `github-rules`, `caveman` and `karpathy-guidelines` --
  all four called mandatory by `CLAUDE.md` -- invoked zero times via the
  `Skill` tool across a long session that repeatedly matched their own trigger
  descriptions (writing `.qplug`/`.qplugx` files with raw `cp`/`sed -i`,
  dispatching workflows and merging PRs, replying without a compression or
  behavioural-principles pass). Root cause worth remembering: `CLAUDE.md` and
  `.claude/rules/*.md` are auto-injected passive context, whereas a `SKILL.md`
  loads its real content ONLY on an explicit `Skill` call. Conflating the two
  is what let it go unnoticed -- the rules "being in context" is not the skill
  running.
  Fix, same day: `file-operations` got a genuine hard gate,
  `.claude/hooks/file-operations-enforcement.sh` (`PreToolUse`/`Bash`,
  `permissionDecision: deny`), modelled on `no-commit-on-main.sh`. **Honest
  limit, do not overstate it later**: that hook covers only raw
  `cp`/`mv`/`rm`/`dd`/`tee`/`install`/`sed -i` against a repo path outside
  `/tmp/`. It deliberately does NOT catch a `python3 -c` file write, because
  detecting that by pattern risks blocking legitimate reads. The other three
  skills have no comparable chokepoint -- no single command means "replied
  without compressing" or "merged without checking conventions" -- so they are
  backed only by `rule-check-reminder.sh` naming them every firing. That is a
  stronger reminder, NOT a guarantee, and the difference is the whole point of
  this entry.

- **The config bundle had never actually been applied to CPSeries
  (2026-07-30).** The import commit there (`d516d15`) added only metadata
  files -- `config-export-import.md`, `recommended-skills.txt`,
  `skills-history.md`, `removed-files.txt`, `00-START-HERE.md`,
  `programming-optional-skills.txt` -- and never touched `CLAUDE.md`,
  `settings.json` or `hooks/`. It was reported at the time as a completed
  import. Two consequences surfaced only when the user asked, sessions later,
  whether the other repos still had their changelog rules: CPSeries kept its
  pre-bundle common section, and a later cleanup commit (`b988959`) deleted
  the skills that section pointed at, leaving live dangling pointers to
  `git-rules`, `changelog-rules` and `karpathy-guidelines`.
  That same `b988959` also deleted two skills that were on NO removal list:
  CPSeries' own `cpx50-parser` and `cpx50-equalizer`. The import step should
  prune only what `removed-files.txt` names; it pruned everything outside the
  bundle allowlist instead. The user chose to keep them deleted rather than
  restore, so the damage is settled -- but the lesson is the procedure, not
  the outcome: **an import must delete only what `removed-files.txt` lists,
  and "imported the bundle" must not be reported unless `CLAUDE.md`,
  `settings.json` and `hooks/` were actually part of it.** Eines, checked the
  same day, had received the full import correctly and needed only the
  latest revision.

- **"CP Series Emulator" added (2026-07-31): a complete, all-5-model
  replacement for the three old single-model `Dolby CP Emulator/*.quc`
  files, which never covered CP950/CP950A at all.** First attempted in the
  wrong repo entirely -- the user's initial ask ("un simulador virtual...
  ha d'imitar tots els processadors que tenim definits", "CP Series
  Emulator") was built as a Python `cpx50-emulator` package in **CPSeries**
  (the Dolby cinema-processor Python/Lua toolkit repo), following the wrong
  thread: CPSeries already HAS a complete simulator
  (`cpx50.comms.simulator.ProcessorSim`), so "the CP Series plugin" the
  user actually meant was THIS repo's own Q-SYS plugin
  (`Developer/plugins/Dolby CPSeries Control/`), not CPSeries the toolkit.
  Corrected once the user clarified ("l'emulador té que anar en el que
  estem treballant... la de Plugins"): the CPSeries commit was reverted
  (`d541d1a`), and the real work landed here instead --
  `Developer/cp-series-emulator/cp-series-emulator.lua`, a single Control
  Script covering all five defined models from one file, modeling the
  CPServices wire vocabulary from `commlib.lua` exactly (not a separate,
  possibly-diverging reimplementation).
  **Cannot produce the `.quc` binary directly** (a serialized .NET object,
  no generator for it outside Q-SYS Designer) -- delivered as plain Lua
  source instead, meant to be pasted into a new Control Script component
  in Designer (see `Dolby CP Emulator/README.md`, also added this session,
  for the exact steps and the gap it fills).
  **Verified for real, not just written**: `qsys_stub.lua` gained a
  `TcpSocketServer` stub (`.Listen`/`.EventHandler`, no real network) so
  `Developer/tests/test_cp_series_emulator.lua` could wire the emulator's
  server side to the REAL `CPSeries`/`CPModels`/`CPProtocol` client classes
  in-process and drive a genuine round trip -- 55 checks, added to
  `run.sh`. Two non-obvious protocol details only surfaced by actually
  running this against the real client, not by reading the wire spec:
  (1) **CP650 must raw-echo the sent line before its real reply** -- the
  client's own `echopending` logic treats a SET's reply as the mechanical
  echo and discards it if the emulator's only line back is textually
  identical to what was sent (which it is, for an echoed SET); (2) **the
  macro-model `sys.macros` burst needs a bare `sys.macros` header line
  before the `n:name` entries** -- without it, `received()` never
  recognizes the burst as belonging to the formlist action at all, and the
  entries silently vanish into the generic "unrecognized action" fallback
  instead of ever firing a `formlist` event.
  A related test-design trap, worth remembering for any future test like
  this: **the CPSeries client's `EventHandler` does not refire for a value
  the client itself just set** (`setValue(...,isevent=true)` skips the
  callback), and the device's own confirmation of that exact value is then
  ALSO swallowed by `received()`'s `isEqual()` short-circuit -- so
  "call `Action()`, wait for the same event to fire again" silently never
  passes, for correct reasons on both sides. The test instead checks writes
  (SET reached the wire) plus a second, independent connection to the same
  live emulator instance (the value actually persisted), and relies on the
  client's zero-initialized cache to make the FIRST read of any param a
  genuine mismatch that does fire.

- **CP Series Emulator turned into a real Plugin (2026-07-31), same day
  it was first built as a Control Script.** The user clarified they
  actually wanted a Plugin (PLUGCC, `.qplug`), not a Control Script pasted
  by hand into Designer -- the Control Script version
  (`Developer/cp-series-emulator/cp-series-emulator.lua`) stays, since it
  still serves the non-Designer bench-testing workflow, but the new
  `Developer/plugins/CP Series Emulator/` is now the primary form. Chosen
  design (asked via AskUserQuestion, recommended option picked): a `Model`
  enum property (5 choices, same shape as the real plugin's own) plus a
  minimal `Status`/`Status.Led` indicator -- no manual override controls.
  Built through the normal `Developer workflow`: `build-qplug.yml`'s
  `plugin` choice list needed "CP Series Emulator" added first (run
  30627826424, windows-latest, succeeded on the first try, no literal
  unexpanded `#include` left in the output). The built `.qplug` was
  reconstructed locally rather than hand-transcribed from the job log --
  this session's egress proxy blocks both the artifact's blob-storage URL
  and the signed full-log-zip URL (`results-receiver.actions.
  githubusercontent.com`, 403), so a Python script did the same `--[[
  #include "x.lua" ]]` -> file-content substitution PLUGCC does (confirmed
  by inspecting the job log: each included line gets the include
  directive's own leading whitespace prepended, not naive concatenation),
  then the result was verified against the job log's own echoed output
  line-for-line and syntax-checked (`luac5.3 -p`) before being written to
  the repo root as `CP Series Emulator.qplug`, LF line endings matching
  the other four root `.qplug` files (the job log's own `\r\n` is GitHub
  Actions' own log-transport wrapping, not the actual file's line endings
  -- confirmed by checking an existing root `.qplug` has none).
  `build-qplugx.yml`'s choice list and `$all` array also got "CP Series
  Emulator.qplug" added, ahead of that workflow actually being dispatched
  for it (not done yet -- no `.qplugx` built this session).
  New test `Developer/tests/test_dist_cpseriesemulator.lua` (37 checks,
  added to `run.sh`) covers the BUILT distributable specifically -- not a
  duplicate of `test_cp_series_emulator.lua`'s own 55 checks (which drove
  the Control Script source against the real CPSeries client class):
  definition pass (Model's 5 choices, Status controls, RectifyProperties
  hides `plugin_show_debug`), and a runtime pass per model wiring
  `server`/`SocketHandler` through `qsys_stub.lua`'s `TcpSocketServer`
  stub, checking `Status` transitions 4 (no client) -> 0 (connected) -> 4
  (disconnected) and one GET round trip per model.

- **The Control Script version removed the same day, once its only
  remaining edge (no build step) was judged not worth the duplication
  (2026-07-31, explicit user request, asked directly: "why do I need
  [it] if I already have the [plugin]").** By this point the protocol
  core (constants, `escape`/`isGet`/`trySet`/`macroName`/`macroIndex`,
  `SocketHandler`) had already been extracted out of duplication into one
  file to fix a ~150-line byte-for-byte duplication between
  `Developer/cp-series-emulator/cp-series-emulator.lua` and `Developer/
  plugins/CP Series Emulator/runtime.lua` (found when asked generally
  "if there are repeated things in the repo" -- there were, this was it):
  first landed in `Developer/shared/cp-series-emulator-protocol.lua` so
  both could #include/reference the same source (the Plugin via a
  depth-1 `#include` from `plugin.lua`, kept out of `runtime.lua` itself
  to avoid PLUGCC's nested-#include-must-be-first-line rule; the Control
  Script, which cannot `#include` at all -- no PLUGCC build step -- kept
  a hand-synced inline copy). Once the Control Script was deleted
  outright, that file had exactly one real consumer left, so it moved
  again, out of `Developer/shared/` (for code more than one plugin
  actually uses) into a private per-plugin file, `Developer/plugins/CP
  Series Emulator/protocol.lua` -- matching "Dolby CPSeries Control"'s
  own `models.lua`/`protocol.lua`/`commlib.lua` split. `BuildVersion`
  bumped twice the same day for these two structural passes (1.0.0.1,
  then 1.0.0.2), each rebuilt via `build-qplug.yml` and re-verified
  against `Developer/tests/run.sh` before being written to the repo
  root, replacing the previous `CP Series Emulator.qplug`.
  `Dolby CP Emulator/README.md` rewritten to point only at the Plugin (no
  more paste-into-Designer instructions); `Developer/tests/
  test_cp_series_emulator.lua` and the whole `Developer/cp-series-
  emulator/` folder deleted; `run.sh`'s syntax-check globs and test list
  updated to match. The Plugin's own `plugin.lua` header keeps the full
  history (v1.0 -> v1.0.0.1 -> v1.0.0.2) rather than restating it here in
  full a second time.

- **The three old single-model `.quc` emulators deleted too, same day
  (explicit user request, after listing this repo's modules and asking
  for the old ones to go).** `Dolby CP Emulator/CP650 Emulator.quc`,
  `CP750 Emulator.quc`, `CP850 Emulator.quc` -- the ones the standalone
  Control Script and then the Plugin were both built to replace, per the
  history above. Nothing left referencing them any more (`README.md`'s
  catalog was already plugin-only; `Dolby CP Emulator/README.md`
  rewritten again, now describing them purely as history; the folder
  itself kept, holding only that README). No test coverage existed for
  the `.quc` binaries themselves (never testable outside Designer), so
  deleting them doesn't touch `run.sh`.

- **`CHANGELOG.md` deleted (2026-07-31), same day it was started.**
  Created earlier this session and maintained by hand across several
  entries (v0.1.0 through v0.5.0), but `changelog-rules` was never
  actually installed in this repo (`.claude/skills/changelog-rules/`
  doesn't exist here) -- the user caught the inconsistency directly
  ("si no està instal·lat rules no té que estar amb md") and chose
  deletion over installing the skill retroactively. CLAUDE.md's own
  "Changelog-before-commit" rule already no-ops gracefully when the
  skill isn't installed, so nothing else needed touching -- no other
  file in this repo claimed `CHANGELOG.md` existed or referenced its
  content.

- **PLUGCC's real indentation for a NESTED `#include` doesn't match a
  naive "prefix every line with the marker's current indent, recurse"
  model (found rebuilding DolbyFader, 2026-07-31).** `DolbyFader/
  plugin.lua` includes `../../shared/dolbyfader.lua` at 1-tab indent;
  `dolbyfader.lua`'s own first line includes `../../shared/qknob.lua`
  at 0 indent in ITS OWN source. A two-pass local simulation (apply the
  same regex substitution twice, using each pass's own computed indent)
  gives qknob.lua's content 1 tab of indent; the REAL PLUGCC output
  (confirmed against the actual build-qplug.yml job log) gives it 2
  tabs -- dolbyfader.lua's own directly-written content (not further
  nested) correctly gets 1 tab either way, so the discrepancy is
  specific to the SECOND nesting level, and the exact rule PLUGCC
  actually uses for it wasn't fully reverse-engineered from this one
  example. Rather than guess further, the fix was procedural, not
  algorithmic: for any plugin with a nested `#include` chain (currently
  only `DolbyFader` and `Dolby CPSeries Control`, both via
  `dolbyfader.lua` -> `qknob.lua`; `Dolby Sweep` includes `qknob.lua`
  directly, no nesting), write the root `.qplug` from the VERIFIED job
  log content itself (extracted and cleaned of timestamps/ANSI codes),
  not from local `#include` simulation. Local simulation stays valid
  and already double-checked for any plugin with no nested includes
  (confirmed for `CP Series Emulator`'s three rebuilds this session,
  each byte-for-byte matched against its own job log).

- **`Developer/host-emulator/components/{gain,filter_lowpass,
  equalizer_parametric}.lua` pin lists independently confirmed (2026-07-31),
  closing `PROJECT.md`'s former "Open threads" item 2.** Direct fetches of
  both `help.qsys.com` and `q-syshelp.qsc.com` still 403 (same block first
  hit 2026-07-29 when these three files were written; also tried and
  blocked this session: `web.archive.org`, the `r.jina.ai` read proxy,
  GitHub code search over `gdyr/qsys-plugin-docs` and related public repos
  for a real plugin wiring these specific component Types -- none turned up
  a `GetWiring` example beyond the `mixer` one already cited in
  `mixer.lua`). What DID work: a plain web search's own crawled index of
  each component's official Q-SYS Help page (`gain.htm`,
  `filter_lowpass.htm`, `equalizer_parametric.htm`) -- the same source
  category, once removed from a direct fetch, that already confirmed
  `sine.lua`. All three pages' indexed text states the same pattern: Mono
  (default) = one input, one output; Stereo = two/two; Multi-Channel =
  2-256, selectable via Properties. That corroborates the "Input 1"/
  "Output 1" convention these three files already returned for the Mono
  case, on top of the pre-existing internal evidence (SubharmonicSynth's own
  shipped `GetWiring`, wiring them as "GainSub Input 1"/"Lpf Input 1"/
  "Peq Input 1" etc.). Deliberately NOT extended to model Stereo/
  Multi-Channel pin naming -- no plugin in this repo uses any of the three
  outside Mono, and the exact Properties key(s) that would select those
  modes for these Types (`mixer.lua`'s own `n_inputs`/`n_outputs` keys are
  confirmed only for `mixer`) are still unverified, so guessing them would
  be exactly the kind of speculative addition this repo's conventions rule
  out. Re-open if a real host or a new plugin ever needs non-Mono wiring
  for `gain`/`filter_lowpass`/`equalizer_parametric`.
