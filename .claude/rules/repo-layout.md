---
paths:
  - "Developer/**"
  - "*.qplug"
  - "*.qplugx"
  - "vendor/**"
  - "Dolby CP Emulator/**"
  - ".github/workflows/**"
---

<!-- Split out of CLAUDE.md 2026-07-30 (explicit user request) to bring the
main memory file under the ~200-line guidance. A directory tree is exactly
what the official guidance calls derivable-from-the-codebase content, so it
loads only when Claude is actually working inside the tree it describes. -->

<!-- Cross-references in this file that say "above"/"below" may now point at
a sibling file after the 2026-07-30 split: CLAUDE.md (operative rules),
.claude/rules/repo-layout.md (directory tree),
.claude/rules/qsys-plugin-development.md (plugin/build reference), or
docs/continuity-notes.md (dated history). -->

### Repository layout

```
.
├── README.md                         Short plugin catalog
├── .vscode/settings.json             Associates *.qplug with the Lua language
│
├── .claude/                          Claude Code tooling: CLAUDE.md's companion
│   │                                 config, all of it version-controlled
│   ├── rules/                        Path-scoped memory files, incl. this one
│   ├── skills/                       Installed skills (2 bundled + the rest
│   │                                 fetched per recommended-skills.txt)
│   ├── hooks/                        Session/tool lifecycle scripts
│   ├── scripts/                      export-config-skill.sh, merge-settings.sh
│   ├── settings.json                 Hook registrations + permissions
│   ├── recommended-skills.txt        Fetch-on-demand skill list
│   ├── removed-files.txt             Paths an import should prune
│   ├── skills-history.md             Why each skill is bundled/optional/removed
│   └── config-export-import.md       The export/import procedure
├── .agents/skills/                   Where `npx skills` installs; several
│                                     .claude/skills/ entries are symlinks here
├── skills-lock.json                  `npx skills` install manifest -- a restore
│                                     source, so keep it matching what is really
│                                     installed (never prune skills by hand
│                                     without updating it)
├── .github/workflows/                build-qplug.yml (PLUGCC .qplug builds) and
│                                     build-qplugx.yml (encryption); both
│                                     windows-latest, workflow_dispatch only
├── docs/
│   └── continuity-notes.md           Dated institutional memory, not auto-loaded
│
├── *.qplug / *.qplugx                Distributable plugins (repo root), built by
│   │                                 QSC's own PLUGCC.exe via
│   │                                 .github/workflows/build-qplug.yml (see
│   │                                 "Developer workflow" below)
│   ├── DolbyFader.qplug              (v2.0)
│   ├── DolbyFader.qplugx
│   ├── Dolby Sweep V2.0.qplug
│   ├── Dolby Sweep V2.0.qplugx
│   ├── MultiFlip-Flop.qplug          (v2.0)
│   ├── MultiFlip-Flop.qplugx
│   ├── Dolby CPSeries Control V4.0.qplug
│   ├── Dolby CPSeries Control V4.0.qplugx   Packaged/encrypted (JSON envelope);
│   │                                 the original four .qplugx built 2026-07-27 via
│   │                                 .github/workflows/build-qplugx.yml
│   │                                 (GitHub Actions, windows-latest),
│   │                                 replacing the old stale
│   │                                 "Dolby CPSeries Control V2.2.qplugx"
│   │                                 (last hand-compiled at v2.2, now removed).
│   │                                 Never hand-edited; regenerate via the
│   │                                 workflow (or Designer's "Save as
│   │                                 compiled plugin") after any .qplug rebuild.
│   ├── SubharmonicSynth.qplug        (v0.6, added 2026-07-29)
│   ├── SubharmonicSynth.qplugx       All five .qplugx (including this one, for the
│   │                                 first time) rebuilt together 2026-07-30 via
│   │                                 the same workflow, once it was added to that
│   │                                 workflow's own choice list -- corrected same
│   │                                 day, this section previously said
│   │                                 SubharmonicSynth had no .qplugx yet.
│   ├── CP Series Emulator.qplug      (v1.0, added 2026-07-31) -- no real Dolby
│   │                                 hardware behind this one; fakes a
│   │                                 processor for bench-testing Dolby CPSeries
│   │                                 Control. No .qplugx built yet (workflow
│   │                                 choice list updated, not yet dispatched).
│   ├── StateTrigger.qplug            (v2.0, added 2026-07-31) -- inverse of
│   │                                 MultiFlip-Flop: Channels property
│   │                                 (1-256) for N independent State_n/Out_n
│   │                                 pairs, each firing its own Out per
│   │                                 State change; Detection property
│   │                                 (On/Off/Both, default Both) gates which
│   │                                 direction fires. No .qplugx built yet.
│   └── DolbyKnobTest.qplug           (v1.0.0.3, added 2026-07-31, rebuilt
│                                     2026-08-01) -- scratch/test plugin,
│                                     not production: a single native
│                                     ControlType="Knob" control (GainDb,
│                                     ControlUnit="dB", -90..10), no
│                                     QKnob/Text wrapper, no
│                                     shared/qknob.lua dependency, no
│                                     runtime logic. DolbyFader itself
│                                     untouched. No .qplugx built yet.
│
├── Dolby CP Emulator/                Once held 3 hand-written .quc Control
│   └── README.md                     Scripts (CP650/CP750/CP850, no CP950/CP950A)
│                                     -- deleted 2026-07-31 (explicit user request),
│                                     fully superseded by the root CP Series
│                                     Emulator.qplug. README.md kept as a pointer.
│
├── vendor/                            Read-only reference material (git submodules) —
│   │                                 `git submodule update --init --recursive` after
│   │                                 cloning if empty; never edit contents, it's all
│   │                                 upstream's
│   ├── qsys-plugins/                  QSC's own org (support contact
│   │   │                             qsyscontrolfeedback@qsc.com, confirmed in
│   │   │                             BasePlugin's and PluginEncryptionTool's own
│   │   │                             READMEs -- ExamplePlugin has no README.md
│   │   │                             at all, corrected 2026-07-30, was wrongly
│   │   │                             claimed "in each README")
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
    ├── plugins/                      One folder per plugin, each built by QSC's own
    │   │                             PLUGCC.exe (see "Developer workflow" below).
    │   │                             `plugin.lua` is the PLUGCC entry point; sibling
    │   │                             files are pulled in via `--[[ #include "x.lua" ]]`
    │   │                             Lua-comment directives.
    │   ├── DolbyFader/
    │   │   ├── plugin.lua            PluginInfo/Get*/GetComponents + runtime #include
    │   │   ├── info.lua              PluginInfo table
    │   │   ├── controls.lua          GetControls body
    │   │   └── layout.lua            GetControlLayout body
    │   ├── Dolby Sweep/
    │   │   ├── plugin.lua
    │   │   ├── info.lua
    │   │   ├── properties.lua        GetProperties body
    │   │   ├── controls.lua
    │   │   ├── layout.lua
    │   │   └── runtime.lua           Runtime logic; #include's ../../shared/qknob.lua
    │   ├── MultiFlip-Flop/
    │   │   ├── plugin.lua
    │   │   ├── info.lua
    │   │   ├── properties.lua
    │   │   ├── controls.lua
    │   │   ├── layout.lua
    │   │   └── runtime.lua           No shared-file dependency (simplest case)
    │   ├── Dolby CPSeries Control/
    │   │   ├── plugin.lua            #include order: shared/dolbyfader.lua, models.lua,
    │   │   │                         protocol.lua, commlib.lua, runtime.lua (all direct,
    │   │   │                         depth-1 includes -- see the #include rules below)
    │   │   ├── info.lua
    │   │   ├── properties.lua
    │   │   ├── controls.lua
    │   │   ├── layout.lua
    │   │   ├── models.lua            Per-model wire config (private to this plugin)
    │   │   ├── protocol.lua          Per-model message formatting/GET framing (private)
    │   │   ├── commlib.lua           CPSeries class, per-model protocol state machine
    │   │   │                         (private to this plugin, formerly
    │   │   │                         Developer/Modules/cpseries_commlib.lua)
    │   │   └── runtime.lua           Application layer: TCP connection lifecycle,
    │   │                             Controls wiring (formerly Developer/Modules/cpseries.lua)
    │   ├── SubharmonicSynth/         Bass enhancement / subharmonic-style boost for
    │       ├── plugin.lua            LFE/Sub channels (incorporated 2026-07-29 from an
    │       │                         external contribution, restructured onto this
    │       │                         repo's own convention -- see the Continuity notes
    │       │                         below for the full incorporation story)
    │       ├── info.lua
    │       ├── controls.lua          No properties.lua -- GetProperties() returns {}
    │       ├── layout.lua            directly in plugin.lua, same as DolbyFader
    │       └── runtime.lua           Sub-path LPF+PEQ+Gain / dry-path Gain / 2->1 Mix;
    │                                 guarded one-time init sets SubGain/QFactor/Cutoff
    │                                 defaults (the original's per-control `DefaultValue`
    │                                 field isn't a real Q-SYS key, so those defaults
    │                                 never actually applied pre-incorporation)
    │   ├── CP Series Emulator/       Fakes a Dolby processor over TCP for
    │       ├── plugin.lua            bench-testing Dolby CPSeries Control without
    │       ├── info.lua              hardware (added 2026-07-31). Model property (5
    │       ├── properties.lua        choices) + Status/Status.Led indicator. The
    │       ├── controls.lua          only plugin here with a 7th file: protocol.lua,
    │       ├── layout.lua            split out of runtime.lua so it could briefly be
    │       ├── protocol.lua          shared with a standalone Control Script version
    │       └── runtime.lua           (removed the same day once this plugin covered
    │                                 the same job with less to maintain -- see
    │                                 docs/continuity-notes.md); kept as its own
    │                                 private file rather than merged back into
    │                                 runtime.lua. Not #include'd from Dolby CPSeries
    │                                 Control's own private models.lua/protocol.lua --
    │                                 this plugin keeps its own copy of the same wire
    │                                 tables, kept in sync by hand.
    │   ├── StateTrigger/             Inverse of MultiFlip-Flop: Boolean State_n in,
    │   │   ├── plugin.lua            Trigger Out_n out (added 2026-07-31, given
    │   │   ├── info.lua              a Channels property the same day, 1-256, same
    │   │   ├── properties.lua        convention as MultiFlip-Flop's own InputCount,
    │   │   ├── controls.lua          plus a Detection property: enum On/Off/Both,
    │   │   ├── layout.lua            default Both). Runtime loops Channels times,
    │   │   └── runtime.lua           one EventHandler per pair, re-reads
    │   │                             Controls["State_"..t].Boolean (not the handler's
    │   │                             own ctrl arg -- MultiFlip-Flop convention) and
    │   │                             fires Controls["Out_"..t]:Trigger() per Detection.
    │   └── DolbyKnobTest/            Scratch/test plugin (added 2026-07-31), not
    │       ├── plugin.lua            production. v1.0.0.3: a single native
    │       ├── info.lua              ControlType="Knob" control (GainDb,
    │       ├── controls.lua          ControlUnit="dB", -90..10) -- no
    │       └── layout.lua            QKnob/Text wrapper, no shared/qknob.lua
    │                                 dependency, no runtime.lua (deleted,
    │                                 nothing left to run). DolbyFader itself
    │                                 is untouched by this.
    ├── shared/                       Code #include'd by more than one plugin
    │   ├── qknob.lua                 QKnob class: text control ⇄ value/position/string sync (self-contained, plain metatables, no external OOP base); #include'd by dolbyfader.lua and Dolby Sweep's own runtime.lua (DolbyKnobTest no longer #include's this since v1.0.0.3 -- switched to a native Knob control)
    │   └── dolbyfader.lua            Dolby fader runtime (dB ⇄ 0.0-10.0 Dolby scale); #include'd by DolbyFader and Dolby CPSeries Control
    ├── host-emulator/                The Q-SYS Designer host stub, its own module
    │   │                             (added 2026-07-29, split out of Developer/tests/)
    │   │                             so it reads as a standalone unit distinct from
    │   │                             `Dolby CP Emulator/` (that one emulates the Dolby
    │   │                             processors, this one emulates the Q-SYS Lua host)
    │   ├── qsys_stub.lua             Stand-in for the Q-SYS host globals (Controls,
    │   │                             Timer, TcpSocket, TcpSocketServer [added
    │   │                             2026-07-31, for testing cp-series-emulator/
    │   │                             above], Properties, System); every test file
    │   │                             adds this directory to its own package.path
    │   │                             alongside Developer/tests/ itself.
    │   └── components/                One file per Q-SYS embedded component Type
    │                                 (mixer.lua, sine.lua, gain.lua, filter_lowpass.lua,
    │                                 equalizer_parametric.lua, stepper.lua), each
    │                                 returning that Type's exact audio pin names for
    │                                 GetWiring validation (qsys_stub.lua's
    │                                 check_wiring); loaded lazily via this file's own
    │                                 directory (debug.getinfo), not package.path
    │                                 Standing convention: a new plugin needing a host
    │                                 feature this stub doesn't model yet gets that
    │                                 feature looked up in Q-SYS Help first (see the
    │                                 file's own header comment), the stub extended to
    │                                 add it -- never guessed, never worked around in
    │                                 the plugin or the test instead
    └── tests/                        Lua 5.3 test suite, no framework (see its README)
        ├── run.sh                    Syntax pass over every source, then every test
        ├── harness.lua               Path resolution + check counter
        ├── test_modules.lua          CPSeries class, loaded straight from
        │                             Developer/plugins/Dolby CPSeries Control/
        │                             {models,protocol,commlib}.lua
        ├── test_dist_cpseries.lua    Root CP Series distributable, both host passes
        ├── test_dist_fader.lua       Root Dolby Fader distributable, both host passes
        ├── test_dist_sweep.lua       Root Dolby Sweep distributable, both host passes
        ├── test_dist_flipflop.lua    Root MultiFlip-Flop distributable, both host passes
        ├── test_dist_subharmonic.lua Root SubharmonicSynth distributable, both host passes
        ├── test_dist_cpseriesemulator.lua Root CP Series Emulator distributable
        │                             (added 2026-07-31): definition pass, and a
        │                             runtime pass per model exercising the built
        │                             plugin's own server/Status wiring end to end
        ├── test_dist_statetrigger.lua Root StateTrigger distributable (added
        │                             2026-07-31, 19 checks): definition pass
        │                             (incl. Detection property's own default/
        │                             Choices), control/layout count for a given
        │                             Channels, and runtime checks per Detection
        │                             value (On/Off/Both) that each State_n only
        │                             ever fires its own Out_n, gated by the
        │                             selected edge(s)
        ├── test_dist_dolbyknobtest.lua Root DolbyKnobTest distributable (added
        │                             2026-07-31, rewritten 2026-08-01 for the
        │                             v1.0.0.3 single-native-Knob shape, 11
        │                             checks): definition pass (control count,
        │                             ControlType/ControlUnit/Min/Max, layout),
        │                             plus a runtime-pass load check -- no sync
        │                             assertions, v1.0.0.3 has no runtime logic
        ├── test_stress.lua           Stress/fuzz over all five plugins: asserts invariants
        │                             (nothing throws, nothing publishes nil, every written
        │                             value stays in range) rather than exact values. Fixed
        │                             math.randomseed so a failure reproduces; carries its
        │                             own anti-vacuity checks (see its README section)
        └── wire_trace.lua            Diffs two builds by the bytes they put on the wire
```

**`Developer/` holds the source of truth.** The root-level `.qplug` files are
single-file distributable builds produced from `Developer/plugins/<Name>/
plugin.lua` (and its `#include`d siblings) by QSC's own `PLUGCC.exe`, run via
`.github/workflows/build-qplug.yml` (see "Developer workflow" below) — never
hand-edit them, or they drift from `Developer/` and the next rebuild silently
discards the hand edit. The four root `.qplugx` files are packaged builds
produced from those same `.qplug` files by `.github/workflows/build-qplugx.yml`
(or Designer's own "Save as compiled plugin") — also never hand-edited;
regenerate the same way after any `.qplug` rebuild.
