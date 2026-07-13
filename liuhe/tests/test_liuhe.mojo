# liuhe/tests/test_liuhe.mojo — 六合模块 TDD 测试（零桩函数）
# 运行: mojo run -I . -I core liuhe/tests/test_liuhe.mojo
from liuhe import (
    EAST, WEST, SOUTH, NORTH, UP, DOWN, DIRECTION_COUNT,
    direction_name, opposite, axis_of, element_direction,
    SupplyVector, build_supply,
    he_harmony, harmony_index, merge_supplies, BRANCH_COUNT,
)
from wuxing.elements import WOOD, FIRE, EARTH, METAL, WATER, NEUTRAL_ELEMENT

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

# ---------- directions ----------
def test_directions(mut c: Counter):
    var ids = List[Int]()
    ids.append(EAST); ids.append(WEST); ids.append(SOUTH)
    ids.append(NORTH); ids.append(UP); ids.append(DOWN)
    var ordered = True
    for i in range(6):
        if ids[i] != i:
            ordered = False
    c.check(ordered, "方向常量按 0..5 有序")
    c.check(DIRECTION_COUNT == 6, "DIRECTION_COUNT==6")
    c.check(direction_name(EAST) == "东", "东名")
    c.check(direction_name(DOWN) == "下", "下名")
    c.check(opposite(EAST) == WEST, "东西互反")
    c.check(opposite(SOUTH) == NORTH, "南北互反")
    c.check(opposite(UP) == DOWN, "上下互反")
    c.check(opposite(7) == -1, "无效方向 opposite=-1")
    c.check(axis_of(EAST) == 0 and axis_of(WEST) == 0, "东西属横轴0")
    c.check(axis_of(SOUTH) == 1 and axis_of(NORTH) == 1, "南北属纵轴1")
    c.check(axis_of(UP) == 2 and axis_of(DOWN) == 2, "上下属竖轴2")
    c.check(axis_of(9) == -1, "无效方向 axis_of=-1")
    c.check(element_direction(WOOD) == EAST, "木→东")
    c.check(element_direction(FIRE) == SOUTH, "火→南")
    c.check(element_direction(METAL) == WEST, "金→西")
    c.check(element_direction(WATER) == NORTH, "水→北")
    c.check(element_direction(EARTH) == UP, "土→上(中)")
    c.check(element_direction(99) == -1, "无效元素 element_direction=-1")

# ---------- SupplyVector 载体 ----------
def test_supply_vector(mut c: Counter) raises:
    var sv = SupplyVector()
    c.check(sv.s0 == 0.0 and sv.s5 == 0.0 and sv.harmony == 0.0, "初始化全 0")
    sv.set(EAST, 3.0)
    sv.set(NORTH, 9.0)
    c.check(sv.get(EAST) == 3.0, "set/get EAST")
    c.check(sv.get(NORTH) == 9.0, "set/get NORTH")
    var raised = False
    try:
        var _ = sv.get(7)
    except:
        raised = True
    c.check(raised, "get 越界 raises")
    raised = False
    try:
        sv.set(99, 1.0)
    except:
        raised = True
    c.check(raised, "set 越界 raises")
    var l = sv.as_list()
    c.check(len(l) == 6, "as_list 长度 6")
    c.check(sv.capacity(WEST) == 0.0, "capacity 默认 0")
    var sv2 = SupplyVector()
    c.check(sv2.is_valid(), "全非负 is_valid")
    sv2.set(SOUTH, -1.0)
    c.check(not sv2.is_valid(), "含负 is_valid=False")

# ---------- build_supply ----------
def test_build_supply(mut c: Counter) raises:
    var e = _energies(1.0, 2.0, 3.0, 2.0, 1.0)
    var sv = build_supply(e, 5.0, 8, 3, 25)
    c.check(sv.get(EAST) == 9.0, "EAST=总能量9")
    c.check(sv.get(WEST) == 5.0, "WEST=max_depth-chain=5")
    c.check(sv.get(SOUTH) == 5.0, "SOUTH=focus=5")
    c.check(sv.get(NORTH) == 8.0, "NORTH=max_depth=8")
    c.check(sv.get(UP) == 1.0, "UP=chain/2=1")
    c.check(sv.get(DOWN) == 5.0, "DOWN=ground/5=5")
    c.check(sv.harmony > 0.0 and sv.harmony <= 1.0, "harmony 在 (0,1]")
    c.check(sv.is_valid(), "build 结果 is_valid")
    # 越界校验
    var r1 = False
    try:
        var _ = build_supply(e, 1.0, 0, 1, 1)
    except:
        r1 = True
    c.check(r1, "max_depth<=0 raises")
    var r2 = False
    try:
        var _ = build_supply(e, 1.0, 5, -1, 1)
    except:
        r2 = True
    c.check(r2, "chain_depth<0 raises")
    var r3 = False
    try:
        var _ = build_supply(e, 1.0, 5, 1, -2)
    except:
        r3 = True
    c.check(r3, "ground<0 raises")
    # 越界链深: west 余量截断为 0
    var svb = build_supply(e, 1.0, 2, 5, 0)
    c.check(svb.get(WEST) == 0.0, "chain>max_depth 时 WEST=0")

# ---------- harmony 地支六合 ----------
def test_harmony(mut c: Counter):
    c.check(he_harmony(0, 1) == EARTH, "子丑合土")
    c.check(he_harmony(2, 11) == WOOD, "寅亥合木")
    c.check(he_harmony(3, 10) == FIRE, "卯戌合火")
    c.check(he_harmony(4, 9) == METAL, "辰酉合金")
    c.check(he_harmony(5, 8) == WATER, "巳申合水")
    c.check(he_harmony(6, 7) == EARTH, "午未合土")
    c.check(he_harmony(1, 0) == EARTH, "无序对等价(子丑)")
    c.check(he_harmony(0, 2) == NEUTRAL_ELEMENT, "非六合对降级中性(土)")
    c.check(harmony_index(0, 1) == 1.0, "六合对 index=1")
    c.check(harmony_index(2, 11) == 1.0, "寅亥 index=1")
    c.check(harmony_index(0, 3) == 0.0, "非六合对 index=0")
    c.check(BRANCH_COUNT == 12, "BRANCH_COUNT==12")

# ---------- merge_supplies ----------
def test_merge(mut c: Counter) raises:
    var a = SupplyVector()
    a.set(EAST, 2.0); a.set(SOUTH, 1.0); a.set(NORTH, 4.0); a.harmony = 0.3
    var b = SupplyVector()
    b.set(EAST, 5.0); b.set(WEST, 3.0); b.set(NORTH, 4.0); b.harmony = 0.7
    var m = merge_supplies(a, b)
    c.check(m.get(EAST) == 5.0, "merge EAST=max(2,5)")
    c.check(m.get(WEST) == 3.0, "merge WEST=max(0,3)")
    c.check(m.get(SOUTH) == 1.0, "merge SOUTH=max(1,0)")
    c.check(m.get(NORTH) == 4.0, "merge NORTH=max(4,4)")
    c.check(m.harmony == 0.7, "merge harmony=max(0.3,0.7)")
    c.check(m.is_valid(), "merge 结果 is_valid")

def main() raises:
    var c = Counter()
    test_directions(c)
    test_supply_vector(c)
    test_build_supply(c)
    test_harmony(c)
    test_merge(c)
    print("liuhe -> passed: ", c.passed, " failed: ", c.failed)
