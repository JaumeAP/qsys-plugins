---
name: changelog-rules
description: MUST use whenever a file contains a "## Changelog" section or changelog work is requested. This is mandatory for all changelog work. Covers semantic versioning, entry format, the accumulate-in-memory-until-push workflow, retention/dedup rules, and which files are excluded (pure rule/prompt files defining behavior for other files, with no logic of their own).
---

# Changelog Rules

Standard for maintaining changelog entries across all projects.

## Scope

- Auto-activate if file contains `## Changelog`. New files: ask once, remember.
- Applies to all text files (`.md`, code comments, release notes, skill files).
- Applies: functional code libraries, skills, and any file with real content/logic.
- Excluded: files whose sole purpose is defining behavior/rules for OTHER files (e.g. project profile, prompts). No changelog there; history lives in version control.
- This skill file (changelog-rules) is self-exempted: it is the standard's own reference implementation, so it carries a changelog to demonstrate the format it defines.

## Format

```
## Changelog

- **v0.0.0** (YYYY-MM-DD) - Summary
  - type: Description
```

- **Version:** Semantic versioning `v0.0.0`
- **Date:** ISO 8601 `YYYY-MM-DD`
- **Summary:** One-line description of the release/set of changes
- **Types:** `bugfix`, `feature`, `refactor`, `docs`, `chore`, `perf`, `security`
- **Entries:** Short, action-focused descriptions per change type

### Version Increment Logic

Default: infer increment level (patch/minor/major) from number and importance of changes.

- **Patch (v0.0.X):** Bug fixes, small docs updates, security patches
- **Minor (v0.X.0):** New features, non-breaking refactors, performance improvements
- **Major (vX.0.0):** Breaking changes, major rearchitecture, API changes

Do not ask for increment level unless user specifies explicitly.

## Workflow

### Accumulation (In Memory)

- Do not write changelog entries to disk mid-session; write the accumulated
  entries just before each `git push` (push is autonomous — see the repo
  `CLAUDE.md` Git rules). The old "wait for a save/desa/guarda keyword" gate
  is removed (2026-07-14): the changelog is now written as part of the push
  flow, not on a manual keyword.
- Presenting file for verification does not count as writing it out
- Confirm accumulation silently after each change
- Keep entries in memory across multiple edits within a single session

### On Push

Just before each `git push`:

1. **Verify:** Changelog entry accumulated, version incremented per logic above, no conflicts
2. **Update file:** Add entry, maintain chronological order (newest first)
3. **Present:** Only if file is renderable (`.md`, `.html`) and not excessively long; no inline text
4. **Announce:** Version, date, entries added in active conversation language
5. **Summary:** One-line summary of all changes made; if no changes, announce nothing

### Maintenance

- **Retention:** Keep 10 most recent entries. Remove older entries silently on each push.
- **Deduplication:** Do not add duplicate entries for the same change.
- **Coherence:** Each entry must trace to a verifiable change; do not add placeholders or "TBD" entries.

## Placement

- **If `## Changelog` at top:** Move to end before any operation
- **If `## Changelog` at end or missing:** Append new entries at top of section, maintaining newest-first order
- **Filename:** Rename with version suffix only if filename already contains a version suffix (e.g., `SKILL.md` -> `SKILL-v1.0.0.md` only if original had version)

## Examples

### Good

```markdown
- **v2.1.0** (2026-06-30) - Added async I/O support
  - feature: Async file read/write via asyncio thread pool
  - perf: Reduced I/O latency by 40% on large files
  - docs: Updated README with streaming examples
```

### Avoid

```markdown
- **v2.0.999** (2026-06-30) - Various improvements  # Too vague
  - TBD                                              # No content
  - bugfix: Fixed stuff                              # Not specific
```

## Special Cases

### First Changelog Entry

If file has no existing `## Changelog` section:

1. Create section at end of file
2. Add initial entry with appropriate version (usually `v0.1.0` or `v1.0.0`)
3. Ask once if adding changelog to new file types; remember preference

### Breaking Changes

Always bump major version. Note breaking change explicitly:

```markdown
- **v3.0.0** (2026-06-30) - Breaking API changes
  - breaking: Removed deprecated `old_function()` -- use `new_function()` instead
  - feature: New modular architecture for extensibility
```

### Pre-release Versions

Optional; use only if explicitly requested:

```markdown
- **v2.0.0-beta.1** (2026-06-30) - Beta release for testing
- **v2.0.0-rc.1** (2026-06-30) - Release candidate
```

## Integration with Coding Rules

Changelog accumulation is governed by **Critical Rules > Verification** and this skill:

- Critical Rules dictate: before writing the changelog to disk, verify the entry is accumulated
- This skill dictates: do not write mid-session, accumulate silently, flush just before the push
- Both rules align: the push flow triggers verification and disk write in one step

No contradiction; they work together.

## Changelog

- **v1.1.0** (2026-07-06) - Converted standard to skill format
  - refactor: Repackaged CHANGELOG-RULES.md as SKILL.md with frontmatter for auto-discovery
  - docs: Merged "Scope of Applicability" into main Scope section
  - docs: Self-exemption note moved into Scope

- **v1.0.1** (2026-07-05) - Fixed self-contradiction in Scope of Applicability
  - docs: Excluded clause now scoped to files defining rules for OTHER files
  - docs: File explicitly self-exempted as the standard's own reference implementation

- **v1.0.0** (2026-06-30) - Initial standalone release
  - feature: Separated Changelog Rules from coding.md into dedicated file
  - feature: Added format, workflow, examples, special cases sections
  - docs: Clarified integration with Critical Rules; no contradiction
  - docs: Added version increment logic and breaking change guidance
