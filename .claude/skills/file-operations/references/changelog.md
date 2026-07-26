# Changelog

- **v1.2.0** (2026-07-05) - Restructured for progressive disclosure
  - refactor: split monolithic 1609-line SKILL.md into SKILL.md (<150
    lines) + references/ (functions, guards, testing, changelog)
  - fix: real importable `scripts/fileops.py` module -- replaces the
    "extract code from markdown via regex" pattern the tests
    previously relied on (which also pointed at a filename,
    `file-operations-skill.md`, that never matched `SKILL.md`)
  - fix: title no longer claims "Audio Streaming" -- no audio
    functions existed in the source
  - test scripts (`test_fileops.py`, `stress_fileops.py`,
    `corruption_fileops.py`, `sweep_fileops.py`) now `import fileops`
    directly instead of parsing markdown at runtime
  - verified: all four test scripts pass against the extracted module
    in this container

- **v1.1.0** (2026-07-04) - New guards, wired logging, perf and test fixes
  - feature: Write blocklist guard (do-not-touch paths, opt-in FILEOPS_BLOCKED_PATHS)
  - feature: Protected-root confirm guard (require confirm=True under FILEOPS_PROTECTED_ROOTS)
  - feature: verify_idempotent helper for setup/migration scripts
  - feature: Operation logging wired into all guarded writers (opt-in FILEOPS_LOG_OPS)
  - perf: Default block_size 64KB to 1MB (stream_chunks, file_checksum, compress_stream, decompress_stream)
  - perf: secure_delete reuses one random buffer per pass instead of per block
  - perf: sweep_all compress sample uses level=1 (test-only; production default unchanged)
  - perf: Crash-injection stress iterations 30 to 10 for routine runs
  - bugfix: Protected guard now forwards confirm to the wrapped function when accepted
  - bugfix: atomic_write crash test now asserts an exception was actually raised

- **v1.0.0** (2026-07-04) - Guardrails, move, logging added
  - feature: Write allowlist guard (opt-in, deterministic path enforcement)
  - feature: Destructive op confirmation guard on secure_delete
  - feature: str_replace move guard (blocks delete+reinsert relocation)
  - feature: str_replace no-loss verification (verify_targeted_edit)
  - feature: Read-only copy-before-edit guard (ensure_writable_copy)
  - feature: Atomic cross-filesystem move_file (EXDEV fallback)
  - feature: Directory/permissions/size helpers (ensure_dir, set_permissions, file_size, is_executable)
  - feature: Operation logging (log_operation JSON lines, get_logger)
  - bugfix: secure_delete self-tests updated for confirm=True requirement
