# === taiji/api.mojo ===
# 对外入口（规划 §4.1.1 边界：taiji 仅暴露 run_cycle 与 Persistence 对外）。
# 注：CycleResult 含 String/List 非 Movable, 故以 mut 参数回填, 不以值返回（与 runtime.integration 同口径）。

from taiji.cycle import CognitiveCycle, CycleConfig, CycleResult


def run_cycle(text: String, cfg: CycleConfig, mut result: CycleResult) raises:
    # 端到端: 文本 + 配置 → 闭环结果（recall→plan→execute→feedback + 持久化）。
    # 内部复用 CognitiveCycle（真实 wuxing 规划 + shifang 执行 + ReinjectionBridge 回灌）。
    var c = CognitiveCycle(cfg)
    var r = c.run(text)
    result.output_text = r.output_text
    result.decision = List[Int]()
    for i in range(len(r.decision)):
        result.decision.append(r.decision[i])
    result.phase = r.phase
    result.intensity = r.intensity
    result.round = r.round
