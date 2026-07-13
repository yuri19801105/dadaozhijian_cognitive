# === wuxing/sheng_ke.mojo ===
# 生克转移规则 → 调度转移表（数据驱动，非硬编码）。
# 相生（母子相续，循环资生）：木→火→土→金→水→木。
# 相克（间隔相制，彼此约束）：木克土、火克金、土克水、金克木、水克火。
# 「生克制化的动态平衡」= 正反馈(生) + 负反馈(克) 的自我调节网络。
# 依赖：core（math.ops.clamp）。

from math.ops import clamp
from .elements import WOOD, FIRE, EARTH, METAL, WATER, ELEMENT_COUNT


# 关系码（a 相对 b 的关系）
comptime REL_SAME: Int = 0            # a == b
comptime REL_GENERATED_BY: Int = 1    # b 生 a（b 是 a 的母）
comptime REL_GENERATES: Int = 2       # a 生 b（b 是 a 的子）
comptime REL_RESTRAINED_BY: Int = 3   # b 克 a（b 是 a 的克者）
comptime REL_RESTRAINS: Int = 4       # a 克 b（b 是 a 所克）


# 我生者（子）：相生下一位
def sheng_next(id: Int) -> Int:
    if id == WOOD: return FIRE
    if id == FIRE: return EARTH
    if id == EARTH: return METAL
    if id == METAL: return WATER
    if id == WATER: return WOOD
    return EARTH


# 生我者（母）：相生上一位
def sheng_prev(id: Int) -> Int:
    if id == WOOD: return WATER
    if id == FIRE: return WOOD
    if id == EARTH: return FIRE
    if id == METAL: return EARTH
    if id == WATER: return METAL
    return EARTH


# 我克者：相克目标（隔一位）
def ke_target(id: Int) -> Int:
    if id == WOOD: return EARTH
    if id == FIRE: return METAL
    if id == EARTH: return WATER
    if id == METAL: return WOOD
    if id == WATER: return FIRE
    return EARTH


# 克我者：谁克我（相克逆）
def ke_source(id: Int) -> Int:
    if id == WOOD: return METAL
    if id == FIRE: return WATER
    if id == EARTH: return WOOD
    if id == METAL: return FIRE
    if id == WATER: return EARTH
    return EARTH


# a 相对 b 的关系码（五元环中：自身 + 母/子/克我/我克 恰好覆盖全部 5 元素）
def relation(a: Int, b: Int) -> Int:
    if a == b: return REL_SAME
    if sheng_prev(a) == b: return REL_GENERATED_BY
    if sheng_next(a) == b: return REL_GENERATES
    if ke_source(a) == b: return REL_RESTRAINED_BY
    if ke_target(a) == b: return REL_RESTRAINS
    return REL_SAME  # 五元环不可达；保守回退


# b 对 a 的净能量贡献：b 为 a 之母 → +gen_rate；b 克 a → -ke_rate；否则 0。
def sheng_ke_gain(a: Int, b: Int, gen_rate: Float64, ke_rate: Float64) -> Float64:
    var r = relation(a, b)
    if r == REL_GENERATED_BY:
        return gen_rate
    if r == REL_RESTRAINED_BY:
        return -ke_rate
    return 0.0


# 一轮生克传播：new[a] = clamp(old[a] + gen_rate*old[母] - ke_rate*old[克我者], 0, +inf)。
# 母生我（正反馈）+ 克我者制我（负反馈），能量不为负。energies 须为 5 长度。
def propagate(energies: List[Float64], gen_rate: Float64, ke_rate: Float64) raises -> List[Float64]:
    if len(energies) != ELEMENT_COUNT:
        raise Error("wuxing: propagate requires exactly 5 element energies")
    var out = List[Float64]()
    for a in range(ELEMENT_COUNT):
        var mother = sheng_prev(a)
        var restrainer = ke_source(a)
        var v = energies[a] + gen_rate * energies[mother] - ke_rate * energies[restrainer]
        out.append(clamp(v, 0.0, 1.0e18))
    return out^
