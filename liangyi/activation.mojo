# === liangyi/activation.mojo ===
# 阴阳激活门 (迁自 core/math 之上): 为 sancai/sixiang/wuxing 提供激活基元。

from .dual import Dual, YIN, YANG
from math.activate import sigmoid


# dual_gate 的返回值载体 (本构建元组返回不可用, 以结构体替代)
struct GatePair(Movable):
    var yin: Float64
    var yang: Float64
    def __init__(out self, y: Float64, g: Float64):
        self.yin = y
        self.yang = g


struct YinYangGate:
    # 阴门: 抑制(低激活) — 由阴分量驱动 gating; 阴越高, 门越低
    @staticmethod
    def yin_gate(x: Dual, bias: Float64 = 0.0) -> Float64:
        return sigmoid(bias - x.yin_part())

    # 阳门: 激发(高激活) — 由阳分量驱动 gating; 阳越高, 门越高
    @staticmethod
    def yang_gate(x: Dual, bias: Float64 = 0.0) -> Float64:
        return sigmoid(x.yang_part() - bias)

    # 阴阳双门: 同时输出 (抑制量, 激发量), 供上层选择
    @staticmethod
    def dual_gate(x: Dual, bias: Float64 = 0.0) -> GatePair:
        var ng = sigmoid(bias - x.yin_part())
        var yg = sigmoid(x.yang_part() - bias)
        return GatePair(ng, yg)

    # 平衡门: 阴阳归一后 sigmoid (相偏置调激活阈值)
    #   ratio = (yang - yin)/(yang + yin) ∈ (-1,1); 平衡时 ratio=0 -> sigmoid(-threshold)
    @staticmethod
    def balance_gate(x: Dual, threshold: Float64 = 0.0) -> Float64:
        var yi = x.yin_part()
        var ya = x.yang_part()
        var s = yi + ya
        if s == 0.0:
            return sigmoid(-threshold)
        var ratio = (ya - yi) / s
        return sigmoid(ratio - threshold)
