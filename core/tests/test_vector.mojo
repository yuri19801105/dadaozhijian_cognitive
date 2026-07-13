# === core/tests/test_vector.mojo ===
# TDD RED: 测试 core/simd/vector。模块尚未实现, 应编译失败(RED)。
from std.testing import assert_equal

from simd.vector import Vector


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    return (a - b) < 0.0 if (a - b) < 0.0 else (b - a) < tol


def test_construct_fill_zero() raises:
    var z = Vector[4]()
    if z.get(0) != 0.0 or z.get(3) != 0.0:
        raise Error("zero ctor broken")
    var f = Vector[4](2.5)
    if not approx(f.get(0), 2.5, 1e-9) or not approx(f.get(3), 2.5, 1e-9):
        raise Error("fill ctor broken")


def test_get_set() raises:
    var v = Vector[3](1.0)
    v.set(1, 7.0)
    if not approx(v.get(1), 7.0, 1e-9):
        raise Error("set/get broken")


def test_from_list() raises:
    var src = List[Float64]()
    src.append(1.0); src.append(2.0); src.append(3.0)
    var v = Vector[3](src)
    if not approx(v.get(2), 3.0, 1e-9):
        raise Error("from_list broken")


def test_elementwise() raises:
    var a = Vector[4](1.0)
    var b = Vector[4](2.0)
    var s = a.add(b)
    var d = a.sub(b)
    var m = a.mul(b)
    var q = a.div(b)
    if not approx(s.get(0), 3.0, 1e-9): raise Error("add broken")
    if not approx(d.get(0), -1.0, 1e-9): raise Error("sub broken")
    if not approx(m.get(0), 2.0, 1e-9): raise Error("mul broken")
    if not approx(q.get(0), 0.5, 1e-9): raise Error("div broken")


def test_scale_and_add_scaled() raises:
    var a = Vector[4](1.0)
    var b = Vector[4](2.0)
    var sc = a.scale(3.0)
    if not approx(sc.get(0), 3.0, 1e-9): raise Error("scale broken")
    var fas = a.add_scaled(b, 2.0)
    if not approx(fas.get(0), 5.0, 1e-9): raise Error("add_scaled broken")


def test_dot() raises:
    var a = Vector[4](1.0)
    var b = Vector[4](2.0)
    if not approx(a.dot(b), 8.0, 1e-9): raise Error("dot broken")


def test_reductions() raises:
    var v = Vector[4](1.0)
    v.set(1, 3.0); v.set(2, 5.0); v.set(3, 2.0)
    if not approx(v.sum(), 11.0, 1e-9): raise Error("sum broken")
    if not approx(v.max(), 5.0, 1e-9): raise Error("max broken")
    if not approx(v.min(), 1.0, 1e-9): raise Error("min broken")
    if not approx(v.prod(), 30.0, 1e-9): raise Error("prod broken")


def test_argmax() raises:
    var v = Vector[4](1.0)
    v.set(2, 9.0)
    if v.argmax() != 2: raise Error("argmax broken")
    # 边界: 全相等时返回首个索引
    var w = Vector[4](5.0)
    if w.argmax() != 0: raise Error("argmax tie broken")


def test_compare_mask_select() raises:
    var a = Vector[4](1.0)
    var b = Vector[4](2.0)
    var mask = a.lt(b)            # 期望全 True
    var blended = a.select(mask, b)
    if not approx(blended.get(0), 1.0, 1e-9): raise Error("select true-case broken")
    var mask2 = a.gt(b)           # 期望全 False
    var blended2 = a.select(mask2, b)
    if not approx(blended2.get(0), 2.0, 1e-9): raise Error("select false-case broken")


def test_to_list() raises:
    var v = Vector[3](1.0)
    v.set(1, 4.0)
    var L = v.to_list()
    if len(L) != 3: raise Error("to_list length broken")
    if not approx(L[1], 4.0, 1e-9): raise Error("to_list content broken")


def test_normalize() raises:
    var v = Vector[3](3.0)
    var n = v.normalize()
    if not approx(n.norm(), 1.0, 1e-9): raise Error("normalize broken")


def test_bounds_checked_at_raises() raises:
    # 异常处理: 越界访问必须 raise
    var v = Vector[4](1.0)
    var caught = False
    try:
        _ = v.at(4)
    except:
        caught = True
    if not caught:
        raise Error("at() should raise on OOB index 4")
    try:
        _ = v.at(-1)
    except:
        caught = True
    if not caught:
        raise Error("at() should raise on negative index")


def main() raises:
    var failed = 0
    print("=== core/simd/vector tests ===")
    try: test_construct_fill_zero();   print("  passed: test_construct_fill_zero")
    except e: failed += 1; print("  FAILED: test_construct_fill_zero ->", e)
    try: test_get_set();               print("  passed: test_get_set")
    except e: failed += 1; print("  FAILED: test_get_set ->", e)
    try: test_from_list();             print("  passed: test_from_list")
    except e: failed += 1; print("  FAILED: test_from_list ->", e)
    try: test_elementwise();           print("  passed: test_elementwise")
    except e: failed += 1; print("  FAILED: test_elementwise ->", e)
    try: test_scale_and_add_scaled();  print("  passed: test_scale_and_add_scaled")
    except e: failed += 1; print("  FAILED: test_scale_and_add_scaled ->", e)
    try: test_dot();                   print("  passed: test_dot")
    except e: failed += 1; print("  FAILED: test_dot ->", e)
    try: test_reductions();            print("  passed: test_reductions")
    except e: failed += 1; print("  FAILED: test_reductions ->", e)
    try: test_argmax();                print("  passed: test_argmax")
    except e: failed += 1; print("  FAILED: test_argmax ->", e)
    try: test_compare_mask_select();   print("  passed: test_compare_mask_select")
    except e: failed += 1; print("  FAILED: test_compare_mask_select ->", e)
    try: test_to_list();               print("  passed: test_to_list")
    except e: failed += 1; print("  FAILED: test_to_list ->", e)
    try: test_normalize();             print("  passed: test_normalize")
    except e: failed += 1; print("  FAILED: test_normalize ->", e)
    try: test_bounds_checked_at_raises(); print("  passed: test_bounds_checked_at_raises")
    except e: failed += 1; print("  FAILED: test_bounds_checked_at_raises ->", e)
    if failed > 0:
        print("vector -> passed: 0  failed:", failed)
        raise Error("core/simd/vector tests failed")
    print("vector -> passed: 13  failed: 0")
