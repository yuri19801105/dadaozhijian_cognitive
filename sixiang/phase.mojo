# === sixiang/phase.mojo ===
# 四相状态机: 老少阴阳流转(老阴 -> 少阳 -> 老阳 -> 少阴 -> 老阴)。
#
# 对 liangyi 调用契约(§4.4.0):
#   - 判相: Polarity.classify(d) (-1/0/1) 粗分阴阳
#   - 相位翻转与插值: Polarity.invert / Polarity.compose(在 QuadrantClassifier.canonical 内)
#   - 流转强度门控: YinYangGate.dual_gate(d, bias) 给出阴阳双门, 取 yang 门调制能量流强
#
# 设计注(Mojo 1.0.0b2): Dual 为 Movable, 可作 PhaseMachine 字段; 跨步流转用 mut self 就地改写。

from liangyi.dual import Dual
from liangyi.polarity import Polarity
from liangyi.activation import YinYangGate, GatePair
from .quadrant import Quadrant, QuadrantClassifier, OLD_YIN, YOUNG_YANG, OLD_YANG, YOUNG_YIN, QUADRANT_COUNT


struct PhaseMachine:
    var current: Dual       # 当前阴阳态
    var rounds: Int         # 已流转轮次

    def __init__(out self, start: Dual):
        self.current = Dual.from_parts(start.yin_part(), start.yang_part())
        self.rounds = 0

    # 当前所处象限(输出契约: Quadrant; 非法输入经 from_dual 降级)
    def current_quadrant(self) -> Quadrant:
        return QuadrantClassifier.from_dual(self.current)

    # 当前象限索引(非严格, 不抛错)
    def current_index(self) -> Int:
        return QuadrantClassifier.safe_index(self.current)

    # 流转一步到下一象(严格: 非法/NaN/平衡 抛 Error)。
    # 用 Polarity.classify 判当前相, canonical 构造下一象(其内部 invert/compose 翻转插值),
    # 用 YinYangGate.dual_gate 的 yang 门调制流转强度(能量守恒: 幅度守恒, 门控只调流强)。
    def advance(mut self) raises:
        var idx = QuadrantClassifier.classify(self.current)   # raises on NaN/平衡
        var nq = (idx + 1) % QUADRANT_COUNT
        var m = QuadrantClassifier.magnitude(self.current)
        var gate = YinYangGate.dual_gate(self.current, 0.0)   # 流转强度门控(contract)
        var strength = m * (0.4 + 0.6 * gate.yang)
        self.current = QuadrantClassifier.canonical(nq, strength)
        self.rounds = self.rounds + 1

    # 纯函数: 给定 Dual 求流转一步后的 Dual(严格)
    @staticmethod
    def next_dual(d: Dual) raises -> Dual:
        var idx = QuadrantClassifier.classify(d)
        var nq = (idx + 1) % QUADRANT_COUNT
        var m = QuadrantClassifier.magnitude(d)
        return QuadrantClassifier.canonical(nq, m)
