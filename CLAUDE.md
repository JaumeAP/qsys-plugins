# CLAUDE.md — common rules (identical across all my projects)

Every section of this file is IDENTICAL in every one of my repos — copy it
verbatim into a new project, unchanged — EXCEPT the final "Project-specific
rules" section: that one holds this repo's own docs-to-read/coding
conventions and gets replaced with the new repo's own content, everything
above it stays untouched.

## Response style (always, every session)

Token economy top priority. Answer first, no preamble. Telegraphic, drop
articles/filler/nuance, fragments over sentences, minimum tokens preserving
info, compress aggressively, grammar may break if meaning holds. Code,
commands, paths, params stay literal. Proper nouns/technical
terms: original language unless misleading, clarity over purism. No
servility, contradict directly when wrong, never agree to appease, challenge
politely if disagree, never invent, say if unsure. Assume technical
competence, no basic intros, preserve files/configs/decisions/params
literally, apply corrections immediately within session. Never rename an output file without explicit
request. One question per reply except technical tasks needing several. No
postamble, no unsolicited closing offers/summaries/tangents.

Conditional: length under fifty words unless code snippets, multi-step
technical tasks, or teaching requested, then expand as needed but stay
focused. Verify with search first for changing facts (prices, versions,
charges, events); verify before critical or irreversible actions.

Multi-step tool sequences (git commit/push, multi-file edits, test runs):
announce each step as a bare 1-3 word action, e.g. "Commit.", "Push.",
"Tests." No sentences, no explaining what the command does, why, or its
mechanism/internals — bare label only, before or after, not both.

