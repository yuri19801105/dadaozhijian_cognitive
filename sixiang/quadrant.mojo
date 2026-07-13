# === sixiang/quadrant.mojo ===
# 四象: 老少阴阳四象限。由两仪(Dual)派生, 调用 liangyi 的 Polarity / Dual。
#
# 经典映射(对 liangyi 调用契约, 见 §4.4.0):
#   老阴 OLD_YIN   : 纯阴  -> value < 0 且 yang = 0            (Dual(yin=m, yang=0))
#   少阳 YOUNG_YANG: 阳生  -> value > 0 且 yin > 0  (yang>yin)  (Dual: yang 占优)
#   老阳 OLD_YANG  : 纯阳  -> value > 0 且 yin = 0            (Dual(yang=m, yin=0))
#   少阴 YOUNG_YIN : 阴生  -> value < 0 且 yang > 0 (yin>yang)  (Dual: yin 占优)
# 相位流转顺序(老少阴阳循环): 老阴 -> 少阳 -> 老阳 -> 少阴 -> 老阴
#
# 设计注(Mojo 1.0.0b2 实证约束, 同 sancai):
#   - 含 String 字段的 struct 不可 Movable, 故 Quadrant 不存 name 字段,
#     改由 name() 实例方法 / phase_name() 自由函数按需派生 String(局部构造可返回)。
#   - 相位判定用 Polarity.classify(返回 -1/0/1) 粗分阴阳, 再据 yin/yang 分量细化老/少。
#   - canonical 形状用 Polarity.invert(翻转) + Polarity.compose(插值) 在两仪层构造,
#     满足 §4.4.0「用 Polarity.invert/compose 做相位翻转与插值」的调用契约。

from liangyi.dual import Dual, YIN, YANG
from liangyi.polarity import Polarity

comptime OLD_YIN: Int = 0      # 老阴: 纯阴
comptime YOUNG_YANG: Int = 1   # 少阳: 阳生
comptime OLD_YANG: Int = 2     # 老阳: 纯阳
comptime YOUNG_YIN: Int = 3    # 少阴: 阴生
comptime QUADRANT_COUNT: Int = 4


# 象限名(中文字面量构造 String; 作为自由函数, 避免 String 进 struct 字段)
def phase_name(index: Int) -> String:
    if index == OLD_YIN:
        return String("老阴")
    elif index == YOUNG_YANG:
        return String("少阳")
    elif index == OLD_YANG:
        return String("老阳")
    return String("少阴")


# 单象限(可移动载体): 索引 + 符号 Dual; 名称由 name() 派生。
struct Quadrant(Movable):
    var index: Int
    var symbol: Dual

    def __init__(out self, index: Int, symbol: Dual):
        self.index = index
        self.symbol = Dual.from_parts(symbol.yin_part(), symbol.yang_part())

    def name(self) -> String:
        return phase_name(self.index)


# 四象判别与构造(纯函数, 确定性)。
struct QuadrantClassifier:
    # 由 Dual 推导四象限索引(严格: NaN / 平衡态(阴==阳) 抛 Error)
    @staticmethod
    def classify(d: Dual) raises -> Int:
        if d.get_value() != d.get_value():
            raise Error("sixiang: NaN 相位不可判别")
        var sign = Polarity.classify(d)
        if sign > 0:
            if d.yin_part() == 0.0:
                return OLD_YANG
            return YOUNG_YANG
        if sign < 0:
            if d.yang_part() == 0.0:
                return OLD_YIN
            return YOUNG_YIN
        # sign == 0: value==0 -> 阴==阳(平衡/中性), 相位不收敛
        raise Error("sixiang: 平衡态(阴==阳)相位不收敛, 无法归类")

    # 非严格: NaN / 平衡 -> 默认老阴(中性降级, 不抛错)
    @staticmethod
    def safe_index(d: Dual) -> Int:
        try:
            return QuadrantClassifier.classify(d)
        except:
            return OLD_YIN

    # 总激活量(阴+阳, 守恒量): 跨象传递幅度, 保证流转中能量不增不减。
    @staticmethod
    def magnitude(d: Dual) -> Float64:
        return d.yin_part() + d.yang_part()

    # 由索引 + 幅度构造该象典型 Dual(调用 Polarity.invert/compose 在两仪层做相位翻转与插值)
    @staticmethod
    def canonical(index: Int, magnitude: Float64) -> Dual:
        var yin_only = Dual.from_parts(magnitude, 0.0)      # 老阴极 (yin=m, yang=0)
        var yang_only = Polarity.invert(yin_only)           # 老阳极 (yang=m, yin=0) 相位翻转
        if index == OLD_YIN:
            return yin_only^
        if index == OLD_YANG:
            return yang_only^
        if index == YOUNG_YANG:
            # 阳生: 偏向老阳 (ratio=0.6 取 yang_only 分量 -> yang>yin)
            var q = Polarity.compose(yang_only, yin_only, 0.6)
            return q^
        # YOUNG_YIN: 阴生: 偏向老阴 (ratio=0.6 取 yin_only 分量 -> yin>yang)
        var q = Polarity.compose(yin_only, yang_only, 0.6)
        return q^

    # 由 Dual 构造象限(输出契约 Quadrant{index, symbol, name()}; 降级保留原符号不丢弃)
    @staticmethod
    def from_dual(d: Dual) -> Quadrant:
        try:
            var idx = QuadrantClassifier.classify(d)
            var m = QuadrantClassifier.magnitude(d)
            return Quadrant(idx, QuadrantClassifier.canonical(idx, m))
        except:
            # 降级: 未知/非法输入 -> 映射中性象限(太极近似), 保留原符号不静默丢弃
            return Quadrant(OLD_YIN, Dual.from_parts(d.yin_part(), d.yang_part()))
