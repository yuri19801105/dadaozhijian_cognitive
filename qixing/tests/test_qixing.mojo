# qixing/tests/test_qixing.mojo — 七星模块 TDD 测试（零桩函数）
# 运行: mojo run -I . -I core qixing/tests/test_qixing.mojo
from qixing import (
    abstract_level, capacity_factor, priority_of, priority_list,
    order_chain, DecisionSequence, build_sequence,
)
from wuxing import schedule, ScheduleDecision, WOOD, FIRE, EARTH, METAL, WATER
from wuxing.elements import NEUTRAL_ELEMENT
from liuhe import build_supply, SupplyVector, EAST, WEST, SOUTH, NORTH, UP, DOWN

struct Counter(Movable):
    var passed: Int
    var failed: Int
    def __init__(out self):
        self.passed = 0
        self.failed = 0
    def check(mut self, cond: Bool, name: String):
        if cond:
            self.passed = self.passed + 1
        else:
            self.failed = self.failed + 1
            print("  FAIL:", name)

def _energies(a: Float64, b: Float64, c: Float64, d: Float64, e: Float64) -> List[Float64]:
    var l = List[Float64]()
    l.append(a); l.append(b); l.append(c); l.append(d); l.append(e)
    return l^

def _uniform_supply() raises -> SupplyVector:
    # 六向等容量(各=8), quota=8 → 任一元素 capacity_factor=1
    var sv = SupplyVector()
    sv.set(EAST, 8.0); sv.set(WEST, 8.0); sv.set(SOUTH, 8.0)
    sv.set(NORTH, 8.0); sv.set(UP, 8.0); sv.set(DOWN, 8.0)
    sv.harmony = 1.0
    return sv^

def _empty_decision() -> ScheduleDecision:
    var d = ScheduleDecision()
    d.c_len = 0
    return d^

# ---------- abstract_level ----------
def test_abstract_level(mut c: Counter):
    c.check(abstract_level(EARTH) == 5, "土抽象度5")
    c.check(abstract_level(FIRE) == 3 and abstract_level(METAL) == 3, "火金抽象度3")
    c.check(abstract_level(WATER) == 2 and abstract_level(WOOD) == 2, "水木抽象度2")
    c.check(abstract_level(99) == 0, "越界抽象度0")

# ---------- capacity_factor ----------
def test_capacity_factor(mut c: Counter) raises:
    var uni = _uniform_supply()
    c.check(capacity_factor(uni, WOOD) == 1.0, "均匀供给 capacity_factor=1")
    # 构造 EAST(木) 容量为 0 的供给 → 木折扣为 0
    var low_east = _uniform_supply()
    low_east.set(EAST, 0.0)
    c.check(capacity_factor(low_east, WOOD) == 0.0, "EAST=0 时木折扣=0")
    c.check(capacity_factor(uni, 99) == 0.0, "越界元素折扣=0")

# ---------- priority_of / priority_list ----------
def test_priority(mut c: Counter) raises:
    var dec = schedule(_energies(4.0, 1.0, 1.0, 1.0, 1.0))  # 木主导
    var uni = _uniform_supply()
    # 权重随木增大而增 → 木优先级高于火(同 supply)
    c.check(priority_of(WOOD, dec, uni) > priority_of(FIRE, dec, uni), "权重高者优先级高")
    var pl = priority_list(dec, uni)
    c.check(len(pl) == 5, "priority_list 长度 5")
    # 容量打折后木优先级下降
    var low_east = _uniform_supply(); low_east.set(EAST, 0.0)
    c.check(priority_of(WOOD, dec, low_east) == 0.0, "木容量0→优先级0")

# ---------- order_chain ----------
def test_order_chain(mut c: Counter) raises:
    var dec = schedule(_energies(4.0, 1.0, 1.0, 1.0, 1.0))  # 木主导
    var uni = _uniform_supply()
    var ord = order_chain(dec, uni)
    c.check(len(ord) > 0, "order_chain 非空")
    # 降序: 首元素优先级 >= 次元素
    c.check(priority_of(ord[0], dec, uni) >= priority_of(ord[1], dec, uni), "降序排列")
    # 空链 raises
    var raised = False
    try:
        var _ = order_chain(_empty_decision(), uni)
    except:
        raised = True
    c.check(raised, "空候选链 raises")
    # 同优先级锚定: 木(抽象2)与火(抽象3) 权重相等时火在前
    var tie = ScheduleDecision()
    tie.set_weight(WOOD, 0.5); tie.set_weight(FIRE, 0.5)
    tie.append_chain(WOOD); tie.append_chain(FIRE); tie.c_len = 2
    var tied = order_chain(tie, uni)
    c.check(tied[0] == FIRE and tied[1] == WOOD, "同优先级抽象度高者前(火>木)")

# ---------- DecisionSequence / build_sequence ----------
def test_sequence(mut c: Counter) raises:
    var dec = schedule(_energies(4.0, 1.0, 1.0, 1.0, 1.0))
    var uni = _uniform_supply()
    var seq = build_sequence(dec, uni)
    c.check(seq.s_len > 0, "build_sequence 非空")
    var lst = seq.as_list()
    var ord = order_chain(dec, uni)
    c.check(len(lst) == len(ord), "as_list 长度=order_chain")
    var same = True
    for i in range(len(ord)):
        if lst[i] != ord[i]:
            same = False
    c.check(same, "as_list 与 order_chain 一致")
    # 取超出范围 step_at 返回 -1
    c.check(seq.step_at(99) == -1, "step_at 越界=-1")

def main() raises:
    var c = Counter()
    test_abstract_level(c)
    test_capacity_factor(c)
    test_priority(c)
    test_order_chain(c)
    test_sequence(c)
    print("qixing -> passed: ", c.passed, " failed: ", c.failed)
