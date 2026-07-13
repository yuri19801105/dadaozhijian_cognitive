# liuhe/supply.mojo — 由五行策略 + 上下文派生六向供给向量（六合之供给义）
# 六合对调度脑"供给"资源/上下文：把 wuxing 能量 + 上下文（焦点/最大深度/链深/接地）
# 投影为六向容量向量，并派生整体和合度(harmony)。SupplyVector 用固定标量槽保 Movable 可按值返回。
# 运行: mojo run -I . -I core liuhe/supply.mojo
from math.ops import clamp
from wuxing.elements import ELEMENT_COUNT, NEUTRAL_ELEMENT
from wuxing.balance import total_energy, variance
from .directions import EAST, WEST, SOUTH, NORTH, UP, DOWN, DIRECTION_COUNT

def _mini(a: Int, b: Int) -> Int:
    return a if a < b else b

struct SupplyVector(Movable):
    var s0: Float64; var s1: Float64; var s2: Float64
    var s3: Float64; var s4: Float64; var s5: Float64
    var harmony: Float64
    def __init__(out self):
        self.s0 = 0.0; self.s1 = 0.0; self.s2 = 0.0
        self.s3 = 0.0; self.s4 = 0.0; self.s5 = 0.0
        self.harmony = 0.0
    def get(self, dir: Int) raises -> Float64:
        if dir == EAST: return self.s0
        if dir == WEST: return self.s1
        if dir == SOUTH: return self.s2
        if dir == NORTH: return self.s3
        if dir == UP: return self.s4
        if dir == DOWN: return self.s5
        raise Error("SupplyVector.get: 方向越界")
    def set(mut self, dir: Int, v: Float64) raises:
        if dir == EAST: self.s0 = v; return
        if dir == WEST: self.s1 = v; return
        if dir == SOUTH: self.s2 = v; return
        if dir == NORTH: self.s3 = v; return
        if dir == UP: self.s4 = v; return
        if dir == DOWN: self.s5 = v; return
        raise Error("SupplyVector.set: 方向越界")
    def as_list(self) -> List[Float64]:
        var l = List[Float64]()
        l.append(self.s0); l.append(self.s1); l.append(self.s2)
        l.append(self.s3); l.append(self.s4); l.append(self.s5)
        return l^
    def capacity(self, dir: Int) raises -> Float64:
        return self.get(dir)
    def is_valid(self) -> Bool:
        return (self.s0 >= 0.0 and self.s1 >= 0.0 and self.s2 >= 0.0
                and self.s3 >= 0.0 and self.s4 >= 0.0 and self.s5 >= 0.0)

def build_supply(energies: List[Float64], focus: Float64,
                 max_depth: Int, chain_depth: Int, ground: Int) raises -> SupplyVector:
    # 上下文校验（能量合法性由 wuxing.schedule 保证；此处校验供给上下文）
    if max_depth <= 0:
        raise Error("build_supply: max_depth 须 > 0")
    if chain_depth < 0:
        raise Error("build_supply: chain_depth 须 >= 0")
    if ground < 0:
        raise Error("build_supply: ground 须 >= 0")
    var total = total_energy(energies)
    var sv = SupplyVector()
    sv.s0 = clamp(total, 0.0, 1e9)                       # EAST: 容量基(总能量)
    var west = max_depth - chain_depth
    sv.s1 = Float64(west) if west > 0 else 0.0           # WEST: 链深余量
    sv.s2 = clamp(focus, 0.0, 1e9)                       # SOUTH: 焦点强度
    sv.s3 = Float64(max_depth)                           # NORTH: 最大深度配额
    sv.s4 = Float64(_mini(9, chain_depth / 2))           # UP: 上升余量(截断)
    sv.s5 = Float64(_mini(9, ground / 5))               # DOWN: 接地余量(截断)
    var v = variance(energies)
    sv.harmony = clamp(1.0 / (1.0 + v), 0.0, 1.0)        # 越均衡越和合(0..1)
    return sv^