**Deference to `caveman` (2026-07-30, explicit user request, reversing the
same day's earlier "this section wins" note).** The `caveman` skill
(JuliusBrussee/caveman) governs reply language and formatting now: it
replies in the user's own dominant language rather than a fixed Catalan
mandate, and it is not constrained by a numbered-lists-only rule, a
bold/em-dash/ellipsis/header/table ban, or a mandatory leading "Rebut:"
line — all of those requirements are removed from this section for that
reason. `caveman` stays installed with its sibling tools (caveman-commit,
caveman-review, caveman-compress, caveman-stats) as the actual source of
truth for compression/format/language, not just a compression add-on to
rules stated here. Note: the repo's own `check-reply-format.sh` and
`reply-format-preflight.sh` hooks still mechanically enforce the removed
Rebut-line/format rules regardless of this text change — they read their
own hardcoded logic, not this file — so removing the rule here does not by
itself change enforced behavior; the hooks need their own separate edit or
removal to match.

## Portable skills (installed with the config)

These generic skills travel with this file and the rest of the `.claude/`
config (see `.claude/config-export-import.md`). `file-operations` and
`github-rules` are mandatory/blind-copy on import into
another repo — the only two skills still bundled as files at all.
`find-skills` moved to fetch-on-demand only 2026-07-28 (explicit user
request), after its own longer mandatory/optional/bundled history
below: no longer bundled as a file, listed instead in
`.claude/recommended-skills.txt` (`find-skills -> vercel-labs/skills`)
like any other unbundled recommendation, fetched live via
`npx skills add vercel-labs/skills -s find-skills` by whoever wants it —
a state it had already passed through once before this same day,
reverted at the time, now the settled choice (see the history note
below). This repo's own local copy of `find-skills` was deleted
outright 2026-07-29 (explicit user request) — `.claude/skills/
find-skills/` removed from disk, repo-local only, deliberately NOT
added to `.claude/removed-files.txt` (that would mechanize pruning it
from every other repo importing this bundle in the future, which
wasn't asked for and isn't warranted here — `find-skills` already
isn't shipped as a bundled file per the paragraph above, so there's
nothing export-side this deletion needed to affect). It had been meant
to stay on disk but disabled via a `skillOverrides: {"find-skills":
"off"}` entry in `.claude/settings.local.json` (gitignored) — but that
settings file was never actually present in this checkout, so the
local copy was live (not disabled) the whole time until this deletion.
Pointers
only, not summaries — same
drift-safety reason as above; each skill is the authority on its own topic,
invoke it when the task calls for it:

1. `github-rules` (`.claude/skills/github-rules/SKILL.md`) — portable GitHub
   PR conventions (workflow shape, reading `pull_request_read` results,
   merge mechanics); generalized 2026-07-27 from an earlier repo-specific
   skill of the same name. Originally: must never encode a standing
   auto-merge policy, since a portable file installs into every repo it's
   imported into, so a rule like that written here would silently apply
   everywhere, not just where someone actually agreed to it. Relaxed
   2026-07-29, explicit user request, after being shown that exact
   consequence and choosing it anyway: the skill now carries a dated,
   attributed standing authorization to open a PR at session close when
   the branch has unmerged commits and none exists, then merge it once
   clean. The reasoning behind the original prohibition is unchanged and
   still applies to anything BEYOND that one authorization — a policy
   written there without a named source and date, or one covering more
   than the routine open/merge cycle, is still the thing to refuse. What
   made this case different is that the authorization is recorded rather
   than self-granted, which is also what lets it satisfy (not bypass) a
   calling environment's own PR-creation gate.

(`git-rules` removed from the portable bundle 2026-07-25, explicit user
request — deleted from `.claude/skills/`, its `skillOverrides` entry
dropped from `settings.json`, and its path added to
`.claude/removed-files.txt` so future imports of an older bundle prune it
from target repos too. Git workflow now follows plain judgement +
the rest of this file's rules, not a dedicated skill.)

(`changelog-rules` and `find-skills` briefly removed from the portable
bundle 2026-07-27, explicit user request, then restored from git history
2026-07-28, also explicit user request. `changelog-rules` stayed optional
from there on, disabled locally alongside `find-skills` once that one
also went optional later 2026-07-28 — until `changelog-rules` was
deleted from the portable bundle entirely a second and final time, also
2026-07-28, also explicit user request: same treatment as `git-rules`
above (`.claude/skills/changelog-rules/` deleted, its now-moot
`skillOverrides` entry dropped from `settings.local.json`, its path
added to `.claude/removed-files.txt`). Changelog work now follows the
repo-wide conventions stated directly where needed, not a dedicated
skill — see the version-history/breaking-change note under "Plugin
structure/naming convention" below.
`find-skills` took a longer road of its own — removed from the
bundle again the same day as a `recommended-skills.txt` fetch-on-demand
entry, then, after weighing whether that was actually worth it, made
mandatory/always-present again the same day, then superseded later the
same day, also explicit user request: moved to optional (still a
bundled file at that point) instead. Superseded once more, also
2026-07-28, also explicit user request: moved off the bundled-file path
entirely, back to fetch-on-demand-only via `recommended-skills.txt` —
ending up back where its first fetch-on-demand attempt left off. Its
local copy went one step further 2026-07-29, also explicit user
request: deleted outright rather than kept disk-side and disabled, see
above.)

**Find Skills**: `find-skills`, imported from `vercel-labs/skills`
(`skills/find-skills/SKILL.md`) — discovers and installs third-party
skills via the `npx skills` CLI, #1 by install count on skills.sh at
import time. Note its own workflow can
install other skills straight from that ecosystem, bypassing this
repo's own skill-creator/config-ingest governance — worth keeping in
mind wherever it ends up. Fetch-on-demand only now (see above), not a
bundled file — no longer tracked in `skills-lock.json` in the export
either, since that file existed specifically to carry `find-skills`'
own installation provenance along with the bundled copy; a target repo
fetching it fresh via `npx skills add` generates its own lock entry
instead.

(`file-operations` needs no pointer here beyond the numbered list above
— its own description triggers it by context when there's file I/O to
do.)

**Which additional skills travel on export is defined in
`.claude/scripts/export-config-skill.sh`** — not repeated here, to avoid
two places that can drift out of sync. Anything installed here but not in
that script's copy list stays local; its name/source is kept in
`.claude/recommended-skills.txt` (plain list, one name per line,
updated by hand) for a target repo to fetch itself if wanted — that
file itself always travels on export.

**Skill creation/extension.** Any skill creation or extension (a new
`SKILL.md`, or a content/frontmatter change to an existing one — this
applies regardless of whether the skill itself is repo-specific or
portable) goes through the `skill-creator` skill's process, not a plain
manual edit (2026-07-20 standing rule). Mechanized best-effort by
`.claude/hooks/skill-creation-reminder.sh` — a non-blocking reminder on
every `Write`/`Edit` to a `SKILL.md`; it can't verify skill-creator was
actually invoked, so it can't hard-block, same honest limitation as
`config-ingest-reminder.sh`. The `writing-skills` skill (from the
`obra/superpowers` bundle) was installed 2026-07-30 alongside the rest
of that bundle, then removed the same day (explicit user request) once
it turned out to prescribe a competing TDD-based process for this same
action, conflicting with `skill-creator`; also dropped from
`recommended-skills.txt`. `skill-creator` remains the sole mandated
process here.

## Session continuity

**Long-session hygiene.** There's no reliable way to measure exact chat
length / token budget from inside a turn, so this is heuristic: when signs of
a long session appear (many turns, lots of accumulated work, or a
context summarization/compaction has clearly happened), proactively suggest
continuing in a fresh chat — don't wait to be asked. Rationale: long
sessions get lossy (early detail blurs on compaction).

**"Tanca" always means end the session.** A user message that is just
"tanca" (bare, no other object attached) always means "tanca sessió" — end
the current session — never "close/drop this topic/investigation" or
anything else. Before signaling the session is closed: run plain `git
status` (not `--short`) -- it reports the current branch and the
clean/dirty state together, so a separate `git branch --show-current`
call adds nothing -- then `git log --oneline -1` for the last commit;
one line is enough to confirm it, not a longer history. Say plainly
what's left uncommitted/unpushed if anything is -- and before signaling
closed, also check whether the current branch has an open PR sitting at
`mergeable_state: clean`; if so, merge it as part of this same close
routine per `github-rules`' merge-automation default, don't leave it for
the user to ask separately. If there's an open
question or unfinished work worth a future session picking up, save a
note of it in this file's Project-specific rules section first (as its
own dated entry) so the next session doesn't have to re-derive it from
scratch.

## Project-specific rules

### What this repo is

A collection of **QSC Q-SYS plugins** written in **Lua**, targeting Dolby
cinema audio processors (CP650 → CP950 series) and general utility components.
Plugins run inside **Q-SYS Designer** on QSC audio DSP cores. There is no build
system, package manager, or CI here — plugins are authored in Lua, tested in
Q-SYS Designer's emulator, and distributed as `.qplug` / `.qplugx` files.

There *is* a small test suite under `Developer/tests/` (added 2026-07-27):
plain Lua 5.3 — matching Q-SYS Designer's own embedded Lua version, not 5.4
(confirmed 2026-07-27 against Q-SYS Help, which points to the Lua 5.3
Reference Manual for native Lua support) — no framework, run with
`Developer/tests/run.sh`. `.claude/hooks/ensure-lua53.sh` (SessionStart,
added 2026-07-28) checks for `lua5.3`/`luac5.3` on `PATH` and installs the
`lua5.3` package via `apt-get` if missing, best-effort, so a fresh
container has it before `run.sh` is ever invoked; this hook is
project-specific (installs a runtime only this repo's own test suite
needs) and deliberately not part of the portable `.claude/` bundle, per
`config-export-import.md`'s own example of what stays out of the export.
It stubs the
Q-SYS host globals so plugin logic can be driven from a terminal. It does not
replace testing in Designer — it only covers the plugins' own logic, not real
DSP behaviour, timing, or the Designer UI — but it catches regressions before
they reach the bench, and `wire_trace.lua` in there diffs two builds by the
bytes they put on the wire, which is the tool to use after any refactor.

Author/contact history in the sources: `james.puig@dolby.com` / Jaume Puig
(Barcelona).

### Repository layout

```
.
├── README.md                         Short plugin catalog
├── .vscode/settings.json             Associates *.qplug with the Lua language
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
│   │                                 all four .qplugx built 2026-07-27 via
│   │                                 .github/workflows/build-qplugx.yml
│   │                                 (GitHub Actions, windows-latest),
│   │                                 replacing the old stale
│   │                                 "Dolby CPSeries Control V2.2.qplugx"
│   │                                 (last hand-compiled at v2.2, now removed).
│   │                                 Never hand-edited; regenerate via the
│   │                                 workflow (or Designer's "Save as
│   │                                 compiled plugin") after any .qplug rebuild.
│   └── SubharmonicSynth.qplug        (v0.6, added 2026-07-29) No .qplugx yet --
│                                     not run through build-qplugx.yml/the
│                                     encryption tool since being incorporated.
│
├── Dolby CP Emulator/                Q-SYS User Components (.quc) that emulate
│   ├── CP650 Emulator.quc            real Dolby processors for bench testing
│   ├── CP750 Emulator.quc
│   └── CP850 Emulator.quc
│
├── vendor/                            Read-only reference material (git submodules) —
│   │                                 `git submodule update --init --recursive` after
│   │                                 cloning if empty; never edit contents, it's all
│   │                                 upstream's
│   ├── qsys-plugins/                  QSC's own org (confirmed: support contact
│   │   │                             qsyscontrolfeedback@qsc.com in each README)
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
    │   └── SubharmonicSynth/         Bass enhancement / subharmonic-style boost for
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
    ├── shared/                       Code #include'd by more than one plugin
    │   ├── qknob.lua                 QKnob class: text control ⇄ value/position/string sync (self-contained, plain metatables, no external OOP base); #include'd by dolbyfader.lua and Dolby Sweep's own runtime.lua
    │   └── dolbyfader.lua            Dolby fader runtime (dB ⇄ 0.0-10.0 Dolby scale); #include'd by DolbyFader and Dolby CPSeries Control
    ├── host-emulator/                The Q-SYS Designer host stub, its own module
    │   │                             (added 2026-07-29, split out of Developer/tests/)
    │   │                             so it reads as a standalone unit distinct from
    │   │                             `Dolby CP Emulator/` (that one emulates the Dolby
    │   │                             processors, this one emulates the Q-SYS Lua host)
    │   ├── qsys_stub.lua             Stand-in for the Q-SYS host globals (Controls,
    │   │                             Timer, TcpSocket, Properties, System); every
    │   │                             test file adds this directory to its own
    │   │                             package.path alongside Developer/tests/ itself.
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


### Plugin development reference

The Q-SYS plugin definition/runtime API reference, the full Lua extension
API table, module patterns, the mandatory naming convention, `.qplug` vs
`.qplugx`, the PLUGCC build workflow, and edit-time conventions all moved to
`.claude/rules/qsys-plugin-development.md` (2026-07-30, explicit user
request) — a path-scoped rule (Claude Code's official mechanism, see
code.claude.com/docs/en/memory) that loads only when Claude is actually
touching `Developer/plugins/**`, `Developer/shared/**`, a root `.qplug`/
`.qplugx`, or a `build-qplug*.yml` workflow, instead of unconditionally on
every session regardless of task. Read that file directly whenever editing
plugin source; nothing in it changed content-wise, only where it lives.

### Git

- `Developer/Modules/class` (a vendored OOP base) was the last submodule and
  was removed; five new ones were added 2026-07-27 under `vendor/` — four
  from QSC's own `qsys-plugins` org (`BasePlugin`, `ExamplePlugin`,
  `PluginCompile`, `PluginEncryptionTool`) and one third-party
  (`q-sys-community/q-sys-plugin-guide`, not QSC) — all read-only reference
  material (see "Repository layout" and "Plugin structure/naming
  convention" above). Same rule as always: commit submodule pointer changes
  deliberately, don't bump one incidentally.
- **No duplicate submodule vendoring (revised 2026-07-27, same day as the
  original fix).** `BasePlugin` and `ExamplePlugin` each declare their own
  nested `PluginCompile` submodule (confirmed via `git submodule status
  --recursive`, same commit both places). This repo first "fixed" that by
  vendoring `PluginCompile` a third time at the top level
  (`vendor/qsys-plugins/PluginCompile`) and keeping submodule init
  non-recursive so the nested copies stayed empty placeholders — that
  avoided the clone cost but kept three separate `.gitmodules`-visible
  copies of the same repo. Superseded same day: the top-level
  `vendor/qsys-plugins/PluginCompile` submodule was removed entirely: it
  contributed nothing `BasePlugin`'s and `ExamplePlugin`'s own nested
  copies don't already provide, once the whole tree is initialized
  recursively. `.claude/hooks/init-submodules.sh` now runs `git submodule
  update --init --recursive`, so a fresh clone gets `PluginCompile`'s
  content solely through the two nested paths
  (`vendor/qsys-plugins/BasePlugin/PluginCompile` and
  `vendor/qsys-plugins/ExamplePlugin/PluginCompile`) — one fewer top-level
  `.gitmodules` entry, same content reachable, no duplication either way.
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

### Continuity notes

(Moved back here 2026-07-27 from a short-lived `HANDOFF.md` split: a
separate file isn't auto-loaded at session start the way CLAUDE.md is, so
it's a worse fit for exactly this purpose — `HANDOFF.md` deleted.)

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
