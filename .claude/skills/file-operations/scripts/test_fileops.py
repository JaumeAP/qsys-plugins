"""Failure-path tests for fileops.py. Run: python -m pytest test_fileops.py
or `python test_fileops.py` directly. Linux/ext4 assumed."""
import os
import sys
import tempfile
import tracemalloc

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fileops as M


def test_atomic_write_durable_roundtrip():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "a.txt")
        M.atomic_write(p, "hello", durable=True)
        assert open(p).read() == "hello"


def test_atomic_write_never_partial_on_writer_error():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "a.txt")
        M.atomic_write(p, "seed", durable=True)
        orig = open(p).read()
        raised = False
        try:
            bad = type("B", (), {"encode": lambda self, e: (_ for _ in ()).throw(RuntimeError("boom"))})()
            M.atomic_write(p, bad, durable=True)
        except Exception:
            raised = True
        assert raised, "expected atomic_write to raise, none raised"
        assert open(p).read() == orig
        leftovers = [f for f in os.listdir(d) if f != "a.txt"]
        assert not leftovers


def test_replace_range_unaligned():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "b.bin")
        open(p, "wb").write(b"0123456789")
        M.replace_range(p, 3, 4, b"XX", durable=True)  # 3456 -> XX
        assert open(p, "rb").read() == b"012XX789"


def test_copy_file_happy():
    with tempfile.TemporaryDirectory() as d:
        s, t = os.path.join(d, "s"), os.path.join(d, "t")
        open(s, "wb").write(os.urandom(200_000))
        assert M.copy_file(s, t) == 200_000
        assert open(s, "rb").read() == open(t, "rb").read()


def test_copy_file_fallback_after_partial_write():
    with tempfile.TemporaryDirectory() as d:
        s, t = os.path.join(d, "s"), os.path.join(d, "t")
        open(s, "wb").write(os.urandom(200_000))
        orig = M.copy_range_fast
        M.copy_range_fast = lambda a, b, c: (os.write(b, b"GARBAGE"), (_ for _ in ()).throw(OSError("x")))[0]
        try:
            M.copy_file(s, t)
        finally:
            M.copy_range_fast = orig
        assert open(s, "rb").read() == open(t, "rb").read()


def test_secure_delete_bounded_memory():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "sec")
        open(p, "wb").write(os.urandom(30_000_000))
        tracemalloc.start()
        M.secure_delete(p, passes=1, confirm=True)
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        assert not os.path.exists(p)
        assert peak < 8_000_000, peak


def test_compress_reproducible_and_roundtrip():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "c.bin")
        open(p, "wb").write(os.urandom(500_000))
        o1, o2 = os.path.join(d, "c1.gz"), os.path.join(d, "c2.gz")
        M.compress_stream(p, o1)
        M.compress_stream(p, o2)
        assert open(o1, "rb").read() == open(o2, "rb").read()
        out = os.path.join(d, "c.out")
        M.decompress_stream(o1, out)
        assert open(p, "rb").read() == open(out, "rb").read()


def test_copy_tree_preserves_structure():
    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, "src")
        os.makedirs(os.path.join(src, "sub"))
        open(os.path.join(src, "a.txt"), "w").write("A")
        open(os.path.join(src, "sub", "b.txt"), "w").write("B")
        dst = os.path.join(d, "dst")
        n = M.copy_tree(src, dst)
        assert n == 2
        assert open(os.path.join(dst, "a.txt")).read() == "A"
        assert open(os.path.join(dst, "sub", "b.txt")).read() == "B"
        assert os.path.exists(os.path.join(src, "a.txt")), "src must survive copy"


def test_copy_tree_rejects_nonempty_dst():
    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, "src")
        os.makedirs(src)
        open(os.path.join(src, "a.txt"), "w").write("A")
        dst = os.path.join(d, "dst")
        os.makedirs(dst)
        open(os.path.join(dst, "existing.txt"), "w").write("X")
        raised = False
        try:
            M.copy_tree(src, dst)
        except FileExistsError:
            raised = True
        assert raised


