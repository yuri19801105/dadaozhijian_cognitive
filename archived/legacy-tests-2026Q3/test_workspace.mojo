# 九宫 - 工作记忆测试套件 (M3 重做, 对照计划 §4 九宫)
# 运行: .venv/bin/mojo -I src tests/test_workspace.mojo

from std.testing import assert_equal
from workspace import Workspace

def test_init_grid() raises:
    var ws = Workspace()
    assert_equal(len(ws.grid), 3)
    for i in range(3):
        assert_equal(len(ws.grid[i]), 3)
        for j in range(3):
            assert_equal(ws.grid[i][j], -1)
    assert_equal(len(ws.attention), 9)
    assert_equal(len(ws.history), 0)

def test_hold_returns_tuple() raises:
    var ws = Workspace()
    var res = ws.hold(42)
    assert_equal(len(res[0]), 3)
    assert_equal(len(res[1]), 9)

def test_hold_fills_first_empty_only() raises:
    var ws = Workspace()
    var res = ws.hold(42)
    var g = res[0].copy()
    var count = 0
    for i in range(3):
        for j in range(3):
            if g[i][j] == 42:
                count += 1
    assert_equal(count, 1)

def test_hold_preserves_existing() raises:
    var ws = Workspace()
    _ = ws.hold(1)
    _ = ws.hold(2)
    var total = 0
    for i in range(3):
        for j in range(3):
            if ws.grid[i][j] >= 0:
                total += 1
    assert_equal(total, 2)

def test_update_attention_focus() raises:
    var ws = Workspace()
    ws.update_attention(0)
    assert_equal(len(ws.attention), 9)
    assert_equal(ws.attention[0], 9)
    assert_equal(ws.get_focus_strength(), 9)
    assert_equal(ws.attention[8], 1)

def test_get_weighted_state() raises:
    var ws = Workspace()
    _ = ws.hold(10)
    ws.update_attention(0)
    var w = ws.get_weighted_state()
    assert_equal(w[0][0], 90)
    assert_equal(w[0][1], -4)   # 空格(-1) * 权重(距聚焦格 d²=1 -> 9/2=4)

def test_history_retrieval() raises:
    var ws = Workspace()
    _ = ws.hold(10)
    _ = ws.hold(20)
    var h0 = ws.retrieve_history(0)
    var h1 = ws.retrieve_history(1)
    assert_equal(h0[0][0], 10)
    assert_equal(h1[0][1], 20)

def test_attention_retrieves_history() raises:
    var ws = Workspace()
    ws.grid[0][0] = 100
    ws.history.append(ws._grid_copy())
    ws.grid[0][0] = -1
    ws.grid[2][2] = 100
    ws.history.append(ws._grid_copy())
    ws.update_attention(0)
    var r0 = ws.attention_retrieve()
    assert_equal(r0[0][0], 100)
    ws.update_attention(8)
    var r8 = ws.attention_retrieve()
    assert_equal(r8[2][2], 100)

def test_clear_cell() raises:
    var ws = Workspace()
    ws.clear_cell(1, 1)
    assert_equal(ws.grid[1][1], -1)

def test_available_cells() raises:
    var ws = Workspace()
    _ = ws.hold(1)
    _ = ws.hold(2)
    var before = ws.available_cells()
    ws.clear_cell(0, 0)
    ws.clear_cell(0, 1)
    assert_equal(ws.available_cells(), before + 2)

def main() raises:
    var passed = 0
    var failed = 0
    try: test_init_grid(); passed += 1
    except e: failed += 1; print("FAIL test_init_grid:", e)
    try: test_hold_returns_tuple(); passed += 1
    except e: failed += 1; print("FAIL test_hold_returns_tuple:", e)
    try: test_hold_fills_first_empty_only(); passed += 1
    except e: failed += 1; print("FAIL test_hold_fills_first_empty_only:", e)
    try: test_hold_preserves_existing(); passed += 1
    except e: failed += 1; print("FAIL test_hold_preserves_existing:", e)
    try: test_update_attention_focus(); passed += 1
    except e: failed += 1; print("FAIL test_update_attention_focus:", e)
    try: test_get_weighted_state(); passed += 1
    except e: failed += 1; print("FAIL test_get_weighted_state:", e)
    try: test_history_retrieval(); passed += 1
    except e: failed += 1; print("FAIL test_history_retrieval:", e)
    try: test_attention_retrieves_history(); passed += 1
    except e: failed += 1; print("FAIL test_attention_retrieves_history:", e)
    try: test_clear_cell(); passed += 1
    except e: failed += 1; print("FAIL test_clear_cell:", e)
    try: test_available_cells(); passed += 1
    except e: failed += 1; print("FAIL test_available_cells:", e)

    print("Workspace tests -> passed:", passed, " failed:", failed)
    if failed > 0:
        raise Error("Workspace tests failed")
