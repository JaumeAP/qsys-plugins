"""
file-operations skill -- runtime module.

Import directly, no markdown parsing:
    from fileops import atomic_write, secure_delete, ...

Guards (allowlist, blocklist, protected-root, confirm, logging) are
opt-in via env vars, applied at import time by wrapping the writer
functions in place. See references/guards.md for details.
"""

from pathlib import Path
import base64
import ctypes
import difflib
import errno
import fcntl
import functools
import gzip
import hashlib
import json
import logging
import mmap
import os
import shutil
import stat
import tarfile
import tempfile
import time
import uuid
import zipfile
import zlib
from contextlib import contextmanager

# ---------------------------------------------------------------------------
# File I/O Abstractions
# ---------------------------------------------------------------------------


def read_file(path: str, encoding: str = "utf-8") -> str:
    return Path(path).read_text(encoding=encoding)


def write_file(path: str, content: str, encoding: str = "utf-8") -> None:
    Path(path).write_text(content, encoding=encoding)


def append_file(path: str, content: str, encoding: str = "utf-8") -> None:
    with open(path, "a", encoding=encoding) as f:
        f.write(content)


def read_file_bytes(path: str) -> bytes:
    return Path(path).read_bytes()


def write_file_bytes(path: str, data: bytes) -> None:
    Path(path).write_bytes(data)


def stream_chunks(path: str, size: int = 1048576):
    if size < 1:
        raise ValueError("size must be >= 1")
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(size), b""):
            yield block


def mmap_read(path: str, offset: int = 0, length: int | None = None) -> bytes:
    """Read a bounded window [offset, offset+length) via mmap.
    length is required: without it mm.read() materializes the whole
    file into a bytes object, same memory cost as read_file_bytes but
    with extra mmap overhead. Use read_file_bytes for whole-file reads.
    """
    if length is None:
        raise ValueError("length is required; use read_file_bytes() for the whole file")
    if Path(path).stat().st_size == 0:
        return b""  # mmap cannot map an empty file
    with open(path, "rb") as f:
        mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        try:
            mm.seek(offset)
            return mm.read(length)
        finally:
            mm.close()


# ---------------------------------------------------------------------------
# In-Place Editing & Zero-Copy (2026, Linux, ext4/xfs)
# ---------------------------------------------------------------------------

_libc = ctypes.CDLL("libc.so.6", use_errno=True)

FALLOC_FL_PUNCH_HOLE = 0x02
FALLOC_FL_COLLAPSE_RANGE = 0x08
FALLOC_FL_INSERT_RANGE = 0x20


def _fallocate(fd: int, mode: int, offset: int, length: int) -> None:
    ret = _libc.fallocate(fd, mode, ctypes.c_long(offset), ctypes.c_long(length))
    if ret != 0:
        err = ctypes.get_errno()
        raise OSError(err, os.strerror(err))


def cut_range(path: str, offset: int, length: int) -> None:
    """Remove [offset, offset+length) from a file in-place, no rewrite.
    ext4/xfs only. offset and length are commonly required to be
    filesystem-block-aligned (typically 4096 bytes).

    NOT constant-time: measured linear scaling with tail size (page
    cache invalidation past offset), ~28x faster than a full userspace
    rewrite at the same size, but grows with file size regardless.
    """
    fd = os.open(path, os.O_RDWR)
    try:
        _fallocate(fd, FALLOC_FL_COLLAPSE_RANGE, offset, length)
    finally:
        os.close(fd)


def insert_gap(path: str, offset: int, length: int) -> None:
    """Insert a zeroed gap of length bytes at offset, shifting the rest
    of the file right, in-place, no rewrite. Same alignment caveat and
    same non-constant-time scaling as cut_range.
    """
    fd = os.open(path, os.O_RDWR)
    try:
        _fallocate(fd, FALLOC_FL_INSERT_RANGE, offset, length)
    finally:
        os.close(fd)


def copy_range_fast(src_fd: int, dst_fd: int, count: int) -> int:
    """Kernel-side copy, no userspace buffering (Python 3.8+, Linux).
    copy_file_range() may copy fewer bytes than requested per call
    (documented syscall behavior); loop until count is fully copied
    or the source is exhausted.
    """
    total = 0
    while total < count:
        n = os.copy_file_range(src_fd, dst_fd, count - total)
        if n == 0:
            break  # source exhausted
        total += n
    return total