def test_move_tree_removes_source():
    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, "src")
        os.makedirs(src)
        open(os.path.join(src, "a.txt"), "w").write("A")
        dst = os.path.join(d, "dst")
        M.move_tree(src, dst)
        assert not os.path.exists(src)
        assert open(os.path.join(dst, "a.txt")).read() == "A"


def test_is_safe_path_blocks_traversal():
    with tempfile.TemporaryDirectory() as d:
        assert M.is_safe_path(d, "ok/sub/file.txt") is True
        assert M.is_safe_path(d, "../../etc/passwd") is False
        assert M.is_safe_path(d, "/etc/passwd") is False


def test_disk_free_positive():
    with tempfile.TemporaryDirectory() as d:
        assert M.disk_free(d) > 0
        assert M.disk_free(os.path.join(d, "not_yet_created.txt")) > 0


def test_safe_extract_zip_blocks_zip_slip():
    import zipfile
    with tempfile.TemporaryDirectory() as d:
        evil = os.path.join(d, "evil.zip")
        with zipfile.ZipFile(evil, "w") as zf:
            zf.writestr("../../evil.txt", "pwn")
        out = os.path.join(d, "out")
        raised = False
        try:
            M.safe_extract_zip(evil, out)
        except ValueError:
            raised = True
        assert raised
        assert not os.path.exists(os.path.join(d, "evil.txt")), "payload must not escape out_dir"


def test_safe_extract_zip_happy():
    import zipfile
    with tempfile.TemporaryDirectory() as d:
        good = os.path.join(d, "good.zip")
        with zipfile.ZipFile(good, "w") as zf:
            zf.writestr("inner/file.txt", "hello")
        out = os.path.join(d, "out")
        n = M.safe_extract_zip(good, out)
        assert n == 1
        assert open(os.path.join(out, "inner", "file.txt")).read() == "hello"


def test_safe_extract_tar_blocks_tar_slip():
    import tarfile
    import io
    with tempfile.TemporaryDirectory() as d:
        evil = os.path.join(d, "evil.tar")
        with tarfile.open(evil, "w") as tf:
            info = tarfile.TarInfo(name="../../evil2.txt")
            data = b"pwn"
            info.size = len(data)
            tf.addfile(info, io.BytesIO(data))
        out = os.path.join(d, "out")
        raised = False
        try:
            M.safe_extract_tar(evil, out)
        except ValueError:
            raised = True
        assert raised
        assert not os.path.exists(os.path.join(d, "evil2.txt"))


def test_rmtree_safe_requires_confirm():
    with tempfile.TemporaryDirectory() as d:
        victim = os.path.join(d, "victim")
        os.makedirs(os.path.join(victim, "sub"))
        open(os.path.join(victim, "a.txt"), "w").write("A")
        open(os.path.join(victim, "sub", "b.txt"), "w").write("B")
        raised = False
        try:
            M.rmtree_safe(victim)
        except PermissionError:
            raised = True
        assert raised
        assert os.path.exists(victim), "must survive missing confirm"
        n = M.rmtree_safe(victim, confirm=True)
        assert n == 2
        assert not os.path.exists(victim)


# ---------------------------------------------------------------------------
# Parameter-limit edge cases
# ---------------------------------------------------------------------------


def test_replace_range_negative_offset_rejected():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(b"0123456789")
        raised = False
        try:
            M.replace_range(p, -1, 2, b"X")
        except ValueError:
            raised = True
        assert raised
        assert open(p, "rb").read() == b"0123456789"


def test_replace_range_out_of_bounds_rejected():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(b"0123456789")
        raised = False
        try:
            M.replace_range(p, 5, 100, b"X")
        except ValueError:
            raised = True
        assert raised
        assert open(p, "rb").read() == b"0123456789"


def test_replace_range_zero_length_pure_insert():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(b"0123456789")
        M.replace_range(p, 5, 0, b"++")
        assert open(p, "rb").read() == b"01234++56789"


def test_bin_to_md_rejects_non_multiple_of_3():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "b")
        open(p, "wb").write(b"hello")
        raised = False
        try:
            M.bin_to_md(p, os.path.join(d, "m.md"), line_bytes=10)
        except ValueError:
            raised = True
        assert raised


