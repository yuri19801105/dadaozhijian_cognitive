# === bagua/trigrams.mojo ===
# 八卦定义：8 卦 = 3 条 Dual 爻线（初/二/三爻 = 地/人/天）的全组合，每条爻线阴=YIN/阳=YANG。
# 卦码（3 位 yin/yang，初爻为最低位，yang=1）：乾7 兑3 离5 震1 巽6 坎2 艮4 坤0。
# 依赖：liangyi（Dual / Polarity）、sancai（派生卦象）。
# 约束：Trigram 只存 id（Int），name/lines/essence 按需派生 -> 保持 Movable（String 字段会破坏 Movable）。

from liangyi.dual import Dual, YIN, YANG
from liangyi.polarity import Polarity
from math.ops import abs_f64
from sancai.layers import SanCai


comptime QIAN: Int = 0
comptime KUN: Int = 1
comptime ZHEN: Int = 2
comptime XUN: Int = 3
comptime KAN: Int = 4
comptime LI: Int = 5
comptime GEN: Int = 6
comptime DUI: Int = 7
comptime TRIGRAM_COUNT: Int = 8

# 降级中性卦：未知符号映射至此（坤=全阴，承载/归零），不静默丢弃。
comptime NEUTRAL_ID: Int = KUN


# id -> 名称（中文单字）
def trigram_name(id: Int) -> String:
    if id == QIAN: return "乾"
    if id == KUN: return "坤"
    if id == ZHEN: return "震"
    if id == XUN: return "巽"
    if id == KAN: return "坎"
    if id == LI: return "离"
    if id == GEN: return "艮"
    if id == DUI: return "兑"
    return "?"


# id -> 3 位 yao 码（初爻为最低位, yang=1）
def trigram_code(id: Int) -> Int:
    if id == QIAN: return 7
    if id == KUN: return 0
    if id == ZHEN: return 1
    if id == XUN: return 6
    if id == KAN: return 2
    if id == LI: return 5
    if id == GEN: return 4
    if id == DUI: return 3
    return -1


# yao 码 -> id（逆映射）
def trigram_id_from_code(code: Int) -> Int:
    if code == 7: return QIAN
    if code == 0: return KUN
    if code == 1: return ZHEN
    if code == 6: return XUN
    if code == 2: return KAN
    if code == 5: return LI
    if code == 4: return GEN
    if code == 3: return DUI
    return -1


# 由相位构造一条爻线 Dual：阳线 = (yin=0, yang=mag)，阴线 = (yin=mag, yang=0)；零幅时保留相位。
def _line_from_phase(phase: Int, mag: Float64) -> Dual:
    if phase == YANG:
        return Dual.from_parts(0.0, mag)
    if mag == 0.0:
        return Dual(0.0, YIN)
    return Dual.from_parts(mag, 0.0)


struct Trigram(Movable):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    # 3 位 yao 码
    def code(self) -> Int:
        return trigram_code(self.id)

    # 中文名
    def name(self) -> String:
        return trigram_name(self.id)

    # 三条爻线（初/二/三爻，由低到高），每条为阴阳 Dual
    def lines(self) -> List[Dual]:
        var c = self.code()
        var ls = List[Dual]()
        for i in range(3):
            var bit = (c >> i) & 1
            if bit == 1:
                ls.append(Dual.from_parts(0.0, 1.0))
            else:
                ls.append(Dual.from_parts(1.0, 0.0))
        return ls^

    # 卦之"精"：三条爻线调和（两两 reconcile）后的代表 Dual
    def essence(self) -> Dual:
        var ls = self.lines()
        var a = Polarity.reconcile(ls[0], ls[1])
        return Polarity.reconcile(a, ls[2])


# 由 id 构造（越界 raises）
def trigram_by_id(id: Int) raises -> Trigram:
    if id < 0 or id >= TRIGRAM_COUNT:
        raise Error("bagua: trigram id out of range [0,7]")
    return Trigram(id)


# 由 yao 码（0..7）构造（越界 raises）
def trigram_by_code(code: Int) raises -> Trigram:
    if code < 0 or code > 7:
        raise Error("bagua: yao code out of range [0,7]")
    var id = trigram_id_from_code(code)
    if id < 0:
        raise Error("bagua: invalid yao code")
    return Trigram(id)


# 由三条爻线构造（数量错 / 非法相位 raises）
def trigram_from_lines(lines: List[Dual]) raises -> Trigram:
    if len(lines) != 3:
        raise Error("bagua: a trigram requires exactly 3 yao lines")
    var code = 0
    for i in range(3):
        var ph = lines[i].get_phase()
        if ph != YIN and ph != YANG:
            raise Error("bagua: illegal yao line phase")
        var bit = 1 if ph == YANG else 0
        code = code | (bit << i)
    var id = trigram_id_from_code(code)
    if id < 0:
        raise Error("bagua: illegal yao line combination")
    return Trigram(id)


# 符号/令牌 -> 卦（无映射 raises）
def trigram_from_symbol(sym: String) raises -> Trigram:
    if sym == "乾" or sym == "qian" or sym == "天" or sym == "乾卦": return Trigram(QIAN)
    if sym == "坤" or sym == "kun" or sym == "地" or sym == "坤卦": return Trigram(KUN)
    if sym == "震" or sym == "zhen" or sym == "雷" or sym == "震卦": return Trigram(ZHEN)
    if sym == "巽" or sym == "xun" or sym == "风" or sym == "巽卦": return Trigram(XUN)
    if sym == "坎" or sym == "kan" or sym == "水" or sym == "坎卦": return Trigram(KAN)
    if sym == "离" or sym == "li" or sym == "火" or sym == "离卦": return Trigram(LI)
    if sym == "艮" or sym == "gen" or sym == "山" or sym == "艮卦": return Trigram(GEN)
    if sym == "兑" or sym == "dui" or sym == "泽" or sym == "兑卦": return Trigram(DUI)
    raise Error("bagua: symbol has no trigram mapping")


# 符号 -> 卦（未知符号降级为中性卦 NEUTRAL_ID，不静默丢弃）
def trigram_from_symbol_safe(sym: String) -> Trigram:
    try:
        return trigram_from_symbol(sym)
    except:
        return Trigram(NEUTRAL_ID)


# 由 sancai 三层 Dual 派生卦象：初爻=人, 二爻=地, 三爻=天（相位定阴阳，幅度定强弱）。
# 含 NaN 校验（raises）。sc 以值传入（非 Movable，按移动语义消费）。
def trigram_from_sancai(sc: SanCai) raises -> Trigram:
    sc.validate()
    var ren_line = _line_from_phase(sc.ren.get_phase(), abs_f64(sc.ren.get_value()))
    var di_line = _line_from_phase(sc.di.get_phase(), abs_f64(sc.di.get_value()))
    var tian_line = _line_from_phase(sc.tian.get_phase(), abs_f64(sc.tian.get_value()))
    var lines = List[Dual]()
    lines.append(ren_line^)   # 初爻（底）
    lines.append(di_line^)    # 二爻（中）
    lines.append(tian_line^)  # 三爻（顶）
    return trigram_from_lines(lines)
