# runtime/lifecycle.mojo — 运行时生命周期状态机 + 健康检查
# 状态: INIT → RUNNING → PAUSED → STOPPED。执行层(shifang)仅 RUNNING 时扇出。
# 运行: mojo run -I . -I core runtime/lifecycle.mojo
comptime RT_INIT: Int = 0
comptime RT_RUNNING: Int = 1
comptime RT_PAUSED: Int = 2
comptime RT_STOPPED: Int = 3

def runtime_state_name(id: Int) -> String:
    if id == RT_INIT: return "INIT"
    if id == RT_RUNNING: return "RUNNING"
    if id == RT_PAUSED: return "PAUSED"
    if id == RT_STOPPED: return "STOPPED"
    return "?"

struct RuntimeState(Movable):
    var state: Int
    var uptime_ticks: Int
    var error_count: Int
    var max_errors: Int          # 健康阈值(超过则 is_healthy=0)
    # —— 回灌健康度信号（需求 ③：把回灌流程纳入健康度检查）——
    var backfill_total: Int
    var backfill_ok: Int
    var backfill_errors: Int
    var backfill_latency_sum: Int
    var backfill_latency_samples: Int
    def __init__(out self):
        self.state = RT_INIT
        self.uptime_ticks = 0
        self.error_count = 0
        self.max_errors = 5
        self.backfill_total = 0
        self.backfill_ok = 0
        self.backfill_errors = 0
        self.backfill_latency_sum = 0
        self.backfill_latency_samples = 0
    def start(mut self):
        # INIT/PAUSED/STOPPED 均可启动为 RUNNING。
        self.state = RT_RUNNING
    def mark_running(mut self):
        self.state = RT_RUNNING
    def pause(mut self):
        if self.state == RT_RUNNING:
            self.state = RT_PAUSED
    def resume(mut self):
        if self.state == RT_PAUSED:
            self.state = RT_RUNNING
    def stop(mut self):
        self.state = RT_STOPPED
    def tick(mut self):
        self.uptime_ticks = self.uptime_ticks + 1
    def record_error(mut self):
        self.error_count = self.error_count + 1
    # 回灌门控信号：记录一次回灌结果（成功/失败 + 耗时），纳入健康度与超时门控。
    def record_backfill(mut self, success: Int, latency_ms: Int):
        self.backfill_total = self.backfill_total + 1
        if success == 1:
            self.backfill_ok = self.backfill_ok + 1
        else:
            self.backfill_errors = self.backfill_errors + 1
        self.backfill_latency_sum = self.backfill_latency_sum + latency_ms
        self.backfill_latency_samples = self.backfill_latency_samples + 1
    def backfill_success_rate(self) -> Float64:
        if self.backfill_total == 0:
            return 1.0
        return Float64(self.backfill_ok) / Float64(self.backfill_total)
    def backfill_avg_latency(self) -> Int:
        if self.backfill_latency_samples == 0:
            return 0
        return self.backfill_latency_sum / self.backfill_latency_samples
    def is_healthy(self) -> Int:
        # RUNNING 且错误未超阈值 → 健康。
        if self.state != RT_RUNNING:
            return 0
        if self.error_count > self.max_errors:
            return 0
        # 回灌纳入健康度：样本足够(>=4)且成功率<50% → 不健康（回灌持续失败即降级）。
        if self.backfill_total >= 4 and self.backfill_success_rate() < 0.5:
            return 0
        return 1
    def can_execute(self) -> Int:
        # 仅 RUNNING 且健康可扇出（回灌健康度经 is_healthy 一并纳入）。
        if self.state == RT_RUNNING and self.is_healthy() == 1:
            return 1
        return 0


# 回灌超时门控（需求 ③）：结合 runtime 健康度 + 单次回灌耗时预算，决定是否放行回灌。
# runtime 不健康或上次回灌耗时超预算 → 降级（返回 0，不执行/跳过），不阻塞状态根；
# 连续违规超过上限 → 门控熔断（tripped），由上层介入而非无限重试。
struct BackfillGate(Movable):
    var budget_ms: Int          # 单次回灌耗时预算(ms)
    var violations: Int         # 超时/拒放次数
    var max_violations: Int     # 连续违规上限(超过则门控熔断)
    def __init__(out self, budget_ms: Int):
        self.budget_ms = budget_ms
        self.violations = 0
        self.max_violations = 3
    # 判定本次回灌是否放行: runtime 可执行 + 上次耗时未超预算。
    def allow(mut self, rt: RuntimeState, last_latency_ms: Int) -> Int:
        if rt.can_execute() == 0:
            return 0
        if last_latency_ms > self.budget_ms:
            self.violations = self.violations + 1
            return 0
        return 1
    def tripped(self) -> Int:
        if self.violations > self.max_violations:
            return 1
        return 0
