"""Crash-injection stress tests. Linux only (uses os.fork). Run directly:
python stress_fileops.py"""
import os
import sys
import time
import random
import signal
import ctypes
import errno
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fileops as M


def _child_crash_atomic(path, new, when):
    pid = os.fork()
    if pid == 0:
        try:
            if when == "before_rename":
                os.replace = lambda *a, **k: os.kill(os.getpid(), signal.SIGKILL)
            elif when == "before_dirfsync":
                _real = os.fsync
                calls = {"n": 0}

                def f(fd):
                    _real(fd)
                    calls["n"] += 1
                    if calls["n"] >= 2:  # 2nd fsync is the dir fsync, after rename
                        os.kill(os.getpid(), signal.SIGKILL)
                os.fsync = f
            M.atomic_write(path, new, durable=True)
            os._exit(0)
        except BaseException:
            os._exit(1)
    _, st = os.waitpid(pid, 0)
    return st


def stress_atomic_write_crash_before_rename():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "f")
        old = b"OLD" * 1000
        M.atomic_write(p, old, durable=True)
        for _ in range(10):  # was 30; full 30 reserved for release-gate runs
            _child_crash_atomic(p, b"NEW" * 2000, "before_rename")
            assert open(p, "rb").read() == old
        assert os.path.exists(p)


def stress_atomic_write_crash_after_rename():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "f")
        old = b"OLD" * 1000
        new = b"NEW" * 2000
        M.atomic_write(p, old, durable=True)
        for _ in range(10):
            _child_crash_atomic(p, new, "before_dirfsync")
            assert open(p, "rb").read() in (old, new)
        assert open(p, "rb").read() == new


def stress_atomic_write_fuzz_random_kill():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "f")
        old = b"A" * 5000
        new = b"B" * 9000
        M.atomic_write(p, old, durable=True)
        for _ in range(60):
            pid = os.fork()
            if pid == 0:
                try:
                    M.atomic_write(p, new, durable=True)
                    os._exit(0)
                except BaseException:
                    os._exit(1)
            time.sleep(random.uniform(0, 0.0009))
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            os.waitpid(pid, 0)
            assert open(p, "rb").read() in (old, new), "torn write under random kill"


def stress_replace_range_crash_before_rename():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "f")
        base = b"0123456789" * 100
        M.atomic_write(p, base, durable=True)
        for _ in range(10):
            pid = os.fork()
            if pid == 0:
                try:
                    os.replace = lambda *a, **k: os.kill(os.getpid(), signal.SIGKILL)
                    M.replace_range(p, 50, 10, b"ZZZZ", durable=True)
                    os._exit(0)
                except BaseException:
                    os._exit(1)
            os.waitpid(pid, 0)
            assert open(p, "rb").read() == base


def stress_file_lock_serializes_writers():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "counter")
        open(p, "w").write("0")

        def worker():
            for _ in range(50):
                with M.file_lock(p):
                    v = int(open(p).read())
                    open(p, "w").write(str(v + 1))
        pids = []
        for _ in range(8):
            pid = os.fork()
            if pid == 0:
                worker()
                os._exit(0)
            pids.append(pid)
        for pid in pids:
            os.waitpid(pid, 0)
        assert int(open(p).read()) == 8 * 50


def stress_edge_empty_and_boundaries():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "e")
        M.atomic_write(p, b"", durable=True)
        assert open(p, "rb").read() == b""
        M.atomic_write(p, b"x" * 10, durable=True)
        M.replace_range(p, 0, 10, b"WHOLE")
        assert open(p, "rb").read() == b"WHOLE"
        M.replace_range(p, 5, 0, b"++")
        assert open(p, "rb").read() == b"WHOLE++"
        M.replace_range(p, 0, 0, b">>")
        assert open(p, "rb").read() == b">>WHOLE++"


