# === taiji/consolidation.mojo ===
# 巩固/遗忘（防灾难性遗忘, 持续学习横切落地, 迁自规划 §4.1.1 接口骨架）。
# 弹性权重巩固(EWC)思路 Mojo 化: 强化高能量/近期轨迹, 衰减低权重历史。
#
# 实现约束（Mojo 1.0.0b2）:
#   - TaijiState 以 mut 参数就地改写（含 Tensor 不可 Movable, 不按值返回）。

from taiji.taiji_state import TaijiState


struct Consolidation:
    var keep_rate: Float64        # 重要轨迹保留率（配置化, 安全域偏保守）
    var forget_rate: Float64      # 低权重遗忘率（强度衰减系数）

    def __init__(out self, keep_rate: Float64, forget_rate: Float64):
        self.keep_rate = keep_rate
        self.forget_rate = forget_rate

    # 巩固: 保留最近 keep_rate 比例的轨迹, 衰减存活轨迹强度(EWC 思路)
    # 委派至 TaijiState.consolidate_in_place（mut self 字段整体赋值在本构建可用）
    def consolidate(mut self, mut state: TaijiState) raises:
        state.consolidate_in_place(self.keep_rate, self.forget_rate)
