# Phase 5 执行层设计规格 · shifang / runtime / observability（v1.2）

> 配套 `docs/architecture-modular-plan.md` §4.10 / §4.13 / §4.14。本文件锁定 **接口契约、I/O、错误处理、跨模块依赖**，作为 TDD 落地依据。
> 语言：Mojo 1.0.0b2。硬约束（来自 skill `mojo-modular-tdd`，已实证）：不用 `let`/`fn`/`alias`/`inout`/`bitcast`/`String.strip`/`String.contains`/`List[Int](...)` 构造；用 `var`/`def`/`comptime`/`mut`/`Dual.from_parts`；`struct(Movable)` 字段须标量（含 `List` 字段即非 Movable → 不可按值返回，改用固定标量槽或 `mut self` 原地构建/渲染）。

---

## 0. 当前进度（落地前）

| 模块 | 规划状态 | MVP 遗留 | 本轮目标 |
|---|---|---|---|
| `shifang` | §4.10 占位 + `src/executor.mojo`（trigram→文本桩，无连接器） | 仅占位模板，无真实模型/API | ✅ TDD 落地：十方扇出 + 真实连接器协议（含熔断/重试/降级）+ 让架构"能说话" |
| `runtime` | §4.13 占位（无代码） | 无 | ✅ TDD 落地：生命周期状态机 + 内存预算 + 并发/超时模型 |
| `observability` | §4.14 占位 + `src/emoji.mojo`（EmojiGraph 渲染桩） | 仅 emoji 渲染，无指标/追踪/审计 | ✅ TDD 落地：metrics + tracing（强制决策溯源）+ explain + render + logging/audit |

三者此前均属"待 TDD"——仅有规划占位与 MVP 桩，本轮按既定范式（零桩函数、红→绿→重构、基准、README、文档同步）逐一落地。

---

## 1. 跨模块接口契约（已锁定、一致）

```
                         ┌──────────── PipelineResult (phase/intensity/plan/confidence/policy_id/ok/failed_stage)
                         │
  shifang.fanout(result, connector) ──► ShifangOutput(十方 action 码 + ok + degraded + latency)
                         │                         │
                         │                         └─► connector.dispatch(prompt, result, timeout, mut resp): ConnectorResponse(text)
                         │
  observability 采集侧：metrics.record / tracing.decision_lineage(result, output, resp) / explain.explain_decision / render.render_summary / logging.audit
                         │
  runtime 守护侧：lifecycle（RUNNING 门控执行）/ memory（预算约束扇出规模）/ concurrency（TaskSlot 限并发 + TimeoutGuard 非阻塞）
```

- **载体约定**：可 Movable 的载体（含 `String` 之外的字段）一律**固定标量槽**；含 `String` 的载体（`ConnectorResponse`、`ShifangOutput` 不含 String 故 Movable）用 **`mut self` 原地写 / `mut resp` 传出**，绝不以值返回含 `String` 的 struct。
- **错误处理**：子模块 `raises` 透传（调用方决定重试/静默）；连接器层 **熔断 + 重试 + 降级**（`ok=0`/`degraded=1` 不崩溃）；全链路确定性（无随机），故障隔离不影响 `taiji` 状态根。
- **真实 API 接入点（诚实标注）**：Mojo 1.0.0b2 **无内置 HTTP 客户端**。连接器协议以 `call_external(prompt) raises -> String` 为唯一真实接入缝——当前返回**确定性模板化流式响应**（离线可测），并在该函数内以注释明确标注如何替换为：①`@extern` 链接 libcurl C shim；②`subprocess` 调用 Python/本地 sidecar；③未来 Mojo `net` 模块。测试不依赖网络。

---

## 2. `shifang/` — 十方执行扇出 + 真实连接器

### 2.1 核心调度逻辑
- **消费**：`PipelineResult.plan`（七星定序后的有序元素链，0..4 = 木火土金水）。
- **十方扇出**：把规划链"周遍"到十个方向（东/南/西/北/东南/西南/东北/西北/上/下）。映射：`direction = (element * 2 + step_index) % 10`，每方向记录一个 **action 码**（取元素本身，或元素+方向派生，见 `action_code`）。
- **让架构说话**：以 `plan + phase + intensity + confidence + policy_id` 构造自然语言 prompt，经连接器生成**可读回复**（如"依据五行调度（主导：木，优势度 0.42），规划链 木→火→土 已扇出十方…"），即架构首次"能说话"。