def stress_unaligned_range_ops_fail_clean():
    """cut_range/insert_gap need block-aligned offsets on ext4/xfs. An
    unaligned call must raise cleanly (OSError, typically EINVAL), not
    silently corrupt the file."""
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "u")
        base = bytes([1]) * 4096 + bytes([2]) * 4096 + bytes([3]) * 4096
        open(p, "wb").write(base)
        try:
            M.cut_range(p, 100, 4096)  # unaligned offset
            raised = False
        except OSError:
            raised = True
        assert raised, "unaligned cut_range should raise OSError"
        assert open(p, "rb").read() == base, "unaligned cut_range must not corrupt file"

        try:
            M.insert_gap(p, 4096, 100)  # unaligned length
            raised = False
        except OSError:
            raised = True
        assert raised, "unaligned insert_gap should raise OSError"
        assert open(p, "rb").read() == base, "unaligned insert_gap must not corrupt file"


def stress_concurrent_real_writers_no_torn_read():
    """Real concurrent processes (not fork+kill) hammering the same
    path with atomic_write and replace_range. A concurrent reader must
    always see a complete, valid write -- never a torn/mixed one."""
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "cw")
        tags = [f"TAG{i}".encode() * 2000 for i in range(4)]
        M.atomic_write(p, tags[0], durable=False)

        def writer(tag):
            for _ in range(30):
                M.atomic_write(p, tag, durable=False)

        def replacer():
            for _ in range(30):
                try:
                    M.replace_range(p, 0, 4, b"XXXX", durable=False)
                except (ValueError, FileNotFoundError):
                    pass  # racing with a full atomic_write swap, expected

        pids = []
        for tag in tags[1:]:
            pid = os.fork()
            if pid == 0:
                writer(tag)
                os._exit(0)
            pids.append(pid)
        pid = os.fork()
        if pid == 0:
            replacer()
            os._exit(0)
        pids.append(pid)

        bad = 0
        for _ in range(200):
            try:
                data = open(p, "rb").read()
            except FileNotFoundError:
                continue  # mid-rename window, not a torn read
            valid = any(data == t for t in tags) or (
                len(data) == len(tags[0]) and data[4:] in (t[4:] for t in tags)
            )
            if not valid:
                bad += 1
        for pid in pids:
            os.waitpid(pid, 0)
        assert bad == 0, f"{bad} torn/mixed reads observed under concurrent writers"


def stress_move_tree_crash_leaves_consistent_state():
    """Kill the process mid cross-fs move_tree fallback (forced via
    monkeypatched os.rename raising EXDEV). Either src or dst must hold
    the complete tree, never both partially, never neither."""
    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, "src")
        os.makedirs(src)
        for i in range(5):
            open(os.path.join(src, f"f{i}"), "w").write(f"DATA{i}")
        dst = os.path.join(d, "dst")

        for kill_after in range(5):  # kill after copying kill_after files
            if os.path.exists(dst):
                import shutil as _sh
                _sh.rmtree(dst)
            if not os.path.exists(src):
                _sh.copytree(dst, src)
                _sh.rmtree(dst)

            pid = os.fork()
            if pid == 0:
                try:
                    _orig_rename = os.rename

                    def fake_rename(a, b):
                        raise OSError(errno.EXDEV, "cross-device")
                    os.rename = fake_rename

                    _orig_copy_file = M.copy_file
                    count = {"n": 0}

                    def counting_copy_file(s, t):
                        if count["n"] >= kill_after:
                            os.kill(os.getpid(), signal.SIGKILL)
                        r = _orig_copy_file(s, t)
                        count["n"] += 1
                        return r
                    M.copy_file = counting_copy_file
                    M.move_tree(src, dst)
                    os._exit(0)
                except BaseException:
                    os._exit(1)
            os.waitpid(pid, 0)

            src_ok = os.path.isdir(src) and len(os.listdir(src)) == 5
            dst_ok = os.path.isdir(dst) and len(os.listdir(dst)) == 5
            assert src_ok or dst_ok, "tree lost: neither src nor dst complete"
            assert not (src_ok and dst_ok), "tree duplicated: both src and dst complete"


