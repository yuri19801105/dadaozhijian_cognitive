# === taiji/tests/test_reinjection.mojo ===
# TDD (RED -> GREEN): 测试 taiji/reinjection（回灌衔接：
#   数据源对接 + 字段映射 + 异常/日志隔离 + 不影响既有 taiji 闭环）。
from taiji.reinjection import (
    ReinjectionBridge, reinject_output, reinject_decision, reinject_intensity, validate_source,
)
from pipeline import PipelineResult
from shifang import ShifangOutput
from observability.tracing import Tracer, TraceSpan
from observability.metrics import Metrics
from observability import REC_TRACE, REC_BACKFILL
from taiji.cycle import CognitiveCycle, CycleConfig


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol


# 合法调度产物: plan=[木,火,土], conf=0.9, policy=3, phase=2
def _sample_result() -> PipelineResult:
    var res = PipelineResult()
    res.phase = 2
    res.intensity = 5
    res.confidence = 0.9
    res.policy_id = 3
    res.append_plan(0)
    res.append_plan(1)
    res.append_plan(2)
    return res^


# 合法十方扇出: 3 向, ok, 非降级
def _sample_output() -> ShifangOutput:
    var out = ShifangOutput()
    out._set(0, 0)
    out._set(1, 1)
    out._set(2, 2)
    out.ok = 1
    out.degraded = 0
    return out^


# 合法运行指标: 全 ok, 无退化
def _sample_metrics() -> Metrics:
    var m = Metrics()
    m.record(10, 1, 0)
    return m^


# 合法决策溯源: 与 plan 对应的 3 个 span
def _sample_tracer() -> Tracer:
    var t = Tracer()
    for i in range(3):
        var sp = TraceSpan()
        sp.trace_id = i
        sp.stage = i
        sp.element = i
        sp.decision = i
        sp.confidence_milli = 900
        sp.policy_id = 3
        t.add_span(sp)
    return t


def test_validate_source_valid() raises:
    if not validate_source(_sample_result(), _sample_output(), _sample_metrics()):
        raise Error("valid source should pass validation")


def test_validate_source_invalid_phase() raises:
    var r = _sample_result()
    r.phase = 9
    if validate_source(r, _sample_output(), _sample_metrics()):
        raise Error("phase=9 should be rejected")


def test_validate_source_invalid_conf() raises:
    var r = _sample_result()
    r.confidence = 2.0
    if validate_source(r, _sample_output(), _sample_metrics()):
        raise Error("confidence=2.0 should be rejected")


def test_reinject_output_mapping() raises:
    var s = reinject_output(_sample_result(), _sample_output(), "测试输入")
    if s.find("[回灌]") < 0: raise Error("missing [回灌] tag")
    if s.find("phase=2") < 0: raise Error("missing phase")
    if s.find("conf=90%") < 0: raise Error("missing conf")
    if s.find("policy=3") < 0: raise Error("missing policy")
    if s.find("木→火→土") < 0: raise Error("missing plan names (木→火→土)")
    if s.find("十方=3向") < 0: raise Error("missing shifang count")
    if s.find("ok=1 degraded=0") < 0: raise Error("missing shifang status")


def test_reinject_decision_from_plan() raises:
    var dec = reinject_decision(_sample_result())
    if len(dec) != 3: raise Error("plan_len should be 3")
    if dec[0] != 0 or dec[1] != 1 or dec[2] != 2: raise Error("decision should equal plan")


def test_reinject_decision_fallback_candidates() raises:
    var r = PipelineResult()   # 无 plan
    r.append_candidate(4)
    r.append_candidate(3)
    var dec = reinject_decision(r)
    if len(dec) != 2: raise Error("should fall back to candidates")
    if dec[0] != 4 or dec[1] != 3: raise Error("decision should equal candidates")


def test_reinject_intensity_blend() raises:
    # conf=1, degr=0, ok, 非降级 -> 1.0
    var r = _sample_result(); r.confidence = 1.0
    var m = _sample_metrics()
    var o = _sample_output()
    if not approx(reinject_intensity(r, m, o), 1.0, 1e-12): raise Error("intensity should be 1.0")
    # 扇出降级 -> 折半 -> 0.5
    o.degraded = 1
    if not approx(reinject_intensity(r, m, o), 0.5, 1e-12): raise Error("degraded should halve to 0.5")
    # conf=0.5, degr=0.5, 非降级 -> 0.25
    var r2 = _sample_result(); r2.confidence = 0.5
    var m2 = Metrics()
    m2.record(10, 1, 1)   # ok=1, degraded=1 -> degr=0.5
    var o2 = _sample_output()
    if not approx(reinject_intensity(r2, m2, o2), 0.25, 1e-12): raise Error("blend should be 0.25")


def test_bridge_reinject_ok() raises:
    var b = ReinjectionBridge(7, 1.0, 1e9)   # 高阈值, 不触发巩固
    var ok = b.reinject_safe(_sample_result(), _sample_output(), _sample_tracer(), _sample_metrics(), "测试输入")
    if not ok: raise Error("reinject should succeed")
    if b.injected != 1: raise Error("injected should be 1")
    if b.last_status != 1: raise Error("last_status should be 1")
    if b.loop.state.round != 1: raise Error("taiji round should advance to 1")
    var found_ok = False
    for i in range(b.log_count()):
        if b.log_at(i).find("REINJECT_OK") >= 0: found_ok = True
    if not found_ok: raise Error("expected REINJECT_OK audit line")


