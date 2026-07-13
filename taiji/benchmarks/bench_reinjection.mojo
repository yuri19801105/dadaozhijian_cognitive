# taiji/benchmarks/bench_reinjection.mojo — 回灌衔接基准
# @extern("clock") 取时; sink 反馈 + 连续变化种子防 DCE。
# 运行: mojo run -I . -I core taiji/benchmarks/bench_reinjection.mojo
from taiji.reinjection import (
    ReinjectionBridge, reinject_output, reinject_decision, reinject_intensity,
)
from pipeline import PipelineResult
from shifang import ShifangOutput
from observability.tracing import Tracer, TraceSpan
from observability.metrics import Metrics

@extern("clock")
def clock() abi("C") -> Int:
    ...


def _sample_result(seed: Int) -> PipelineResult:
    var res = PipelineResult()
    res.phase = seed % 5
    res.confidence = 0.5 + Float64(seed % 50) / 100.0
    res.policy_id = seed % 8
    res.append_plan(seed % 5)
    res.append_plan((seed + 1) % 5)
    res.append_plan((seed + 2) % 5)
    return res^


def _sample_output(seed: Int) -> ShifangOutput:
    var out = ShifangOutput()
    out._set(0, seed % 5)
    out._set(1, (seed + 1) % 5)
    out.ok = 1
    if seed % 7 == 0:
        out.degraded = 1
    else:
        out.degraded = 0
    return out^


def _sample_metrics(seed: Int) -> Metrics:
    var m = Metrics()
    m.record(seed % 100, 1, seed % 2)
    return m^


def _sample_tracer(seed: Int) -> Tracer:
    var t = Tracer()
    for i in range(3):
        var sp = TraceSpan()
        sp.trace_id = i
        sp.stage = i
        sp.element = (seed + i) % 5
        sp.decision = (seed + i) % 5
        sp.confidence_milli = 500
        sp.policy_id = seed % 8
        t.add_span(sp)
    return t


def main() raises:
    var N: Int = 100_000
    var sink_i: Int = 0
    var seed: Int = 1

    # --- reinject_safe 全路径(映射 + 校验 + feedback + 日志) ---
    var b = ReinjectionBridge(1, 1.0, 1e9)   # 复用桥(日志累积, 贴近真实多轮回灌)
    var t0 = clock()
    for _ in range(N):
        seed = seed * 1103515245 + 12345
        var ok = b.reinject_safe(_sample_result(seed), _sample_output(seed),
                                 _sample_tracer(seed), _sample_metrics(seed), "bench")
        if ok:
            sink_i = sink_i + 1
    var t1 = clock()
    var ns_safe = (t1 - t0) * 1000 / N

    # --- 字段映射原语(输出串 + 决策链 + 强度) 单独观测 ---
    var t2 = clock()
    for _ in range(N):
        seed = seed * 1103515245 + 12345
        var s = reinject_output(_sample_result(seed), _sample_output(seed), "bench")
        var d = reinject_decision(_sample_result(seed))
        var it = reinject_intensity(_sample_result(seed), _sample_metrics(seed), _sample_output(seed))
        sink_i = sink_i + s.byte_length() + len(d) + Int(it * 1000.0)
    var t3 = clock()
    var ns_map = (t3 - t2) * 1000 / N

    print("reinjection reinject_safe : " + String(ns_safe) + " ns/op (ok=" + String(sink_i) + ")")
    print("reinjection map_primitives: " + String(ns_map) + " ns/op")
