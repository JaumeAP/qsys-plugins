# Testing

Four independent scripts, each `import fileops` directly (no markdown
regex-parsing -- the original skill's tests parsed a file named
`file-operations-skill.md` that never matched the actual `SKILL.md`
filename; that's fixed here). Run any of them standalone
(`python3 <file>.py`) or under `pytest` for the `test_*` one.

## `test_fileops.py` -- failure paths, not just happy path

Forces the actual bad case for every claim that mentions one:
- `atomic_write`: writer error mid-write leaves the target untouched,
  no temp file left behind.
- `copy_file`: `copy_range_fast` writes garbage then raises -- the
  chunked fallback still produces a byte-exact copy.
- `secure_delete`: peak memory on a 30MB file stays under 8MB
  (`tracemalloc`), i.e. it never buffers the whole file.
- `compress_stream`: byte-reproducible across two runs of the same
  input; round-trips byte-exact through `decompress_stream`.

## `stress_fileops.py` -- crash injection (Linux, `os.fork` + `SIGKILL`)

Forks a child, kills it at the worst possible moment, and asserts a
reader never observes a partial file:
- killed before rename -> reader sees the old file, intact.
- killed after rename, before the directory fsync -> reader sees old
  or new, never torn.
- 60-round random-offset kill fuzz -> same invariant holds regardless
  of timing.
- `file_lock` serialization checked across 8 concurrent processes
  doing 400 total increments: no lost updates.
- Boundary coverage: empty file, whole-file replace, insert at BOF/EOF,
  all 256 byte values round-tripped through the base64 markdown dump.

Real interruption, not simulated -- the child process is actually
`SIGKILL`ed mid-syscall.

## `corruption_fileops.py` -- detection, not prevention

Real block-layer fault injection (silent bit-rot, a controller lying
about fsync) needs root + `dm-flakey`/`dm-dust`, out of userspace
scope. What's tested: a flipped byte, a truncated file, and a
corrupted markdown dump each surface as a `verify_checksum` mismatch,
never silently.

## `sweep_fileops.py` -- full-scale run, hard memory ceiling

Exercises every function against a 64MB input (16MB for the base64
round-trip, which expands ~5x) and asserts every streaming function's
peak memory stays under a 12MB cap, regardless of input size.
Whole-file loaders (`read_file`, `read_file_bytes`, `atomic_write`) are
correctness-only by design, not capped. `cut_range`/`insert_gap` need
block-aligned offsets and a real ext4/xfs mount.

Measured peaks on this container were all under ~4MB, well inside the
12MB cap.
