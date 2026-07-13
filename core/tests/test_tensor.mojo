# === core/tests/test_tensor.mojo ===
# TDD RED: 测试 core/tensor/tensor (轻量 NDArray)。模块未实现, 应编译失败。
from tensor.tensor import Tensor


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol


def test_init_zeros_shape_size_rank() raises:
    var t = Tensor()
    t.init([2, 3])
    if t.rank() != 2: raise Error("rank should be 2")
    if t.size() != 6: raise Error("size should be 6")
    var sh = t.shape()
    if len(sh) != 2 or sh[0] != 2 or sh[1] != 3: raise Error("shape wrong")
    # 初值全 0
    if not approx(t.at_flat(0), 0.0, 1e-9): raise Error("init not zero")


def test_from_list_and_nd_get_set() raises:
    var t = Tensor()
    var data = List[Float64]()
    for i in range(6):
        data.append(Float64(i + 1))
    t.from_list(data, [2, 3])
    if not approx(t.at([0, 0]), 1.0, 1e-9): raise Error("at[0,0] wrong")
    if not approx(t.at([1, 2]), 6.0, 1e-9): raise Error("at[1,2] wrong")
    t.set([1, 2], 99.0)
    if not approx(t.at([1, 2]), 99.0, 1e-9): raise Error("set wrong")


def test_at_flat() raises:
    var t = Tensor()
    var data = List[Float64]()
    for i in range(4):
        data.append(Float64(i))
    t.from_list(data, [2, 2])
    if not approx(t.at_flat(3), 3.0, 1e-9): raise Error("at_flat wrong")


def test_to_list_roundtrip() raises:
    var t = Tensor()
    var data = List[Float64]()
    data.append(1.0); data.append(2.0); data.append(3.0)
    t.from_list(data, [3])
    var out = t.to_list()
    if len(out) != 3 or not approx(out[2], 3.0, 1e-9): raise Error("to_list wrong")


def test_fill_scale_add_scalar() raises:
    var t = Tensor()
    t.init([2, 2])
    t.fill(2.0)
    if not approx(t.at_flat(0), 2.0, 1e-9): raise Error("fill wrong")
    t.scale(3.0)
    if not approx(t.at_flat(0), 6.0, 1e-9): raise Error("scale wrong")
    t.add_scalar(4.0)
    if not approx(t.at_flat(0), 10.0, 1e-9): raise Error("add_scalar wrong")


def test_elementwise_add() raises:
    var a = Tensor()
    a.init([2, 2])
    a.set([0, 0], 1.0); a.set([0, 1], 2.0); a.set([1, 0], 3.0); a.set([1, 1], 4.0)
    var b = Tensor()
    b.init([2, 2])
    b.set([0, 0], 10.0); b.set([0, 1], 20.0); b.set([1, 0], 30.0); b.set([1, 1], 40.0)
    a.add(b.to_list(), b.shape())
    if not approx(a.at([0, 0]), 11.0, 1e-9): raise Error("add[0,0] wrong")
    if not approx(a.at([1, 1]), 44.0, 1e-9): raise Error("add[1,1] wrong")


def test_sum_max_min_argmax() raises:
    var t = Tensor()
    var data = List[Float64]()
    data.append(4.0); data.append(1.0); data.append(9.0); data.append(2.0)
    t.from_list(data, [4])
    if not approx(t.sum(), 16.0, 1e-9): raise Error("sum wrong")
    if not approx(t.max(), 9.0, 1e-9): raise Error("max wrong")
    if not approx(t.min(), 1.0, 1e-9): raise Error("min wrong")
    if t.argmax_flat() != 2: raise Error("argmax wrong")


def test_row_2d() raises:
    var t = Tensor()
    var data = List[Float64]()
    for i in range(6):
        data.append(Float64(i + 1))
    t.from_list(data, [2, 3])
    var r0 = t.row(0)
    if len(r0) != 3 or not approx(r0[2], 3.0, 1e-9): raise Error("row0 wrong")
    var r1 = t.row(1)
    if not approx(r1[0], 4.0, 1e-9): raise Error("row1 wrong")


def test_oob_raises() raises:
    var t = Tensor()
    t.init([2, 2])
    var caught = False
    try:
        _ = t.at([2, 0])
    except:
        caught = True
    if not caught:
        raise Error("at() should raise on OOB")
    try:
        _ = t.at([0, 0, 0])
    except:
        caught = True
    if not caught:
        raise Error("at() should raise on rank mismatch")


def test_shape_mismatch_add_raises() raises:
    var a = Tensor()
    a.init([2, 2])
    var bdata = List[Float64]()
    bdata.append(1.0)
    var caught = False
    try:
        a.add(bdata, [1])
    except:
        caught = True
    if not caught:
        raise Error("add() should raise on shape mismatch")


def test_init_3x3_and_6dir() raises:
    var g = Tensor()
    g.init_3x3()
    if g.rank() != 2 or g.size() != 9: raise Error("3x3 wrong")
    var h = Tensor()
    h.init_6dir()
    if h.rank() != 1 or h.size() != 6: raise Error("6dir wrong")


def main() raises:
    var failed = 0
    print("=== core/tensor/tensor tests ===")
    try: test_init_zeros_shape_size_rank(); print("  passed: test_init_zeros_shape_size_rank")
    except e: failed += 1; print("  FAILED: test_init_zeros_shape_size_rank ->", e)
    try: test_from_list_and_nd_get_set(); print("  passed: test_from_list_and_nd_get_set")
    except e: failed += 1; print("  FAILED: test_from_list_and_nd_get_set ->", e)
    try: test_at_flat();                   print("  passed: test_at_flat")
    except e: failed += 1; print("  FAILED: test_at_flat ->", e)
    try: test_to_list_roundtrip();         print("  passed: test_to_list_roundtrip")
    except e: failed += 1; print("  FAILED: test_to_list_roundtrip ->", e)
    try: test_fill_scale_add_scalar();      print("  passed: test_fill_scale_add_scalar")
    except e: failed += 1; print("  FAILED: test_fill_scale_add_scalar ->", e)
    try: test_elementwise_add();            print("  passed: test_elementwise_add")
    except e: failed += 1; print("  FAILED: test_elementwise_add ->", e)
    try: test_sum_max_min_argmax();        print("  passed: test_sum_max_min_argmax")
    except e: failed += 1; print("  FAILED: test_sum_max_min_argmax ->", e)
    try: test_row_2d();                    print("  passed: test_row_2d")
    except e: failed += 1; print("  FAILED: test_row_2d ->", e)
    try: test_oob_raises();                print("  passed: test_oob_raises")
    except e: failed += 1; print("  FAILED: test_oob_raises ->", e)
    try: test_shape_mismatch_add_raises();  print("  passed: test_shape_mismatch_add_raises")
    except e: failed += 1; print("  FAILED: test_shape_mismatch_add_raises ->", e)
    try: test_init_3x3_and_6dir();         print("  passed: test_init_3x3_and_6dir")
    except e: failed += 1; print("  FAILED: test_init_3x3_and_6dir ->", e)
    if failed > 0:
        print("tensor -> passed: 0  failed:", failed)
        raise Error("core/tensor/tensor tests failed")
    print("tensor -> passed: 12  failed: 0")