def test_secure_delete_zero_passes_still_deletes():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "y")
        open(p, "wb").write(b"AAAA")
        M.secure_delete(p, passes=0, confirm=True)
        assert not os.path.exists(p)


def test_mmap_read_requires_length():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "m")
        open(p, "wb").write(b"x" * 100)
        raised = False
        try:
            M.mmap_read(p)  # length omitted
        except ValueError:
            raised = True
        assert raised


def test_stream_chunks_rejects_zero_size():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "s")
        open(p, "wb").write(b"x" * 10)
        raised = False
        try:
            list(M.stream_chunks(p, size=0))
        except ValueError:
            raised = True
        assert raised


def test_copy_tree_deeply_nested_150_levels():
    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, "src")
        cur = src
        for i in range(150):
            cur = os.path.join(cur, f"d{i}")
        os.makedirs(cur)
        open(os.path.join(cur, "leaf.txt"), "w").write("deep")
        dst = os.path.join(d, "dst")
        n = M.copy_tree(src, dst)
        assert n == 1
        cur2 = dst
        for i in range(150):
            cur2 = os.path.join(cur2, f"d{i}")
        assert open(os.path.join(cur2, "leaf.txt")).read() == "deep"


def test_is_safe_path_empty_target_is_base_itself():
    with tempfile.TemporaryDirectory() as d:
        assert M.is_safe_path(d, "") is True


def test_zip_compress_decompress_roundtrip():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "c.bin")
        open(p, "wb").write(os.urandom(500_000))
        z = os.path.join(d, "c.zip")
        M.zip_compress_stream(p, z, level=9)
        out = os.path.join(d, "c.out")
        M.zip_decompress_stream(z, out)
        assert open(p, "rb").read() == open(out, "rb").read()


def test_zip_compress_custom_arcname():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "c.bin")
        open(p, "wb").write(b"hello")
        z = os.path.join(d, "c.zip")
        M.zip_compress_stream(p, z, arcname="renamed.bin", level=9)
        import zipfile
        with zipfile.ZipFile(z) as zf:
            assert zf.namelist() == ["renamed.bin"]
        out = os.path.join(d, "out.bin")
        M.zip_decompress_stream(z, out)
        assert open(out, "rb").read() == b"hello"


def test_zip_decompress_missing_arcname_uses_first_entry():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "c.bin")
        open(p, "wb").write(b"data")
        z = os.path.join(d, "c.zip")
        M.zip_compress_stream(p, z)
        out = os.path.join(d, "out.bin")
        M.zip_decompress_stream(z, out)  # no arcname given
        assert open(out, "rb").read() == b"data"


# ---------------------------------------------------------------------------
# Out-of-range parameter tests
# ---------------------------------------------------------------------------


def test_stream_chunks_rejects_negative_size():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(b"0123456789")
        raised = False
        try:
            list(M.stream_chunks(p, size=-5))
        except ValueError:
            raised = True
        assert raised


def test_mmap_read_negative_offset_raises():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(b"0123456789")
        raised = False
        try:
            M.mmap_read(p, offset=-1, length=3)
        except ValueError:
            raised = True
        assert raised


def test_mmap_read_length_beyond_eof_truncates_no_crash():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(b"0123456789")
        assert M.mmap_read(p, offset=0, length=10_000) == b"0123456789"


def test_cut_range_negative_offset_raises_oserror():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(b"0" * 4096 * 3)
        raised = False
        try:
            M.cut_range(p, -1, 4096)
        except OSError:
            raised = True
        assert raised


def test_compress_stream_rejects_invalid_level():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(b"0123456789")
        raised = False
        try:
            M.compress_stream(p, os.path.join(d, "o.gz"), level=99)
        except ValueError:
            raised = True
        assert raised


def test_zip_compress_rejects_invalid_level_no_leftover():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(b"0123456789")
        out = os.path.join(d, "o.zip")
        raised = False
        try:
            M.zip_compress_stream(p, out, level=99)
        except ValueError:
            raised = True
        assert raised
        assert not os.path.exists(out), "no partial/corrupt zip left behind"