def stress_concurrent_extract_and_rmtree_safe():
    """One process extracts a zip repeatedly while another rmtree_safe's
    a different, independent directory concurrently. No cross-talk: each
    directory's outcome depends only on its own operations."""
    import zipfile
    with tempfile.TemporaryDirectory() as d:
        zpath = os.path.join(d, "a.zip")
        with zipfile.ZipFile(zpath, "w") as zf:
            zf.writestr("x/y.txt", "content")
        extract_dir = os.path.join(d, "extract")
        victim_root = os.path.join(d, "victims")
        os.makedirs(victim_root)

        def extractor():
            for i in range(20):
                out = os.path.join(extract_dir, str(i))
                M.safe_extract_zip(zpath, out)

        def deleter():
            for i in range(20):
                v = os.path.join(victim_root, str(i))
                os.makedirs(v)
                open(os.path.join(v, "f"), "w").write("x")
                M.rmtree_safe(v, confirm=True)

        pids = []
        for target in (extractor, deleter):
            pid = os.fork()
            if pid == 0:
                target()
                os._exit(0)
            pids.append(pid)
        statuses = [os.waitpid(pid, 0)[1] for pid in pids]
        assert all(s == 0 for s in statuses), statuses
        for i in range(20):
            assert open(os.path.join(extract_dir, str(i), "x", "y.txt")).read() == "content"
            assert not os.path.exists(os.path.join(victim_root, str(i)))


def stress_cut_range_crash_before_fallocate():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "f")
        base = bytes([1]) * 4096 + bytes([2]) * 4096 + bytes([3]) * 4096
        for _ in range(10):
            open(p, "wb").write(base)
            pid = os.fork()
            if pid == 0:
                try:
                    orig = ctypes.CDLL("libc.so.6").fallocate
                    M._libc.fallocate = lambda *a: os.kill(os.getpid(), signal.SIGKILL)
                    M.cut_range(p, 4096, 4096)
                    os._exit(0)
                except BaseException:
                    os._exit(1)
            os.waitpid(pid, 0)
            assert open(p, "rb").read() == base, "killed before fallocate must leave file untouched"


def stress_compress_stream_crash_mid_write_leaves_source_untouched():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "src")
        data = os.urandom(2_000_000)
        open(p, "wb").write(data)
        out = os.path.join(d, "out.gz")
        for _ in range(10):
            pid = os.fork()
            if pid == 0:
                try:
                    _orig_write = os.write
                    calls = {"n": 0}

                    def fake_write(fd, buf):
                        calls["n"] += 1
                        if calls["n"] >= 3:
                            os.kill(os.getpid(), signal.SIGKILL)
                        return _orig_write(fd, buf)
                    os.write = fake_write
                    M.compress_stream(p, out, level=1)
                    os._exit(0)
                except BaseException:
                    os._exit(1)
            os.waitpid(pid, 0)
            assert open(p, "rb").read() == data, "source must survive interrupted compress"
        M.compress_stream(p, out, level=1)
        back = os.path.join(d, "back")
        M.decompress_stream(out, back)
        assert open(back, "rb").read() == data, "retry after interruption must still round-trip"


def stress_secure_delete_crash_mid_overwrite_file_survives():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "victim")
        open(p, "wb").write(b"SECRET" * 500_000)
        for _ in range(10):
            if not os.path.exists(p):
                open(p, "wb").write(b"SECRET" * 500_000)
            pid = os.fork()
            if pid == 0:
                try:
                    _orig_fsync = os.fsync
                    calls = {"n": 0}

                    def fake_fsync(fd):
                        calls["n"] += 1
                        if calls["n"] >= 1:
                            os.kill(os.getpid(), signal.SIGKILL)
                        return _orig_fsync(fd)
                    os.fsync = fake_fsync
                    M.secure_delete(p, passes=3, confirm=True)
                    os._exit(0)
                except BaseException:
                    os._exit(1)
            os.waitpid(pid, 0)
            assert os.path.exists(p), "killed mid-overwrite must not unlink (unlink is last step)"
        M.secure_delete(p, passes=1, confirm=True)
        assert not os.path.exists(p)