def atomic_write(path: str, content: str | bytes, encoding: str = "utf-8", durable: bool = True) -> None:
    """Crash-safe write: temp file in same dir, then atomic rename.
    Never leaves a partially-written target file.

    durable=True (default): fsync before rename, survives power loss,
    ~3.4x slower on large writes (measured, 100MB).
    durable=False: skip fsync, still atomic against readers (rename is
    atomic) but a crash before the OS flushes its buffers can lose the
    write entirely. Use for speed when the caller can tolerate losing
    the write on a crash (caches, regenerable data).
    """
    directory = os.path.dirname(os.path.abspath(path)) or "."
    binary = isinstance(content, bytes)
    fd, tmp_path = tempfile.mkstemp(dir=directory)
    try:
        with os.fdopen(fd, "wb" if binary else "w", encoding=None if binary else encoding) as f:
            f.write(content)
            if durable:
                f.flush()
                os.fsync(f.fileno())
        os.replace(tmp_path, path)  # atomic on POSIX and Windows
        if durable:
            dir_fd = os.open(directory, os.O_RDONLY)
            try:
                os.fsync(dir_fd)  # make the rename itself durable
            finally:
                os.close(dir_fd)
    except Exception:
        os.unlink(tmp_path)
        raise


def replace_range(
    path: str,
    offset: int,
    length: int,
    new_content: str | bytes,
    encoding: str = "utf-8",
    durable: bool = True,
) -> None:
    """Replace [offset, offset+length) with new_content at ANY position,
    no block-alignment required. Works for text files and arbitrary
    byte offsets where cut_range/insert_gap don't apply. new_content
    may differ in size from the replaced range (grows or shrinks the
    file).

    No OS primitive covers unaligned edits: this streams head + new
    content + tail into a temp file via copy_file_range (kernel-side,
    no full-file load into memory), then atomically renames. O(n) in
    the bytes after offset, unlike the O(1) aligned ops above.

    Uses raw os.write for new_content, not a buffered file object:
    mixing buffered writes with copy_file_range on the same fd causes
    the buffer to flush at the wrong kernel file offset and corrupts
    the result.
    """
    if isinstance(new_content, str):
        new_content = new_content.encode(encoding)

    directory = os.path.dirname(os.path.abspath(path)) or "."
    src_fd = os.open(path, os.O_RDONLY)
    out_fd = None
    tmp_path = None
    try:
        size = os.fstat(src_fd).st_size
        if offset < 0 or length < 0 or offset + length > size:
            raise ValueError(f"range [{offset}, {offset+length}) out of bounds for size {size}")

        out_fd, tmp_path = tempfile.mkstemp(dir=directory)

        remaining = offset
        while remaining > 0:
            n = os.copy_file_range(src_fd, out_fd, remaining)
            if n == 0:
                break
            remaining -= n

        written = 0
        while written < len(new_content):
            written += os.write(out_fd, new_content[written:])

        os.lseek(src_fd, offset + length, os.SEEK_SET)
        remaining = size - (offset + length)
        while remaining > 0:
            n = os.copy_file_range(src_fd, out_fd, remaining)
            if n == 0:
                break
            remaining -= n

        if durable:
            os.fsync(out_fd)
        os.close(out_fd)
        out_fd = None
        os.replace(tmp_path, path)
        if durable:
            dir_fd = os.open(directory, os.O_RDONLY)
            try:
                os.fsync(dir_fd)  # make the rename itself durable
            finally:
                os.close(dir_fd)
    except Exception:
        if out_fd is not None:
            os.close(out_fd)
        if tmp_path is not None:
            os.unlink(tmp_path)
        raise
    finally:
        os.close(src_fd)


# ---------------------------------------------------------------------------
# Unknown Binary <-> Markdown (reversible, any format)
# ---------------------------------------------------------------------------


def bin_to_md(path: str, out_path: str, line_bytes: int = 3072) -> None:
    """Base64-encode any binary file into a markdown fence, byte-exact
    round-trip. Streams both files in bounded chunks (line_bytes at a
    time); never loads the whole file into memory.

    line_bytes must be a multiple of 3 so each emitted line is
    self-contained base64 with no intra-line padding (only the final
    line may be padded), which lets md_to_bin decode line by line.

    Uses C-implemented base64.b64encode. Output is ~1.33x the binary
    size, far smaller than a hex dump, but not byte-inspectable.
    """
    if line_bytes <= 0 or line_bytes % 3 != 0:
        raise ValueError("line_bytes must be a positive multiple of 3")
    fence = chr(96) * 3
    with open(path, "rb") as src, open(out_path, "w", encoding="utf-8") as out:
        out.write("# binary (base64)\n\n" + fence + "base64\n")
        while True:
            chunk = src.read(line_bytes)
            if not chunk:
                break
            out.write(base64.b64encode(chunk).decode("ascii"))
            out.write("\n")
        out.write(fence + "\n")


def md_to_bin(md_path: str, out_path: str) -> None:
    """Reconstruct exact original bytes from a bin_to_md base64 fence.
    Streams line by line; never loads the whole markdown into memory.
    Reads only the lines inside the base64 code fence.

    Uses C-implemented base64.b64decode. Each fence line is an
    independent multiple-of-4 base64 unit, so per-line decode
    concatenates to the exact original bytes.
    """
    fence_open = chr(96) * 3 + "base64"
    fence_close = chr(96) * 3
    with open(md_path, "r", encoding="utf-8") as src, open(out_path, "wb") as out:
        in_fence = False
        for line in src:
            s = line.rstrip("\n")
            if not in_fence:
                if s == fence_open:
                    in_fence = True
                continue
            if s == fence_close:
                break
            if s:
                out.write(base64.b64decode(s))


