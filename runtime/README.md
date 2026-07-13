# `runtime/` — 运行时（生命周期 / 内存 / 并发）【v1.4 已落地 ✅】

> 运行时的职责是**薄守护层**：对象生命周期、内存预算、并发/超时约束。它不实现业务逻辑，只保证执行层（shifang）在 **RUNNING 且健康**时才扇出，且扇出规模受内存预算约束——与"执行器崩溃不影响状态根（taiji）"的故障隔离原则一致。

## 一、子模块
- **`lifecycle.mojo`** — `RuntimeState` 状态机 `INIT→RUNNING→PAUSED→STOPPED`；`start/pause/resume/stop/tick/record_error`；`is_healthy`（RUNNING 且错误未超阈值）、`can_execute`（仅 RUNNING+健康可扇出）。
- **`memory.mojo`** — `MemoryBudget` 预算字节 + 已用；`alloc`（超预算 `raises` → 调用方降级为局部执行）、`free`、`available`、`utilization`（0.0..1.0，零预算防除零=1.0）。
- **`concurrency.mojo`** — `TaskSlot` 固定容量并发槽池（`acquire/release/can_accept`，非阻塞、满即拒）；`TimeoutGuard` 以 `deadline/elapsed` 建模非阻塞超时，`with_timeout` 超时返回降级标记（不阻塞状态根）。**确定性模型，非 OS 线程**。
- **回灌健康度 + 超时门控（v1.4 · 需求 ③）** — `RuntimeState` 新增 `record_backfill(success, latency_ms)` + `backfill_success_rate` + `backfill_avg_latency`，并把回灌成功率纳入 `is_healthy`（样本≥4 且成功率<50% → 不健康，经 `can_execute` 一并生效）；新增 `BackfillGate(预算ms)`：结合 runtime 健康度与单次回灌耗时预算判定是否放行，连续违规超上限→门控熔断（`tripped`），不阻塞状态根。

## 二、接口骨架（函数签名 · 参数类型 · 返回值）
```mojo
# runtime/lifecycle.mojo
comptime RT_INIT=0; RT_RUNNING=1; RT_PAUSED=2; RT_STOPPED=3
def runtime_state_name(id) -> String
struct RuntimeState(Movable):
    var state: Int; var uptime_ticks: Int; var error_count: Int; var max_errors: Int
    var backfill_total, backfill_ok, backfill_errors: Int
    var backfill_latency_sum, backfill_latency_samples: Int
    def start(mut self); def pause(mut self); def resume(mut self); def stop(mut self)
    def tick(mut self); def record_error(mut self)
    def record_backfill(mut self, success: Int, latency_ms: Int)
    def backfill_success_rate(self) -> Float64
    def backfill_avg_latency(self) -> Int
    def is_healthy(self) -> Int; def can_execute(self) -> Int
# 回灌超时门控
struct BackfillGate(Movable):
    var budget_ms, violations, max_violations: Int
    def __init__(out self, budget_ms: Int)
    def allow(mut self, rt: RuntimeState, last_latency_ms: Int) -> Int   # 1 放行 / 0 降级
    def tripped(self) -> Int                                              # 连续违规超上限→1
# runtime/memory.mojo
struct MemoryBudget(Movable):
    var budget: Int; var used: Int
    def __init__(out self, budget: Int)
    def alloc(mut self, size: Int) raises
    def free(mut self, size: Int)
    def available(self) -> Int; def utilization(self) -> Float64
# runtime/concurrency.mojo
struct TaskSlot(Movable):
    var capacity: Int; var in_flight: Int
    def acquire(mut self) -> Int; def release(mut self); def can_accept(self) -> Int
struct TimeoutGuard(Movable):
    var deadline: Int; var elapsed: Int
    def tick(mut self, dt: Int); def expired(self) -> Int; def with_timeout(mut self, dt: Int) -> Int
```

## 三、调用示例（守护 shifang 扇出 + 回灌门控）
```mojo
from runtime import RuntimeState, MemoryBudget, TaskSlot, BackfillGate
from shifang import Connector, fanout

var rt = RuntimeState(); rt.start()
var mb = MemoryBudget(4096)
var slot = TaskSlot(8)
var gate = BackfillGate(20)            # 单次回灌预算 20ms
if rt.can_execute() == 1 and slot.acquire() == 1:
    try:
        mb.alloc(256)                 # 受预算约束
        var out = fanout(res, conn)   # 仅 RUNNING 时执行
    except:
        rt.record_error()             # 超预算 → 降级 + 记错误
    slot.release(); mb.free(256)
# 回灌闭环：每次回灌后回报健康度 + 门控
if gate.allow(rt, last_latency_ms) == 1:
    var ok = bridge.reinject_safe(...)   # 放行
    rt.record_backfill((1 if ok else 0), last_latency_ms)
else:
    rt.record_backfill(0, last_latency_ms)   # 超时/不健康 → 降级记录
```

## 四、实现状态（v1.4 · 零桩函数 TDD 全绿）
`lifecycle.mojo` + `memory.mojo` + `concurrency.mojo` 三文件 + 回灌健康度/门控扩展。**67 用例全绿**；基准 lifecycle≈0（sub-ns）/ memory≈2 / concurrency≈4 / backfill≈4 ns/op（极轻量薄守护层）。详见 `docs/phase5-execution-design.md` 与 `docs/architecture-modular-plan.md` §4.13。
