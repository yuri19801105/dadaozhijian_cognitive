# === sancai/interface.mojo ===
# 层间消息契约: 天→地→人 的传递类型与门控放行。
# 调用契约(见 §4.3.0):
#   合并上下游用 Polarity.compose(a, b, ratio); 冲突调和用 Polarity.reconcile(a, b); 主导相用 Polarity.classify(d)
#   层间门控(是否放行到下一层)用 YinYangGate.balance_gate(d, threshold)

from liangyi.dual import Dual, YIN, YANG
from liangyi.polarity import Polarity
from liangyi.activation import YinYangGate, GatePair
from .layers import SanCai, TIAN, DI, REN


# 层间消息载体(可移动): source→target 传递的阴阳属性 content + 门控值 gate
struct LayerMessage(Movable):
    var source: Int
    var target: Int
    var content: Dual
    var gate: Float64

    def __init__(out self, source: Int, target: Int, content: Dual, gate: Float64):
        self.source = source
        self.target = target
        # content 为借入参数(不可隐式复制), 以 from_parts 重构后落入字段(同源不变)
        self.content = Dual.from_parts(content.yin_part(), content.yang_part())
        self.gate = gate


struct LayerBus:
    # 通用层间传递: from_layer 与 to_layer 按 ratio 合并 -> content; balance_gate 判门
    @staticmethod
    def transmit(source: Int, target: Int, from_layer: Dual, to_layer: Dual, ratio: Float64, threshold: Float64) raises -> LayerMessage:
        var content = Polarity.compose(from_layer, to_layer, ratio)
        var gate = YinYangGate.balance_gate(content, threshold)
        return LayerMessage(source, target, content, gate)

    # 天→地: 天之显隐 与 地之动静 合并, 默认均权, 默认阈值 0
    @staticmethod
    def pass_tian_to_di(tian: Dual, di: Dual, ratio: Float64 = 0.5, threshold: Float64 = 0.0) raises -> LayerMessage:
        return LayerBus.transmit(TIAN, DI, tian, di, ratio, threshold)

    # 地→人: 地之动静 与 人 之有无 合并, 默认均权, 默认阈值 0
    @staticmethod
    def pass_di_to_ren(di: Dual, ren: Dual, ratio: Float64 = 0.5, threshold: Float64 = 0.0) raises -> LayerMessage:
        return LayerBus.transmit(DI, REN, di, ren, ratio, threshold)

    # 门控判定: gate >= 0.5 视为放行
    @staticmethod
    def is_passed(msg: LayerMessage) -> Bool:
        return msg.gate >= 0.5

    # 调和: 地(中) 由 天·人 两端调和(中庸), 就地改写 sc 并同步 payload 中间行
    @staticmethod
    def harmonize(mut sc: SanCai) raises:
        var balanced = Polarity.reconcile(sc.tian, sc.ren)
        sc.di = Dual.from_parts(balanced.yin_part(), balanced.yang_part())
        if sc.payload.rank() == 2:
            var i0 = List[Int](); i0.append(DI); i0.append(0)
            var i1 = List[Int](); i1.append(DI); i1.append(1)
            var i2 = List[Int](); i2.append(DI); i2.append(2)
            sc.payload.set(i0, balanced.yin_part())
            sc.payload.set(i1, (balanced.yin_part() + balanced.yang_part()) * 0.5)
            sc.payload.set(i2, balanced.yang_part())