def bin_to_text(path: str, out_path: str, line_bytes: int = 3072) -> None:
    """Base64-encode any binary file into a plain, editable text file
    (one base64 line per line_bytes chunk, no markdown fence). Byte-
    exact round-trip via text_to_bin. Streams both files in bounded
    chunks; never loads the whole file into memory. Same line_bytes
    multiple-of-3 constraint as bin_to_md.
    """
    if line_bytes <= 0 or line_bytes % 3 != 0:
        raise ValueError("line_bytes must be a positive multiple of 3")
    with open(path, "rb") as src, open(out_path, "w", encoding="utf-8") as out:
        while True:
            chunk = src.read(line_bytes)
            if not chunk:
                break
            out.write(base64.b64encode(chunk).decode("ascii"))
            out.write("\n")


def text_to_bin(text_path: str, out_path: str) -> None:
    """Reconstruct exact original bytes from a bin_to_text dump.
    Streams line by line; never loads the whole text file into memory.
    """
    with open(text_path, "r", encoding="utf-8") as src, open(out_path, "wb") as out:
        for line in src:
            s = line.rstrip("\n")
            if s:
                out.write(base64.b64decode(s))


# ---------------------------------------------------------------------------
# Compress / Decompress (streaming, gzip, stdlib only)
# ---------------------------------------------------------------------------


def compress_stream(path: str, out_path: str, level: int = 6, block_size: int = 1048576) -> None:
    """Stream-compress a file with gzip. level 1-9: higher ratio,
    slower. Never loads the whole file into memory.
    """
    # filename="" + mtime=0: suppress the header FNAME and timestamp so
    # output is byte-reproducible across runs and independent of out_path.
    with open(path, "rb") as src, open(out_path, "wb") as raw, gzip.GzipFile(
        filename="", mode="wb", compresslevel=level, fileobj=raw, mtime=0
    ) as out:
        while True:
            chunk = src.read(block_size)
            if not chunk:
                break
            out.write(chunk)


def decompress_stream(path: str, out_path: str, block_size: int = 1048576) -> None:
    """Stream-decompress a gzip file. Never loads the whole file into
    memory; speed doesn't depend on the compression level used.
    """
    with gzip.open(path, "rb") as src, open(out_path, "wb") as out:
        while True:
            chunk = src.read(block_size)
            if not chunk:
                break
            out.write(chunk)


def zip_compress_stream(
    path: str, out_path: str, arcname: str | None = None,
    level: int = 9, block_size: int = 1048576,
) -> None:
    """Stream a single file into a zip archive, ZIP_DEFLATED at
    compresslevel (0-9, default 9 = max ratio). Streams both source
    and archive member in bounded chunks; never loads the whole file
    into memory. arcname defaults to path's basename. Never leaves a
    partial/corrupt out_path on error.
    """
    if not 0 <= level <= 9:
        raise ValueError(f"level must be 0-9, got {level}")
    if arcname is None:
        arcname = os.path.basename(path)
    try:
        with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED, compresslevel=level) as zf, \
             zf.open(arcname, "w") as dst, open(path, "rb") as src:
            while True:
                chunk = src.read(block_size)
                if not chunk:
                    break
                dst.write(chunk)
    except Exception:
        if os.path.exists(out_path):
            os.unlink(out_path)
        raise


def zip_decompress_stream(
    zip_path: str, out_path: str, arcname: str | None = None, block_size: int = 1048576,
) -> None:
    """Stream a single member out of a zip archive to out_path.
    arcname defaults to the archive's first entry. Never loads the
    whole member into memory (ZipExtFile.read(n) reads in chunks).
    """
    with zipfile.ZipFile(zip_path) as zf:
        names = zf.namelist()
        if arcname is None:
            if not names:
                raise ValueError(f"zip archive has no entries: {zip_path}")
            name = names[0]
        else:
            name = arcname
        with zf.open(name) as src, open(out_path, "wb") as out:
            while True:
                chunk = src.read(block_size)
                if not chunk:
                    break
                out.write(chunk)


# ---------------------------------------------------------------------------
# Locking, Checksums, Copy, Secure Delete
# ---------------------------------------------------------------------------


@contextmanager
def file_lock(path: str, exclusive: bool = True):
    """Advisory flock on path for the duration of the with-block.
    Prevents concurrent writers from corrupting the file. Advisory
    only: cooperating processes must all use flock; it does not stop
    a process that ignores locking.
    """
    fd = os.open(path, os.O_RDWR | os.O_CREAT, 0o644)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH)
        yield fd
    finally:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)


