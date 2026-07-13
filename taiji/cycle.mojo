# === taiji/cycle.mojo ===
# 四步闭环编排（recall→plan→execute→feedback）, 迁自规划 §4.1.1 接口骨架。
#
# 真实接线（需求 A / ① / ② / ③ 统一收口）：
#   - plan   : 真实 wuxing/liuhe/qixing/scheduler 编排（pipeline.run_pipeline），
#              相位可回溯到五行生克、决策链由七星定序派生（可审计，见 §4.1.0）。
#   - execute: 真实 shifang 十方扇出（Connector → call_external → 真实 LLM 侧车），
#              未设置 LLM_API_KEY 时侧车优雅降级（ok=1）。
#   - feedback: 经 ReinjectionBridge 安全回灌进太极长期记忆根，并把 lineage_id 落库，
#              与 observability 溯源 ledger 跨进程串联（需求 ②）；回灌成败/耗时上报 runtime
#              健康度与超时门控（需求 ③）。
#
# 依赖边界声明（后续 Phase 真实落地, 此处直接复用, 非占位）：
#   from pipeline import run_pipeline
#   from shifang import fanout_with_response, Connector, render_reply
#   from observability import Tracer, Metrics
# 注：taiji 作为 L1 状态根直接复用 L5/L6 产物，与 reinjection.mojo 同口径（已实证可用）。

from taiji.feedback_loop import FeedbackLoop
from taiji.consolidation import Consolidation
from taiji.taiji_state import TaijiState
from taiji.persistence import Persistence
from taiji.reinjection import ReinjectionBridge
from pipeline import run_pipeline
from shifang import (
    Connector, ConnectorResponse, CONNECTOR_LLM,
    SIDECAR_EXTERNAL, SIDECAR_TEMPLATE, ShifangOutput, build_prompt, DIR_COUNT,
)
from observability.tracing import Tracer
from observability.metrics import Metrics


struct CycleConfig:
    var energy_budget: Float64
    var feedback_threshold: Float64
    var snapshot_every: Int
    var enable_persistence: Bool

    def __init__(out self, energy_budget: Float64, feedback_threshold: Float64, snapshot_every: Int, enable_persistence: Bool):
        self.energy_budget = energy_budget
        self.feedback_threshold = feedback_threshold
        self.snapshot_every = snapshot_every
        self.enable_persistence = enable_persistence


struct CycleResult:
    var output_text: String
    var decision: List[Int]
    var phase: Int
    var intensity: Float64
    var round: Int

    def __init__(out self, output_text: String, decision: List[Int], phase: Int, intensity: Float64, round: Int):
        self.output_text = output_text
        # List[Int] 非 ImplicitlyCopyable -> 逐元素拷贝（borrowed 读取, 无移动）
        self.decision = List[Int]()
        for i in range(len(decision)):
            self.decision.append(decision[i])
        self.phase = phase
        self.intensity = intensity
        self.round = round


