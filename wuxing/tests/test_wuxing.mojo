# === wuxing/tests/test_wuxing.mojo ===
# 五行调度策略核心 TDD 测试套件（RED→GREEN，零桩函数）。
# 覆盖：elements（元素/名称/符号映射/Element·Dual 能量）、sheng_ke（相生相克/关系码/生克传播）、
#      scheduler_core（主导元素/schedule/schedule_from_phase/ScheduleDecision）、balance（方差/均衡/归一/再平衡）。
# 运行：.venv/bin/mojo run -I . -I core wuxing/tests/test_wuxing.mojo

from liangyi.dual import Dual, YIN, YANG
from math.ops import abs_f64
from wuxing.elements import (
    WOOD, FIRE, EARTH, METAL, WATER, ELEMENT_COUNT, NEUTRAL_ELEMENT,
    Element, element_name, element_glyph, element_by_symbol, element_by_symbol_safe,
)
from wuxing.sheng_ke import (
    sheng_next, sheng_prev, ke_target, ke_source, relation,
    REL_SAME, REL_GENERATED_BY, REL_GENERATES, REL_RESTRAINED_BY, REL_RESTRAINS,
    sheng_ke_gain, propagate,
)
from wuxing.scheduler_core import (
    ScheduleDecision, dominant_element, schedule, schedule_from_phase,
)
from wuxing.balance import (
    total_energy, mean_energy, variance, is_balanced, normalize, rebalance,
)


struct Counter(Movable):
    var passed: Int
    var failed: Int

    def __init__(out self):
        self.passed = 0
        self.failed = 0

    def check(mut self, cond: Bool, name: String):
        if cond:
            self.passed += 1
        else:
            self.failed += 1
            print("  FAIL:", name)


def _approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    return abs_f64(a - b) <= tol


def _make5(a: Float64, b: Float64, c: Float64, d: Float64, e: Float64) -> List[Float64]:
    var l = List[Float64]()
    l.append(a); l.append(b); l.append(c); l.append(d); l.append(e)
    return l^


# ---------------- elements ----------------

def test_element_constants(mut c: Counter) raises:
    var ids = List[Int]()
    ids.append(WOOD)
    ids.append(FIRE)
    ids.append(EARTH)
    ids.append(METAL)
    ids.append(WATER)
    var ordered = True
    for i in range(len(ids)):
        if ids[i] != i:
            ordered = False
    c.check(ordered, "element ids 0..4")
    c.check(ELEMENT_COUNT == 5, "ELEMENT_COUNT==5")
    c.check(NEUTRAL_ELEMENT == EARTH, "NEUTRAL_ELEMENT==EARTH")


def test_element_names(mut c: Counter) raises:
    c.check(element_name(WOOD) == "木" and element_name(WATER) == "水", "element_name glyph")
    c.check(element_glyph(FIRE) == "火" and element_glyph(METAL) == "金", "element_glyph")


def test_element_by_symbol(mut c: Counter) raises:
    c.check(element_by_symbol("木") == WOOD, "symbol 木->WOOD")
    c.check(element_by_symbol("wood") == WOOD, "symbol wood->WOOD")
    c.check(element_by_symbol("水") == WATER, "symbol 水->WATER")
    c.check(element_by_symbol("金") == METAL, "symbol 金->METAL")


def test_element_by_symbol_raises(mut c: Counter) raises:
    var raised = False
    try:
        _ = element_by_symbol("龙")
    except:
        raised = True
    c.check(raised, "unknown symbol raises")


def test_element_by_symbol_safe(mut c: Counter) raises:
    c.check(element_by_symbol_safe("木") == WOOD, "safe known 木")
    c.check(element_by_symbol_safe("龙") == NEUTRAL_ELEMENT, "safe unknown -> NEUTRAL(EARTH)")


def test_element_struct(mut c: Counter) raises:
    var e = Element(FIRE, Dual.from_parts(0.0, 4.0))  # 纯阳能量
    c.check(e.id == FIRE, "Element id")
    c.check(e.name() == "火", "Element name")
    c.check(_approx(e.strength(), 4.0, 1e-9), "Element strength = yin+yang")
    c.check(e.bias() == YANG, "Element bias phase = YANG")
    c.check(e.is_valid(), "Element is_valid")


