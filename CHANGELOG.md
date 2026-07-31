# Changelog

## Changelog

- **v0.1.0** (2026-07-31) - Skills tooling overhaul and changelog tracking started
  - feature: Verified and corrected recommended-skills.txt and programming-optional-skills.txt against real sources (WebFetch), fixed several dead/wrong pointers
  - feature: Added Language-specific optional skills section (lua, swift, cpp, swiftui-specialist)
  - feature: Resolved caveman/using-superpowers self-announcement contradiction, added find-skills/skill-security-auditor pairing
  - feature: Made github-rules and session-close routine detect git presence and degrade gracefully when absent
  - chore: Moved karpathy-guidelines from mandatory to programming-optional-skills.txt
  - chore: Reinstalled changelog-rules and started this file
  - feature: Wired changelog-before-commit into CLAUDE.md, auto-detected (no-op if changelog-rules isn't installed)
