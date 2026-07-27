# Handoff notes

Session-to-session continuity for this repo only. Not part of the portable
`.claude/` config bundle (see `.claude/config-export-import.md`) —
`export-config-skill.sh` never references this file, so it never leaves
this repo.

## Open: Button control `.Value` type unresolved (2026-07-27)

Unclear whether a Button control's `.Value` is a Lua boolean or a number
during a live EventHandler read, versus only defaulting to `false` in its
untouched, never-interacted-with state. Evidence from QSC's own Roku and
ShureAxient plugins didn't settle it either way. 8+ numeric-comparison call
sites across `dolbyfader.lua`, `cpseries.lua`, `dolbysweep.lua`, and
`MultiFlip-Flop V2.0.qplug` were audited and deliberately left unchanged —
fixing them without proof risked a regression. Resolves permanently with one
check: `type(Controls.SomeButton.Value)` read from a live EventHandler on
real Q-SYS Designer or a CP Emulator bench, neither available so far.

## Open: two unactioned review findings (2026-07-27)

1. `Developer/plugins/MultiFlip-Flop V2.0.qplug`, `Toggle_N`'s handler:
   writes a boolean to `State_N.Value`, then reads it back with a numeric
   `== 1` comparison in the same synchronous call, no host round-trip in
   between. Same open question above, a more fragile instance of it (script
   write immediately followed by script read, not a host-driven read). Not
   fixed.
2. `Developer/Modules/cpseries_commlib.lua:406`: `readData(self,true)` —
   `readData` only takes `self`, so the second argument is always silently
   ignored. Harmless, but misleads a future reader. Not fixed.
