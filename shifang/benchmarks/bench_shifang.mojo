# shifang/benchmarks/bench_shifang.mojo — 十方扇出 + 连接器基准
# @extern("clock") 取时; sink 反馈 + 连续变化种子防 DCE。
# 运行: mojo run -I . -I core shifang/benchmarks/bench_shifang.mojo
from pipeline import run_pipeline_safe, PipelineResult
from shifang import (
    Connector, ConnectorResponse, CONNECTOR_LLM, ShifangOutput, fanout,
    LLMSidecar, SIDECAR_EXTERNAL,
)

@extern("clock")
def clock() abi("C") -> Int:
    ...

def make_result(seed: Int) -> PipelineResult:
    # 连续变化种子 → 不同规划链, 防常量折叠。
    var texts = List[String]()
    texts.append("短文本"); texts.append("中等长度的一段认知架构调度文本用于基准")
    texts.append("这是一段明显更长的文本内容用来驱动五行相位判定与规划链的生成以测量扇出开销")
    return run_pipeline_safe(texts[seed % 3], 0.5, 8, 3, 5)

def main() raises:
    var N: Int = 1_000_000
    var sink_f: Float64 = 0.0
    var sink_i: Int = 0

    # --- fanout (含连接器派发) ---
    var t0 = clock()
    var conn = Connector(CONNECTOR_LLM)
    for i in range(N):
        var res = make_result(i)
        var out = fanout(res, conn)
        sink_i = sink_i + out.action_len
        sink_f = sink_f + Float64(out.latency_ms)
    var t1 = clock()
    var ns_fanout = (t1 - t0) * 1000 / N

    # --- connector.dispatch only ---
    var t2 = clock()
    var conn2 = Connector(CONNECTOR_LLM)
    for i in range(N):
        var res = make_result(i)
        var resp = ConnectorResponse()
        conn2.dispatch("bench", res, 1000, resp)
        sink_i = sink_i + resp.latency_ms
    var t3 = clock()
    var ns_dispatch = (t3 - t2) * 1000 / N

    print("shifang fanout       : " + String(ns_fanout) + " ns/op")
    print("shifang dispatch-only: " + String(ns_dispatch) + " ns/op")

    # --- external LLM sidecar bridge (spawns python3; measured in us/call) ---
    # 需求 ① 落地成本：每次 dispatch 经 setenv + system(python3 llm_sidecar.py) + 读回。
    # 子进程开销占主导，故用小迭代次数单独测量。
    var t4 = clock()
    var conn_ext = Connector(CONNECTOR_LLM)
    conn_ext.sidecar = LLMSidecar(SIDECAR_EXTERNAL)
    var ext_iters: Int = 10
    for i in range(ext_iters):
        var res = make_result(i)
        var resp = ConnectorResponse()
        conn_ext.dispatch("bench external", res, 1000, resp)
        sink_i = sink_i + resp.latency_ms
    var t5 = clock()
    var us_bridge = (t5 - t4) / ext_iters
    print("shifang external-bridge: " + String(us_bridge) + " us/call (spawns python3 sidecar, " + String(ext_iters) + " iters)")

    print("sink " + String(sink_i) + " " + String(sink_f))
