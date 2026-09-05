# Function Reference

Full behavior notes for every function in `scripts/fileops.py`, grouped
in the same order as the module.

## Basic I/O

- `read_file` / `write_file` / `append_file` -- text, whole-file, `pathlib`-based.
- `read_file_bytes` / `write_file_bytes` -- binary, whole-file.
- `stream_chunks(path, size=1MB)` -- generator, bounded memory, any file size.
- `mmap_read(path, offset, length)` -- `length` is required; without it
  `mm.read()` materializes the whole file (same cost as
  `read_file_bytes` plus mmap overhead). Empty file returns `b""`
  (mmap cannot map a zero-length file).

## In-place / zero-copy (Linux, ext4/xfs only)

- `cut_range(path, offset, length)` -- `fallocate(FALLOC_FL_COLLAPSE_RANGE)`.
  Removes a byte range without rewriting the file. Offsets are
  commonly required to be filesystem-block-aligned (4096 bytes).
  Measured ~28x faster than a full userspace rewrite at matched sizes
  (10-200MB), but **not constant-time** -- scales near-linearly with
  tail size past offset (5ms/20ms/73ms at 10/50/200MB, measured).
- `insert_gap(path, offset, length)` -- `fallocate(FALLOC_FL_INSERT_RANGE)`,
  same alignment and scaling caveats as `cut_range`.
- `copy_range_fast(src_fd, dst_fd, count)` -- kernel-side
  `os.copy_file_range`, no userspace buffer. Loops because the syscall
  may copy fewer bytes than requested per call.
- `atomic_write(path, content, durable=True)` -- temp file in same
  dir + `os.replace`. Never leaves a partial target.
  `durable=True`: fsync before rename + fsync the directory, survives
  power loss, ~3.4x slower on a 100MB write (measured).
  `durable=False`: still atomic against readers, but a crash before
  the OS flushes buffers can lose the write. Use only when the write
  is regenerable (caches).
- `replace_range(path, offset, length, new_content, durable=True)` --
  the general case: any offset, any size delta, text or binary. No OS
  primitive covers unaligned edits, so this streams head + new content
  + tail through a temp file via `copy_file_range`, then renames.
  O(n) in bytes after `offset` (no O(1) shortcut exists for unaligned
  edits on any filesystem). Uses raw `os.write`, not a buffered file
  object, for `new_content` -- mixing buffered writes with
  `copy_file_range` on the same fd flushes at the wrong kernel offset
  and corrupts the result.

## Binary <-> Markdown

- `bin_to_md` / `md_to_bin` -- base64 in a markdown fence, byte-exact
  round-trip, streamed both directions (`line_bytes`, default 3072,
  must be a multiple of 3 so every line but the last is
  self-contained base64 with no intra-line padding). ~1.33x the
  binary size (vs 4-5x for a hex dump); not byte-inspectable or
  diffable -- use a hex dump if you need offset/ascii columns.

## Compression (gzip, stdlib only)

- `compress_stream` / `decompress_stream` -- streamed, bounded
  memory. `filename=""` + `mtime=0` make output byte-reproducible
  across runs. Measured on a 12MB file: level 1 = 0.077s (7.16x),
  level 6 = 0.221s (9.24x, **default**), level 9 = 1.292s (9.50x --
  5.8x slower than level 6 for 2.7% smaller output, not worth it for
  speed). Decompression time is independent of the compression level
  used (~0.03-0.04s regardless, same file; absolute time is
  hardware-dependent). `zstandard` beats gzip on both axes but is a
  third-party dependency -- not added without explicit confirmation.

## Locking / integrity / copy / delete

- `file_lock(path, exclusive=True)` -- advisory `flock`, context
  manager. Advisory only: does not stop a process that ignores
  locking.
- `file_checksum` / `verify_checksum` -- streamed SHA-256 (or any
  `hashlib` algo), bounded memory.
- `copy_file` -- `copy_range_fast` first, falls back to chunked
  read/write on `OSError` (cross-filesystem, some network
  filesystems). Resets both fds before falling back so a partial
  kernel-side write doesn't duplicate or corrupt.
- `secure_delete(path, passes=1, confirm=True)` -- overwrites with
  random bytes before unlinking. **Not forensic-proof**: SSDs and
  copy-on-write/journaled filesystems (btrfs, wear-leveled SSDs) may
  retain copies elsewhere. Only defeats casual filesystem-level
  recovery. Always requires `confirm=True` regardless of any guard
  env var.

## Move

- `move_file(src, dst)` -- `os.rename` first (atomic same-fs); on
  `EXDEV` (cross-filesystem), copies to a UUID-suffixed temp beside
  `dst`, fsyncs, atomically renames, then unlinks `src`. `src` is
  only removed after `dst` is confirmed in place.

## Directory / permissions

- `ensure_dir` -- `mkdir -p` semantics.
- `set_permissions` -- `chmod`, octal mode.
- `file_size` -- `fstat`-based, no read.
- `is_executable` -- checks `S_IXUSR`.

## Editing safety

- `verify_targeted_edit(before, after, old_str, new_str)` -- confirms
  `old_str` appears exactly once and that replacing it fully
  reconstructs `after`; returns a unified diff otherwise. Use after
  any `str_replace`-style edit to prove nothing outside the target
  span changed.
- `ensure_writable_copy(path, work_dir)` -- copies read-only or
  outside-work_dir files into `work_dir` before editing.
- `guard_str_replace(path, old_str, new_str)` -- detects a
  delete-then-reinsert pattern (relocating a block via two
  `str_replace` calls) and raises `PermissionError`; use a full
  view + heredoc rewrite to move blocks instead.

## Logging

- `log_operation(op, path, **extra)` -- one JSON line per call,
  path configurable via `FILEOPS_LOG_PATH` (default `fileops.log`).
- `get_logger(name="fileops")` -- stdlib `logging.Logger`, stderr
  handler, idempotent setup.

## Verification

- `verify_idempotent(fn, target_path, *args, **kwargs)` -- runs `fn`
  twice against the same target, checksums before/after; `True` only
  if the second run left the target byte-identical. Checksum-based,
  not log/return-value-based, so it catches silent drift a script
  might not report on its own.
