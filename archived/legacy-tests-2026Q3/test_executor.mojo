# 十方执行器测试套件
# 12 tests

from std.testing import assert_equal
from workspace import Workspace
from executor import *
from trigram import CHIEN, KUN, ZHEN, XUN, KAN, LI, GEN, DUI

def test_exec_chien() raises:
    var ws = Workspace()
    var out = execute_trigram(CHIEN, ws, "test", 0)
    assert_equal(out, "[0] 创造: test")

def test_exec_kun() raises:
    var ws = Workspace()
    var out = execute_trigram(KUN, ws, "", 0)
    assert_equal(out.byte_length() > 0, True)

def test_exec_zhen() raises:
    var ws = Workspace()
    var out = execute_trigram(ZHEN, ws, "hello", 1)
    assert_equal(out, "[1] 启动: 处理 `hello`")

def test_exec_xun() raises:
    var ws = Workspace()
    var out = execute_trigram(XUN, ws, "data", 2)
    assert_equal(out, "[2] 渗透: 整合输入到九宫")

def test_exec_kan() raises:
    var ws = Workspace()
    var out = execute_trigram(KAN, ws, "abcdef", 3)
    assert_equal(out.find("冒险") >= 0, True)

def test_exec_li() raises:
    var ws = Workspace()
    var out = execute_trigram(LI, ws, "ab", 4)
    assert_equal(out.find("明辨") >= 0, True)
    assert_equal(out.find("偶数") >= 0, True)

def test_exec_gen() raises:
    var ws = Workspace()
    var out = execute_trigram(GEN, ws, "", 5)
    assert_equal(out, "[5] 停止: 结束分支")

def test_exec_dui() raises:
    var ws = Workspace()
    var out = execute_trigram(DUI, ws, "ok", 6)
    assert_equal(out, "[6] 交流: ok")

def test_action_label() raises:
    assert_equal(action_label(CHIEN), "创造")
    assert_equal(action_label(KUN), "承载")
    assert_equal(action_label(ZHEN), "启动")
    assert_equal(action_label(XUN), "渗透")
    assert_equal(action_label(KAN), "冒险")
    assert_equal(action_label(LI), "明辨")
    assert_equal(action_label(GEN), "停止")
    assert_equal(action_label(DUI), "交流")
    assert_equal(action_label(-1), "未知")

def test_execute_chain() raises:
    var ws = Workspace()
    var chain = List[Int]()
    chain.append(CHIEN)
    chain.append(DUI)
    var out = execute(chain, ws, "hello")
    assert_equal(out.find("[0] 创造") >= 0, True)
    assert_equal(out.find("[1] 交流") >= 0, True)

def test_execute_empty_chain() raises:
    var ws = Workspace()
    var chain = List[Int]()
    var out = execute(chain, ws, "x")
    assert_equal(out, "")

def test_exec_odd_even() raises:
    var ws = Workspace()
    var out = execute_trigram(LI, ws, "a", 0)
    assert_equal(out.find("奇数") >= 0, True)
    var out2 = execute_trigram(LI, ws, "ab", 1)
    assert_equal(out2.find("偶数") >= 0, True)


def main() raises:
    var passed = 0
    var failed = 0
    try: test_exec_chien(); passed += 1
    except e: failed += 1; print("FAIL test_exec_chien:", e)
    try: test_exec_kun(); passed += 1
    except e: failed += 1; print("FAIL test_exec_kun:", e)
    try: test_exec_zhen(); passed += 1
    except e: failed += 1; print("FAIL test_exec_zhen:", e)
    try: test_exec_xun(); passed += 1
    except e: failed += 1; print("FAIL test_exec_xun:", e)
    try: test_exec_kan(); passed += 1
    except e: failed += 1; print("FAIL test_exec_kan:", e)
    try: test_exec_li(); passed += 1
    except e: failed += 1; print("FAIL test_exec_li:", e)
    try: test_exec_gen(); passed += 1
    except e: failed += 1; print("FAIL test_exec_gen:", e)
    try: test_exec_dui(); passed += 1
    except e: failed += 1; print("FAIL test_exec_dui:", e)
    try: test_action_label(); passed += 1
    except e: failed += 1; print("FAIL test_action_label:", e)
    try: test_execute_chain(); passed += 1
    except e: failed += 1; print("FAIL test_execute_chain:", e)
    try: test_execute_empty_chain(); passed += 1
    except e: failed += 1; print("FAIL test_execute_empty_chain:", e)
    try: test_exec_odd_even(); passed += 1
    except e: failed += 1; print("FAIL test_exec_odd_even:", e)

    print("Executor tests -> passed:", passed, " failed:", failed)
    if failed > 0:
        raise Error("Executor tests failed")
