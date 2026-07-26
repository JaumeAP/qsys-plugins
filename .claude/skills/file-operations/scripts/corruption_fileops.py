"""Corruption-detection tests (bit-rot/truncation surface as checksum
mismatch, not silently). Real block-layer fault injection (dm-flakey,
dm-dust) is out of scope; this checks the detection layer only."""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fileops as M


def _flip_byte(path, offset):
    with open(path, "r+b") as f:
        f.seek(offset)
        b = f.read(1)
        f.seek(offset)
        f.write(bytes([b[0] ^ 0xFF]))


def corrupt_checksum_detects_flip():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "f")
        open(p, "wb").write(os.urandom(100000))
        good = M.file_checksum(p)
        assert M.verify_checksum(p, good)
        _flip_byte(p, 50000)
        assert not M.verify_checksum(p, good)


def corrupt_checksum_detects_truncation():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "f")
        open(p, "wb").write(os.urandom(100000))
        good = M.file_checksum(p)
        with open(p, "r+b") as f:
            f.truncate(99999)
        assert not M.verify_checksum(p, good)


def corrupt_md_dump_flip_detected_by_checksum():
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "b")
        open(p, "wb").write(os.urandom(20000))
        good = M.file_checksum(p)
        md = os.path.join(d, "m.md")
        back = os.path.join(d, "b2")
        M.bin_to_md(p, md)
        M.md_to_bin(md, back)
        assert M.verify_checksum(back, good)
        lines = open(md).read().splitlines()
        in_fence = False
        for i, ln in enumerate(lines):
            if not in_fence:
                if ln == chr(96) * 3 + "base64":
                    in_fence = True
                continue
            if ln == chr(96) * 3:
                break
            if ln:
                c = "B" if ln[0] != "B" else "C"
                lines[i] = c + ln[1:]
                break
        open(md, "w").write("\n".join(lines) + "\n")
        M.md_to_bin(md, back)
        assert not M.verify_checksum(back, good)


def corrupt_copy_then_verify_roundtrip():
    with tempfile.TemporaryDirectory() as d:
        s = os.path.join(d, "s")
        t = os.path.join(d, "t")
        open(s, "wb").write(os.urandom(300000))
        M.copy_file(s, t)
        assert M.file_checksum(s) == M.file_checksum(t)


if __name__ == "__main__":
    for _n, _fn in sorted(globals().items()):
        if _n.startswith("corrupt_") and callable(_fn):
            _fn()
            print("ok", _n)
    print("ALL CORRUPTION PASS")
