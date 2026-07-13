# observability/benchmarks/bench_store.mojo — 跨进程持久化 ledger 基准
# @extern("clock") 取时; sink 反馈 + 连续变化种子防 DCE。
# 运行: mojo run -I . -I core observability/benchmarks/bench_store.mojo
from observability import TraceLedger, REC_TRACE, REC_BACKFILL
from observability.tracing import Tracer, TraceSpan
from pipeline import PipelineResult
from wuxing import WOOD, FIRE, EARTH

@extern("clock")
def clock() abi("C") -> Int:
    ...

def _mk_result(seed: Int) -> PipelineResult:
    var r = PipelineResult()
    r.phase = seed % 5
    r.confidence = 0.5 + Float64(seed % 50) / 100.0
    r.policy_id = 3
    r.append_plan(WOOD)
    r.append_plan(FIRE)
    r.append_plan(EARTH)
    return r^

def _mk_tracer(seed: Int) -> Tracer:
    var t = Tracer()
    for i in range(3):
        var sp = TraceSpan()
        sp.trace_id = i
        sp.stage = i
        sp.element = (seed + i) % 5
        sp.decision = (seed + i) % 5
        sp.confidence_milli = 800
        sp.policy_id = 3
        t.add_span(sp)
    return t^

def main() raises:
    var N: Int = 200_000
    var sink_i: Int = 0
    var seed: Int = 1

    # --- record_trace + record_backfill + to_jsonl (每轮 50 次, seed 反馈) ---
    var t0 = clock()
    for _ in range(N):
        var s = 0
        for _ in range(50):
            var led = TraceLedger()
            var r = _mk_result(seed)
            var tr = _mk_tracer(seed)
            var lid = led.record_trace(tr, r)
            led.record_backfill(lid, (seed % 3) - 1, 1, (1 if (seed % 7 == 0) else 0), 800, 3, (seed % 30))
            s = s + led.to_jsonl().byte_length()
            seed = seed * 31 + s + 1
        sink_i = sink_i + s
    var t1 = clock()
    var ns_store = (t1 - t0) * 1000 / (N * 50)

    print("observability store  : " + String(ns_store) + " ns/op")
    print("sink " + String(sink_i))
