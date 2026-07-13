# === liangyi/polarity.mojo ===
# 极性运算: 取反 / 合成 / 判别 / 调和。

from .dual import Dual, YIN, YANG


struct Polarity:
    # 取反: 阴阳互换 (phase 翻转, 分量交换)
    @staticmethod
    def invert(d: Dual) -> Dual:
        # from_parts(yang, yin) -> value = yin - yang = -(yang - yin) = -d.value
        return Dual.from_parts(d.yang_part(), d.yin_part())

    # 合成: 按 ratio∈[0,1] 加权调和 (0=纯阴取 b, 1=纯阳取 a)
    @staticmethod
    def compose(a: Dual, b: Dual, ratio: Float64) -> Dual:
        var ny = ratio * a.yang_part() + (1.0 - ratio) * b.yang_part()
        var ni = ratio * a.yin_part() + (1.0 - ratio) * b.yin_part()
        return Dual.from_parts(ni, ny)

    # 判别: 偏阴/平衡/偏阳 -> -1 / 0 / 1
    @staticmethod
    def classify(d: Dual) -> Int:
        if d.get_value() > 0.0:
            return 1
        if d.get_value() < 0.0:
            return -1
        return 0

    # 调和: 一对 Dual 取均值 + 相位归中, 最小冲突
    @staticmethod
    def reconcile(a: Dual, b: Dual) -> Dual:
        var ni = (a.yin_part() + b.yin_part()) * 0.5
        var ny = (a.yang_part() + b.yang_part()) * 0.5
        return Dual.from_parts(ni, ny)