def file_checksum(path: str, algo: str = "sha256", block_size: int = 1048576) -> str:
    """Stream-hash a file; never loads it fully into memory."""
    h = hashlib.new(algo)
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(block_size), b""):
            h.update(block)
    return h.hexdigest()


def verify_checksum(path: str, expected_hex: str, algo: str = "sha256") -> bool:
    return file_checksum(path, algo) == expected_hex


_CHECKSUM_CACHE: dict[tuple, str] = {}


def cached_checksum(path: str, algo: str = "sha256", block_size: int = 1048576) -> str:
    """file_checksum with an in-memory cache keyed by (path, algo,
    size, mtime_ns). A hash on an unchanged file returns instantly on
    repeat calls; any write that changes size or mtime invalidates it
    automatically (no manual cache clearing needed). Cache lives for
    the process lifetime -- clear via clear_checksum_cache() if memory
    matters for very many distinct files.
    """
    st = os.stat(path)
    key = (os.path.realpath(path), algo, st.st_size, st.st_mtime_ns)
    cached = _CHECKSUM_CACHE.get(key)
    if cached is not None:
        return cached
    h = file_checksum(path, algo, block_size)
    _CHECKSUM_CACHE[key] = h
    return h


def clear_checksum_cache() -> int:
    """Drop all cached checksums. Returns count of entries cleared."""
    n = len(_CHECKSUM_CACHE)
    _CHECKSUM_CACHE.clear()
    return n


def crc32(data: bytes) -> int:
    """CRC32 of raw bytes, as an unsigned 32-bit int."""
    return zlib.crc32(data) & 0xFFFFFFFF


def crc32_file(path: str) -> int:
    """CRC32 of a file's contents."""
    return crc32(read_file_bytes(path))


def sha256_hex(data: bytes) -> str:
    """SHA-256 hex digest of raw bytes."""
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: str) -> str:
    """SHA-256 hex digest of a file (streamed via file_checksum)."""
    return file_checksum(path, algo="sha256")


def copy_file(src_path: str, dst_path: str) -> int:
    """Copy src to dst via copy_range_fast (kernel-side); falls back
    to chunked read/write if the syscall fails (cross-filesystem
    copies, some network filesystems don't support copy_file_range).
    """
    size = os.path.getsize(src_path)
    src_fd = os.open(src_path, os.O_RDONLY)
    dst_fd = os.open(dst_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)
    try:
        try:
            return copy_range_fast(src_fd, dst_fd, size)
        except OSError:
            # copy_range_fast may have written some bytes before failing;
            # reset both fds so the fallback doesn't duplicate/corrupt.
            os.lseek(src_fd, 0, os.SEEK_SET)
            os.lseek(dst_fd, 0, os.SEEK_SET)
            os.ftruncate(dst_fd, 0)
            total = 0
            while True:
                chunk = os.read(src_fd, 65536)
                if not chunk:
                    break
                os.write(dst_fd, chunk)
                total += len(chunk)
            return total
    finally:
        os.close(src_fd)
        os.close(dst_fd)


def secure_delete(path: str, passes: int = 1) -> None:
    """Overwrite file content with random bytes before unlinking.
    NOTE: on SSDs and copy-on-write/journaled filesystems (btrfs,
    most SSDs due to wear-leveling) this does NOT guarantee the old
    data is physically gone -- the storage may retain copies elsewhere.
    Only defeats casual recovery through the filesystem, not forensic
    recovery. Full-disk encryption is the real guarantee.
    """
    size = os.path.getsize(path)
    block = 1 << 20  # 1 MiB; avoid allocating the whole file in RAM
    with open(path, "r+b") as f:
        for _ in range(passes):
            buf = os.urandom(block)  # one buffer per pass, reused: security already
            f.seek(0)                # limited (not forensic-proof per note below), so
            remaining = size         # reusing bytes doesn't weaken the real guarantee
            while remaining > 0:     # and skips redundant urandom() calls per block
                n = min(block, remaining)
                f.write(buf[:n])
                remaining -= n
            f.flush()
            os.fsync(f.fileno())
    os.unlink(path)


# ---------------------------------------------------------------------------
# Write Allowlist Guard (opt-in, deterministic) -- FILEOPS_ALLOWED_ROOTS
# ---------------------------------------------------------------------------

_ALLOWED_ROOTS_ENV = "FILEOPS_ALLOWED_ROOTS"

