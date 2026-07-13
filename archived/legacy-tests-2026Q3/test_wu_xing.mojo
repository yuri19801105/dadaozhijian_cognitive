# 五行 - 动态平衡调度器测试套件
# 11 tests

from std.testing import assert_equal
from workspace import Workspace
from wu_xing import *

def test_phase_signal_defaults() raises:
    var sig = PhaseSignal()
    assert_equal(sig.phase, WOOD)
    assert_equal(sig.intensity, 5)

def test_generate_next() raises:
    assert_equal(generate_next(WOOD), FIRE)
    assert_equal(generate_next(FIRE), EARTH)
    assert_equal(generate_next(EARTH), METAL)
    assert_equal(generate_next(METAL), WATER)
    assert_equal(generate_next(WATER), WOOD)

def test_restrain_target() raises:
    assert_equal(restrain_target(WOOD), EARTH)
    assert_equal(restrain_target(FIRE), METAL)
    assert_equal(restrain_target(EARTH), WATER)
    assert_equal(restrain_target(METAL), WOOD)
    assert_equal(restrain_target(WATER), FIRE)

def test_balance_decision_defaults() raises:
    var d = BalanceDecision()
    assert_equal(d.weight(WOOD), 5)
    assert_equal(d.confidence, 5)
    assert_equal(d.t_len, 0)

def test_balance_decision_set_weight() raises:
    var d = BalanceDecision()
    d.set_weight(WATER, 9)
    assert_equal(d.weight(WATER), 9)

def test_balance_decision_append_chain() raises:
    var d = BalanceDecision()
    d.append_chain(CHIEN)
    assert_equal(d.t_len, 1)
    assert_equal(d.chain(0), CHIEN)
    d.append_chain(KUN)
    assert_equal(d.t_len, 2)
    assert_equal(d.chain(1), KUN)

def test_balance_decision_list_roundtrip() raises:
    var d = BalanceDecision()
    d.append_chain(LI)
    d.append_chain(KAN)
    var lst = d.chain_to_list()
    assert_equal(len(lst), 2)
    d.set_from_list(lst)
    assert_equal(d.t_len, 2)
    assert_equal(d.chain(0), LI)

def test_schedule_wood() raises:
    var ws = Workspace()
    var sig = PhaseSignal()
    sig.phase = WOOD
    sig.intensity = 7
    var d = schedule(ws, sig)
    assert_equal(d.t_len, 2)
    # 空网格 9 分支: WOOD = min(9, 7+9) = 9
    assert_equal(d.weight(WOOD), 9)
    # 相生 WOOD->FIRE: FIRE = clamp(3+1) = 4
    assert_equal(d.weight(FIRE), 4)
    # 相克 WOOD->EARTH: EARTH = clamp(2-2) = 0
    assert_equal(d.weight(EARTH), 0)
    # chain = ZHEN, XUN (两者不同, 过载过滤后保留)
    assert_equal(d.chain(0), ZHEN)
    assert_equal(d.chain(1), XUN)
    assert_equal(d.confidence, 7)

def test_schedule_fire() raises:
    var ws = Workspace()
    var sig = PhaseSignal()
    sig.phase = FIRE
    sig.intensity = 5
    var d = schedule(ws, sig)
    assert_equal(d.t_len, 2)
    # FIRE = min(9, 5+3) = 8
    assert_equal(d.weight(FIRE), 8)
    # 相生 FIRE->EARTH: EARTH = clamp(4+1) = 5
    assert_equal(d.weight(EARTH), 5)
    # 相克 FIRE->METAL: METAL = clamp(2-2) = 0
    assert_equal(d.weight(METAL), 0)
    assert_equal(d.chain(0), LI)
    assert_equal(d.chain(1), KAN)

def test_overload_counter() raises:
    var oc = OverloadCounter()
    assert_equal(oc.track(ZHEN), True)
    assert_equal(oc.track(ZHEN), True)

def test_wu_xing_cycle() raises:
    var ws = Workspace()
    var results = wu_xing_cycle(ws, 5)
    assert_equal(len(results), 5)


def main() raises:
    var passed = 0
    var failed = 0
    try: test_phase_signal_defaults(); passed += 1
    except e: failed += 1; print("FAIL test_phase_signal_defaults:", e)
    try: test_generate_next(); passed += 1
    except e: failed += 1; print("FAIL test_generate_next:", e)
    try: test_restrain_target(); passed += 1
    except e: failed += 1; print("FAIL test_restrain_target:", e)
    try: test_balance_decision_defaults(); passed += 1
    except e: failed += 1; print("FAIL test_balance_decision_defaults:", e)
    try: test_balance_decision_set_weight(); passed += 1
    except e: failed += 1; print("FAIL test_balance_decision_set_weight:", e)
    try: test_balance_decision_append_chain(); passed += 1
    except e: failed += 1; print("FAIL test_balance_decision_append_chain:", e)
    try: test_balance_decision_list_roundtrip(); passed += 1
    except e: failed += 1; print("FAIL test_balance_decision_list_roundtrip:", e)
    try: test_schedule_wood(); passed += 1
    except e: failed += 1; print("FAIL test_schedule_wood:", e)
    try: test_schedule_fire(); passed += 1
    except e: failed += 1; print("FAIL test_schedule_fire:", e)
    try: test_overload_counter(); passed += 1
    except e: failed += 1; print("FAIL test_overload_counter:", e)
    try: test_wu_xing_cycle(); passed += 1
    except e: failed += 1; print("FAIL test_wu_xing_cycle:", e)

    print("WuXing tests -> passed:", passed, " failed:", failed)
    if failed > 0:
        raise Error("WuXing tests failed")