### 2.2 接口定义
```mojo
# shifang/protocol.mojo
comptime CONNECTOR_LOCAL=0; CONNECTOR_LLM=1
comptime DIR_EAST=0; DIR_SOUTH=1; DIR_WEST=2; DIR_NORTH=3; DIR_SE=4; DIR_SW=5; DIR_NE=6; DIR_NW=7; DIR_UP=8; DIR_DOWN=9; DIR_COUNT=10
def direction_name(id) -> String
struct ConnectorResponse:              # 含 String → 非 Movable, 用 mut resp 传出
    var text: String; var ok: Int; var degraded: Int
    var latency_ms: Int; var attempt: Int
    def __init__(out self)
struct Connector(Movable):             # 熔断/重试状态机
    var kind: Int; var fail_count: Int; var cb_open: Int; var last_latency: Int
    def __init__(out self, kind: Int)
    def dispatch(mut self, prompt: String, result: PipelineResult, timeout_ms: Int, mut resp: ConnectorResponse) raises
    def with_retry(mut self, prompt: String, result: PipelineResult, timeout_ms: Int, max_retries: Int, mut resp: ConnectorResponse)
def call_external(prompt: String) raises -> String   # ★ 真实 API 接入缝（当前离线模板化）

# shifang/dispatch.mojo
struct ShifangOutput(Movable):         # 固定标量槽: action0..action9 + action_len + ok + degraded + latency_ms
    def append_action(mut self, code: Int)
    def action_at(self, i: Int) -> Int
def fanout(result: PipelineResult, mut connector: Connector) raises -> ShifangOutput
def fanout_safe(result: PipelineResult, mut connector: Connector) -> ShifangOutput

# shifang/executor.mojo
def action_label(element: Int) -> String
def execute_plan_to_text(result: PipelineResult, input: String) -> String   # 返回 String(可 Movable), 人类可读动作串
def render_reply(result: PipelineResult, output: ShifangOutput, resp: ConnectorResponse) -> String  # 内部调用, 返回 String
```

---

## 3. `runtime/` — 生命周期 / 内存 / 并发

### 3.1 核心逻辑
- **lifecycle**：`RuntimeState` 状态机 `INIT→RUNNING→PAUSED→STOPPED`；`start/mark_running/pause/resume/stop`；`is_healthy()`（RUNNING 且未超阈值）。执行层（shifang）仅在 `RUNNING` 时扇出。
- **memory**：`MemoryBudget` 预算字节 + 已用；`alloc(size) raises`（超预算 raise → 调用方降级）+ `free(size)` + `utilization() -> Float64`。扇出规模受预算约束。
- **concurrency**：`TaskSlot` 固定容量池 `acquire/release`（确定性限并发模型，非 OS 线程）；`TimeoutGuard` 以 `deadline` 建模非阻塞热路径，`with_timeout` 失败返回降级标记（不阻塞状态根）。

### 3.2 接口定义
```mojo
# runtime/lifecycle.mojo
comptime RT_INIT=0; RT_RUNNING=1; RT_PAUSED=2; RT_STOPPED=3
def runtime_state_name(id) -> String
struct RuntimeState(Movable):
    var state: Int; var uptime_ticks: Int; var error_count: Int
    def start(mut self); def mark_running(mut self); def pause(mut self); def resume(mut self); def stop(mut self)
    def is_healthy(self) -> Int; def can_execute(self) -> Int
    def tick(mut self); def record_error(mut self)
# runtime/memory.mojo
struct MemoryBudget(Movable):
    var budget: Int; var used: Int
    def alloc(mut self, size: Int) raises; def free(mut self, size: Int)
    def utilization(self) -> Float64; def available(self) -> Int
# runtime/concurrency.mojo
struct TaskSlot(Movable):
    var capacity: Int; var in_flight: Int
    def acquire(mut self) -> Int; def release(mut self)
    def can_accept(self) -> Int
struct TimeoutGuard(Movable):
    var deadline: Int; var elapsed: Int
    def tick(mut self, dt: Int); def expired(self) -> Int
    def with_timeout(mut self, dt: Int) -> Int   # 返回 1=在期内, 0=已超时(降级)
```

