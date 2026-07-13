# `observability/` — 可观测层（指标 / 强制溯源 / 内在解释 / 渲染 / 审计）【v1.4 已落地 ✅】

> 大道至简之"可观测"：让每一步决策**可被度量、可被溯源、可被解释、可被审计**。
> 本层是 Phase 5 执行层的"黑匣子"——不改动 `taiji` 状态根，只对外提供**决策可信度证据**。

## 一、职责与边界
- **消费**：`pipeline.PipelineResult`（相位/强度/规划链/置信度/策略 id）、`shifang.ShifangOutput`（十方扇出结果）、`shifang.ConnectorResponse`（连接器文本）。
- **产出**：指标快照、全链路 trace、内在解释文本、执行摘要、SVG、结构化日志 + 审计行。
- **不侵入**：所有接口均为纯函数 / `(TrivialRegisterPassable)` 或 `(Movable)` 结构体，**绝不持有 `taiji` 可变状态**，可独立测试、独立审查。

## 二、五大子能力
| 子模块 | 文件 | 关键能力 |
|---|---|---|
| 指标 | `metrics.mojo` | 延迟滑动窗(容量 8) + p50/p95 + 吞吐 + 五行均衡度方差 + 鲁棒性退化% |
| 追踪 | `tracing.mojo` | 16 槽固定容量 `TraceSpan`，`add_decision_spans` 把规划链逐点固化为溯源 span，`decision_lineage` 输出相位→规划链→十方扇出全链路 |
| 解释 | `explain.mojo` | `explain_decision` 生成"内在可解释"文本（决策依据/策略/置信度，不依赖外部黑盒） |
| 渲染 | `render.mojo` | `render_summary` 文本摘要 + `render_svg` 轻量 SVG（相位节点→规划链流→十方向点亮） |
| 日志 | `logging.mojo` | `log_line(INFO/WARN/ERROR)` + `audit()` 合规判定强制留痕 |

## 三、接口骨架（函数签名 · 参数类型 · 返回值）
```mojo
# observability/metrics.mojo
struct Metrics(Movable):                     # 延迟窗 8 样本 + 计数 + 吞吐 + 五行方差
    def record(mut self, latency_ms: Int, ok: Int, degraded: Int)
    def p95(self) -> Int
    def p50(self) -> Int
    def robustness_degradation(self) -> Float64
    def set_balance(self, energies: List[Float64])
    def snapshot(self) -> String

# observability/tracing.mojo
struct TraceSpan(TrivialRegisterPassable):   # 全 Int 字段 → 隐式可拷贝(按值返回/传参)
    var trace_id, parent, stage, element, decision, confidence_milli, policy_id: Int
struct Tracer(TrivialRegisterPassable):     # 16 固定槽(非 List 嵌套)
    var s0..s15: TraceSpan; var span_len: Int
    def add_decision_spans(mut self, result: PipelineResult)
    def render_trace(self) -> String
    def decision_lineage(self, result: PipelineResult, output: ShifangOutput) -> String

# observability/explain.mojo
def explain_decision(result: PipelineResult, output: ShifangOutput, resp_text: String) -> String

# observability/render.mojo
def render_summary(result: PipelineResult, output: ShifangOutput, trace: Tracer) -> String
def render_svg(result: PipelineResult, output: ShifangOutput) -> String

# observability/logging.mojo
comptime LOG_INFO=0; LOG_WARN=1; LOG_ERROR=2; LOG_AUDIT=3
def log_line(level: Int, module: String, msg: String) -> String
def audit(event: String) -> String
```

