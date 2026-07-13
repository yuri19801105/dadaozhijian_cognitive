# === wuxing/elements.mojo ===
# 五行元素类型 + 权重（迁自 src/wu_xing.mojo 的权重逻辑，升级为 Dual 阴阳偏置能量）。
# 五行 = 木火土金水 五类动态功能—关系模型；每元素能量以 liangyi.Dual 表示（阳=生发、阴=收敛）。
# 约束（Mojo 1.0.0b2）：Element 只存 Int + Dual（均 Movable）→ 显式 (Movable)；name 按需派生（String 字段会破坏 Movable）。
# 依赖：liangyi（Dual）。

from liangyi.dual import Dual, YIN, YANG


comptime WOOD: Int = 0
comptime FIRE: Int = 1
comptime EARTH: Int = 2
comptime METAL: Int = 3
comptime WATER: Int = 4
comptime ELEMENT_COUNT: Int = 5

# 降级中性元素：土居中央、承载化育，未知符号 / 无法判定时归此（不静默丢弃）。
comptime NEUTRAL_ELEMENT: Int = EARTH


# id -> 中文单字名
def element_name(id: Int) -> String:
    if id == WOOD: return "木"
    if id == FIRE: return "火"
    if id == EARTH: return "土"
    if id == METAL: return "金"
    if id == WATER: return "水"
    return "?"


# element_name 的别名（语义更明确：字形）
def element_glyph(id: Int) -> String:
    return element_name(id)


# 符号 / 令牌 -> 元素 id（含中文单字、拼音、季节别名；无映射 raises）
def element_by_symbol(sym: String) raises -> Int:
    if sym == "木" or sym == "wood" or sym == "春" or sym == "青": return WOOD
    if sym == "火" or sym == "fire" or sym == "夏" or sym == "赤": return FIRE
    if sym == "土" or sym == "earth" or sym == "中" or sym == "黄": return EARTH
    if sym == "金" or sym == "metal" or sym == "秋" or sym == "白": return METAL
    if sym == "水" or sym == "water" or sym == "冬" or sym == "黑": return WATER
    raise Error("wuxing: symbol has no element mapping")


# 符号 -> 元素（未知降级为中性元素 NEUTRAL_ELEMENT=土，不静默丢弃）
def element_by_symbol_safe(sym: String) -> Int:
    try:
        return element_by_symbol(sym)
    except:
        return NEUTRAL_ELEMENT


# 五行元素：id + 能量（Dual 阴阳偏置）。Movable（Int + Dual 皆 Movable）。
struct Element(Movable):
    var id: Int
    var energy: Dual   # 能量强度带阴阳偏置：阳分量=生发力、阴分量=收敛力

    def __init__(out self, id: Int, energy: Dual):
        self.id = id
        # Dual 参数为不可隐式复制借入 → 以 from_parts 重构（同源不变）
        self.energy = Dual.from_parts(energy.yin_part(), energy.yang_part())

    def name(self) -> String:
        return element_name(self.id)

    # 能量幅度（阴+阳 守恒量）
    def strength(self) -> Float64:
        return self.energy.yin_part() + self.energy.yang_part()

    # 阴阳偏向（YIN / YANG）
    def bias(self) -> Int:
        return self.energy.get_phase()

    def is_valid(self) -> Bool:
        return self.id >= 0 and self.id < ELEMENT_COUNT