def test_secure_delete_negative_passes_still_deletes():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "y")
        open(p, "wb").write(b"AAAA")
        M.secure_delete(p, passes=-3, confirm=True)
        assert not os.path.exists(p)


def test_replace_range_huge_offset_rejected():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(b"0123456789")
        raised = False
        try:
            M.replace_range(p, 2**40, 1, b"X")
        except ValueError:
            raised = True
        assert raised


def test_disk_free_deep_nonexistent_path():
    with tempfile.TemporaryDirectory() as d:
        deep = os.path.join(d, "a", "b", "c", "d.txt")
        assert M.disk_free(deep) > 0


# ---------------------------------------------------------------------------
# Memory-limit tests
# ---------------------------------------------------------------------------


def test_file_checksum_tiny_block_size_bounded_memory():
    """block_size=1 forces one syscall per byte; must still be correct
    and stay well under a generous cap (no per-call buffer growth)."""
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        data = os.urandom(200_000)
        open(p, "wb").write(data)
        tracemalloc.start()
        h = M.file_checksum(p, block_size=1)
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        assert h == M.file_checksum(p, block_size=1 << 20)
        assert peak < 5_000_000, peak


def test_zip_compress_stream_bounded_memory_16mb():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "big")
        with open(p, "wb") as f:
            for _ in range(16):
                f.write(os.urandom(1 << 20))
        z = os.path.join(d, "big.zip")
        tracemalloc.start()
        M.zip_compress_stream(p, z, level=1)
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        assert peak < 8_000_000, peak
        out = os.path.join(d, "back")
        M.zip_decompress_stream(z, out)
        assert open(p, "rb").read() == open(out, "rb").read()


def test_bin_to_text_roundtrip_all_byte_values():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "b")
        t = os.path.join(d, "t.txt")
        back = os.path.join(d, "back")
        open(p, "wb").write(bytes(range(256)) * 40)
        M.bin_to_text(p, t)
        M.text_to_bin(t, back)
        assert open(back, "rb").read() == open(p, "rb").read()


def test_bin_to_text_no_markdown_fence():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "b")
        t = os.path.join(d, "t.txt")
        open(p, "wb").write(b"hello world")
        M.bin_to_text(p, t)
        content = open(t).read()
        assert "```" not in content
        assert "# binary" not in content


def test_bin_to_text_rejects_non_multiple_of_3():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "b")
        open(p, "wb").write(b"hello")
        raised = False
        try:
            M.bin_to_text(p, os.path.join(d, "t.txt"), line_bytes=10)
        except ValueError:
            raised = True
        assert raised


def test_bin_to_text_empty_file():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "b")
        t = os.path.join(d, "t.txt")
        back = os.path.join(d, "back")
        open(p, "wb").close()
        M.bin_to_text(p, t)
        assert open(t).read() == ""
        M.text_to_bin(t, back)
        assert open(back, "rb").read() == b""


def test_bin_to_text_bounded_memory_16mb():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "big")
        with open(p, "wb") as f:
            for _ in range(16):
                f.write(os.urandom(1 << 20))
        t = os.path.join(d, "t.txt")
        tracemalloc.start()
        M.bin_to_text(p, t)
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        assert peak < 5_000_000, peak
        back = os.path.join(d, "back")
        tracemalloc.start()
        M.text_to_bin(t, back)
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        assert peak < 5_000_000, peak
        assert open(p, "rb").read() == open(back, "rb").read()


# ---------------------------------------------------------------------------
# More out-of-range params / scale tests
# ---------------------------------------------------------------------------


def test_copy_tree_missing_src_rejected():
    with tempfile.TemporaryDirectory() as d:
        raised = False
        try:
            M.copy_tree(os.path.join(d, "nope"), os.path.join(d, "out"))
        except NotADirectoryError:
            raised = True
        assert raised
        assert not os.path.exists(os.path.join(d, "out")), "must not create dst on missing src"


def test_zip_decompress_stream_empty_zip_rejected():
    import zipfile
    with tempfile.TemporaryDirectory() as d:
        ez = os.path.join(d, "empty.zip")
        with zipfile.ZipFile(ez, "w"):
            pass
        raised = False
        try:
            M.zip_decompress_stream(ez, os.path.join(d, "out"))
        except ValueError:
            raised = True
        assert raised


