# === taiji/tests/test_feedback_loop.mojo ===
# TDD (RED -> GREEN): 测试 taiji/feedback_loop（回灌入口 + 归一能量 + 巩固判定）。
from taiji.feedback_loop import FeedbackLoop


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol


def test_init_sets_fields() raises:
    var fl = FeedbackLoop(3, 2.0, 1.5)
    if fl.state.intent_hash != 3: raise Error("intent_hash should be 3")
    if not approx(fl.energy_budget, 2.0, 1e-12): raise Error("energy_budget mismatch")
    if not approx(fl.feedback_threshold, 1.5, 1e-12): raise Error("threshold mismatch")
    if fl.state.round != 0: raise Error("fresh loop round 0")


def test_feedback_advances_round_and_energy() raises:
    var fl = FeedbackLoop(1, 1.0, 1e9)   # 高阈值 -> 不触发巩固
    var dec = List[Int]()
    dec.append(1); dec.append(2); dec.append(3)
    fl.feedback("out", dec, 2, 0.5)
    if fl.state.round != 1: raise Error("round should be 1 after feedback")
    if fl.state.last_decision()[0] != 1: raise Error("decision not recorded")
    # 能量按 phase 累积于第 2 宫
    if fl.state.energy.at_flat(2) <= 0.0: raise Error("energy should accumulate at phase 2")
    # recall 应反映轮次与意图根
    if fl.recall().find("1 轮") < 0: raise Error("recall should mention round")
    if fl.recall().find("意图根=1") < 0: raise Error("recall should mention intent root")


def test_recall_empty_before_first_round() raises:
    var fl = FeedbackLoop(0, 1.0, 1.0)
    if fl.recall() != "": raise Error("first-round recall should be empty")


def test_should_consolidate_by_threshold() raises:
    # 阈值=0: 任意正能量即触发
    var fl = FeedbackLoop(0, 1.0, 0.0)
    var dec = List[Int]()
    dec.append(1)
    fl.feedback("x", dec, 0, 0.5)
    if not fl.should_consolidate(): raise Error("should consolidate when total energy >= 0")

    # 巨阈值: 永不触发
    var fl2 = FeedbackLoop(0, 1.0, 1e9)
    fl2.feedback("x", dec, 0, 0.5)
    if fl2.should_consolidate(): raise Error("should NOT consolidate with huge threshold")

    # 中性: 阈值介于首轮能量与两轮能量之间 -> 首轮 False, 次轮 True
    var fl3 = FeedbackLoop(0, 1.0, 0.7)
    fl3.feedback("x", dec, 0, 0.2)        # 首轮能量约 sigmoid(0.2)=0.55
    if fl3.should_consolidate(): raise Error("round1 energy below 0.7 threshold")
    fl3.feedback("y", dec, 1, 0.2)        # 次轮能量约 1.1
    if not fl3.should_consolidate(): raise Error("round2 energy above 0.7 threshold")


def main() raises:
    var failed = 0
    print("=== taiji/feedback_loop tests ===")
    try: test_init_sets_fields(); print("  passed: init_sets_fields")
    except e: failed += 1; print("  FAILED: init_sets_fields ->", e)
    try: test_feedback_advances_round_and_energy(); print("  passed: feedback_advances_round_and_energy")
    except e: failed += 1; print("  FAILED: feedback_advances_round_and_energy ->", e)
    try: test_recall_empty_before_first_round(); print("  passed: recall_empty_before_first_round")
    except e: failed += 1; print("  FAILED: recall_empty_before_first_round ->", e)
    try: test_should_consolidate_by_threshold(); print("  passed: should_consolidate_by_threshold")
    except e: failed += 1; print("  FAILED: should_consolidate_by_threshold ->", e)
    if failed > 0:
        print("feedback_loop -> passed: 0  failed:", failed)
        raise Error("feedback_loop tests failed")
    print("feedback_loop -> passed: 4  failed: 0")
