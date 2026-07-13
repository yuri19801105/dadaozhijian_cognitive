# 六合 - 空间态势感知测试套件
# 8 tests

from std.testing import assert_equal
from workspace import Workspace
from config import Config
from liuhe import context_vector

def test_context_vector_shape() raises:
    var ws = Workspace()
    var cfg = Config()
    var vec = context_vector(ws, 3, "hello", cfg)
    assert_equal(len(vec), 6)

def test_context_vector_east() raises:
    var ws = Workspace()
    var cfg = Config()
    ws.clear_cell(0, 0)
    var vec = context_vector(ws, 1, "test", cfg)
    assert_equal(Int(vec[0]), ws.available_cells())

def test_context_vector_west() raises:
    var ws = Workspace()
    var cfg = Config()
    var vec = context_vector(ws, 5, "hi", cfg)
    assert_equal(Int(vec[1]), 5)

def test_context_vector_south() raises:
    var ws = Workspace()
    var cfg = Config()
    var vec = context_vector(ws, 0, "a", cfg)
    assert_equal(Int(vec[2]), ws.get_focus_strength())

def test_context_vector_north() raises:
    var ws = Workspace()
    var cfg = Config()
    var vec = context_vector(ws, 0, "x", cfg)
    assert_equal(Int(vec[3]), cfg.max_depth)

def test_context_vector_up() raises:
    var ws = Workspace()
    var cfg = Config()
    var vec = context_vector(ws, 8, "test", cfg)
    assert_equal(Int(vec[4]), 4)

def test_context_vector_down() raises:
    var ws = Workspace()
    var cfg = Config()
    var vec = context_vector(ws, 0, "hello world!", cfg)
    assert_equal(Int(vec[5]), 2)

def test_context_vector_returns_simd() raises:
    var ws = Workspace()
    var cfg = Config()
    var vec = context_vector(ws, 0, "", cfg)
    assert_equal(len(vec), 6)
    assert_equal(Int(vec[1]), 0)


def main() raises:
    var passed = 0
    var failed = 0
    try: test_context_vector_shape(); passed += 1
    except e: failed += 1; print("FAIL test_context_vector_shape:", e)
    try: test_context_vector_east(); passed += 1
    except e: failed += 1; print("FAIL test_context_vector_east:", e)
    try: test_context_vector_west(); passed += 1
    except e: failed += 1; print("FAIL test_context_vector_west:", e)
    try: test_context_vector_south(); passed += 1
    except e: failed += 1; print("FAIL test_context_vector_south:", e)
    try: test_context_vector_north(); passed += 1
    except e: failed += 1; print("FAIL test_context_vector_north:", e)
    try: test_context_vector_up(); passed += 1
    except e: failed += 1; print("FAIL test_context_vector_up:", e)
    try: test_context_vector_down(); passed += 1
    except e: failed += 1; print("FAIL test_context_vector_down:", e)
    try: test_context_vector_returns_simd(); passed += 1
    except e: failed += 1; print("FAIL test_context_vector_returns_simd:", e)

    print("LiuHe tests -> passed:", passed, " failed:", failed)
    if failed > 0:
        raise Error("LiuHe tests failed")
