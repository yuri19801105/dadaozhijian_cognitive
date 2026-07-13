# runtime/tests/test_runtime.mojo — TDD 测试套件(红→绿→重构)
# 运行: mojo run -I . -I core runtime/tests/test_runtime.mojo
from runtime import (
    RT_INIT, RT_RUNNING, RT_PAUSED, RT_STOPPED, runtime_state_name,
    RuntimeState, MemoryBudget, TaskSlot, TimeoutGuard, BackfillGate, BackfillSupervisor,
)
from taiji.cycle import CognitiveCycle, CycleConfig, CycleResult
from shifang import SIDECAR_TEMPLATE

struct Counter(Movable):
    var passed: Int
    var failed: Int
    def __init__(out self):
        self.passed = 0
        self.failed = 0
    def check(mut self, cond: Bool, name: String):
        if cond:
            self.passed = self.passed + 1
        else:
            self.failed = self.failed + 1
            print("[FAIL] " + name)

def test_state_names(mut c: Counter):
    c.check(runtime_state_name(RT_INIT) == "INIT", "INIT 名")
    c.check(runtime_state_name(RT_RUNNING) == "RUNNING", "RUNNING 名")
    c.check(runtime_state_name(RT_PAUSED) == "PAUSED", "PAUSED 名")
    c.check(runtime_state_name(RT_STOPPED) == "STOPPED", "STOPPED 名")

def test_lifecycle_transitions(mut c: Counter):
    var rt = RuntimeState()
    c.check(rt.state == RT_INIT, "初始 INIT")
    c.check(rt.can_execute() == 0, "INIT 不可执行")
    rt.start()
    c.check(rt.state == RT_RUNNING, "start→RUNNING")
    c.check(rt.can_execute() == 1, "RUNNING 可执行")
    c.check(rt.is_healthy() == 1, "RUNNING 健康")
    rt.pause()
    c.check(rt.state == RT_PAUSED, "pause→PAUSED")
    c.check(rt.can_execute() == 0, "PAUSED 不可执行")
    rt.resume()
    c.check(rt.state == RT_RUNNING, "resume→RUNNING")
    rt.stop()
    c.check(rt.state == RT_STOPPED, "stop→STOPPED")
    c.check(rt.can_execute() == 0, "STOPPED 不可执行")
    # 重启
    rt.start()
    c.check(rt.state == RT_RUNNING, "STOPPED→start→RUNNING")

def test_health_threshold(mut c: Counter):
    var rt = RuntimeState()
    rt.start()
    c.check(rt.is_healthy() == 1, "初始健康")
    for _ in range(6):
        rt.record_error()
    c.check(rt.error_count == 6, "记录 6 错误")
    c.check(rt.is_healthy() == 0, "超阈值→不健康")
    c.check(rt.can_execute() == 0, "不健康→不可执行")

def test_uptime_tick(mut c: Counter):
    var rt = RuntimeState()
    rt.start()
    rt.tick()
    rt.tick()
    rt.tick()
    c.check(rt.uptime_ticks == 3, "tick 累计")

def test_memory_budget(mut c: Counter) raises:
    var mb = MemoryBudget(100)
    c.check(mb.available() == 100, "初始可用 100")
    c.check(mb.utilization() == 0.0, "初始利用率 0")
    mb.alloc(40)
    c.check(mb.used == 40, "分配 40")
    c.check(mb.available() == 60, "可用 60")
    var u = mb.utilization()
    c.check(u > 0.39, "利用率>0.39")
    c.check(u < 0.41, "利用率<0.41")
    # 超预算 → raises
    var raised = False
    try:
        mb.alloc(80)
    except:
        raised = True
    c.check(raised, "超预算 alloc raises")
    mb.free(40)
    c.check(mb.used == 0, "释放后归零")

def test_memory_zero_budget(mut c: Counter):
    var mb = MemoryBudget(0)
    c.check(mb.utilization() == 1.0, "零预算利用率=1.0(防除零)")

def test_task_slot(mut c: Counter):
    var slot = TaskSlot(2)
    c.check(slot.can_accept() == 1, "空槽可接")
    c.check(slot.acquire() == 1, "取槽1")
    c.check(slot.acquire() == 1, "取槽2")
    c.check(slot.in_flight == 2, "在飞=2")
    c.check(slot.acquire() == 0, "满→拒绝(非阻塞)")
    c.check(slot.can_accept() == 0, "满→不可接")
    slot.release()
    c.check(slot.in_flight == 1, "释放后=1")
    c.check(slot.acquire() == 1, "释放后可再取")

def test_timeout_guard(mut c: Counter):
    var g = TimeoutGuard(5)
    c.check(g.expired() == 0, "初始未超时")
    c.check(g.with_timeout(3) == 1, "推进 3 在期内")
    c.check(g.with_timeout(3) == 0, "再推进 3 超时→降级")
    c.check(g.expired() == 1, "确认超时")

