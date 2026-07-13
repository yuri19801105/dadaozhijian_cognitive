# === e2e_demo.mojo ===
# 端到端联调演示：pipeline(符号引擎) → shifang(真实 LLM 渲染) → 双 ledger 累积。
# 目标：
#   1) 跑通「太极→…→十方」符号计算 + 真实 Qwen3.5 中文渲染的整链路；
#   2) 确认侧车自带 ledger(shifang/ledger/sidecar_calls.jsonl) 自动累积 (计划→响应) 配对；
#   3) 经 ReinjectionBridge 把 (PipelineResult + ShifangOutput + Tracer + Metrics + 用户原文)
#      序列化为可溯源血缘 ledger(shifang/ledger/e2e_lineage.jsonl) —— 即阶段 B 蒸馏的训练数据源。
#
# 运行: mojo run -I . -I core e2e_demo.mojo
# 前置: Ollama 已起(:11434)，且已 pull qwen3.5:4b-mlx（默认后端，见 shifang/sidecar_config.json）。

from pipeline import run_pipeline_safe, PipelineResult
from shifang import (
    Connector, ConnectorResponse, CONNECTOR_LLM, build_prompt, ShifangOutput, DIR_COUNT,
)
from taiji.reinjection import ReinjectionBridge
from observability.tracing import Tracer, TraceSpan
from observability.metrics import Metrics
from wuxing import element_name, WOOD, FIRE, EARTH, METAL, WATER


# —— 辅助：把规划链构造为 Tracer(每步一 span) ——
def _tracer(result: PipelineResult) -> Tracer:
    var t = Tracer()
    for i in range(result.plan_len):
        var sp = TraceSpan()
        sp.trace_id = i
        sp.parent = i - 1
        sp.stage = i
        sp.element = result.plan_at(i)
        sp.decision = result.plan_at(i)
        sp.confidence_milli = Int(result.confidence * 1000.0)
        sp.policy_id = result.policy_id
        t.add_span(sp)
    return t


# —— 辅助：由 dispatch 响应构造十方扇出(镜像 shifang.fanout 的映射) ——
def _output_from_dispatch(result: PipelineResult, resp: ConnectorResponse) -> ShifangOutput:
    var o = ShifangOutput()
    for i in range(result.plan_len):
        var element = result.plan_at(i)
        var dir = (element * 2 + i) % DIR_COUNT
        o._set(dir, element)
    o.ok = resp.ok
    o.degraded = resp.degraded
    o.latency_ms = resp.latency_ms
    return o^


def _run_one(mut bridge: ReinjectionBridge, text: String) raises:
    # 1) 符号引擎：阶段图驱动端到端编排（五行调度→六合供给→七星定序→总派发）。
    var res = run_pipeline_safe(text, 0.5, 8, 3, 5)
    var phase_name = element_name(res.phase)
    print("────────────────────────────────────────────")
    print("[输入] ", text)
    print("[符号] phase=", phase_name,
          " intensity=", res.intensity,
          " confidence=", Int(res.confidence * 100.0), "%",
          " policy=", res.policy_id,
          " ok=", res.ok)
    var plan = String("[规划链] ")
    for i in range(res.plan_len):
        if i > 0:
            plan = plan + "→"
        plan = plan + element_name(res.plan_at(i))
    print(plan)

    # 2) 十方执行层：把符号计划交给真实 LLM 渲染（经 Mojo→python3 侧车 → Ollama Qwen3.5）。
    var connector = Connector(CONNECTOR_LLM)
    var resp = ConnectorResponse()
    var prompt = build_prompt(res)
    connector.dispatch(prompt, res, 2000, resp)   # raises；侧车自动写 sidecar ledger

    print("[渲染] ", resp.text)
    print("[侧车] ok=", resp.ok, " degraded=", resp.degraded)

    # 3) 血缘 ledger：把本轮全产物序列化（供阶段 B 自蒸馏训练对）。
    var output = _output_from_dispatch(res, resp)
    var tracer = _tracer(res)
    var metrics = Metrics()
    metrics.record(resp.latency_ms, resp.ok, resp.degraded)
    var lid = bridge.begin_lineage(tracer, res)
    _ = bridge.reinject_safe(res, output, tracer, metrics, text, lid)


def main() raises:
    print("=== 大道至简 · 端到端联调（真实 Qwen3.5:4b-mlx）===")

    # 多元认知语义输入：覆盖 水/木/火/土/金 五相位 + 不同认知主题（决策/博弈/演化/定序/供给），
    # 验证符号调度随输入自适应，并加厚 ledger 供阶段 B 蒸馏。
    var inputs = List[String]()
    inputs.append("")                                                                           # 空 → 水(归静)
    inputs.append("木")                                                                         # 3B → 木
    inputs.append("解释五行相生相克如何驱动认知调度")                                              # ~30B → 火
    inputs.append("论述八卦与决策定序在实时推理中的关系")                                          # ~30B → 火
    inputs.append("请设计一个能够自适应不同负载并解释其决策依据的五行调度策略，保持可解释可测量可实时")      # ~70B → 土
    inputs.append("基于七星定序实现多任务优先级调度与资源编排")                                    # ~40B → 火/土
    inputs.append("如何在博弈对抗中运用太极阴阳维持系统动态平衡")                                  # ~30B → 火
    inputs.append("让模型解释六合供给链的能量守恒约束与反馈闭环")                                  # ~30B → 火
    inputs.append("在大规模分布式认知系统中，如何让太极阴阳两仪三才四象五行六合七星八卦九宫十方这一整套符号引擎在保持可解释可测量可实时原则的同时，还能根据环境反馈自适应演化并支撑实时推理")  # >100B → 金

    var bridge = ReinjectionBridge(7, 1.0, 1e9)
    for i in range(len(inputs)):
        _run_one(bridge, inputs[i])

    # 累积血缘 ledger（追加模式，与侧车 ledger 同目录，便于阶段 B 跨文件 join 与跨运行汇聚）。
    bridge.append_ledger(String("shifang/ledger/e2e_lineage.jsonl"))

    print("────────────────────────────────────────────")
    print("[血缘 ledger] injected=", bridge.injected,
          " rejected=", bridge.rejected,
          " errors=", bridge.errors)
    print("[累积] shifang/ledger/e2e_lineage.jsonl（追加模式，跨运行汇聚）")
    print("[侧车 ledger] 自动累积于 shifang/ledger/sidecar_calls.jsonl（每条含 call_id，可溯源）")
