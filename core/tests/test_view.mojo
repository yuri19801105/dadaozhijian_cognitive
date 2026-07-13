# === core/tests/test_view.mojo ===
# TDD RED: 测试 core/tensor/view (切片/转置/广播)。模块未实现, 应编译失败。
from tensor.tensor import Tensor
from tensor.view import transpose_2d, slice_rows, slice_cols, broadcast_add


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol


def _mk_2x3_data() -> List[Float64]:
    var d = List[Float64]()
    d.append(1.0); d.append(2.0); d.append(3.0)
    d.append(4.0); d.append(5.0); d.append(6.0)
    return d^


def test_transpose_2d() raises:
    var t = Tensor()
    t.from_list(_mk_2x3_data(), [2, 3])
    var td = transpose_2d(t.to_list(), t.shape())
    # 2x3 -> 3x2: [[1,4],[2,5],[3,6]]
    var r = Tensor()
    r.from_list(td, [3, 2])
    if not approx(r.at([0, 0]), 1.0, 1e-9): raise Error("T[0,0] wrong")
    if not approx(r.at([0, 1]), 4.0, 1e-9): raise Error("T[0,1] wrong")
    if not approx(r.at([2, 0]), 3.0, 1e-9): raise Error("T[2,0] wrong")
    if not approx(r.at([2, 1]), 6.0, 1e-9): raise Error("T[2,1] wrong")


def test_slice_rows() raises:
    var t = Tensor()
    t.from_list(_mk_2x3_data(), [2, 3])
    var sd = slice_rows(t.to_list(), t.shape(), 0, 1)
    var r = Tensor()
    r.from_list(sd, [1, 3])
    if not approx(r.at([0, 0]), 1.0, 1e-9): raise Error("slice row0[0] wrong")
    if not approx(r.at([0, 2]), 3.0, 1e-9): raise Error("slice row0[2] wrong")


def test_slice_cols() raises:
    var t = Tensor()
    t.from_list(_mk_2x3_data(), [2, 3])
    var sd = slice_cols(t.to_list(), t.shape(), 1, 3)
    var r = Tensor()
    r.from_list(sd, [2, 2])
    if not approx(r.at([0, 0]), 2.0, 1e-9): raise Error("slice col[0,0] wrong")
    if not approx(r.at([1, 1]), 6.0, 1e-9): raise Error("slice col[1,1] wrong")


def test_broadcast_scalar_add() raises:
    var t = Tensor()
    var d = List[Float64]()
    d.append(1.0); d.append(2.0); d.append(3.0); d.append(4.0)
    t.from_list(d, [2, 2])
    var b = List[Float64]()
    b.append(10.0)
    var bd = broadcast_add(t.to_list(), t.shape(), b, [1, 1])
    var r = Tensor()
    r.from_list(bd, [2, 2])
    if not approx(r.at([0, 0]), 11.0, 1e-9): raise Error("bcast scalar[0,0] wrong")
    if not approx(r.at([1, 1]), 14.0, 1e-9): raise Error("bcast scalar[1,1] wrong")


def test_broadcast_row_add() raises:
    var t = Tensor()
    var d = List[Float64]()
    d.append(1.0); d.append(2.0); d.append(3.0); d.append(4.0)
    t.from_list(d, [2, 2])
    var b = List[Float64]()
    b.append(100.0); b.append(200.0)
    var bd = broadcast_add(t.to_list(), t.shape(), b, [1, 2])
    var r = Tensor()
    r.from_list(bd, [2, 2])
    if not approx(r.at([0, 0]), 101.0, 1e-9): raise Error("bcast row[0,0] wrong")
    if not approx(r.at([1, 1]), 204.0, 1e-9): raise Error("bcast row[1,1] wrong")


def test_broadcast_col_add() raises:
    var t = Tensor()
    var d = List[Float64]()
    d.append(1.0); d.append(2.0); d.append(3.0); d.append(4.0)
    t.from_list(d, [2, 2])
    var b = List[Float64]()
    b.append(100.0); b.append(200.0)
    var bd = broadcast_add(t.to_list(), t.shape(), b, [2, 1])
    var r = Tensor()
    r.from_list(bd, [2, 2])
    if not approx(r.at([0, 0]), 101.0, 1e-9): raise Error("bcast col[0,0] wrong")
    if not approx(r.at([1, 1]), 204.0, 1e-9): raise Error("bcast col[1,1] wrong")


def test_slice_oob_raises() raises:
    var t = Tensor()
    t.from_list(_mk_2x3_data(), [2, 3])
    var caught = False
    try:
        _ = slice_rows(t.to_list(), t.shape(), 0, 5)
    except:
        caught = True
    if not caught:
        raise Error("slice_rows should raise on OOB")


def test_broadcast_incompatible_raises() raises:
    var t = Tensor()
    var d = List[Float64]()
    d.append(1.0); d.append(2.0); d.append(3.0); d.append(4.0)
    t.from_list(d, [2, 2])
    var b = List[Float64]()
    b.append(1.0); b.append(2.0); b.append(3.0); b.append(4.0); b.append(5.0); b.append(6.0)
    var caught = False
    try:
        _ = broadcast_add(t.to_list(), t.shape(), b, [3, 3])
    except:
        caught = True
    if not caught:
        raise Error("broadcast_add should raise on incompatible shape")


def main() raises:
    var failed = 0
    print("=== core/tensor/view tests ===")
    try: test_transpose_2d();             print("  passed: test_transpose_2d")
    except e: failed += 1; print("  FAILED: test_transpose_2d ->", e)
    try: test_slice_rows();               print("  passed: test_slice_rows")
    except e: failed += 1; print("  FAILED: test_slice_rows ->", e)
    try: test_slice_cols();               print("  passed: test_slice_cols")
    except e: failed += 1; print("  FAILED: test_slice_cols ->", e)
    try: test_broadcast_scalar_add();     print("  passed: test_broadcast_scalar_add")
    except e: failed += 1; print("  FAILED: test_broadcast_scalar_add ->", e)
    try: test_broadcast_row_add();        print("  passed: test_broadcast_row_add")
    except e: failed += 1; print("  FAILED: test_broadcast_row_add ->", e)
    try: test_broadcast_col_add();        print("  passed: test_broadcast_col_add")
    except e: failed += 1; print("  FAILED: test_broadcast_col_add ->", e)
    try: test_slice_oob_raises();         print("  passed: test_slice_oob_raises")
    except e: failed += 1; print("  FAILED: test_slice_oob_raises ->", e)
    try: test_broadcast_incompatible_raises(); print("  passed: test_broadcast_incompatible_raises")
    except e: failed += 1; print("  FAILED: test_broadcast_incompatible_raises ->", e)
    if failed > 0:
        print("view -> passed: 0  failed:", failed)
        raise Error("core/tensor/view tests failed")
    print("view -> passed: 8  failed: 0")