def test_bridge_reinject_rejected() raises:
    var b = ReinjectionBridge(0, 1.0, 1e9)
    var r = _sample_result(); r.phase = 9   # 非法相位
    var ok = b.reinject_safe(r, _sample_output(), _sample_tracer(), _sample_metrics(), "测试输入")
    if ok: raise Error("invalid phase should be rejected")
    if b.rejected != 1: raise Error("rejected should be 1")
    if b.loop.state.round != 0: raise Error("rejected must not touch taiji state")
    var found_rej = False
    for i in range(b.log_count()):
        if b.log_at(i).find("REINJECT_REJECTED") >= 0: found_rej = True
    if not found_rej: raise Error("expected REINJECT_REJECTED audit line")


def test_bridge_isolates_errors_and_keeps_existing_functional() raises:
    # 1) 回灌衔接层多次调用均不向上 raises(即便输入非法也只返回 False)
    var b = ReinjectionBridge(1, 1.0, 1e9)
    var r_bad = _sample_result(); r_bad.phase = 99
    var r1 = b.reinject_safe(r_bad, _sample_output(), _sample_tracer(), _sample_metrics(), "x")
    var r2 = b.reinject_safe(_sample_result(), _sample_output(), _sample_tracer(), _sample_metrics(), "y")
    if r1: raise Error("bad input should return False")
    if not r2: raise Error("good input should return True")
    # 2) 现有 taiji 闭环(CognitiveCycle)独立运行, 不受回灌衔接影响
    var cfg = CycleConfig(1.0, 1e9, 0, False)   # 关闭持久化, 避免落盘副作用
    var cyc = CognitiveCycle(cfg)
    _ = cyc.run("第一轮")
    _ = cyc.run("第二轮")
    if cyc.bridge.loop.state.round != 2: raise Error("CognitiveCycle should still advance independently")
    if b.loop.state.round != 1: raise Error("bridge round should be 1 (separate state)")


def test_bridge_links_ledger() raises:
    # begin_lineage 登记溯源, reinject_safe(lineage_id) 落库回灌, 二者以 lineage_id 串联。
    var b = ReinjectionBridge(2, 1.0, 1e9)
    var lid = b.begin_lineage(_sample_tracer(), _sample_result())
    var ok = b.reinject_safe(_sample_result(), _sample_output(), _sample_tracer(),
                             _sample_metrics(), "测试输入", lid)
    if not ok: raise Error("reinject should succeed")
    if b.ledger.size() != 2: raise Error("ledger should have 2 records (trace + backfill)")
    if b.ledger.count_kind(lid, REC_TRACE) != 1: raise Error("should have 1 trace record")
    if b.ledger.count_kind(lid, REC_BACKFILL) != 1: raise Error("should have 1 backfill record")
    if b.ledger.backfill_status(lid) != 1: raise Error("backfill status should be success(1)")
    if b.ledger.backfill_conf(lid) != 900: raise Error("backfill conf should be 900‰")
    if b.ledger.to_jsonl().byte_length() == 0: raise Error("jsonl export should be non-empty")


def main() raises:
    var failed = 0
    print("=== taiji/reinjection tests ===")
    try: test_validate_source_valid(); print("  passed: validate_source_valid")
    except e: failed += 1; print("  FAILED: validate_source_valid ->", e)
    try: test_validate_source_invalid_phase(); print("  passed: validate_source_invalid_phase")
    except e: failed += 1; print("  FAILED: validate_source_invalid_phase ->", e)
    try: test_validate_source_invalid_conf(); print("  passed: validate_source_invalid_conf")
    except e: failed += 1; print("  FAILED: validate_source_invalid_conf ->", e)
    try: test_reinject_output_mapping(); print("  passed: reinject_output_mapping")
    except e: failed += 1; print("  FAILED: reinject_output_mapping ->", e)
    try: test_reinject_decision_from_plan(); print("  passed: reinject_decision_from_plan")
    except e: failed += 1; print("  FAILED: reinject_decision_from_plan ->", e)
    try: test_reinject_decision_fallback_candidates(); print("  passed: reinject_decision_fallback_candidates")
    except e: failed += 1; print("  FAILED: reinject_decision_fallback_candidates ->", e)
    try: test_reinject_intensity_blend(); print("  passed: reinject_intensity_blend")
    except e: failed += 1; print("  FAILED: reinject_intensity_blend ->", e)
    try: test_bridge_reinject_ok(); print("  passed: bridge_reinject_ok")
    except e: failed += 1; print("  FAILED: bridge_reinject_ok ->", e)
    try: test_bridge_reinject_rejected(); print("  passed: bridge_reinject_rejected")
    except e: failed += 1; print("  FAILED: bridge_reinject_rejected ->", e)
    try: test_bridge_isolates_errors_and_keeps_existing_functional(); print("  passed: bridge_isolates_errors_and_keeps_existing_functional")
    except e: failed += 1; print("  FAILED: bridge_isolates_errors_and_keeps_existing_functional ->", e)
    try: test_bridge_links_ledger(); print("  passed: bridge_links_ledger")
    except e: failed += 1; print("  FAILED: bridge_links_ledger ->", e)
    if failed > 0:
        print("reinjection -> passed: 0  failed:", failed)
        raise Error("reinjection tests failed")
    print("reinjection -> passed: 12  failed: 0")
