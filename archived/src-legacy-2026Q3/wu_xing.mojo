# 五行 - 动态平衡调度器
# 根据认知状态决定八卦算子序列
# 语言: Mojo 1.0.0b2 | 验证: TDD

from workspace import Workspace
from trigram import TrigramAction, CHIEN, KUN, ZHEN, XUN, KAN, LI, GEN, DUI, apply_trigram, apply_chain

comptime WOOD: Int = 0
comptime FIRE: Int = 1
comptime EARTH: Int = 2
comptime METAL: Int = 3
comptime WATER: Int = 4

struct PhaseSignal(ImplicitlyCopyable):
    var phase: Int
    var data_tag: Int
    var intensity: Int

    def __init__(out self):
        self.phase = WOOD
        self.data_tag = 0
        self.intensity = 5

    def __copy_init__(out self, other: Self):
        self.phase = other.phase
        self.data_tag = other.data_tag
        self.intensity = other.intensity

# 五行权重索引: 0=WOOD 1=FIRE 2=EARTH 3=METAL 4=WATER
# trigram_chain 最多 2 个算子
struct BalanceDecision(ImplicitlyCopyable):
    var w0: Int
    var w1: Int
    var w2: Int
    var w3: Int
    var w4: Int
    var confidence: Int
    var t0: Int
    var t1: Int
    var t_len: Int

    def __init__(out self):
        self.w0 = 5
        self.w1 = 5
        self.w2 = 5
        self.w3 = 5
        self.w4 = 5
        self.confidence = 5
        self.t0 = -1
        self.t1 = -1
        self.t_len = 0

    def __copy_init__(out self, other: Self):
        self.w0 = other.w0
        self.w1 = other.w1
        self.w2 = other.w2
        self.w3 = other.w3
        self.w4 = other.w4
        self.confidence = other.confidence
        self.t0 = other.t0
        self.t1 = other.t1
        self.t_len = other.t_len

    def weight(mut self, idx: Int) -> Int:
        if idx == 0: return self.w0
        elif idx == 1: return self.w1
        elif idx == 2: return self.w2
        elif idx == 3: return self.w3
        elif idx == 4: return self.w4
        return 0

    def set_weight(mut self, idx: Int, val: Int):
        if idx == 0: self.w0 = val
        elif idx == 1: self.w1 = val
        elif idx == 2: self.w2 = val
        elif idx == 3: self.w3 = val
        elif idx == 4: self.w4 = val

    def chain(mut self, idx: Int) -> Int:
        if idx == 0: return self.t0
        elif idx == 1: return self.t1
        return -1

    def append_chain(mut self, trig: Int):
        if self.t_len == 0:
            self.t0 = trig
            self.t_len = 1
        elif self.t_len == 1:
            self.t1 = trig
            self.t_len = 2

    def chain_to_list(mut self) -> List[Int]:
        var result = List[Int]()
        for i in range(self.t_len):
            result.append(self.chain(i))
        return result^

    def set_from_list(mut self, lst: List[Int]):
        self.t0 = -1
        self.t1 = -1
        self.t_len = 0
        for i in range(len(lst)):
            self.append_chain(lst[i])


def _min(a: Int, b: Int) -> Int:
    return a if a < b else b

def _max(a: Int, b: Int) -> Int:
    return a if a > b else b

def _clamp(v: Int) -> Int:
    return _max(0, _min(9, v))


# ----- 相生相克网络 -----

def generate_next(phase: Int) -> Int:
    if phase == WOOD: return FIRE
    elif phase == FIRE: return EARTH
    elif phase == EARTH: return METAL
    elif phase == METAL: return WATER
    elif phase == WATER: return WOOD
    return WOOD

def restrain_target(phase: Int) -> Int:
    if phase == WOOD: return EARTH
    elif phase == FIRE: return METAL
    elif phase == EARTH: return WATER
    elif phase == METAL: return WOOD
    elif phase == WATER: return FIRE
    return WOOD

# ----- 过载保护 (8 trigram types) -----

