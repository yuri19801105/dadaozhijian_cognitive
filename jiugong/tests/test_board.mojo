# === jiugong/tests/test_board.mojo ===
# TDD: 测试 jiugong/board (九宫 3x3 真张量盘)。先定义契约（RED 思想），再实现（GREEN）。
from jiugong.board import WorkspaceBoard
from tensor.tensor import Tensor
from math.activate import softmax_list


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol


def test_init_zeros_uniform_attention() raises:
    var b = WorkspaceBoard()
    if b.grid.rank() != 2 or b.grid.size() != 9: raise Error("grid should be 3x3")
    if not approx(b.grid.at_flat(0), 0.0, 1e-12): raise Error("grid not zero")
    # 注意力初始均匀 -> softmax 后约 1/9
    var w = b.attention_weights()
    if len(w) != 9: raise Error("attention weights len")
    for i in range(9):
        if not approx(w[i], 1.0 / 9.0, 1e-9): raise Error("uniform attention failed")
    if b.focus_cell != 4: raise Error("default focus should be center(4)")
    if b.round != 0: raise Error("round should be 0")


def test_at_set_read_write() raises:
    var b = WorkspaceBoard()
    b.set(0, 0, 1.0)
    b.set(2, 1, 5.0)
    if not approx(b.at(0, 0), 1.0, 1e-12): raise Error("at(0,0) wrong")
    if not approx(b.at(2, 1), 5.0, 1e-12): raise Error("at(2,1) wrong")
    b.set_flat(8, 9.0)
    if not approx(b.at_flat(8), 9.0, 1e-12): raise Error("set_flat wrong")
    if not approx(b.at(2, 2), 9.0, 1e-12): raise Error("at_flat mapping wrong")


def test_row_col() raises:
    var b = WorkspaceBoard()
    b.set(1, 0, 10.0); b.set(1, 1, 20.0); b.set(1, 2, 30.0)
    var r1 = b.row(1)
    if len(r1) != 3 or not approx(r1[2], 30.0, 1e-12): raise Error("row wrong")
    var c0 = b.col(0)
    if len(c0) != 3 or not approx(c0[1], 10.0, 1e-12): raise Error("col wrong")


def test_init_from() raises:
    var t = Tensor()
    var data = List[Float64]()
    for i in range(9):
        data.append(Float64(i + 1))
    t.from_list(data, [3, 3])
    var b = WorkspaceBoard()
    b.init_from(t)
    if not approx(b.at(1, 1), 5.0, 1e-12): raise Error("init_from wrong")
    # 非 3x3 应 raise
    var bad = Tensor()
    bad.init([2, 2])
    var caught = False
    try:
        b.init_from(bad)
    except:
        caught = True
    if not caught:
        raise Error("init_from should raise on non-3x3")


def test_transpose_slice() raises:
    var b = WorkspaceBoard()
    b.set(0, 1, 7.0)
    var tp = b.transpose()   # List[Float64], 转置后 flat = c_org*3 + r_org
    # 原 (0,1)=7 -> 转置 (1,0) -> flat index = 1*3+0 = 3
    if len(tp) != 9 or not approx(tp[3], 7.0, 1e-12): raise Error("transpose wrong")
    var sr = b.slice_rows(0, 2)
    if len(sr) != 6: raise Error("slice_rows shape")
    var sc = b.slice_cols(1, 3)
    if len(sc) != 6: raise Error("slice_cols shape")


