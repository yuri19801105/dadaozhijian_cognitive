# === taiji/tests/test_cycle.mojo ===
# TDD (RED -> GREEN): 测试 taiji/cycle（四步闭环编排: recall→plan→execute→feedback + 落盘）。
from taiji.cycle import CognitiveCycle, CycleConfig, CycleResult
from taiji.persistence import Persistence
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


def test_config_and_result_fields() raises:
    var cfg = CycleConfig(1.0, 0.7, 1, False)
    if not approx(cfg.energy_budget, 1.0, 1e-12): raise Error("energy_budget")
    if cfg.snapshot_every != 1: raise Error("snapshot_every")
    if cfg.enable_persistence: raise Error("enable_persistence should be False")


def test_run_four_step_order_and_state_flow() raises:
    var cfg = CycleConfig(1.0, 1e9, 0, False)   # 高阈值不巩固; 不持久化
    var c = CognitiveCycle(cfg)
    var r1 = c.run("你好世界")
    # 编排顺序: recall -> plan -> execute -> feedback
    if len(c.trace) != 4: raise Error("trace should have 4 steps, got " + String(len(c.trace)))
    if c.trace[0] != "recall": raise Error("step0 should be recall")
    if c.trace[1] != "plan": raise Error("step1 should be plan")
    if c.trace[2] != "execute": raise Error("step2 should be execute")
    if c.trace[3] != "feedback": raise Error("step3 should be feedback")
    # 状态流转
    if r1.round != 1: raise Error("round should be 1")
    if len(r1.decision) <= 0: raise Error("decision chain should be non-empty (real 七星定序)")
    if r1.phase < 0 or r1.phase > 4: raise Error("phase should be in 0..4")
    if r1.intensity <= 0.0: raise Error("intensity should be > 0 (confidence)")
    if r1.output_text.find("[扇出]") < 0: raise Error("output should mention 十方扇出")
    if c.bridge.loop.state.round != 1: raise Error("loop state round should be 1")
    # 第二轮推进
    var r2 = c.run("再次回灌")
    if r2.round != 2: raise Error("round should be 2 after second run")
    if len(c.trace) != 8: raise Error("trace should accumulate to 8 steps, got " + String(len(c.trace)))
    if c.bridge.loop.state.round != 2: raise Error("loop state round should be 2")


def test_plan_deterministic() raises:
    # 同输入 -> 同 plan（确定性, 无随机）
    var cfg = CycleConfig(1.0, 1e9, 0, False)
    var c1 = CognitiveCycle(cfg)
    var c2 = CognitiveCycle(cfg)
    var r1 = c1.run("确定性文本")
    var r2 = c2.run("确定性文本")
    if r1.phase != r2.phase: raise Error("phase should be deterministic")
    if not ints_equal(r1.decision, r2.decision): raise Error("decision should be deterministic")


def test_flush_persists_and_recovers() raises:
    var cfg = CycleConfig(1.0, 1e9, 0, True)   # 手动 flush, 启用持久化
    var c = CognitiveCycle(cfg)
    _ = c.run("持久化测试一")
    _ = c.run("持久化测试二")
    c.flush()
    # 从落盘恢复
    var p = Persistence("/tmp/taiji_cycle", "cycle")
    var reloaded = TaijiState()
    p.load(reloaded)
    if reloaded.round != 2: raise Error("reloaded round should be 2, got " + String(reloaded.round))
    if reloaded.intent_hash != c.bridge.loop.state.intent_hash: raise Error("reloaded intent_hash mismatch")


def test_auto_snapshot_every() raises:
    var cfg = CycleConfig(1.0, 1e9, 1, True)   # 每轮自动落盘
    var c = CognitiveCycle(cfg)
    _ = c.run("auto1")
    var p = Persistence("/tmp/taiji_cycle", "cycle")
    var reloaded = TaijiState()
    p.load(reloaded)
    if reloaded.round != 1: raise Error("auto snapshot should persist round 1")


def main() raises:
    var failed = 0
    print("=== taiji/cycle tests ===")
    try: test_config_and_result_fields(); print("  passed: config_and_result_fields")
    except e: failed += 1; print("  FAILED: config_and_result_fields ->", e)
    try: test_run_four_step_order_and_state_flow(); print("  passed: run_four_step_order_and_state_flow")
    except e: failed += 1; print("  FAILED: run_four_step_order_and_state_flow ->", e)
    try: test_plan_deterministic(); print("  passed: plan_deterministic")
    except e: failed += 1; print("  FAILED: plan_deterministic ->", e)
    try: test_flush_persists_and_recovers(); print("  passed: flush_persists_and_recovers")
    except e: failed += 1; print("  FAILED: flush_persists_and_recovers ->", e)
    try: test_auto_snapshot_every(); print("  passed: auto_snapshot_every")
    except e: failed += 1; print("  FAILED: auto_snapshot_every ->", e)
    if failed > 0:
        print("cycle -> passed: 0  failed:", failed)
        raise Error("cycle tests failed")
    print("cycle -> passed: 5  failed: 0")
