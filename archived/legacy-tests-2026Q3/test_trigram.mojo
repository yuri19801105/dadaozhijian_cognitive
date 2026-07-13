# 八卦 - 推理算子测试套件
# 23 tests — 3 基础 + 8 算子 × 2 + 1 chain + 1 调度

from std.testing import assert_equal
from workspace import Workspace
from trigram import *

# ----- 基础结构 -----

def test_trigram_action_ctor() raises:
    var a = TrigramAction()
    assert_equal(a.action_id, 0)
    assert_equal(a.trigram, 0)
    assert_equal(a.confidence, 5)

def test_trigram_action_copy() raises:
    var a = TrigramAction()
    a.action_id = 7
    a.trigram = 3
    a.confidence = 9
    var b = a
    assert_equal(b.action_id, 7)

def test_constants() raises:
    assert_equal(CHIEN, 0)
    assert_equal(KUN, 1)
    assert_equal(ZHEN, 2)
    assert_equal(XUN, 3)
    assert_equal(KAN, 4)
    assert_equal(LI, 5)
    assert_equal(GEN, 6)
    assert_equal(DUI, 7)

# ----- 各算子测试 -----

def test_apply_chien() raises:
    var ws = Workspace()
    var a = apply_chien(ws, 42)
    assert_equal(a.trigram, CHIEN)
    assert_equal(a.value, 42)
    assert_equal(a.confidence, 7)

def test_apply_kun() raises:
    var ws = Workspace()
    var a = apply_kun(ws, 0)
    assert_equal(a.trigram, KUN)
    assert_equal(a.confidence, 6)

def test_apply_zhen() raises:
    var ws = Workspace()
    var a = apply_zhen(ws, 9)
    assert_equal(a.trigram, ZHEN)
    assert_equal(a.action_id, 1009)
    assert_equal(a.confidence, 8)

def test_apply_xun() raises:
    var ws = Workspace()
    var a = apply_xun(ws, 0)
    assert_equal(a.trigram, XUN)
    assert_equal(a.confidence, 4)

def test_apply_kan() raises:
    var ws = Workspace()
    var a = apply_kan(ws, 5)
    assert_equal(a.trigram, KAN)
    assert_equal(a.action_id, 2005)
    assert_equal(a.confidence, 3)

def test_apply_li() raises:
    var ws = Workspace()
    var a = apply_li(ws, 2)
    assert_equal(a.trigram, LI)
    assert_equal(a.action_id, 2)
    assert_equal(a.confidence, 9)

def test_apply_gen() raises:
    var ws = Workspace()
    var a = apply_gen(ws, 7)
    assert_equal(a.trigram, GEN)
    assert_equal(a.action_id, -7)
    assert_equal(a.confidence, 9)

def test_apply_dui() raises:
    var ws = Workspace()
    var a = apply_dui(ws, 3)
    assert_equal(a.trigram, DUI)
    assert_equal(a.value, 3)
    assert_equal(a.confidence, 5)

# ----- 调度路由 -----

def test_apply_trigram_dispatch() raises:
    var ws = Workspace()
    var a = apply_trigram(CHIEN, ws, 10)
    assert_equal(a.trigram, CHIEN)
    var b = apply_trigram(KUN, ws, 0)
    assert_equal(b.trigram, KUN)
    var c = apply_trigram(-1, ws, 0)
    assert_equal(c.trigram, -1)

# ----- 推理链 -----

def test_apply_chain_two() raises:
    var ws = Workspace()
    var chain = List[Int]()
    chain.append(CHIEN)
    chain.append(DUI)
    var r = apply_chain(ws, chain, 7)
    assert_equal(r.trigram, DUI)

# ----- 额外深度验证 -----

def test_apply_chien_preserves_input() raises:
    var ws = Workspace()
    var r = apply_chien(ws, 100)
    assert_equal(r.value, 100)
    assert_equal(r.action_id, 100)