def test_element_invalid(mut c: Counter) raises:
    var e = Element(9, Dual(1.0))
    c.check(not e.is_valid(), "Element id=9 invalid")


# ---------------- sheng_ke（相生相克网络）----------------

def test_sheng_next(mut c: Counter) raises:
    # 相生: 木→火→土→金→水→木
    c.check(sheng_next(WOOD) == FIRE, "木生火")
    c.check(sheng_next(FIRE) == EARTH, "火生土")
    c.check(sheng_next(EARTH) == METAL, "土生金")
    c.check(sheng_next(METAL) == WATER, "金生水")
    c.check(sheng_next(WATER) == WOOD, "水生木")


def test_sheng_prev(mut c: Counter) raises:
    # 生我者（母）
    c.check(sheng_prev(WOOD) == WATER, "水生木 -> 木之母=水")
    c.check(sheng_prev(FIRE) == WOOD, "木生火 -> 火之母=木")
    c.check(sheng_prev(EARTH) == FIRE, "火生土 -> 土之母=火")


def test_ke_target(mut c: Counter) raises:
    # 相克: 木克土, 火克金, 土克水, 金克木, 水克火
    c.check(ke_target(WOOD) == EARTH, "木克土")
    c.check(ke_target(FIRE) == METAL, "火克金")
    c.check(ke_target(EARTH) == WATER, "土克水")
    c.check(ke_target(METAL) == WOOD, "金克木")
    c.check(ke_target(WATER) == FIRE, "水克火")


def test_ke_source(mut c: Counter) raises:
    # 克我者
    c.check(ke_source(WOOD) == METAL, "克木者=金")
    c.check(ke_source(FIRE) == WATER, "克火者=水")
    c.check(ke_source(EARTH) == WOOD, "克土者=木")


def test_relation(mut c: Counter) raises:
    c.check(relation(WOOD, WOOD) == REL_SAME, "same")
    c.check(relation(WOOD, WATER) == REL_GENERATED_BY, "水生木: 木 GENERATED_BY 水")
    c.check(relation(WOOD, FIRE) == REL_GENERATES, "木生火: 木 GENERATES 火")
    c.check(relation(WOOD, METAL) == REL_RESTRAINED_BY, "金克木: 木 RESTRAINED_BY 金")
    c.check(relation(WOOD, EARTH) == REL_RESTRAINS, "木克土: 木 RESTRAINS 土")


def test_relation_total(mut c: Counter) raises:
    # 对每个 a，五种关系恰好覆盖全部 5 个元素（含自身）
    for a in range(ELEMENT_COUNT):
        var seen = List[Int]()
        for _i in range(ELEMENT_COUNT):
            seen.append(0)
        for b in range(ELEMENT_COUNT):
            var r = relation(a, b)
            seen[r] = seen[r] + 1
        var all_one = True
        for k in range(5):
            if seen[k] != 1:
                all_one = False
        c.check(all_one, "relation partition total for a=" + String(a))


def test_sheng_ke_gain(mut c: Counter) raises:
    # b 是 a 的母 -> 正贡献；b 克 a -> 负贡献；否则 0
    c.check(sheng_ke_gain(WOOD, WATER, 1.0, 2.0) > 0.0, "母生我正")
    c.check(sheng_ke_gain(WOOD, METAL, 1.0, 2.0) < 0.0, "克我者负")
    c.check(_approx(sheng_ke_gain(WOOD, FIRE, 1.0, 2.0), 0.0, 1e-9), "我生者/无关 0")


def test_propagate_basic(mut c: Counter) raises:
    # 单点火种：仅 WOOD 有能量，一轮后其子 FIRE 应获得生助（母生我）
    var e = _make5(10.0, 0.0, 0.0, 0.0, 0.0)
    var out = propagate(e, 0.5, 0.25)
    c.check(out[FIRE] > 0.0, "propagate: 木生火使火增")
    var non_neg = True
    for i in range(ELEMENT_COUNT):
        if out[i] < 0.0:
            non_neg = False
    c.check(non_neg, "propagate: 能量非负")


