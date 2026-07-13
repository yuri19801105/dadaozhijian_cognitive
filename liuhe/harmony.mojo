# liuhe/harmony.mojo — 地支六合(和合化生) + 多源供给归并（六合之关系义）
# 六合(术数义): 十二地支两两相合成六对，合化生出五行之气。本项目以之提供
# "亲和—合化"关系运算，并以 merge_supplies 实现多源供给的逐向归并（和合统一）。
# 运行: mojo run -I . -I core liuhe/harmony.mojo
from wuxing.elements import WOOD, FIRE, EARTH, METAL, WATER, NEUTRAL_ELEMENT
from .supply import SupplyVector

comptime BRANCH_COUNT: Int = 12   # 十二地支: 子0 丑1 寅2 卯3 辰4 巳5 午6 未7 申8 酉9 戌10 亥11

def he_harmony(a: Int, b: Int) -> Int:
    # 无序化(六合为无序对)
    var x = a; var y = b
    if x > y:
        var t = x; x = y; y = t
    # 六合配对 → 合化五行(非六合对显式降级中性元素, 不静默丢弃)
    if x == 0 and y == 1: return EARTH    # 子丑合化土
    if x == 2 and y == 11: return WOOD    # 寅亥合化木
    if x == 3 and y == 10: return FIRE    # 卯戌合化火
    if x == 4 and y == 9: return METAL    # 辰酉合化金
    if x == 5 and y == 8: return WATER    # 巳申合化水
    if x == 6 and y == 7: return EARTH    # 午未合化土
    return NEUTRAL_ELEMENT

def harmony_index(a: Int, b: Int) -> Float64:
    var x = a; var y = b
    if x > y:
        var t = x; x = y; y = t
    if (x == 0 and y == 1) or (x == 2 and y == 11) or (x == 3 and y == 10) \
       or (x == 4 and y == 9) or (x == 5 and y == 8) or (x == 6 and y == 7):
        return 1.0
    return 0.0

def merge_supplies(a: SupplyVector, b: SupplyVector) -> SupplyVector:
    # 多源和合: 逐向取容量并集(max)，harmony 取较强者
    var m = SupplyVector()
    m.s0 = a.s0 if a.s0 > b.s0 else b.s0
    m.s1 = a.s1 if a.s1 > b.s1 else b.s1
    m.s2 = a.s2 if a.s2 > b.s2 else b.s2
    m.s3 = a.s3 if a.s3 > b.s3 else b.s3
    m.s4 = a.s4 if a.s4 > b.s4 else b.s4
    m.s5 = a.s5 if a.s5 > b.s5 else b.s5
    m.harmony = a.harmony if a.harmony > b.harmony else b.harmony
    return m^