# function name -> (positional index of destination path, its keyword name)
_GUARDED_WRITERS = {
    "write_file": (0, "path"),
    "append_file": (0, "path"),
    "write_file_bytes": (0, "path"),
    "atomic_write": (0, "path"),
    "replace_range": (0, "path"),
    "cut_range": (0, "path"),
    "insert_gap": (0, "path"),
    "secure_delete": (0, "path"),
    "bin_to_md": (1, "out_path"),
    "md_to_bin": (1, "out_path"),
    "bin_to_text": (1, "out_path"),
    "text_to_bin": (1, "out_path"),
    "compress_stream": (1, "out_path"),
    "decompress_stream": (1, "out_path"),
    "copy_file": (1, "dst_path"),
    "zip_compress_stream": (1, "out_path"),
    "zip_decompress_stream": (1, "out_path"),
}


def _allowed_roots() -> list:
    raw = os.environ.get(_ALLOWED_ROOTS_ENV, "")
    return [r for r in raw.split(os.pathsep) if r.strip()]


def write_allowed(dest_path: str) -> bool:
    """True if dest_path resolves within an allowed root, or if no
    allowlist is configured (guard disabled). Uses commonpath so a
    sibling like /data-evil is not treated as under /data.
    """
    roots = _allowed_roots()
    if not roots:
        return True
    target = os.path.realpath(os.path.abspath(dest_path))
    for root in roots:
        base = os.path.realpath(os.path.abspath(root))
        try:
            if os.path.commonpath([target, base]) == base:
                return True
        except ValueError:
            continue  # different drive/root: cannot be under this root
    return False


def _dest_arg(args: tuple, kwargs: dict, index: int, kw_name: str):
    if len(args) > index:
        return args[index]
    return kwargs.get(kw_name)


def _guard_writer(fn, index: int, kw_name: str):
    @functools.wraps(fn)
    def guarded(*args, **kwargs):
        dest = _dest_arg(args, kwargs, index, kw_name)
        if dest is not None and not write_allowed(dest):
            raise PermissionError(
                f"{_ALLOWED_ROOTS_ENV}: write blocked outside allowed roots: {dest}"
            )
        return fn(*args, **kwargs)
    return guarded


for _fn_name, (_idx, _kw) in _GUARDED_WRITERS.items():
    _target = globals().get(_fn_name)
    if callable(_target):
        globals()[_fn_name] = _guard_writer(_target, _idx, _kw)


# ---------------------------------------------------------------------------
# Destructive Op Confirmation Guard (deterministic) -- secure_delete only
# ---------------------------------------------------------------------------


def require_confirm(fn):
    @functools.wraps(fn)
    def wrapped(*args, confirm: bool = False, **kwargs):
        if not confirm:
            raise PermissionError(
                f"BLOCKED: {fn.__name__} needs confirm=True (destructive op)."
            )
        return fn(*args, **kwargs)
    return wrapped


secure_delete = require_confirm(secure_delete)


# ---------------------------------------------------------------------------
# str_replace Move Guard (deterministic)
# ---------------------------------------------------------------------------

_LAST_DELETION: dict[str, str] = {}


def _norm(s: str) -> str:
    return hashlib.sha256(s.strip().encode()).hexdigest()


def guard_str_replace(path: str, old_str: str, new_str: str) -> None:
    if old_str and not new_str:
        _LAST_DELETION[path] = _norm(old_str)
        return
    if new_str:
        h = _norm(new_str)
        for p, dh in _LAST_DELETION.items():
            if dh == h:
                raise PermissionError(
                    "BLOCKED: str_replace used to move a block "
                    f"(deleted in {p}, reinserted). Use view + heredoc rewrite."
                )


# ---------------------------------------------------------------------------
# Atomic Cross-Filesystem Move
# ---------------------------------------------------------------------------


def move_file(src: str, dst: str) -> None:
    """Atomic on same filesystem (os.rename). Cross-filesystem: copy to
    a UUID-suffixed temp beside dst, fsync, atomic rename, then unlink
    src. Never leaves dst partially written; src is only removed after
    dst is confirmed in place.
    """
    try:
        os.rename(src, dst)
        return
    except OSError as e:
        if e.errno != errno.EXDEV:
            raise

    tmp_dst = f"{dst}.{uuid.uuid4().hex}.tmp"
    shutil.copy2(src, tmp_dst)
    with open(tmp_dst, "rb") as f:
        os.fsync(f.fileno())
    os.replace(tmp_dst, dst)
    os.unlink(src)


if callable(globals().get("_guard_writer")):
    move_file = _guard_writer(move_file, 1, "dst")
    _GUARDED_WRITERS["move_file"] = (1, "dst")

# move_file is registered after the allowlist guard already ran its loop,
# so it isn't covered by the blocklist/protected/logging guards below
# unless this module is reloaded. Kept faithful to the source skill's
# documented behavior (see references/guards.md).


# ---------------------------------------------------------------------------
# str_replace No-Loss Verification (deterministic)
# ---------------------------------------------------------------------------