def test_propagate_restrain(mut c: Counter) raises:
    # WOOD 与 METAL 同时有能量：金克木 -> 一轮后 WOOD 受克下降
    var e = _make5(10.0, 0.0, 0.0, 10.0, 0.0)
    var out = propagate(e, 0.0, 0.5)  # 关生只看克
    # 克木者=金(10) -> WOOD = 10 - 0.5*10 = 5
    c.check(_approx(out[WOOD], 5.0, 1e-9), "propagate: 金克木 10->5")


def test_propagate_len_raises(mut c: Counter) raises:
    var raised = False
    var bad = _make5(1.0, 1.0, 1.0, 1.0, 1.0)
    bad.append(1.0)  # 6 个，非法
    try:
        _ = propagate(bad, 0.5, 0.5)
    except:
        raised = True
    c.check(raised, "propagate: 非 5 长度 raises")


# ---------------- scheduler_core ----------------

def test_dominant_element(mut c: Counter) raises:
    var e = _make5(1.0, 9.0, 2.0, 3.0, 4.0)
    c.check(dominant_element(e) == FIRE, "dominant = argmax = FIRE")


def test_schedule_basic(mut c: Counter) raises:
    var e = _make5(1.0, 8.0, 1.0, 1.0, 1.0)
    var d = schedule(e)
    c.check(d.dominant == FIRE, "schedule dominant FIRE")
    var s = d.weight(0) + d.weight(1) + d.weight(2) + d.weight(3) + d.weight(4)
    c.check(_approx(s, 1.0, 1e-6), "schedule weights sum to 1")
    c.check(d.weight(FIRE) > d.weight(WOOD), "FIRE weight dominant")
    c.check(_approx(d.confidence, 8.0 / 12.0, 1e-6), "confidence = dominant share")


def test_schedule_chain_generative(mut c: Counter) raises:
    # 决策链沿相生序从主导推进：dominant=FIRE -> FIRE, 土, 金
    var e = _make5(1.0, 8.0, 1.0, 1.0, 1.0)
    var d = schedule(e)
    c.check(d.chain_at(0) == FIRE, "chain[0]=dominant FIRE")
    c.check(d.chain_at(1) == EARTH, "chain[1]=火生土")
    c.check(d.chain_at(2) == METAL, "chain[2]=土生金")


def test_schedule_zero_raises(mut c: Counter) raises:
    var e = _make5(0.0, 0.0, 0.0, 0.0, 0.0)
    var raised = False
    try:
        _ = schedule(e)
    except:
        raised = True
    c.check(raised, "schedule 全零能量 raises")


def test_schedule_len_raises(mut c: Counter) raises:
    var raised = False
    var bad = _make5(1.0, 1.0, 1.0, 1.0, 1.0)
    bad.append(1.0)
    try:
        _ = schedule(bad)
    except:
        raised = True
    c.check(raised, "schedule 非 5 长度 raises")


def test_schedule_from_phase(mut c: Counter) raises:
    # 四象 → 五行: 老阴(0)→水, 少阳(1)→木, 老阳(2)→火, 少阴(3)→金
    var d_water = schedule_from_phase(0, 10.0)
    c.check(d_water.dominant == WATER, "老阴->水主导")
    var d_wood = schedule_from_phase(1, 10.0)
    c.check(d_wood.dominant == WOOD, "少阳->木主导")
    var d_fire = schedule_from_phase(2, 10.0)
    c.check(d_fire.dominant == FIRE, "老阳->火主导")
    var d_metal = schedule_from_phase(3, 10.0)
    c.check(d_metal.dominant == METAL, "少阴->金主导")


def test_schedule_from_phase_neutral(mut c: Counter) raises:
    # 越界象限 -> 中土
    var d = schedule_from_phase(99, 10.0)
    c.check(d.dominant == EARTH, "越界象限->土(中枢)主导")


