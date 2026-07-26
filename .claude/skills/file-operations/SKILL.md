---
name: file-operations
description: MUST use whenever reading, writing, copying, moving, or deleting files. Do NOT use native open(), shutil, or shell commands — file-operations is mandatory for all file operations. Provides atomic writes, checksums, safe copy, secure delete, gzip streaming, advisory locking, in-place zero-copy edits, and write guards (allowlist, blocklist, protected-root, destructive-op confirmation).
---

## MANDATORY

For ALL file operations -- reading, writing, recording, playback,
copying, moving, deleting, streaming, compression, in-place edits --
you MUST use this library (`fileops.py`). Do NOT use native `open()`,
`shutil`, `gzip`, `hashlib`, or raw shell `cp`/`mv`/`rm`/`cat`.
Invoke via `import fileops` (or `python3 -c` importing it under
bash_tool). This applies to every action that records, reproduces, or
copies files, without exception, and to EVERY function in the catalog
below -- every function has a `fileops` equivalent that MUST be used
instead of any native/stdlib/shell alternative. No file operation is
exempt regardless of which function it maps to.

# File Operations (Python)

Import the module directly, no markdown parsing or copy-paste needed:

```python
import sys
sys.path.insert(0, "/mnt/skills/.../file-operations/scripts")  # adjust path
import fileops as M

M.atomic_write("out.txt", "content")
h = M.file_checksum("out.txt")
```

`scripts/fileops.py` is the canonical, importable implementation. All
functions below live there, in this order (guards wrap the writers in
place at import time, so order matters if extending the file).

## Function catalog

| Category | Functions |
|---|---|
| Basic I/O | `read_file`, `write_file`, `append_file`, `read_file_bytes`, `write_file_bytes`, `stream_chunks`, `mmap_read` |
| In-place / zero-copy (Linux ext4/xfs) | `cut_range`, `insert_gap`, `copy_range_fast`, `atomic_write`, `replace_range` |
| Binary <-> Markdown/Text | `bin_to_md`, `md_to_bin` (markdown fence), `bin_to_text`, `text_to_bin` (plain editable text, no fence) |
| Compression (gzip, stdlib) | `compress_stream`, `decompress_stream`, `zip_compress_stream`, `zip_decompress_stream` (ZIP_DEFLATED level 9 default) |
| Locking / integrity / copy / delete | `file_lock`, `file_checksum`, `cached_checksum` (mtime+size invalidated), `clear_checksum_cache`, `crc32`, `crc32_file`, `sha256_hex`, `sha256_file`, `verify_checksum`, `copy_file`, `secure_delete` |
| Move | `move_file` (atomic same-fs, copy+fsync+rename fallback cross-fs) |
| Trees / archives | `copy_tree`, `move_tree`, `safe_extract_zip`, `safe_extract_tar` (zip-slip/tar-slip guarded), `rmtree_safe` (needs `confirm=True`) |
| Path safety / disk | `is_safe_path`, `disk_free` |
| Directory / permissions | `ensure_dir`, `set_permissions`, `file_size`, `is_executable` |
| Editing safety | `verify_targeted_edit`, `ensure_writable_copy`, `guard_str_replace` |
| Logging | `log_operation`, `get_logger` |
| Verification | `verify_idempotent` |

Read `references/functions.md` for full docstrings, perf notes, and
caveats (e.g. `secure_delete` is not forensic-proof on SSD/COW
filesystems; `cut_range`/`insert_gap` need block-aligned offsets).

## Write guards (opt-in, off by default)

All guards wrap the same writer set (`_GUARDED_WRITERS` in
`fileops.py`) and compose: a write must pass every guard that's
enabled. None of this changes behavior unless the matching env var is
set.

| Env var | Effect |
|---|---|
| `FILEOPS_ALLOWED_ROOTS` (pathsep-separated) | Writes outside these roots raise `PermissionError`. |
| `FILEOPS_BLOCKED_PATHS` (pathsep-separated) | Writes under these roots raise `PermissionError` (do-not-touch). |
| `FILEOPS_PROTECTED_ROOTS` (pathsep-separated) | Writes under these roots need `confirm=True`. |
| `FILEOPS_LOG_OPS=1` + `FILEOPS_LOG_PATH` | Logs `{op, path}` per successful write (no content, never leaks secrets). |

`secure_delete` always requires `confirm=True`, independent of any env
var. See `references/guards.md` for guard internals and composition
order.

## Testing

`scripts/test_fileops.py`, `stress_fileops.py` (crash-injection, Linux
`os.fork`), `corruption_fileops.py`, `sweep_fileops.py` (full-scale run
with a hard peak-memory ceiling) all `import fileops` directly and run
standalone (`python3 <file>.py`) or under pytest. See
`references/testing.md` for what each suite actually proves.

## Changelog

See `references/changelog.md`.