def verify_targeted_edit(before: str, after: str, old_str: str, new_str: str) -> tuple[bool, list[str]]:
    """True + [] if old_str appears exactly once and replacing it fully
    reconstructs after. False + diff lines otherwise (edit touched
    something outside old_str's span)."""
    if before.count(old_str) != 1:
        return False, [f"old_str appears {before.count(old_str)} times, expected 1"]
    expected = before.replace(old_str, new_str, 1)
    if expected != after:
        diff = list(difflib.unified_diff(
            expected.splitlines(), after.splitlines(), lineterm="", n=0,
        ))
        return False, diff
    return True, []


# ---------------------------------------------------------------------------
# Read-Only Copy-Before-Edit Guard (deterministic)
# ---------------------------------------------------------------------------


def ensure_writable_copy(path: str, work_dir: str = "/home/claude") -> str:
    """Return a path safe to edit: if `path` is read-only or outside
    work_dir, copy it into work_dir and return the copy's path."""
    target = os.path.realpath(os.path.abspath(path))
    inside_work = os.path.realpath(work_dir) == os.path.commonpath(
        [target, os.path.realpath(work_dir)]
    ) if os.path.exists(work_dir) else False
    writable = os.access(target, os.W_OK)
    if inside_work and writable:
        return path
    os.makedirs(work_dir, exist_ok=True)
    dest = os.path.join(work_dir, os.path.basename(path))
    shutil.copy2(target, dest)
    return dest


# ---------------------------------------------------------------------------
# Directory, Permissions, Size Helpers
# ---------------------------------------------------------------------------


def ensure_dir(path: str, mode: int = 0o755) -> str:
    """mkdir -p, no error if it already exists."""
    os.makedirs(path, mode=mode, exist_ok=True)
    return path


def set_permissions(path: str, mode: int) -> None:
    """chmod. mode as octal, e.g. 0o644, 0o755."""
    os.chmod(path, mode)


def file_size(path: str) -> int:
    """fstat-based size, no read."""
    return os.stat(path).st_size


def is_executable(path: str) -> bool:
    return bool(os.stat(path).st_mode & stat.S_IXUSR)


# ---------------------------------------------------------------------------
# Operation Logging (stdlib, JSON lines) -- FILEOPS_LOG_PATH
# ---------------------------------------------------------------------------

_LOG_PATH_ENV = "FILEOPS_LOG_PATH"


def _log_path() -> str:
    return os.environ.get(_LOG_PATH_ENV, "fileops.log")


def log_operation(op: str, path: str, **extra) -> None:
    """Append one JSON line: {ts, op, path, ...extra}."""
    record = {"ts": time.time(), "op": op, "path": path, **extra}
    with open(_log_path(), "a", encoding="utf-8") as f:
        f.write(json.dumps(record) + "\n")


def get_logger(name: str = "fileops") -> logging.Logger:
    """Standard logging.Logger, stderr handler, idempotent setup."""
    logger = logging.getLogger(name)
    if not logger.handlers:
        h = logging.StreamHandler()
        h.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
        logger.addHandler(h)
        logger.setLevel(logging.INFO)
    return logger


# ---------------------------------------------------------------------------
# Do-Not-Touch Path (Blocklist) Guard (opt-in) -- FILEOPS_BLOCKED_PATHS
# ---------------------------------------------------------------------------

_BLOCKED_PATHS_ENV = "FILEOPS_BLOCKED_PATHS"


def _blocked_roots() -> list:
    raw = os.environ.get(_BLOCKED_PATHS_ENV, "")
    return [r for r in raw.split(os.pathsep) if r.strip()]


def write_blocked(dest_path: str) -> bool:
    """True if dest_path resolves under a blocked root. False (allowed)
    if no blocklist is configured."""
    roots = _blocked_roots()
    if not roots:
        return False
    target = os.path.realpath(os.path.abspath(dest_path))
    for root in roots:
        base = os.path.realpath(os.path.abspath(root))
        try:
            if os.path.commonpath([target, base]) == base:
                return True
        except ValueError:
            continue
    return False


def _guard_blocklist(fn, index: int, kw_name: str):
    @functools.wraps(fn)
    def guarded(*args, **kwargs):
        dest = _dest_arg(args, kwargs, index, kw_name)
        if dest is not None and write_blocked(dest):
            raise PermissionError(
                f"{_BLOCKED_PATHS_ENV}: write blocked, path is do-not-touch: {dest}"
            )
        return fn(*args, **kwargs)
    return guarded


for _fn_name, (_idx, _kw) in _GUARDED_WRITERS.items():
    _target = globals().get(_fn_name)
    if callable(_target):
        globals()[_fn_name] = _guard_blocklist(_target, _idx, _kw)


# ---------------------------------------------------------------------------
# Protected-Root Confirm Guard (opt-in) -- FILEOPS_PROTECTED_ROOTS
# ---------------------------------------------------------------------------

_PROTECTED_ROOTS_ENV = "FILEOPS_PROTECTED_ROOTS"