def test_decision_append_chain(mut c: Counter) raises:
    var d = ScheduleDecision()
    d.append_chain(WOOD)
    d.append_chain(FIRE)
    c.check(d.c_len == 2, "append_chain len=2")
    c.check(d.chain_at(0) == WOOD and d.chain_at(1) == FIRE, "chain order")
    var cl = d.chain_list()
    c.check(len(cl) == 2, "chain_list len")


# ---------------- balance ----------------

def test_total_and_mean(mut c: Counter) raises:
    var e = _make5(1.0, 2.0, 3.0, 4.0, 5.0)
    c.check(_approx(total_energy(e), 15.0, 1e-9), "total=15")
    c.check(_approx(mean_energy(e), 3.0, 1e-9), "mean=3")


def test_variance(mut c: Counter) raises:
    var flat = _make5(3.0, 3.0, 3.0, 3.0, 3.0)
    c.check(_approx(variance(flat), 0.0, 1e-9), "flat variance 0")
    var spread = _make5(1.0, 2.0, 3.0, 4.0, 5.0)
    c.check(variance(spread) > 0.0, "spread variance > 0")


def test_is_balanced(mut c: Counter) raises:
    var flat = _make5(3.0, 3.0, 3.0, 3.0, 3.0)
    c.check(is_balanced(flat, 1e-6), "flat is balanced")
    var spread = _make5(0.0, 0.0, 0.0, 0.0, 20.0)
    c.check(not is_balanced(spread, 1e-6), "spread not balanced")


def test_normalize(mut c: Counter) raises:
    var e = _make5(1.0, 1.0, 1.0, 1.0, 1.0)
    var n = normalize(e)
    var s = 0.0
    for i in range(ELEMENT_COUNT):
        s += n[i]
    c.check(_approx(s, 1.0, 1e-9), "normalize sum=1")
    c.check(_approx(n[0], 0.2, 1e-9), "uniform -> 0.2 each")


def test_normalize_zero_raises(mut c: Counter) raises:
    var e = _make5(0.0, 0.0, 0.0, 0.0, 0.0)
    var raised = False
    try:
        _ = normalize(e)
    except:
        raised = True
    c.check(raised, "normalize 全零 raises")


def test_rebalance_reduces_variance(mut c: Counter) raises:
    var e = _make5(0.0, 0.0, 0.0, 0.0, 20.0)
    var before = variance(e)
    var out = rebalance(e)
    var after = variance(out)
    c.check(after < before, "rebalance 降方差")
    c.check(_approx(total_energy(out), total_energy(e), 1e-6), "rebalance 保总量")


def test_rebalance_preserves_balanced(mut c: Counter) raises:
    var flat = _make5(4.0, 4.0, 4.0, 4.0, 4.0)
    var out = rebalance(flat)
    c.check(_approx(variance(out), 0.0, 1e-9), "已均衡再平衡仍均衡")


def main() raises:
    var c = Counter()
    test_element_constants(c)
    test_element_names(c)
    test_element_by_symbol(c)
    test_element_by_symbol_raises(c)
    test_element_by_symbol_safe(c)
    test_element_struct(c)
    test_element_invalid(c)
    test_sheng_next(c)
    test_sheng_prev(c)
    test_ke_target(c)
    test_ke_source(c)
    test_relation(c)
    test_relation_total(c)
    test_sheng_ke_gain(c)
    test_propagate_basic(c)
    test_propagate_restrain(c)
    test_propagate_len_raises(c)
    test_dominant_element(c)
    test_schedule_basic(c)
    test_schedule_chain_generative(c)
    test_schedule_zero_raises(c)
    test_schedule_len_raises(c)
    test_schedule_from_phase(c)
    test_schedule_from_phase_neutral(c)
    test_decision_append_chain(c)
    test_total_and_mean(c)
    test_variance(c)
    test_is_balanced(c)
    test_normalize(c)
    test_normalize_zero_raises(c)
    test_rebalance_reduces_variance(c)
    test_rebalance_preserves_balanced(c)

    print("wuxing -> passed:", c.passed, " failed:", c.failed)
    if c.failed > 0:
        raise Error("wuxing tests failed")
