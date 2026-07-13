# === bagua/operators.mojo ===
# 八卦推理算子：每卦是一个推理算子，对输入 Dual 做确定性变换。
# 调用契约（见 §4.8.0）：激活门控用 YinYangGate；变换用 Polarity（compose/reconcile/invert）。
# 输出结构化结果 TrigramOperatorResult { trigram, code, activation: GatePair, transformed: Dual }。
# 确定性：纯函数派生，无随机。

from liangyi.dual import Dual, YIN, YANG
from liangyi.polarity import Polarity
from liangyi.activation import YinYangGate, GatePair
from .trigrams import Trigram, QIAN, KUN, ZHEN, XUN, KAN, LI, GEN, DUI, trigram_by_id


# 算子结果载体（Movable：含 GatePair + Dual）
struct TrigramOperatorResult(Movable):
    var trigram: Int       # 卦 id (0..7)
    var code: Int         # 3 位 yao 码 (0..7)
    var activation: GatePair   # 阴阳双门（抑制量, 激发量）
    var transformed: Dual      # 算子对输入的变换结果

    def __init__(out self, trigram: Int, code: Int, activation: GatePair, transformed: Dual):
        self.trigram = trigram
        self.code = code
        self.activation = GatePair(activation.yin, activation.yang)
        self.transformed = Dual.from_parts(transformed.yin_part(), transformed.yang_part())


# 单卦算子核心变换：按卦性对输入 Dual 做确定性运算（不变量全程保持）
def _transform(id: Int, x: Dual) -> Dual:
    var yg = x.yang_part()
    var yi = x.yin_part()
    if id == QIAN:   # 乾·创造：阳盛扩张（幅度翻倍）
        return x.scale(2.0)
    if id == KUN:    # 坤·承载：收敛容纳（幅度减半）
        return x.scale(0.5)
    if id == ZHEN:   # 震·雷动：注入阳动（阳分量 +1）
        return Dual.from_parts(yi, yg + 1.0)
    if id == XUN:    # 巽·风入：与逆相调和（溶解边界 -> 趋衡）
        return Polarity.reconcile(x, Polarity.invert(x))
    if id == KAN:    # 坎·冒险：倾向阳（偏入未知，阳加权）
        return Dual.from_parts(yi * 0.5, yg * 1.5)
    if id == LI:     # 离·明辨：放大对比（锐化阴阳）
        return Dual.from_parts(yi * 2.0, yg * 2.0)
    if id == GEN:    # 艮·山止：归零（终止分支）
        return Dual(0.0)
    if id == DUI:    # 兑·泽悦：与逆半调和（交换视角 -> 取中）
        return Polarity.compose(x, Polarity.invert(x), 0.5)
    return Dual.from_parts(x.yin_part(), x.yang_part())


# 对单卦施加算子：返回结构化结果
def apply(trig: Trigram, x: Dual) -> TrigramOperatorResult:
    var act = YinYangGate.dual_gate(x)
    var t = _transform(trig.id, x)
    return TrigramOperatorResult(trig.id, trig.code(), act, t)


# 按 id 施加算子（越界 raises）
def apply_by_id(id: Int, x: Dual) raises -> TrigramOperatorResult:
    var trig = trigram_by_id(id)
    return apply(trig, x)


# 推理链：顺序施加一串卦算子，返回各步结果
def apply_chain(chain: List[Trigram], x: Dual) -> List[TrigramOperatorResult]:
    var out = List[TrigramOperatorResult]()
    for i in range(len(chain)):
        out.append(apply(chain[i], x))
    return out^