struct OverloadCounter(ImplicitlyCopyable):
    var c0: Int; var c1: Int; var c2: Int; var c3: Int
    var c4: Int; var c5: Int; var c6: Int; var c7: Int
    var last: Int

    def __init__(out self):
        self.c0 = 0; self.c1 = 0; self.c2 = 0; self.c3 = 0
        self.c4 = 0; self.c5 = 0; self.c6 = 0; self.c7 = 0
        self.last = -1

    def __copy_init__(out self, other: Self):
        self.c0 = other.c0; self.c1 = other.c1
        self.c2 = other.c2; self.c3 = other.c3
        self.c4 = other.c4; self.c5 = other.c5
        self.c6 = other.c6; self.c7 = other.c7
        self.last = other.last

    def _get_count(mut self, trig: Int) -> Int:
        if trig == 0: return self.c0
        elif trig == 1: return self.c1
        elif trig == 2: return self.c2
        elif trig == 3: return self.c3
        elif trig == 4: return self.c4
        elif trig == 5: return self.c5
        elif trig == 6: return self.c6
        elif trig == 7: return self.c7
        return 0

    def _inc(mut self, trig: Int):
        if trig == 0: self.c0 += 1
        elif trig == 1: self.c1 += 1
        elif trig == 2: self.c2 += 1
        elif trig == 3: self.c3 += 1
        elif trig == 4: self.c4 += 1
        elif trig == 5: self.c5 += 1
        elif trig == 6: self.c6 += 1
        elif trig == 7: self.c7 += 1

    def track(mut self, trig: Int) -> Bool:
        if trig < 0 or trig > 7: return False
        if trig == self.last:
            self._inc(trig)
            return self._get_count(trig) <= 3
        self.last = trig
        self._inc(trig)
        return True


# ----- 调度器入口 -----

def schedule(ws: Workspace, signal: PhaseSignal) -> BalanceDecision:
    var d = BalanceDecision()
    d.confidence = _min(9, signal.intensity)

    if signal.phase == WOOD:
        var branches = 0
        for i in range(3):
            for j in range(3):
                if ws.grid[i][j] < 0: branches += 1
        d.set_weight(WOOD, _min(9, signal.intensity + branches))
        d.set_weight(FIRE, 3)
        d.set_weight(EARTH, 2)
        d.set_weight(METAL, 1)
        d.set_weight(WATER, 4)
        d.append_chain(ZHEN)
        d.append_chain(XUN)

    elif signal.phase == FIRE:
        d.set_weight(WOOD, 3)
        d.set_weight(FIRE, _min(9, signal.intensity + 3))
        d.set_weight(EARTH, 4)
        d.set_weight(METAL, 2)
        d.set_weight(WATER, 1)
        d.append_chain(LI)
        d.append_chain(KAN)

    elif signal.phase == EARTH:
        d.set_weight(WOOD, 2)
        d.set_weight(FIRE, 4)
        d.set_weight(EARTH, _min(9, signal.intensity + 2))
        d.set_weight(METAL, 3)
        d.set_weight(WATER, 1)
        d.append_chain(KUN)
        d.append_chain(GEN)

    elif signal.phase == METAL:
        d.set_weight(WOOD, 1)
        d.set_weight(FIRE, 2)
        d.set_weight(EARTH, 3)
        d.set_weight(METAL, _min(9, signal.intensity + 2))
        d.set_weight(WATER, 4)
        d.append_chain(DUI)
        d.append_chain(GEN)

    elif signal.phase == WATER:
        d.set_weight(WOOD, 4)
        d.set_weight(FIRE, 1)
        d.set_weight(EARTH, 2)
        d.set_weight(METAL, 3)
        d.set_weight(WATER, _min(9, signal.intensity + 3))
        d.append_chain(CHIEN)
        d.append_chain(KAN)

    else:
        d.append_chain(DUI)
        return d

    # 相生 +1
    var gen = generate_next(signal.phase)
    d.set_weight(gen, _clamp(d.weight(gen) + 1))

    # 相克 -2
    var res = restrain_target(signal.phase)
    d.set_weight(res, _clamp(d.weight(res) - 2))

    # 过载过滤
    var oc = OverloadCounter()
    var filtered = List[Int]()
    for i in range(d.t_len):
        var t = d.chain(i)
        if oc.track(t):
            filtered.append(t)
    d.set_from_list(filtered)

    return d


def wu_xing_cycle(ws: Workspace, intensity: Int) -> List[Int]:
    var results = List[Int]()
    var phases = List[Int]()
    phases.append(WOOD)
    phases.append(FIRE)
    phases.append(EARTH)
    phases.append(METAL)
    phases.append(WATER)
    for i in range(5):
        var sig = PhaseSignal()
        sig.phase = phases[i]
        sig.intensity = intensity
        var d = schedule(ws, sig)
        results.append(d.t_len)
    return results^
