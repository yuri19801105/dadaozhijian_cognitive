# === taiji/tests/test_consolidation.mojo ===
# TDD (RED -> GREEN): 测试 taiji/consolidation（巩固/遗忘: 保留近期轨迹 + 强度衰减）。
from taiji.consolidation import Consolidation
from taiji.taiji_state import TaijiState


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol


def ints_equal(a: List[Int], b: List[Int]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def test_init_fields() raises:
    var c = Consolidation(0.6, 0.1)
    if not approx(c.keep_rate, 0.6, 1e-12): raise Error("keep_rate mismatch")
    if not approx(c.forget_rate, 0.1, 1e-12): raise Error("forget_rate mismatch")


def test_no_consolidation_when_few_rounds() raises:
    var c = Consolidation(0.6, 0.1)
    var s = TaijiState(1)
    for r in range(3):
        var dec = List[Int]()
        dec.append(r)
        s.feedback("o" + String(r), dec, r % 5, 0.5)
    c.consolidate(s)
    # 轨迹 ≤ 3 不巩固
    if s.round != 3: raise Error("should not consolidate when <=3 rounds, round=" + String(s.round))
    if len(s.decision_chains) != 3: raise Error("chains should stay 3")


def test_consolidate_keeps_recent_and_decays() raises:
    var c = Consolidation(0.6, 0.1)
    var s = TaijiState(1)
    for r in range(5):
        var dec = List[Int]()
        dec.append(r); dec.append(r + 10)
        s.feedback("o" + String(r), dec, r % 5, 0.5)
    var last_before = s.decision_chains[4].copy()
    var inten_before = s.intensities[4]
    c.consolidate(s)
    # keep = Int(0.6*5) = 3 -> 保留最近 3 条 (原 rounds 2,3,4)
    if s.round != 3: raise Error("round should be 3 after consolidate, got " + String(s.round))
    if len(s.decision_chains) != 3: raise Error("chains should be 3")
    if len(s.phases) != 3: raise Error("phases should be 3")
    if len(s.intensities) != 3: raise Error("intensities should be 3")
    # 最近一条被保留
    if not ints_equal(s.decision_chains[2], last_before): raise Error("most recent chain should be kept")
    # 强度衰减: 存活 = 原 * (1 - forget_rate)
    if not approx(s.intensities[2], inten_before * 0.9, 1e-12): raise Error("intensity should decay by forget_rate")
    # 根标识不变
    if s.intent_hash != 1: raise Error("intent_hash should be unchanged")


def main() raises:
    var failed = 0
    print("=== taiji/consolidation tests ===")
    try: test_init_fields(); print("  passed: init_fields")
    except e: failed += 1; print("  FAILED: init_fields ->", e)
    try: test_no_consolidation_when_few_rounds(); print("  passed: no_consolidation_when_few_rounds")
    except e: failed += 1; print("  FAILED: no_consolidation_when_few_rounds ->", e)
    try: test_consolidate_keeps_recent_and_decays(); print("  passed: consolidate_keeps_recent_and_decays")
    except e: failed += 1; print("  FAILED: consolidate_keeps_recent_and_decays ->", e)
    if failed > 0:
        print("consolidation -> passed: 0  failed:", failed)
        raise Error("consolidation tests failed")
    print("consolidation -> passed: 3  failed: 0")
