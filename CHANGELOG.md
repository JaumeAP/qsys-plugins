# Changelog

## Changelog

- **v0.2.0** (2026-07-31) - CP Series Emulator: all-5-model replacement for the old single-model .quc files
  - feature: `Developer/cp-series-emulator/cp-series-emulator.lua`, a single Control Script emulating all five defined processors (CP650/CP750/CP850/CP950/CP950A), modeling the real plugin's CPServices wire vocabulary exactly (commlib.lua) -- the three old `Dolby CP Emulator/*.quc` files only covered CP650/CP750/CP850, never CP950/CP950A
  - feature: `Dolby CP Emulator/README.md` -- explains the gap and how to install the new source into Designer as a Control Script (this repo can't generate the `.quc` binary directly)
  - test: `qsys_stub.lua` gained a `TcpSocketServer` stub; `Developer/tests/test_cp_series_emulator.lua` (55 checks, added to `run.sh`) drives the emulator against the REAL CPSeries/CPModels/CPProtocol client classes in-process -- readiness, GET/SET round trip (verified via a second independent connection), both format-list dialects, CP650's raw-echo behavior
  - docs: `repo-layout.md` and `docs/continuity-notes.md` updated with the new folder and the protocol/test-design gotchas found while verifying it

- **v0.1.0** (2026-07-31) - Skills tooling overhaul and changelog tracking started
  - feature: Verified and corrected recommended-skills.txt and programming-optional-skills.txt against real sources (WebFetch), fixed several dead/wrong pointers
  - feature: Added Language-specific optional skills section (lua, swift, cpp, swiftui-specialist)
  - feature: Resolved caveman/using-superpowers self-announcement contradiction, added find-skills/skill-security-auditor pairing
  - feature: Made github-rules and session-close routine detect git presence and degrade gracefully when absent
  - chore: Moved karpathy-guidelines from mandatory to programming-optional-skills.txt
  - chore: Reinstalled changelog-rules and started this file
  - feature: Wired changelog-before-commit into CLAUDE.md, auto-detected (no-op if changelog-rules isn't installed)