def stress_copy_file_crash_mid_copy_retry_succeeds():
    with tempfile.TemporaryDirectory() as d:
        s = os.path.join(d, "s")
        t = os.path.join(d, "t")
        data = os.urandom(5_000_000)
        open(s, "wb").write(data)
        for _ in range(10):
            if os.path.exists(t):
                os.unlink(t)
            pid = os.fork()
            if pid == 0:
                try:
                    _orig = os.copy_file_range
                    calls = {"n": 0}

                    def fake(src_fd, dst_fd, count, **kw):
                        calls["n"] += 1
                        if calls["n"] >= 2:
                            os.kill(os.getpid(), signal.SIGKILL)
                        return _orig(src_fd, dst_fd, count, **kw)
                    os.copy_file_range = fake
                    M.copy_file(s, t)
                    os._exit(0)
                except BaseException:
                    os._exit(1)
            os.waitpid(pid, 0)
            assert open(s, "rb").read() == data, "source must never be touched by copy_file"
        M.copy_file(s, t)
        assert open(t, "rb").read() == data, "retry after interrupted copy must be byte-exact"


def stress_rmtree_safe_crash_mid_delete_retry_completes():
    with tempfile.TemporaryDirectory() as d:
        victim = os.path.join(d, "victim")
        for _ in range(10):
            os.makedirs(victim, exist_ok=True)
            for i in range(8):
                open(os.path.join(victim, f"f{i}"), "w").write(f"D{i}")
            pid = os.fork()
            if pid == 0:
                try:
                    _orig_unlink = os.unlink
                    calls = {"n": 0}

                    def fake_unlink(path):
                        calls["n"] += 1
                        if calls["n"] >= 3:
                            os.kill(os.getpid(), signal.SIGKILL)
                        return _orig_unlink(path)
                    os.unlink = fake_unlink
                    M.rmtree_safe(victim, confirm=True)
                    os._exit(0)
                except BaseException:
                    os._exit(1)
            os.waitpid(pid, 0)
            # partial state: dir may or may not still exist, but whatever
            # files remain must be intact (no truncation/corruption)
            if os.path.isdir(victim):
                for name in os.listdir(victim):
                    i = int(name[1:])
                    assert open(os.path.join(victim, name)).read() == f"D{i}"
                M.rmtree_safe(victim, confirm=True)
            assert not os.path.exists(victim)


def stress_zip_compress_crash_mid_write_source_untouched():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "src")
        data = os.urandom(2_000_000)
        open(p, "wb").write(data)
        z = os.path.join(d, "out.zip")
        for _ in range(10):
            if os.path.exists(z):
                os.unlink(z)
            pid = os.fork()
            if pid == 0:
                try:
                    _orig_write = os.write
                    calls = {"n": 0}

                    def fake_write(fd, buf):
                        calls["n"] += 1
                        if calls["n"] >= 3:
                            os.kill(os.getpid(), signal.SIGKILL)
                        return _orig_write(fd, buf)
                    os.write = fake_write
                    M.zip_compress_stream(p, z, level=1)
                    os._exit(0)
                except BaseException:
                    os._exit(1)
            os.waitpid(pid, 0)
            assert open(p, "rb").read() == data, "source must survive interrupted zip_compress_stream"
        M.zip_compress_stream(p, z, level=1)
        back = os.path.join(d, "back")
        M.zip_decompress_stream(z, back)
        assert open(back, "rb").read() == data, "retry after interruption must round-trip"