def test_add_and_broadcast() raises:
    var a = WorkspaceBoard()
    a.set(0, 0, 1.0); a.set(0, 1, 2.0); a.set(0, 2, 3.0)
    a.set(1, 0, 4.0); a.set(1, 1, 5.0); a.set(1, 2, 6.0)
    a.set(2, 0, 7.0); a.set(2, 1, 8.0); a.set(2, 2, 9.0)
    # 逐元素加
    var oth = WorkspaceBoard()
    oth.set(0, 0, 10.0)
    a.add(oth.grid)
    if not approx(a.at(0, 0), 11.0, 1e-12): raise Error("add wrong")
    # 广播加：vec[3] 加到每列
    var a2 = WorkspaceBoard()
    a2.set(0, 0, 1.0); a2.set(1, 1, 1.0); a2.set(2, 2, 1.0)
    var vec = Tensor()
    vec.init([3])
    vec.set_flat(0, 100.0); vec.set_flat(1, 200.0); vec.set_flat(2, 300.0)
    a2.broadcast_add(vec)
    if not approx(a2.at(0, 0), 101.0, 1e-12): raise Error("broadcast col0 wrong")
    if not approx(a2.at(2, 2), 301.0, 1e-12): raise Error("broadcast col2 wrong")
    # 广播加：vec[3,1] 加到每行
    var a3 = WorkspaceBoard()
    a3.set(0, 0, 1.0); a3.set(1, 1, 1.0); a3.set(2, 2, 1.0)
    var rvec = Tensor()
    rvec.init([3, 1])
    rvec.set_flat(0, 10.0); rvec.set_flat(1, 20.0); rvec.set_flat(2, 30.0)
    a3.broadcast_add(rvec)
    if not approx(a3.at(0, 0), 11.0, 1e-12): raise Error("broadcast row0 wrong")
    if not approx(a3.at(2, 2), 31.0, 1e-12): raise Error("broadcast row2 wrong")
    # 不支持的形状应 raise
    var bad = Tensor()
    bad.init([2, 2])
    var caught = False
    try:
        a3.broadcast_add(bad)
    except:
        caught = True
    if not caught:
        raise Error("broadcast_add should raise on bad shape")


def test_attention_focus_weighted() raises:
    var b = WorkspaceBoard()
    b.update_attention(4)  # 中心
    var w = b.attention_weights()
    # 权重和为 1
    var s = 0.0
    for i in range(9):
        s = s + w[i]
    if not approx(s, 1.0, 1e-9): raise Error("attention weights not normalized")
    # 中心权重应最大（距离 0）
    if w[4] <= w[0]: raise Error("center should be max attention")
    # weighted_state 形状 3x3，且为 grid⊙softmax(attention)
    var ws = b.weighted_state()
    if len(ws) != 9: raise Error("weighted_state shape")
    var g = b.grid.to_list()
    if not approx(ws[0], g[0] * w[0], 1e-12): raise Error("weighted_state wrong")
    if not approx(b.focus_strength(), b.attention.at_flat(4), 1e-12): raise Error("focus_strength wrong")


def test_clear_available_oob() raises:
    var b = WorkspaceBoard()
    b.set(0, 0, 5.0)
    b.clear_cell(0, 0)
    if not approx(b.at(0, 0), 0.0, 1e-12): raise Error("clear_cell wrong")
    if b.available_cells() != 9: raise Error("available_cells should be 9 after clear")
    # 越界 set 应 raise
    var caught = False
    try:
        b.set(3, 0, 1.0)
    except:
        caught = True
    if not caught:
        raise Error("set should raise OOB")
    # update_attention 越界应 raise
    caught = False
    try:
        b.update_attention(9)
    except:
        caught = True
    if not caught:
        raise Error("update_attention should raise OOB")


def main() raises:
    var failed = 0
    print("=== jiugong/board tests ===")
    try: test_init_zeros_uniform_attention(); print("  passed: init/uniform")
    except e: failed += 1; print("  FAILED: init/uniform ->", e)
    try: test_at_set_read_write(); print("  passed: at/set")
    except e: failed += 1; print("  FAILED: at/set ->", e)
    try: test_row_col(); print("  passed: row/col")
    except e: failed += 1; print("  FAILED: row/col ->", e)
    try: test_init_from(); print("  passed: init_from")
    except e: failed += 1; print("  FAILED: init_from ->", e)
    try: test_transpose_slice(); print("  passed: transpose/slice")
    except e: failed += 1; print("  FAILED: transpose/slice ->", e)
    try: test_add_and_broadcast(); print("  passed: add/broadcast")
    except e: failed += 1; print("  FAILED: add/broadcast ->", e)
    try: test_attention_focus_weighted(); print("  passed: attention")
    except e: failed += 1; print("  FAILED: attention ->", e)
    try: test_clear_available_oob(); print("  passed: clear/oob")
    except e: failed += 1; print("  FAILED: clear/oob ->", e)
    if failed > 0:
        print("board -> passed: 0  failed:", failed)
        raise Error("jiugong/board tests failed")
    print("board -> passed: 8  failed: 0")
