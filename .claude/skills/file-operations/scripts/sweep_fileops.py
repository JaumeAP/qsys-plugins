"""Full stress sweep, every function at scale, hard peak-memory ceiling
on streaming ones. Linux only. Run: python sweep_fileops.py"""
import os
import sys
import time
import shutil
import hashlib
import tempfile
import tracemalloc
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fileops as M

CAP = 12_000_000        # peak-memory ceiling for streaming funcs (bytes)
BIG = 64 * 1024 * 1024  # large input: proves memory is size-independent
MID = 16 * 1024 * 1024  # bin<->md expands ~5x, kept smaller
ALIGN = 4096            # fallocate range-op alignment


def _mk(path, size):
    with open(path, "wb") as f:
        rem = size
        while rem > 0:
            n = min(1 << 20, rem)
            f.write(os.urandom(n))
            rem -= n


def _peak(fn, *a, **k):
    tracemalloc.start()
    t = time.perf_counter()
    r = fn(*a, **k)
    dt = time.perf_counter() - t
    _, pk = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    return dt, pk, r


def sweep_all():
    d = tempfile.mkdtemp()
    R = {}

    p = os.path.join(d, "t.txt")
    M.write_file(p, "hello\nx")
    assert M.read_file(p) == "hello\nx"
    M.append_file(p, "Z")
    assert M.read_file(p) == "hello\nxZ"
    R["text_io"] = "ok"

    pb = os.path.join(d, "t.bin")
    data = os.urandom(1_000_000)
    M.write_file_bytes(pb, data)
    assert M.read_file_bytes(pb) == data
    R["bytes_io"] = "ok"

    big = os.path.join(d, "big")
    _mk(big, BIG)
    ref = hashlib.sha256(open(big, "rb").read()).hexdigest()

    total = 0
    tracemalloc.start()
    for ch in M.stream_chunks(big):
        total += len(ch)
    _, pk = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    assert total == BIG and pk < CAP
    R["stream_chunks"] = f"peak={pk/1e6:.1f}MB"

    dt, pk, cs = _peak(M.file_checksum, big)
    assert cs == ref and pk < CAP
    R["file_checksum"] = f"{dt:.2f}s peak={pk/1e6:.1f}MB"
    assert M.verify_checksum(big, ref)
    R["verify_checksum"] = "ok"

    cpy = os.path.join(d, "cpy")
    dt, pk, nb = _peak(M.copy_file, big, cpy)
    assert nb == BIG and M.file_checksum(cpy) == ref and pk < CAP
    R["copy_file"] = f"{dt:.2f}s peak={pk/1e6:.1f}MB"

    gz = os.path.join(d, "big.gz")
    gz2 = os.path.join(d, "big2.gz")
    dt, pk, _ = _peak(M.compress_stream, big, gz, level=1)
    M.compress_stream(big, gz2, level=1)
    assert pk < CAP and open(gz, "rb").read() == open(gz2, "rb").read()
    R["compress_stream"] = f"{dt:.2f}s peak={pk/1e6:.1f}MB reproducible"
    out = os.path.join(d, "big.out")
    dt, pk, _ = _peak(M.decompress_stream, gz, out)
    assert open(out, "rb").read() == open(big, "rb").read() and pk < CAP
    R["decompress_stream"] = f"{dt:.2f}s peak={pk/1e6:.1f}MB"

    rr = os.path.join(d, "rr")
    shutil.copy(big, rr)
    dt, pk, _ = _peak(M.replace_range, rr, 100, 50, b"PATCH", True)
    with open(rr, "rb") as f:
        f.read(100)
        assert f.read(5) == b"PATCH"
    assert pk < CAP
    R["replace_range"] = f"{dt:.2f}s peak={pk/1e6:.1f}MB"

    assert M.mmap_read(big, 0, 16) == open(big, "rb").read()[:16]
    empty = os.path.join(d, "empty")
    open(empty, "wb").close()
    assert M.mmap_read(empty, 0, 10) == b""
    try:
        M.mmap_read(big)
        assert False
    except ValueError:
        pass
    R["mmap_read"] = "ok (window+empty+guard)"

    al = os.path.join(d, "al")
    open(al, "wb").write(bytes([1]) * ALIGN + bytes([2]) * ALIGN + bytes([3]) * ALIGN)
    M.cut_range(al, ALIGN, ALIGN)
    assert open(al, "rb").read() == bytes([1]) * ALIGN + bytes([3]) * ALIGN
    R["cut_range"] = "ok aligned"
    M.insert_gap(al, ALIGN, ALIGN)
    r = open(al, "rb").read()
    assert len(r) == 3 * ALIGN and r[ALIGN:2 * ALIGN] == bytes(ALIGN)
    R["insert_gap"] = "ok aligned"

    s2 = os.path.join(d, "s2")
    t2 = os.path.join(d, "t2")
    _mk(s2, 2_000_000)
    sf = os.open(s2, os.O_RDONLY)
    tf = os.open(t2, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)
    try:
        got = M.copy_range_fast(sf, tf, 2_000_000)
    finally:
        os.close(sf)
        os.close(tf)
    assert got == 2_000_000 and open(s2, "rb").read() == open(t2, "rb").read()
    R["copy_range_fast"] = "ok byte-exact"

    aw = os.path.join(d, "aw")
    big_bytes = os.urandom(MID)
    M.atomic_write(aw, big_bytes, durable=True)
    assert open(aw, "rb").read() == big_bytes
    R["atomic_write"] = "ok durable 16MB"

    mid = os.path.join(d, "mid")
    _mk(mid, MID)
    mref = M.file_checksum(mid)
    md = os.path.join(d, "mid.md")
    back = os.path.join(d, "mid.bin")
    tracemalloc.start()
    t = time.perf_counter()
    M.bin_to_md(mid, md)
    M.md_to_bin(md, back)
    dt = time.perf_counter() - t
    _, pk = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    assert M.verify_checksum(back, mref) and pk < CAP
    R["bin_md_roundtrip"] = f"{dt:.2f}s md={os.path.getsize(md)//1024}KB peak={pk/1e6:.1f}MB"

    vic = os.path.join(d, "vic")
    shutil.copy(big, vic)
    dt, pk, _ = _peak(M.secure_delete, vic, 1, confirm=True)
    assert not os.path.exists(vic) and pk < CAP
    R["secure_delete"] = f"{dt:.2f}s peak={pk/1e6:.1f}MB"

    lp = os.path.join(d, "lock")
    open(lp, "w").write("0")
    pids = []
    for _ in range(8):
        pid = os.fork()
        if pid == 0:
            for _ in range(50):
                with M.file_lock(lp):
                    v = int(open(lp).read())
                    open(lp, "w").write(str(v + 1))
            os._exit(0)
        pids.append(pid)
    for pid in pids:
        os.waitpid(pid, 0)
    assert int(open(lp).read()) == 400
    R["file_lock"] = "ok 8x50=400 no lost"

    ct_src = os.path.join(d, "ct_src")
    os.makedirs(ct_src)
    for i in range(4):
        _mk(os.path.join(ct_src, f"big{i}"), 8 * 1024 * 1024)  # 4x8MB = 32MB tree
    ct_dst = os.path.join(d, "ct_dst")
    tracemalloc.start()
    t = time.perf_counter()
    n = M.copy_tree(ct_src, ct_dst)
    dt = time.perf_counter() - t
    _, pk = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    assert n == 4 and pk < CAP
    for i in range(4):
        assert M.file_checksum(os.path.join(ct_src, f"big{i}")) == M.file_checksum(os.path.join(ct_dst, f"big{i}"))
    R["copy_tree"] = f"{dt:.2f}s peak={pk/1e6:.1f}MB 4x8MB tree"

    zsrc = os.path.join(d, "z_payload")
    _mk(zsrc, 32 * 1024 * 1024)  # 32MB single entry, undercompressed on purpose
    zpath = os.path.join(d, "big.zip")
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_STORED) as zf:
        zf.write(zsrc, arcname="payload.bin")
    zout = os.path.join(d, "z_out")
    tracemalloc.start()
    t = time.perf_counter()
    M.safe_extract_zip(zpath, zout)
    dt = time.perf_counter() - t
    _, pk = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    assert M.file_checksum(zsrc) == M.file_checksum(os.path.join(zout, "payload.bin"))
    R["safe_extract_zip"] = f"{dt:.2f}s peak={pk/1e6:.1f}MB 32MB entry (zipfile buffers, not capped by CAP)"

    print(f"CAP={CAP/1e6:.0f}MB BIG={BIG//1024//1024}MB MID={MID//1024//1024}MB")
    for k, v in R.items():
        print(f"  {k}: {v}")
    print("ALL SWEEP PASS")


if __name__ == "__main__":
    sweep_all()