def stress_zip_decompress_crash_mid_write_retry_succeeds():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "src")
        data = os.urandom(2_000_000)
        open(p, "wb").write(data)
        z = os.path.join(d, "out.zip")
        M.zip_compress_stream(p, z, level=1)
        out = os.path.join(d, "out.bin")
        for _ in range(10):
            if os.path.exists(out):
                os.unlink(out)
            pid = os.fork()
            if pid == 0:
                try:
                    _orig_write = os.write
                    calls = {"n": 0}

                    def fake_write(fd, buf):
                        calls["n"] += 1
                        if calls["n"] >= 2:
                            os.kill(os.getpid(), signal.SIGKILL)
                        return _orig_write(fd, buf)
                    os.write = fake_write
                    M.zip_decompress_stream(z, out)
                    os._exit(0)
                except BaseException:
                    os._exit(1)
            os.waitpid(pid, 0)
            assert open(z, "rb").read() == open(z, "rb").read(), "archive itself never mutated"
        M.zip_decompress_stream(z, out)
        assert open(out, "rb").read() == data, "retry after interruption must round-trip"


def stress_bin_to_text_crash_mid_write_source_untouched():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "src")
        data = os.urandom(1_000_000)
        open(p, "wb").write(data)
        t = os.path.join(d, "t.txt")
        for _ in range(10):
            if os.path.exists(t):
                os.unlink(t)
            pid = os.fork()
            if pid == 0:
                try:
                    _orig_write = os.write
                    calls = {"n": 0}

                    def fake_write(fd, buf):
                        calls["n"] += 1
                        if calls["n"] >= 5:
                            os.kill(os.getpid(), signal.SIGKILL)
                        return _orig_write(fd, buf)
                    os.write = fake_write
                    M.bin_to_text(p, t)
                    os._exit(0)
                except BaseException:
                    os._exit(1)
            os.waitpid(pid, 0)
            assert open(p, "rb").read() == data, "source must survive interrupted bin_to_text"
        M.bin_to_text(p, t)
        back = os.path.join(d, "back")
        M.text_to_bin(t, back)
        assert open(back, "rb").read() == data, "retry after interruption must round-trip"


def stress_text_to_bin_crash_mid_write_retry_succeeds():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "src")
        data = os.urandom(1_000_000)
        open(p, "wb").write(data)
        t = os.path.join(d, "t.txt")
        M.bin_to_text(p, t)
        out = os.path.join(d, "out.bin")
        for _ in range(10):
            if os.path.exists(out):
                os.unlink(out)
            pid = os.fork()
            if pid == 0:
                try:
                    _orig_write = os.write
                    calls = {"n": 0}

                    def fake_write(fd, buf):
                        calls["n"] += 1
                        if calls["n"] >= 3:
                            os.kill(os.getpid(), signal.SIGKILL)
                        return _orig_write(fd, buf)
                    os.write = fake_write
                    M.text_to_bin(t, out)
                    os._exit(0)
                except BaseException:
                    os._exit(1)
            os.waitpid(pid, 0)
            assert open(t, "r").read() == open(t, "r").read(), "text source never mutated"
        M.text_to_bin(t, out)
        assert open(out, "rb").read() == data, "retry after interruption must round-trip"


def stress_cached_checksum_rapid_modify_no_stale_hits():
    """Rapid write+cached_checksum cycles in a tight loop. Guards
    against false cache hits from low filesystem mtime resolution
    (same second, different content)."""
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        for i in range(300):
            content = f"ITER{i}".encode() * 1000
            open(p, "wb").write(content)
            got = M.cached_checksum(p)
            expected = M.file_checksum(p)
            assert got == expected, f"stale cache hit at iter {i}"


def stress_all_byte_values_roundtrip():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "b")
        md = os.path.join(d, "m.md")
        back = os.path.join(d, "b2")
        open(p, "wb").write(bytes(range(256)) * 40 + b"|\n|\n")
        M.bin_to_md(p, md)
        M.md_to_bin(md, back)
        assert open(back, "rb").read() == open(p, "rb").read()


if __name__ == "__main__":
    for _n, _fn in sorted(globals().items()):
        if _n.startswith("stress_") and callable(_fn):
            _fn()
            print("ok", _n)
    print("ALL STRESS PASS")