---

## 4. `observability/` — 指标 / 追踪 / 解释 / 渲染 / 审计

### 4.1 核心逻辑
- **metrics**：`Metrics` 固定槽记录延迟样本（p50/p95/p99 近似：用有序采样窗口）、吞吐计数、五行均衡度（`wuxing.variance`/`is_balanced`）、鲁棒性退化%（degraded 次数/总次数）。`record(latency_ms, ok, degraded)` + `snapshot() -> String`。
- **tracing（强制决策溯源）**：`TraceSpan` 固定槽（trace_id/parent/stage/element/decision_code/confidence/policy_id）；`Tracer` 以 `mut self` 累积（容量上限，非 `List` 嵌套）；`decision_lineage(result, output, resp) -> String` 渲染全链路：五行生克主导 → 规划链 → 十方扇出 → 连接器置信度/策略，满足"不可审计即不部署"。
- **explain**：`explain_decision(result, output, resp) -> String`——内在（符号中间表示：phase/intensity/element）+ 事后（决策链/探针）统一出口。
- **render**：`render_summary(result, output, trace) -> String` + `render_svg(...) -> String`（迁自 `src/emoji.mojo` 的 EmojiGraph 思路，但本层以结构化文本 + 轻量 SVG 字符串产出，不持 `List` 字段故可直接 `-> String`）。
- **logging/audit**：`Logger.log(level, module, msg) -> String` 结构化行；`audit(event)` 合规判定同样留痕（审计覆盖率纳入门禁）。

### 4.2 接口定义
```mojo
# observability/metrics.mojo
struct Metrics(Movable):               # 固定窗口: lat0..lat7 + lat_len + ok_count + degraded_count + throughput
    def record(mut self, latency_ms: Int, ok: Int, degraded: Int)
    def p95(self) -> Int; def throughput(self) -> Int
    def robustness_degradation(self) -> Float64   # degraded/(ok+degraded)
    def snapshot(self) -> String
# observability/tracing.mojo
struct TraceSpan(Movable):             # trace_id/parent/stage/element/decision/confidence(×1000)/policy_id
    var trace_id: Int; var parent: Int; var stage: Int; var element: Int
    var decision: Int; var confidence_milli: Int; var policy_id: Int
struct Tracer(Movable):               # 固定容量 span0..span15 + span_len
    def add_span(mut self, span: TraceSpan)
    def decision_lineage(self, result: PipelineResult, output: ShifangOutput, resp: ConnectorResponse) -> String
    def render_trace(self) -> String
# observability/explain.mojo
def explain_decision(result: PipelineResult, output: ShifangOutput, resp: ConnectorResponse) -> String
# observability/render.mojo
def render_summary(result: PipelineResult, output: ShifangOutput, trace: Tracer) -> String
def render_svg(result: PipelineResult, output: ShifangOutput) -> String
# observability/logging.mojo
comptime LOG_INFO=0; LOG_WARN=1; LOG_ERROR=2; LOG_AUDIT=3
def log_line(level: Int, module: String, msg: String) -> String
def audit(event: String) -> String
```

---

## 5. 错误处理总策略
- 子模块 `raises` 透传；调用方（shifang.fanout / runtime 守护 / observability 采集）决定重试或静默。
- 连接器：`with_retry`（上限 `max_retries`）→ 仍失败则 `degraded=1` 降级回复（不崩溃）；`CircuitBreaker` 连续失败达阈值 → `cb_open`，后续直接降级（防雪崩）。
- 内存：`MemoryBudget.alloc` 超预算 `raises` → 扇出降级为局部执行。
- 全链路故障隔离：任一异常不影响 `taiji` 状态根（回灌由 Phase 5 衔接，本期 `runtime` 提供执行门控）。

## 6. 测试 / 基准 / 文档
- 各模块独立 `tests/test_*.mojo`（TDD 红→绿→重构，≥16 组/模块）。
- 各模块 `benchmarks/bench_*.mojo`（`@extern("clock")` + sink 反馈 + 连续变化种子防 DCE）+ `results_*.json`。
- 各模块 `README.md`（标记【v1.2 已落地 ✅】）。
- 规划文档升至 **v1.2**：§3 表三行、§4.10/§4.13/§4.14 头部 + §4.x.0/§4.x.1、§7/§9 同步。
