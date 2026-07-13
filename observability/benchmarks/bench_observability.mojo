# observability/benchmarks/bench_observability.mojo — 指标/追踪/解释/渲染 基准
# @extern("clock") 取时; sink 反馈 + 连续变化种子防 DCE。
# 运行: mojo run -I . -I core observability/benchmarks/bench_observability.mojo
from pipeline import run_pipeline_safe
from shifang import Connector, CONNECTOR_LLM, fanout
from observability import (
    Metrics, Tracer, explain_decision, render_summary, render_svg,
)

@extern("clock")
def clock() abi("C") -> Int:
    ...

def main() raises:
    var N: Int = 200_000
    var sink_i: Int = 0
    var seed: Int = 1

    # 复用一份真实结果/扇出, 专注观测层原语开销。
    var res = run_pipeline_safe("让五行调度策略自适应不同负载并解释其决策依据", 0.5, 8, 3, 5)
    var conn = Connector(CONNECTOR_LLM)
    var out = fanout(res, conn)

    # --- metrics: record + p95 (每轮 50 次, seed 反馈) ---
    var t0 = clock()
    for _ in range(N):
        var s = 0
        for _ in range(50):
            var m = Metrics()
            m.record((seed % 200), (1 if (seed % 5 != 0) else 0), (1 if (seed % 13 == 0) else 0))
            s = s + m.p95()
            seed = seed * 31 + s + 1
        sink_i = sink_i + s
    var t1 = clock()
    var ns_metrics = (t1 - t0) * 1000 / (N * 50)

    # --- tracer: 溯源 span 固化 + 渲染 (每轮 50 次) ---
    var t2 = clock()
    for _ in range(N):
        var s = 0
        for _ in range(50):
            var tr = Tracer()
            tr.add_decision_spans(res)
            s = s + tr.render_trace().byte_length()
            seed = seed * 31 + s + 1
        sink_i = sink_i + s
    var t3 = clock()
    var ns_trace = (t3 - t2) * 1000 / (N * 50)

    # --- explain + render_summary + render_svg (每轮 50 次) ---
    var t4 = clock()
    for _ in range(N):
        var s = 0
        for _ in range(50):
            var exp = explain_decision(res, out, "probe")
            var sum = render_summary(res, out, Tracer())
            var svg = render_svg(res, out)
            s = s + exp.byte_length() + sum.byte_length() + svg.byte_length()
            seed = seed * 31 + s + 1
        sink_i = sink_i + s
    var t5 = clock()
    var ns_render = (t5 - t4) * 1000 / (N * 50)

    print("observability metrics : " + String(ns_metrics) + " ns/op")
    print("observability trace   : " + String(ns_trace) + " ns/op")
    print("observability render  : " + String(ns_render) + " ns/op")
    print("sink " + String(sink_i))