def test_apply_zhen_offset() raises:
    var ws = Workspace()
    var r = apply_zhen(ws, 0)
    assert_equal(r.action_id, 1000)
    assert_equal(r.value, 0)

def test_apply_kan_offset() raises:
    var ws = Workspace()
    var r = apply_kan(ws, 1)
    assert_equal(r.action_id, 2001)

def test_apply_li_classify_zero() raises:
    var ws = Workspace()
    var r = apply_li(ws, 0)
    assert_equal(r.action_id, 0)

def test_apply_gen_negative_id() raises:
    var ws = Workspace()
    var r = apply_gen(ws, 3)
    assert_equal(r.action_id, -3)

def test_apply_xun_confidence() raises:
    var ws = Workspace()
    var r = apply_xun(ws, 5)
    assert_equal(r.confidence, 4)

def test_apply_kun_confidence() raises:
    var ws = Workspace()
    var r = apply_kun(ws, 1)
    assert_equal(r.confidence, 6)

def test_apply_dui_confidence() raises:
    var ws = Workspace()
    var r = apply_dui(ws, 9)
    assert_equal(r.confidence, 5)


def main() raises:
    var passed = 0
    var failed = 0
    try: test_trigram_action_ctor(); passed += 1
    except e: failed += 1; print("FAIL test_trigram_action_ctor:", e)
    try: test_trigram_action_copy(); passed += 1
    except e: failed += 1; print("FAIL test_trigram_action_copy:", e)
    try: test_constants(); passed += 1
    except e: failed += 1; print("FAIL test_constants:", e)
    try: test_apply_chien(); passed += 1
    except e: failed += 1; print("FAIL test_apply_chien:", e)
    try: test_apply_kun(); passed += 1
    except e: failed += 1; print("FAIL test_apply_kun:", e)
    try: test_apply_zhen(); passed += 1
    except e: failed += 1; print("FAIL test_apply_zhen:", e)
    try: test_apply_xun(); passed += 1
    except e: failed += 1; print("FAIL test_apply_xun:", e)
    try: test_apply_kan(); passed += 1
    except e: failed += 1; print("FAIL test_apply_kan:", e)
    try: test_apply_li(); passed += 1
    except e: failed += 1; print("FAIL test_apply_li:", e)
    try: test_apply_gen(); passed += 1
    except e: failed += 1; print("FAIL test_apply_gen:", e)
    try: test_apply_dui(); passed += 1
    except e: failed += 1; print("FAIL test_apply_dui:", e)
    try: test_apply_trigram_dispatch(); passed += 1
    except e: failed += 1; print("FAIL test_apply_trigram_dispatch:", e)
    try: test_apply_chain_two(); passed += 1
    except e: failed += 1; print("FAIL test_apply_chain_two:", e)
    try: test_apply_chien_preserves_input(); passed += 1
    except e: failed += 1; print("FAIL test_apply_chien_preserves_input:", e)
    try: test_apply_zhen_offset(); passed += 1
    except e: failed += 1; print("FAIL test_apply_zhen_offset:", e)
    try: test_apply_kan_offset(); passed += 1
    except e: failed += 1; print("FAIL test_apply_kan_offset:", e)
    try: test_apply_li_classify_zero(); passed += 1
    except e: failed += 1; print("FAIL test_apply_li_classify_zero:", e)
    try: test_apply_gen_negative_id(); passed += 1
    except e: failed += 1; print("FAIL test_apply_gen_negative_id:", e)
    try: test_apply_xun_confidence(); passed += 1
    except e: failed += 1; print("FAIL test_apply_xun_confidence:", e)
    try: test_apply_kun_confidence(); passed += 1
    except e: failed += 1; print("FAIL test_apply_kun_confidence:", e)
    try: test_apply_dui_confidence(); passed += 1
    except e: failed += 1; print("FAIL test_apply_dui_confidence:", e)

    print("Trigram tests -> passed:", passed, " failed:", failed)
    if failed > 0:
        raise Error("Trigram tests failed")