def test_rmtree_safe_missing_path_raises():
    with tempfile.TemporaryDirectory() as d:
        raised = False
        try:
            M.rmtree_safe(os.path.join(d, "nope"), confirm=True)
        except FileNotFoundError:
            raised = True
        assert raised


def test_rmtree_safe_on_plain_file_raises():
    with tempfile.TemporaryDirectory() as d:
        f = os.path.join(d, "justfile")
        open(f, "w").write("x")
        raised = False
        try:
            M.rmtree_safe(f, confirm=True)
        except NotADirectoryError:
            raised = True
        assert raised
        assert os.path.exists(f)


def test_copy_tree_5000_small_files_bounded_memory():
    with tempfile.TemporaryDirectory() as d:
        src = os.path.join(d, "src")
        os.makedirs(src)
        for i in range(5000):
            open(os.path.join(src, f"f{i}"), "w").write("x")
        dst = os.path.join(d, "dst")
        tracemalloc.start()
        n = M.copy_tree(src, dst)
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        assert n == 5000
        assert peak < 10_000_000, peak
        assert len(os.listdir(dst)) == 5000


def test_safe_extract_zip_2000_entries_bounded_memory():
    import zipfile
    with tempfile.TemporaryDirectory() as d:
        z = os.path.join(d, "many.zip")
        with zipfile.ZipFile(z, "w") as zf:
            for i in range(2000):
                zf.writestr(f"f{i}.txt", "x" * 10)
        tracemalloc.start()
        n = M.safe_extract_zip(z, os.path.join(d, "ext"))
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        assert n == 2000
        assert peak < 10_000_000, peak


def test_cached_checksum_hit_matches_file_checksum():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(os.urandom(500_000))
        h1 = M.cached_checksum(p)
        h2 = M.cached_checksum(p)
        assert h1 == h2 == M.file_checksum(p)


def test_cached_checksum_invalidates_on_content_change():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(b"A" * 100_000)
        h1 = M.cached_checksum(p)
        open(p, "wb").write(b"B" * 100_000)
        h2 = M.cached_checksum(p)
        assert h1 != h2
        assert h2 == M.file_checksum(p)


def test_cached_checksum_different_algo_different_cache_entry():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(os.urandom(50_000))
        h_sha = M.cached_checksum(p, algo="sha256")
        h_md5 = M.cached_checksum(p, algo="md5")
        assert h_sha != h_md5
        assert h_sha == M.file_checksum(p, algo="sha256")
        assert h_md5 == M.file_checksum(p, algo="md5")


def test_clear_checksum_cache_forces_recompute():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(os.urandom(50_000))
        M.cached_checksum(p)
        n = M.clear_checksum_cache()
        assert n >= 1
        assert M.clear_checksum_cache() == 0


def test_cached_checksum_failed_read_leaves_no_stale_entry():
    """A read error mid-hash must not poison the cache with a partial
    result; the entry must be absent, and a later successful call must
    still return the correct hash."""
    import builtins
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "x")
        open(p, "wb").write(os.urandom(5_000_000))
        M.clear_checksum_cache()

        calls = {"n": 0}
        real_open = builtins.open

        class FailingFile:
            def __init__(self, f):
                self.f = f

            def read(self, n):
                calls["n"] += 1
                if calls["n"] >= 2:
                    raise IOError("simulated interrupt")
                return self.f.read(n)

            def __enter__(self):
                return self

            def __exit__(self, *a):
                self.f.close()

        def fake_open(path, mode="r", **kw):
            f = real_open(path, mode, **kw)
            if path == p and "b" in mode:
                return FailingFile(f)
            return f

        builtins.open = fake_open
        raised = False
        try:
            M.cached_checksum(p)
        except IOError:
            raised = True
        finally:
            builtins.open = real_open

        assert raised
        assert len(M._CHECKSUM_CACHE) == 0, "no partial entry left after failed hash"
        h = M.cached_checksum(p)
        assert h == M.file_checksum(p)


if __name__ == "__main__":
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            fn()
            print("ok", name)
    print("ALL PASS")
