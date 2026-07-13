# observability/tests/test_store.mojo — TraceLedger 跨进程持久化 TDD 测试
# 运行: mojo run -I . -I core observability/tests/test_store.mojo
from pipeline import PipelineResult
from observability import TraceLedger, REC_TRACE, REC_BACKFILL
from observability.tracing import Tracer, TraceSpan
from wuxing import WOOD, FIRE, EARTH

struct Counter(Movable):
    var passed: Int
    var failed: Int
    def __init__(out self):
        self.passed = 0
        self.failed = 0
    def check(mut self, cond: Bool, name: String):
        if cond:
            self.passed = self.passed + 1
        else:
            self.failed = self.failed + 1
            print("[FAIL] " + name)

def _sample_result() -> PipelineResult:
    var r = PipelineResult()
    r.phase = 0
    r.confidence = 0.8
    r.policy_id = 3
    r.append_plan(WOOD)
    r.append_plan(FIRE)
    r.append_plan(EARTH)
    return r^

def _sample_tracer() -> Tracer:
    var t = Tracer()
    var sp0 = TraceSpan()
    sp0.trace_id = 0; sp0.stage = 0; sp0.element = WOOD
    sp0.confidence_milli = 800; sp0.policy_id = 3
    var sp1 = TraceSpan()
    sp1.trace_id = 1; sp1.stage = 1; sp1.element = FIRE
    sp1.confidence_milli = 800; sp1.policy_id = 3
    t.add_span(sp0)
    t.add_span(sp1)
    return t

def test_trace_and_backfill_linked(mut c: Counter) raises:
    var r = _sample_result()
    var t = _sample_tracer()
    var led = TraceLedger()
    var id = led.record_trace(t, r)
    led.record_backfill(id, 1, 1, 0, 800, 3, 12)
    c.check(led.size() == 2, "ledger 含 2 条记录")
    # 同一 lineage_id 下既有溯源又有回灌 → 链路串联
    c.check(led.count_kind(id, REC_TRACE) == 1, "lineage 含 1 条溯源记录")
    c.check(led.count_kind(id, REC_BACKFILL) == 1, "lineage 含 1 条回灌记录(链路串联)")
    c.check(led.backfill_status(id) == 1, "回灌状态=成功(1)")
    c.check(led.backfill_latency(id) == 12, "回灌延迟=12ms")
    c.check(led.backfill_conf(id) == 800, "回灌置信=800‰")

def test_jsonl_serialization(mut c: Counter) raises:
    var r = _sample_result()
    var t = _sample_tracer()
    var led = TraceLedger()
    var id = led.record_trace(t, r)
    led.record_backfill(id, 1, 1, 0, 800, 3, 12)
    var j = led.to_jsonl()
    # JSON-Lines: 每条记录一行(含结尾换行), 长度随记录数增长
    c.check(j.byte_length() > 0, "jsonl 非空")
    var led2 = TraceLedger()
    _ = led2.record_trace(t, r)
    c.check(led.to_jsonl().byte_length() > led2.to_jsonl().byte_length(),
            "jsonl 长度随记录数增长")
    # lineage() 人类可读串联同样可用
    c.check(led.lineage(id).byte_length() > 0, "lineage() 可读串联非空")

def test_lineages_independent(mut c: Counter) raises:
    var r = _sample_result()
    var t = _sample_tracer()
    var led = TraceLedger()
    var id1 = led.record_trace(t, r)
    led.record_backfill(id1, 1, 1, 0, 800, 3, 12)
    var id2 = led.record_trace(t, r)
    led.record_backfill(id2, 0, 0, 1, 400, 3, 50)   # 拒绝
    c.check(led.size() == 4, "两条 lineage 共 4 条记录")
    c.check(led.backfill_status(id1) == 1, "lineage1 成功回灌")
    c.check(led.backfill_status(id2) == 0, "lineage2 拒绝回灌")
    c.check(led.backfill_latency(id1) == 12, "lineage1 延迟=12ms")
    c.check(led.backfill_latency(id2) == 50, "lineage2 延迟=50ms(不串入 lineage1)")

def test_reject_and_error_status(mut c: Counter) raises:
    var r = _sample_result()
    var t = _sample_tracer()
    var led = TraceLedger()
    var id = led.record_trace(t, r)
    led.record_backfill(id, 0, 0, 1, 400, 3, 50)    # 拒绝
    led.record_backfill(id, -1, 0, 1, 0, 3, 0)      # 异常
    c.check(led.count_kind(id, REC_BACKFILL) == 2, "同 lineage 含 2 条回灌(拒绝+异常)")
    c.check(led.backfill_status(id) == 0, "首条回灌状态=拒绝(0)")

def test_empty_ledger(mut c: Counter):
    var led = TraceLedger()
    c.check(led.size() == 0, "空 ledger size=0")
    c.check(led.to_jsonl().byte_length() == 0, "空 ledger jsonl 为空")

def main() raises:
    var c = Counter()
    test_trace_and_backfill_linked(c)
    test_jsonl_serialization(c)
    test_lineages_independent(c)
    test_reject_and_error_status(c)
    test_empty_ledger(c)
    print("passed:", c.passed, " failed:", c.failed)
