# === taiji/reinjection.mojo ===
# 回灌衔接（Phase 5 闭环收口）：把执行层产物安全回灌进太极长期记忆。
#
# 职责（对应本次需求 4 条）：
#   1) 对接回灌数据源：消费 PipelineResult(调度产物) + ShifangOutput(十方扇出)
#      + Tracer(决策溯源) + Metrics(运行指标) —— 即架构"能说话/可审计"后的全部产物。
#   2) 数据格式转换与字段映射：映射为 TaijiState.feedback 既有签名
#      (output: String, decision: List[Int], phase: Int, intensity: Float64)，
#      与太极现有数据结构完全兼容（不改动 TaijiState / FeedbackLoop / CognitiveCycle）。
#   3) 异常处理与日志记录：源校验 + try/except 全隔离 + 结构化日志
#      (observability.logging: INFO/WARN/ERROR/AUDIT)，便于排查。
#   4) 不影响现有功能：纯增量衔接层，复用 FeedbackLoop.feedback 公共入口；
#      任何异常均被捕获并降级为 False，绝不向上传播、绝不破坏既有闭环。
#
# 实现约束（Mojo 1.0.0b2，本构建已验证）：
#   - PipelineResult/ShifangOutput/Metrics 均 (Movable)，Tracer 为 TrivialRegisterPassable；
#     在 _reinject 中因被多次读取，Mojo 自动借入（不消费），可安全传给多个映射 helper。
#   - List[Int] 非 Movable → reinject_decision 以 ^ 移动返回；feedback 的 decision 参数
#     为最后一次使用，自动移动入参（与现有 test_feedback_loop 一致）。
#   - List.append 在本构建为 raises，故 _log 标记 raises，并由 reinject_safe 的 try 统一兜住。

from taiji.feedback_loop import FeedbackLoop
from pipeline import PipelineResult
from shifang import ShifangOutput
from observability.tracing import Tracer
from observability.metrics import Metrics
from observability.logging import log_line, LOG_INFO, LOG_WARN, LOG_ERROR, LOG_AUDIT
from observability import TraceLedger
from wuxing import element_name


# —— 字段映射（纯函数，可独立单测；Movable 载体按值接收，因调用方复用而自动借入）——

# 输出串：把调度产物 + 十方扇出编码为可读回灌记录（兼容 TaijiState.feedback.output: String）。
def reinject_output(result: PipelineResult, output: ShifangOutput, input_text: String) -> String:
    var s = String("[回灌] " + input_text)
    s = s + " phase=" + String(result.phase)
    s = s + " conf=" + String(Int(result.confidence * 100.0)) + "%"
    s = s + " policy=" + String(result.policy_id)
    s = s + " plan=["
    for i in range(result.plan_len):
        if i > 0:
            s = s + "→"
        s = s + element_name(result.plan_at(i))
    s = s + "]"
    s = s + " 十方=" + String(output.action_len) + "向"
    s = s + "(ok=" + String(output.ok) + " degraded=" + String(output.degraded) + ")"
    return s^


# 决策链：优先取规划链(plan)，缺失则退化为候选链(candidates)；映射为七星决策链 List[Int]。
def reinject_decision(result: PipelineResult) -> List[Int]:
    var dec = List[Int]()
    var n = result.plan_len
    if n == 0:
        n = result.candidate_len
        for i in range(n):
            dec.append(result.candidate_at(i))
    else:
        for i in range(n):
            dec.append(result.plan_at(i))
    return dec^


# 回灌强度：由置信度、鲁棒性退化率、扇出降级/失败信号共同决定，落在 (0,1)。
#   base = confidence * (1 - robustness_degradation)
#   扇出 degraded=1 或 ok=0 → 能量折半（信号越不可信，回灌权重越低）。
def reinject_intensity(result: PipelineResult, metrics: Metrics, output: ShifangOutput) -> Float64:
    var base = result.confidence * (1.0 - metrics.robustness_degradation())
    if base < 0.0:
        base = 0.0
    if output.degraded == 1:
        base = base * 0.5
    if output.ok == 0:
        base = base * 0.5
    if base > 1.0:
        base = 1.0
    return base