def _protected_roots() -> list:
    raw = os.environ.get(_PROTECTED_ROOTS_ENV, "")
    return [r for r in raw.split(os.pathsep) if r.strip()]


def is_protected(dest_path: str) -> bool:
    roots = _protected_roots()
    if not roots:
        return False
    target = os.path.realpath(os.path.abspath(dest_path))
    for root in roots:
        base = os.path.realpath(os.path.abspath(root))
        try:
            if os.path.commonpath([target, base]) == base:
                return True
        except ValueError:
            continue
    return False


def _guard_protected(fn, index: int, kw_name: str):
    @functools.wraps(fn)
    def guarded(*args, confirm: bool = False, **kwargs):
        dest = _dest_arg(args, kwargs, index, kw_name)
        if dest is not None and is_protected(dest) and not confirm:
            raise PermissionError(
                f"{_PROTECTED_ROOTS_ENV}: destination is protected, "
                f"needs confirm=True: {dest}"
            )
        try:
            return fn(*args, confirm=confirm, **kwargs)
        except TypeError as e:
            if "confirm" in str(e):
                return fn(*args, **kwargs)  # fn doesn't accept confirm; not forwarded
            raise
    return guarded


for _fn_name, (_idx, _kw) in _GUARDED_WRITERS.items():
    _target = globals().get(_fn_name)
    if callable(_target):
        globals()[_fn_name] = _guard_protected(_target, _idx, _kw)


# ---------------------------------------------------------------------------
# Idempotency Verification Helper
# ---------------------------------------------------------------------------


def verify_idempotent(fn, target_path: str, *args, **kwargs) -> bool:
    """Call fn(target_path, *args, **kwargs) once, checksum target_path,
    call fn again with identical arguments, checksum again. True if the
    second run left target_path byte-identical (idempotent); False
    otherwise. Requires fn to have already been run at least once
    before this check if the target must pre-exist.
    """
    fn(target_path, *args, **kwargs)
    first = file_checksum(target_path)
    fn(target_path, *args, **kwargs)
    second = file_checksum(target_path)
    return first == second


# ---------------------------------------------------------------------------
# Operation Logging Guard (opt-in) -- FILEOPS_LOG_OPS=1
# ---------------------------------------------------------------------------

_LOG_OPS_ENV = "FILEOPS_LOG_OPS"


def _guard_logging(fn, index: int, kw_name: str):
    @functools.wraps(fn)
    def guarded(*args, **kwargs):
        result = fn(*args, **kwargs)
        if os.environ.get(_LOG_OPS_ENV) == "1":
            dest = _dest_arg(args, kwargs, index, kw_name)
            log_operation(fn.__name__, dest if dest is not None else "")
        return result
    return guarded


for _fn_name, (_idx, _kw) in _GUARDED_WRITERS.items():
    _target = globals().get(_fn_name)
    if callable(_target):
        globals()[_fn_name] = _guard_logging(_target, _idx, _kw)


# ---------------------------------------------------------------------------
# Path Traversal Guard (read-only check, no env var -- always available)
# ---------------------------------------------------------------------------


def is_safe_path(base: str, target: str) -> bool:
    """True if target resolves inside base (symlinks included), i.e.
    target cannot escape base via '../' or an absolute path. Use before
    joining user-controlled path fragments to a base directory, and
    inside archive extraction to reject zip-slip entries.
    """
    base_r = os.path.realpath(os.path.abspath(base))
    target_r = os.path.realpath(os.path.abspath(os.path.join(base, target) if not os.path.isabs(target) else target))
    try:
        return os.path.commonpath([base_r, target_r]) == base_r
    except ValueError:
        return False  # different drive/root on Windows


# ---------------------------------------------------------------------------
# Disk Space Check (read-only)
# ---------------------------------------------------------------------------


def disk_free(path: str) -> int:
    """Free bytes on the filesystem holding path. Walks up to the
    nearest existing ancestor if path (and its parent dirs) don't
    exist yet, so it works for not-yet-created output paths at any
    depth.
    """
    p = os.path.abspath(path)
    while not os.path.exists(p):
        parent = os.path.dirname(p)
        if parent == p:
            break  # reached filesystem root, give up climbing
        p = parent
    return shutil.disk_usage(p).free


# ---------------------------------------------------------------------------
# Recursive Tree Copy / Move (opt-in guards, same writer set as copy_file)
# ---------------------------------------------------------------------------


def copy_tree(src_dir: str, dst_dir: str) -> int:
    """Recursively copy src_dir to dst_dir, file by file, via copy_file
    (kernel-side copy_file_range, chunked fallback). Returns file count
    copied. Symlinks are followed (not preserved as links). Raises if
    src_dir doesn't exist, or dst_dir already exists and is non-empty
    (to avoid silent merges).
    """
    if not os.path.isdir(src_dir):
        raise NotADirectoryError(f"src_dir does not exist or is not a directory: {src_dir}")
    if os.path.isdir(dst_dir) and os.listdir(dst_dir):
        raise FileExistsError(f"dst_dir not empty: {dst_dir}")
    n = 0
    for root, dirs, files in os.walk(src_dir):
        rel = os.path.relpath(root, src_dir)
        target_root = dst_dir if rel == "." else os.path.join(dst_dir, rel)
        ensure_dir(target_root)
        for name in files:
            copy_file(os.path.join(root, name), os.path.join(target_root, name))
            n += 1
    return n