def test_backfill_health(mut c: Counter):
    # 健康度纳入回灌：样本不足时成功率不影响；样本足够且成功率<50% → 不健康。
    var rt = RuntimeState()
    rt.start()
    c.check(rt.is_healthy() == 1, "初始健康(无回灌)")
    c.check(rt.backfill_success_rate() == 1.0, "无样本成功率=1.0")
    # 前 3 次全失败：样本不足(<4)，仍健康
    rt.record_backfill(0, 10)
    rt.record_backfill(0, 12)
    rt.record_backfill(0, 9)
    c.check(rt.backfill_success_rate() < 0.5, "成功率<0.5")
    c.check(rt.is_healthy() == 1, "样本<4 仍健康(不误判)")
    # 第 4 次失败 → 样本足够且成功率<50% → 不健康
    rt.record_backfill(0, 11)
    c.check(rt.backfill_total == 4, "回灌样本=4")
    c.check(rt.is_healthy() == 0, "成功率<50%且样本≥4 → 不健康")
    c.check(rt.can_execute() == 0, "回灌不健康→不可执行")
    # 注入成功回灌拉回成功率
    for _ in range(6):
        rt.record_backfill(1, 8)
    c.check(rt.backfill_success_rate() > 0.5, "成功率回升>0.5")
    c.check(rt.is_healthy() == 1, "成功率回升→恢复健康")
    c.check(rt.can_execute() == 1, "恢复→可执行")
    c.check(rt.backfill_avg_latency() > 0, "平均延迟可计算")

def test_backfill_gate(mut c: Counter):
    # 超时门控：runtime 可执行 + 上次耗时未超预算 → 放行；超预算/不健康 → 降级。
    var rt = RuntimeState()
    rt.start()
    var gate = BackfillGate(20)   # 单次回灌预算 20ms
    c.check(gate.allow(rt, 10) == 1, "健康+耗时内→放行")
    c.check(gate.allow(rt, 25) == 0, "耗时超预算→降级(不放行)")
    c.check(gate.tripped() == 0, "单次违规未熔断")
    # runtime 不健康 → 一律不放行
    rt.record_error()
    rt.record_error()
    rt.record_error()
    rt.record_error()
    rt.record_error()
    rt.record_error()
    c.check(rt.is_healthy() == 0, "错误超阈值→不健康")
    c.check(gate.allow(rt, 5) == 0, "不健康→不放行(即使耗时内)")
    # 连续超时违规超过上限 → 门控熔断
    var rt2 = RuntimeState()
    rt2.start()
    var gate2 = BackfillGate(5)
    _ = gate2.allow(rt2, 100)
    _ = gate2.allow(rt2, 100)
    _ = gate2.allow(rt2, 100)
    c.check(gate2.tripped() == 0, "3 次违规=上限, 未熔断")
    _ = gate2.allow(rt2, 100)
    c.check(gate2.tripped() == 1, "超上限→门控熔断")

def test_backfill_supervisor(mut c: Counter) raises:
    # 把回灌闭环接入 runtime 健康度 + 超时门控（需求 ③），并落盘溯源 ledger（需求 ②）。
    var cfg = CycleConfig(1.0, 1e9, 0, False)   # 关闭 taiji 自动快照, 仅验证 supervisor 门控
    var cyc = CognitiveCycle(cfg, SIDECAR_TEMPLATE, 0.5, 8, 3, 5)  # 离线模板侧车, 快速确定
    var sup = BackfillSupervisor("/tmp/taiji_supervisor_ledger.jsonl")
    sup.start()
    c.check(sup.can_execute() == 1, "supervisor 初始可执行")
    var r1 = CycleResult("", List[Int](), 0, 0.0, 0)
    sup.step(cyc, "认知架构的五行调度如何决定任务优先级与资源分配", r1)
    c.check(r1.round == 1, "首步 round=1")
    c.check(sup.backfill_total() == 1, "回灌计数=1")
    c.check(sup.is_healthy() == 1, "回灌健康")
    var r2 = CycleResult("", List[Int](), 0, 0.0, 0)
    sup.step(cyc, "再次回灌测试健康度累计与超时门控", r2)
    c.check(r2.round == 2, "第二轮 round=2")
    c.check(sup.backfill_total() == 2, "回灌计数=2")
    c.check(cyc.bridge.loop.state.last_lineage > 0, "lineage_id 已写入太极状态根(跨进程串联键)")
    # ledger 已跨进程落盘（需求 ②）：文件非空且含 JSON-Lines 记录
    var f = FileHandle("/tmp/taiji_supervisor_ledger.jsonl", "r")
    var content = f.read()
    f.close()
    c.check(content.byte_length() > 0, "ledger 已跨进程落盘")


def main() raises:
    var c = Counter()
    test_state_names(c)
    test_lifecycle_transitions(c)
    test_health_threshold(c)
    test_uptime_tick(c)
    test_memory_budget(c)
    test_memory_zero_budget(c)
    test_task_slot(c)
    test_timeout_guard(c)
    test_backfill_health(c)
    test_backfill_gate(c)
    test_backfill_supervisor(c)
    print("runtime -> passed: " + String(c.passed) + "  failed: " + String(c.failed))