# 源校验：在接入前拦截非法数据源（相位/置信度越界、扇出计数/状态位非法），
# 返回 False 时不触碰太极状态根，仅记 WARN + AUDIT REINJECT_REJECTED。
def validate_source(result: PipelineResult, output: ShifangOutput, metrics: Metrics) -> Bool:
    if result.phase < 0 or result.phase > 4:
        return False
    if result.confidence < 0.0 or result.confidence > 1.0:
        return False
    if output.action_len < 0 or output.action_len > 10:
        return False
    if output.degraded != 0 and output.degraded != 1:
        return False
    if output.ok != 0 and output.ok != 1:
        return False
    return True


# —— 回灌衔接桥（纯增量；持有目标 FeedbackLoop + 结构化日志缓冲 + 计数）——

struct ReinjectionBridge:
    var loop: FeedbackLoop          # 目标太极回灌闭环（复用既有入口，不改动）
    var ledger: TraceLedger         # 跨进程持久化 ledger（回灌落库与溯源以 lineage_id 串联）
    var logs: List[String]          # 结构化日志缓冲（便于排查）
    var injected: Int               # 成功回灌次数
    var rejected: Int               # 源校验拒绝次数
    var errors: Int                 # 回灌过程异常次数
    var last_status: Int            # 末次状态: 1 成功 / 0 拒绝 / -1 异常

    def __init__(out self, intent_hash: Int, energy_budget: Float64, feedback_threshold: Float64) raises:
        self.loop = FeedbackLoop(intent_hash, energy_budget, feedback_threshold)
        self.ledger = TraceLedger()
        self.logs = List[String]()
        self.injected = 0
        self.rejected = 0
        self.errors = 0
        self.last_status = 0

    # 结构化日志（List.append 在本题构建为 raises，由调用方 try 兜住）。
    def _log(mut self, level: Int, module: String, msg: String) raises:
        self.logs.append(log_line(level, module, msg))

    # 回灌前登记溯源，返回 lineage_id：后续回灌落库记录以同一 id 串联（见 reinject_safe）。
    # 调用方：var lid = bridge.begin_lineage(tracer, result); bridge.reinject_safe(..., lid)
    def begin_lineage(mut self, tracer: Tracer, result: PipelineResult) -> Int:
        return self.ledger.record_trace(tracer, result)

    def log_count(self) -> Int:
        return len(self.logs)

    def log_at(self, i: Int) -> String:
        if i < 0 or i >= len(self.logs):
            return ""
        return self.logs[i]

    def summary(self) -> String:
        var s = String("[reinjection] injected=")
        s = s + String(self.injected)
        s = s + " rejected=" + String(self.rejected)
        s = s + " errors=" + String(self.errors)
        s = s + " last_status=" + String(self.last_status)
        s = s + " logs=" + String(len(self.logs))
        return s^

    # 跨进程持久化：把 ledger(JSON-Lines, 含 trace↔backfill 以 lineage_id 串联)写到文件，
    # 供下游进程（如 store_reader / 审计系统）消费，实现回灌结果与溯源链路的可追踪串联。
    def persist_ledger(mut self, path: String) raises:
        var f = FileHandle(path, "w")
        f.write(self.ledger.to_jsonl())
        f.close()

    # 跨运行累积：以追加模式把本轮 ledger(JSON-Lines) 接到既有文件末尾，
    # 使多次 e2e 运行的血缘记录汇聚为阶段 B 蒸馏的统一训练数据源（避免 "w" 覆盖）。
    def append_ledger(mut self, path: String) raises:
        var f = FileHandle(path, "a")
        f.write(self.ledger.to_jsonl())
        f.close()

    # 主衔接（安全，永不 raises）：校验 → 回灌 → 异常隔离。
    # 返回 True=成功回灌；False=被拒绝或异常（均已记日志，不影响调用方/既有闭环）。
    # lineage_id>0 时，把本次回灌落库记录以同一 lineage_id 写入 ledger，与 begin_lineage
    #   登记的溯源记录串联（跨进程持久化链路：同一 lineage 下既有 trace 也有 backfill）。
    def reinject_safe(mut self, result: PipelineResult, output: ShifangOutput,
                      tracer: Tracer, metrics: Metrics, input_text: String,
                      lineage_id: Int = 0) -> Bool:
        var conf_milli = Int(result.confidence * 1000.0)
        try:
            if not validate_source(result, output, metrics):
                self.rejected = self.rejected + 1
                self.last_status = 0
                self._log(LOG_WARN, "taiji.reinjection",
                          "source validation FAILED (phase=" + String(result.phase)
                          + " conf=" + String(Int(result.confidence * 100.0)) + "%) -> skip")
                self._log(LOG_AUDIT, "taiji.reinjection",
                          "REINJECT_REJECTED policy=" + String(result.policy_id))
                if lineage_id > 0:
                    self.ledger.record_backfill(lineage_id, 0, output.ok, output.degraded,
                                                conf_milli, result.policy_id, 0)
                return False
            self._reinject(result, output, tracer, metrics, input_text, lineage_id)
            self.injected = self.injected + 1
            self.last_status = 1
            if lineage_id > 0:
                self.ledger.record_backfill(lineage_id, 1, output.ok, output.degraded,
                                            conf_milli, result.policy_id, 0)
            return True
        except e:
            self.errors = self.errors + 1
            self.last_status = -1
            try:
                self._log(LOG_ERROR, "taiji.reinjection", "reinject FAILED (policy=" + String(result.policy_id) + ")")
                self._log(LOG_AUDIT, "taiji.reinjection", "REINJECT_DENIED policy=" + String(result.policy_id))
            except:
                pass
            if lineage_id > 0:
                self.ledger.record_backfill(lineage_id, -1, 0, 1, 0, result.policy_id, 0)
            return False

    # 实际回灌（raises，由 reinject_safe 的 try 兜住）：映射字段 → 接入 FeedbackLoop → 巩固门控。
    def _reinject(mut self, result: PipelineResult, output: ShifangOutput,
                  tracer: Tracer, metrics: Metrics, input_text: String,
                  lineage_id: Int) raises:
        # 提取标量(读字段不消费结构体)
        var phase = result.phase
        var conf_milli = Int(result.confidence * 1000.0)
        var plan_len = result.plan_len
        var span_len = tracer.span_len
        var degraded = output.degraded
        var policy = result.policy_id

        # 关联键落库：把本次回灌的 lineage_id 写入太极长期记忆根，
        # 使 taiji_state.json 侧车与 ledger jsonl 可经 lineage_id 跨进程 join。
        if lineage_id > 0:
            self.loop.state.last_lineage = lineage_id


        # 溯源审计：消费 observability 数据源——比对 tracer 决策链覆盖度与 result 规划链。
        self._log(LOG_INFO, "taiji.reinjection",
                  "recv phase=" + String(phase) + " conf=" + String(conf_milli) + "%"
                  + " plan_len=" + String(plan_len) + " spans=" + String(span_len)
                  + " degraded=" + String(degraded) + " ok=" + String(output.ok))
        if plan_len > 0 and span_len < plan_len:
            self._log(LOG_WARN, "taiji.reinjection",
                      "lineage gap: tracer spans=" + String(span_len)
                      + " < plan_len=" + String(plan_len))

        # 字段映射（各 helper 按值接收；result/output/metrics 因后续仍被读取而自动借入，不消费）
        var out_text = reinject_output(result, output, input_text)
        var dec = reinject_decision(result)
        var intensity = reinject_intensity(result, metrics, output)

        # 接入太极现有回灌入口（TaijiState.feedback 经 FeedbackLoop 封装，未做任何改动）
        self.loop.feedback(out_text, dec, phase, intensity)

        # 巩固门控：复用既有 should_consolidate，不重复实现巩固逻辑
        if self.loop.should_consolidate():
            self._log(LOG_INFO, "taiji.reinjection", "energy threshold reached, consolidation eligible")

        self._log(LOG_AUDIT, "taiji.reinjection",
                  "REINJECT_OK round=" + String(self.loop.state.round)
                  + " policy=" + String(policy))