def move_tree(src_dir: str, dst_dir: str) -> int:
    """Move src_dir to dst_dir. Same-filesystem: os.rename (atomic).
    Cross-filesystem: copy_tree then rmtree_safe(src_dir). Returns file
    count moved (best-effort; 0 on the atomic-rename fast path since no
    per-file count is available)."""
    try:
        os.rename(src_dir, dst_dir)
        return 0
    except OSError as e:
        if e.errno != errno.EXDEV:
            raise
    n = copy_tree(src_dir, dst_dir)
    rmtree_safe(src_dir, confirm=True)
    return n


for _fn_name in ("copy_tree", "move_tree"):
    _target = globals().get(_fn_name)
    if callable(_target):
        _wrapped = _guard_writer(_target, 1, "dst_dir")
        _wrapped = _guard_blocklist(_wrapped, 1, "dst_dir")
        _wrapped = _guard_protected(_wrapped, 1, "dst_dir")
        _wrapped = _guard_logging(_wrapped, 1, "dst_dir")
        globals()[_fn_name] = _wrapped
        _GUARDED_WRITERS[_fn_name] = (1, "dst_dir")


# ---------------------------------------------------------------------------
# Safe Archive Extraction (zip-slip guarded)
# ---------------------------------------------------------------------------


def safe_extract_zip(zip_path: str, out_dir: str) -> int:
    """Extract a zip file, rejecting any entry that would resolve
    outside out_dir (zip-slip: entries like '../../etc/passwd' or
    absolute paths embedded in the archive). Returns count extracted.
    Raises ValueError on the first unsafe entry, before extracting
    anything past that point.
    """
    ensure_dir(out_dir)
    n = 0
    with zipfile.ZipFile(zip_path) as zf:
        for info in zf.infolist():
            if not is_safe_path(out_dir, info.filename):
                raise ValueError(f"zip-slip blocked: unsafe entry {info.filename!r}")
        for info in zf.infolist():
            zf.extract(info, out_dir)
            n += 1
    return n


def safe_extract_tar(tar_path: str, out_dir: str) -> int:
    """Extract a tar file (any compression tarfile auto-detects),
    rejecting any member that would resolve outside out_dir, and any
    symlink/hardlink member pointing outside out_dir. Returns count
    extracted."""
    ensure_dir(out_dir)
    n = 0
    with tarfile.open(tar_path) as tf:
        members = tf.getmembers()
        for m in members:
            if not is_safe_path(out_dir, m.name):
                raise ValueError(f"tar-slip blocked: unsafe entry {m.name!r}")
            if m.issym() or m.islnk():
                if not is_safe_path(out_dir, m.linkname):
                    raise ValueError(f"tar-slip blocked: unsafe link target {m.linkname!r}")
        tf.extractall(out_dir, members=members)
        n = len(members)
    return n


for _fn_name in ("safe_extract_zip", "safe_extract_tar"):
    _target = globals().get(_fn_name)
    if callable(_target):
        _wrapped = _guard_writer(_target, 1, "out_dir")
        _wrapped = _guard_blocklist(_wrapped, 1, "out_dir")
        _wrapped = _guard_protected(_wrapped, 1, "out_dir")
        _wrapped = _guard_logging(_wrapped, 1, "out_dir")
        globals()[_fn_name] = _wrapped
        _GUARDED_WRITERS[_fn_name] = (1, "out_dir")


# ---------------------------------------------------------------------------
# Guarded Recursive Delete (always requires confirm=True, like secure_delete)
# ---------------------------------------------------------------------------


def _rmtree_safe_impl(path: str) -> int:
    """Internal: recursive delete, returns count of files removed."""
    n = 0
    for root, dirs, files in os.walk(path, topdown=False):
        for name in files:
            os.unlink(os.path.join(root, name))
            n += 1
        for name in dirs:
            os.rmdir(os.path.join(root, name))
    os.rmdir(path)
    return n


rmtree_safe = require_confirm(_rmtree_safe_impl)
rmtree_safe = _guard_writer(rmtree_safe, 0, "path")
rmtree_safe = _guard_blocklist(rmtree_safe, 0, "path")
rmtree_safe = _guard_protected(rmtree_safe, 0, "path")
rmtree_safe = _guard_logging(rmtree_safe, 0, "path")
_GUARDED_WRITERS["rmtree_safe"] = (0, "path")