## 四、关键设计决策（踩坑沉淀）
1. **标量结构体必须显式标 `TrivialRegisterPassable` 才能按值返回/传参**：Mojo 1.0.0b2 中 `struct X:` 与 `struct X(Movable):` 都**不会**隐式可拷贝（`a2 = a` 报 `cannot be implicitly copied`）；旧式 `@register_passable("trivial")` 装饰器已移除，改为 conform `TrivialRegisterPassable` trait。`TraceSpan` / `Tracer` 全 Int 字段，标此 trait 后 `_span_at` 按值返回、`render_summary(trace: Tracer)` 按值传参均成立。
2. **`ConnectorResponse` 含 `String` → 非 Movable**：不可按值传参。`decision_lineage` 的 ok/degraded 已固化于 `ShifangOutput`，故签名**不接收** `ConnectorResponse`，彻底规避非 Movable 传参坑。
3. **指标窗口用 8 个固定标量槽 + `lat_len`**，而非 `List[Int]` 字段——保留 `Metrics(Movable)` 可按值返回/传参能力；统计时临时 `List` 仅在栈内构造并返回。
4. **渲染开销集中、不进热路径**：`explain/render` 的 ns/op（~9.5μs）主要来自字符串拼装，与"决策可解释"价值匹配；`taiji` 状态根热路径完全不触碰观测层。

## 五、基准（见 `benchmarks/results_observability.json`）
| 指标 | ns/op |
|---|---|
| metrics record+p95 | 39 |
| tracer span 固化+渲染 | 2269 |
| explain+summary+svg | 9552 |

运行：`.venv/bin/mojo run -I . -I core observability/benchmarks/bench_observability.mojo`

## 六、测试
`observability/tests/test_observability.mojo` — 21 断言全绿（指标/追踪/溯源/解释/渲染/日志分级）。
运行：`.venv/bin/mojo run -I . -I core observability/tests/test_observability.mojo`

## 七、跨进程持久化 ledger（store.mojo · v1.3 ✅）
> 需求 ②：把"回灌结果"与"observability 溯源链路"以 `lineage_id` 跨进程串联，确保数据可追踪。

**真实约束（Mojo 1.0.0b2）**：本构建**无原生文件/HTTP/子进程 API**；`@extern` 的 `fclose`/`fflush` 被 FFI 判为非法，`system()` 的字符串传递不可靠。因此"跨进程"经由**可靠的 stdout 管道**实现：Mojo 侧把 ledger 序列化为 JSON-Lines（`to_jsonl()`）字符串，由下游进程（如 `store_reader.py`）从 stdin 消费——这是本构建下唯一可靠的持久化/跨进程通道。

**接口骨架**：
```mojo
# observability/store.mojo
comptime REC_TRACE=0; REC_BACKFILL=1
struct TraceRecord(TrivialRegisterPassable):   # 纯标量 → 可拷贝 + Movable(可入 List)
    var kind, lineage_id, phase, policy_id: Int
    var plan0..plan7, plan_len, span_len: Int
    var conf_milli, ok, degraded, status, latency_ms: Int
struct TraceLedger(Movable):                    # 追加式内存 ledger, 导出 JSON-Lines
    def record_trace(mut self, t: Tracer, r: PipelineResult) -> Int   # 返回 lineage_id
    def record_backfill(mut self, lineage_id, status, ok, degraded, conf_milli, policy_id, latency_ms)
    def count_kind(self, lineage_id, kind) -> Int
    def backfill_status(self, lineage_id) -> Int
    def backfill_latency(self, lineage_id) -> Int
    def backfill_conf(self, lineage_id) -> Int
    def to_jsonl(self) -> String                # 跨进程消费格式(key 顺序稳定)
    def emit(self)                              # 直接 print JSON-Lines 供下游 stdin 消费
```

**与 taiji 回灌衔接的串联**：`taiji.ReinjectionBridge` 持有 `TraceLedger`，调用方在回灌前 `begin_lineage(tracer, result)` 登记溯源并取得 `lineage_id`，再以 `reinject_safe(..., lineage_id)` 落库回灌——同一 `lineage_id` 下既有 `REC_TRACE` 也有 `REC_BACKFILL` 记录。

**跨进程校验**：
```bash
mojo run -I . -I core observability/store_demo.mojo | python3 observability/store_reader.py
```
`store_reader.py` 按 `lineage_id` 分组，断言每个 lineage 同时存在 trace 与 backfill → 串联成立。

**基准**（见 `benchmarks/results_store.json`）：`trace+backfill+jsonl` ≈ 4816 ns/op（开销主要来自 JSON 序列化，内存态追加 O(1)，不进 taiji 热路径）。
测试：`observability/tests/test_store.mojo`（18 断言全绿）。
