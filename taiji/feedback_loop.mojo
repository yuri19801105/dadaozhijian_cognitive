# === taiji/feedback_loop.mojo ===
# 太极回灌闭环（迁自规划 §4.1.1 接口骨架）。
# 回灌入口: 输出 → 归一能量(sigmoid) → 叠加进 state.energy → 写历史 → 重算 seed → 判定巩固。
#
# 实现约束（Mojo 1.0.0b2，本构建已验证）:
#   - sigmoid 位于 core.math.activate（非 core.math.ops）。
#   - TaijiState 含 Tensor(不可 Movable)，但以字段按值持有（本构建允许字段按值赋值/拷贝）。

from taiji.taiji_state import TaijiState
from math.activate import sigmoid


struct FeedbackLoop:
    var state: TaijiState
    var energy_budget: Float64        # 每轮能量预算（配置化）
    var feedback_threshold: Float64   # 巩固触发阈值（累计能量 ≥ 阈值）

    def __init__(out self, intent_hash: Int, energy_budget: Float64, feedback_threshold: Float64) raises:
        self.state = TaijiState(intent_hash)
        self.energy_budget = energy_budget
        self.feedback_threshold = feedback_threshold

    # 回灌入口: 输出 → 归一能量 → 叠加进 state.energy → 写历史 → 重算 seed → 判定 consolidate
    def feedback(mut self, output: String, decision: List[Int], phase: Int, raw_intensity: Float64) raises:
        # 能量归一: sigmoid(raw / (budget+eps)) ∈ (0,1)，保证有界、可累积
        var norm = sigmoid(raw_intensity / (self.energy_budget + 1e-9))
        self.state.feedback(output, decision, phase, norm)

    # 注入: 下一轮派生输入（记忆上下文）
    def recall(self) -> String:
        return self.state.recall()

    # 回灌触发条件判定（巩固）: 累计能量 ≥ 阈值
    def should_consolidate(self) -> Bool:
        var ed = self.state.energy.to_list()
        var total = 0.0
        for i in range(len(ed)):
            total += ed[i]
        return total >= self.feedback_threshold
