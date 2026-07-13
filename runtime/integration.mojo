# === runtime/integration.mojo ===
# 把回灌闭环纳入 runtime 健康度检查与超时门控（需求 ③），并落盘溯源 ledger（需求 ②）。
#
# 定位：runtime 为 L6 横切层，可聚合 taiji(状态根) / pipeline(调度) / shifang(执行) /
#   observability(溯源) 各层，故本文件作为"真实端到端闭环"的统一驱动点。
#
# 门控语义：每次回灌前经 BackfillGate.allow 判定（runtime 可执行 且 上次耗时未超预算）；
#   门控关闭则不执行本次回灌闭环、记一次失败供健康度累计；连续超时违规超上限 → 门控熔断、
#   暂停 runtime 由上层介入（不阻塞状态根）。回灌成败/耗时经 RuntimeState.record_backfill
#   纳入 is_healthy / can_execute。

from taiji.cycle import CognitiveCycle, CycleConfig, CycleResult
from runtime.lifecycle import RuntimeState, BackfillGate
from std.io import FileHandle


struct BackfillSupervisor:
    var rt: RuntimeState
    var gate: BackfillGate
    var ledger_path: String
    var steps: Int

    def __init__(out self, ledger_path: String):
        self.rt = RuntimeState()
        self.gate = BackfillGate(2000)
        self.ledger_path = ledger_path
        self.steps = 0

    def start(mut self):
        self.rt.start()

    # 单步：超时门控放行 → 跑完整认知闭环(含回灌) → 上报健康度 → 落盘 ledger。
    # 门控关闭则不执行回灌闭环, 仅记一次失败并保持上一轮状态（降级, 不崩溃）。
    # 注：CycleResult 含 String/List 非 Movable, 故以 mut 参数回填, 不以值返回。
    def step(mut self, mut cyc: CognitiveCycle, text: String, mut result: CycleResult) raises:
        self.steps = self.steps + 1
        if self.gate.allow(self.rt, cyc.last_backfill_latency) == 0:
            # 门控关闭：记失败供健康度累计, 不执行回灌闭环。
            self.rt.record_backfill(0, cyc.last_backfill_latency)
            if self.gate.tripped():
                self.rt.pause()
            result.output_text = ""
            result.decision = List[Int]()
            result.phase = -1
            result.intensity = 0.0
            result.round = cyc.bridge.loop.state.round
            return
        var r = cyc.run(text)
        # 回灌结果纳入健康度检查（需求 ③）
        self.rt.record_backfill(cyc.last_backfill_ok, cyc.last_backfill_latency)
        if self.gate.tripped():
            self.rt.pause()
        # 跨进程持久化 ledger（需求 ②）
        cyc.persist_ledger(self.ledger_path)
        result.output_text = r.output_text
        result.decision = List[Int]()
        for i in range(len(r.decision)):
            result.decision.append(r.decision[i])
        result.phase = r.phase
        result.intensity = r.intensity
        result.round = r.round

    def is_healthy(self) -> Int:
        return self.rt.is_healthy()

    def can_execute(self) -> Int:
        return self.rt.can_execute()

    def backfill_total(self) -> Int:
        return self.rt.backfill_total
