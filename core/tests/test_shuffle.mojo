# === core/tests/test_shuffle.mojo ===
# TDD RED: 测试 core/simd/shuffle (gather/scatter/reverse/rotate/mask 归约)。模块未实现, 应编译失败。
from simd.vector import Vector
from simd.shuffle import (
    gather, scatter, reverse, rotate_left, rotate_right,
    mask_any, mask_all, count_true, first_true_index,
)


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol


def test_gather() raises:
    var base = Vector[4](1.0)
    base.set(1, 10.0); base.set(3, 30.0)
    var idx = Vector[4](0.0)
    idx.set(0, 3.0); idx.set(1, 1.0); idx.set(2, 0.0); idx.set(3, 1.0)
    var g = gather(base, idx)
    if not approx(g.get(0), 30.0, 1e-9): raise Error("gather[0] wrong")
    if not approx(g.get(1), 10.0, 1e-9): raise Error("gather[1] wrong")
    if not approx(g.get(2), 1.0, 1e-9): raise Error("gather[2] wrong")


def test_gather_oob_raises() raises:
    var base = Vector[4](1.0)
    var idx = Vector[4](0.0); idx.set(0, 9.0)   # 越界
    var caught = False
    try:
        _ = gather(base, idx)
    except:
        caught = True
    if not caught:
        raise Error("gather should raise on OOB index")


def test_scatter() raises:
    var dst = Vector[4](0.0)
    var src = Vector[4](7.0)
    var idx = Vector[4](0.0)
    idx.set(0, 2.0); idx.set(1, 0.0); idx.set(2, 3.0); idx.set(3, 1.0)
    scatter(dst, src, idx)
    if not approx(dst.get(2), 7.0, 1e-9): raise Error("scatter dst[2] wrong")
    if not approx(dst.get(0), 7.0, 1e-9): raise Error("scatter dst[0] wrong")
    if not approx(dst.get(3), 7.0, 1e-9): raise Error("scatter dst[3] wrong")


def test_reverse() raises:
    var v = Vector[4](1.0)
    v.set(0, 1.0); v.set(1, 2.0); v.set(2, 3.0); v.set(3, 4.0)
    var r = reverse(v)
    if not approx(r.get(0), 4.0, 1e-9): raise Error("reverse[0] wrong")
    if not approx(r.get(3), 1.0, 1e-9): raise Error("reverse[3] wrong")


def test_rotate_left() raises:
    var v = Vector[4](1.0)
    v.set(0, 1.0); v.set(1, 2.0); v.set(2, 3.0); v.set(3, 4.0)
    var r = rotate_left(v, 1)
    if not approx(r.get(0), 2.0, 1e-9): raise Error("rotl[0] wrong")
    if not approx(r.get(3), 1.0, 1e-9): raise Error("rotl[3] wrong")


def test_rotate_right() raises:
    var v = Vector[4](1.0)
    v.set(0, 1.0); v.set(1, 2.0); v.set(2, 3.0); v.set(3, 4.0)
    var r = rotate_right(v, 1)
    if not approx(r.get(0), 4.0, 1e-9): raise Error("rotr[0] wrong")
    if not approx(r.get(3), 3.0, 1e-9): raise Error("rotr[3] wrong")


def test_mask_any_all() raises:
    var a = Vector[4](1.0)
    var b = Vector[4](2.0)
    var all_true = a.lt(b)
    var none_true = a.gt(b)
    if not mask_any(all_true): raise Error("mask_any should be True")
    if mask_any(none_true): raise Error("mask_any should be False")
    if not mask_all(all_true): raise Error("mask_all should be True")


def test_count_true() raises:
    var a = Vector[4](1.0)
    a.set(0, 5.0); a.set(2, 9.0)
    var b = Vector[4](2.0)
    var m = a.gt(b)        # lanes 0 和 2 为 True
    if count_true(m) != 2: raise Error("count_true should be 2")


def test_first_true_index() raises:
    var a = Vector[4](1.0)
    a.set(2, 9.0)
    var b = Vector[4](2.0)
    var m = a.gt(b)
    if first_true_index(m) != 2: raise Error("first_true_index should be 2")


def main() raises:
    var failed = 0
    print("=== core/simd/shuffle tests ===")
    try: test_gather();              print("  passed: test_gather")
    except e: failed += 1; print("  FAILED: test_gather ->", e)
    try: test_gather_oob_raises();   print("  passed: test_gather_oob_raises")
    except e: failed += 1; print("  FAILED: test_gather_oob_raises ->", e)
    try: test_scatter();             print("  passed: test_scatter")
    except e: failed += 1; print("  FAILED: test_scatter ->", e)
    try: test_reverse();             print("  passed: test_reverse")
    except e: failed += 1; print("  FAILED: test_reverse ->", e)
    try: test_rotate_left();         print("  passed: test_rotate_left")
    except e: failed += 1; print("  FAILED: test_rotate_left ->", e)
    try: test_rotate_right();        print("  passed: test_rotate_right")
    except e: failed += 1; print("  FAILED: test_rotate_right ->", e)
    try: test_mask_any_all();        print("  passed: test_mask_any_all")
    except e: failed += 1; print("  FAILED: test_mask_any_all ->", e)
    try: test_count_true();          print("  passed: test_count_true")
    except e: failed += 1; print("  FAILED: test_count_true ->", e)
    try: test_first_true_index();    print("  passed: test_first_true_index")
    except e: failed += 1; print("  FAILED: test_first_true_index ->", e)
    if failed > 0:
        print("shuffle -> passed: 0  failed:", failed)
        raise Error("core/simd/shuffle tests failed")
    print("shuffle -> passed: 10  failed: 0")