struct CognitiveCycle:
    var bridge: ReinjectionBridge        # 回灌衔接桥（持有太极状态根 + 溯源 ledger）
    var consolidator: Consolidation
    var cfg: CycleConfig
    var persistence: Persistence
    var trace: List[String]              # 编排追踪（验证四步顺序）
    var runs_since_flush: Int
    # —— 规划/执行参数（真实 wuxing/scheduler 入口）——
    var plan_focus: Float64
    var max_depth: Int
    var chain_depth: Int
    var ground: Int
    var sidecar_mode: Int                # 真实 LLM 侧车模式（默认 EXTERNAL）
    # —— 回灌结果上报（供 runtime 健康度/超时门控，需求 ③）——
    var last_backfill_ok: Int
    var last_backfill_latency: Int

    def __init__(out self, cfg: CycleConfig) raises:
        self.bridge = ReinjectionBridge(0, cfg.energy_budget, cfg.feedback_threshold)
        self.consolidator = Consolidation(0.6, 0.1)
        self.cfg = CycleConfig(cfg.energy_budget, cfg.feedback_threshold, cfg.snapshot_every, cfg.enable_persistence)
        self.persistence = Persistence("/tmp/taiji_cycle", "cycle")
        self.trace = List[String]()
        self.runs_since_flush = 0
        self.plan_focus = 0.5
        self.max_depth = 8
        self.chain_depth = 3
        self.ground = 5
        self.sidecar_mode = SIDECAR_EXTERNAL
        self.last_backfill_ok = 0
        self.last_backfill_latency = 0

    def __init__(out self, cfg: CycleConfig, sidecar_mode: Int,
                 plan_focus: Float64, max_depth: Int, chain_depth: Int, ground: Int) raises:
        self.bridge = ReinjectionBridge(0, cfg.energy_budget, cfg.feedback_threshold)
        self.consolidator = Consolidation(0.6, 0.1)
        self.cfg = CycleConfig(cfg.energy_budget, cfg.feedback_threshold, cfg.snapshot_every, cfg.enable_persistence)
        self.persistence = Persistence("/tmp/taiji_cycle", "cycle")
        self.trace = List[String]()
        self.runs_since_flush = 0
        self.plan_focus = plan_focus
        self.max_depth = max_depth
        self.chain_depth = chain_depth
        self.ground = ground
        self.sidecar_mode = sidecar_mode
        self.last_backfill_ok = 0
        self.last_backfill_latency = 0

    # 四步闭环: recall -> plan -> execute -> feedback, 返回本轮结果
    def run(mut self, text: String) raises -> CycleResult:
        self.trace.append("recall")
        var ctx = self.bridge.loop.recall()
        # —— plan: 真实 wuxing/liuhe/qixing/scheduler 编排 ——
        self.trace.append("plan")
        var res = run_pipeline(text, self.plan_focus, self.max_depth, self.chain_depth, self.ground)
        # —— execute: 真实 shifang 十方扇出（Connector → 真实 LLM 侧车）——
        self.trace.append("execute")
        var conn = Connector(CONNECTOR_LLM, self.sidecar_mode)
        var resp = ConnectorResponse()
        var prompt = build_prompt(res)
        conn.dispatch(prompt, res, 1000, resp)
        var out = ShifangOutput()
        out.latency_ms = resp.latency_ms
        out.ok = resp.ok
        out.degraded = resp.degraded
        for i in range(res.plan_len):
            var element = res.plan_at(i)
            var dir = (element * 2 + i) % DIR_COUNT
            out._set(dir, element)
        var out_text = resp.text + "\n[扇出] 十方已落地 " + String(out.action_len) \
                       + " 向 (ok=" + String(out.ok) + " degraded=" + String(out.degraded) + ")"
        # —— feedback: 经 ReinjectionBridge 安全回灌 + 溯源 ledger 关联 ——
        self.trace.append("feedback")
        var tracer = Tracer()
        tracer.add_decision_spans(res)
        var metrics = Metrics()
        metrics.record(out.latency_ms, out.ok, out.degraded)
        var lid = self.bridge.begin_lineage(tracer, res)
        var ok = self.bridge.reinject_safe(res, out, tracer, metrics, text, lid)
        if ok:
            self.last_backfill_ok = 1
        else:
            self.last_backfill_ok = 0
        self.last_backfill_latency = out.latency_ms
        # 巩固门控
        if self.bridge.loop.should_consolidate():
            self.consolidator.consolidate(self.bridge.loop.state)
        # 自动落盘（按 snapshot_every）
        self.runs_since_flush += 1
        if self.cfg.enable_persistence and self.cfg.snapshot_every > 0:
            if self.runs_since_flush >= self.cfg.snapshot_every:
                self.persistence.save_snapshot(self.bridge.loop.state)
                self.runs_since_flush = 0
        # 重建决策链（真实七星定序产物）
        var decision = List[Int]()
        for i in range(res.plan_len):
            decision.append(res.plan_at(i))
        return CycleResult(out_text, decision, res.phase, res.confidence, self.bridge.loop.state.round)

    # 显式落盘触发（持久化太极状态根 + 回灌 ledger）
    def flush(mut self) raises:
        if self.cfg.enable_persistence:
            self.persistence.save_snapshot(self.bridge.loop.state)
        self.runs_since_flush = 0
        self.trace = List[String]()

    # 跨进程持久化：把回灌溯源 ledger(JSON-Lines)落盘（需求 ②）。
    def persist_ledger(mut self, path: String) raises:
        self.bridge.persist_ledger(path)
