# === wuxing/scheduler_core.mojo ===
# 由生克派生的真实派发策略（替代 MVP 硬编码 set_weight）。
# 输入：五元素能量向量 → 派生 { 主导元素, 归一权重, 主导优势度(confidence), 相生决策链 }。
# 「相生构成万物长养的动力链」→ 决策链沿相生序从主导推进（母子相续）。
# 约束（Mojo 1.0.0b2）：ScheduleDecision 用固定标量槽（w0..w4 / c0..c4）避免 List 字段破坏 Movable，
#   使其可按值返回（同 src/wu_xing.mojo BalanceDecision 的做法）。
# 依赖：core、sheng_ke、sixiang（四象相位种子）。

from .elements import WOOD, FIRE, EARTH, METAL, WATER, ELEMENT_COUNT, NEUTRAL_ELEMENT
from .sheng_ke import sheng_next


# 调度决策载体：固定标量槽 → Movable，可按值返回。
struct ScheduleDecision(Movable):
    var dominant: Int         # 主导元素 id（最高能量）
    var w0: Float64           # 五元素归一调度权重
    var w1: Float64
    var w2: Float64
    var w3: Float64
    var w4: Float64
    var confidence: Float64   # 主导优势度（主导能量占总能量份额，0..1）
    var c0: Int               # 相生决策链（最多 5 位）
    var c1: Int
    var c2: Int
    var c3: Int
    var c4: Int
    var c_len: Int

    def __init__(out self):
        self.dominant = NEUTRAL_ELEMENT
        self.w0 = 0.0
        self.w1 = 0.0
        self.w2 = 0.0
        self.w3 = 0.0
        self.w4 = 0.0
        self.confidence = 0.0
        self.c0 = -1
        self.c1 = -1
        self.c2 = -1
        self.c3 = -1
        self.c4 = -1
        self.c_len = 0

    def weight(self, idx: Int) -> Float64:
        if idx == 0: return self.w0
        if idx == 1: return self.w1
        if idx == 2: return self.w2
        if idx == 3: return self.w3
        if idx == 4: return self.w4
        return 0.0

    def set_weight(mut self, idx: Int, v: Float64):
        if idx == 0: self.w0 = v
        elif idx == 1: self.w1 = v
        elif idx == 2: self.w2 = v
        elif idx == 3: self.w3 = v
        elif idx == 4: self.w4 = v

    def chain_at(self, i: Int) -> Int:
        if i == 0: return self.c0
        if i == 1: return self.c1
        if i == 2: return self.c2
        if i == 3: return self.c3
        if i == 4: return self.c4
        return -1

    def append_chain(mut self, e: Int):
        if self.c_len == 0: self.c0 = e
        elif self.c_len == 1: self.c1 = e
        elif self.c_len == 2: self.c2 = e
        elif self.c_len == 3: self.c3 = e
        elif self.c_len == 4: self.c4 = e
        else: return
        self.c_len += 1

    def weights_list(self) -> List[Float64]:
        var l = List[Float64]()
        l.append(self.w0); l.append(self.w1); l.append(self.w2)
        l.append(self.w3); l.append(self.w4)
        return l^

    def chain_list(self) -> List[Int]:
        var l = List[Int]()
        for i in range(self.c_len):
            l.append(self.chain_at(i))
        return l^


# 主导元素 = 能量最高者（argmax；平局取小 id）
def dominant_element(energies: List[Float64]) -> Int:
    var best = 0
    var best_v = energies[0]
    for i in range(1, len(energies)):
        if energies[i] > best_v:
            best_v = energies[i]
            best = i
    return best


# 依五元素能量 + 生克网络派生调度决策。
# 权重 = 归一能量（各 / 总）；confidence = 主导能量份额；决策链 = 相生序从主导起 3 位。
def schedule(energies: List[Float64]) raises -> ScheduleDecision:
    if len(energies) != ELEMENT_COUNT:
        raise Error("wuxing: schedule requires exactly 5 element energies")
    var total = 0.0
    for i in range(ELEMENT_COUNT):
        if energies[i] < 0.0:
            raise Error("wuxing: negative energy is illegal")
        total += energies[i]
    if total <= 0.0:
        raise Error("wuxing: cannot schedule zero total energy")

    var d = ScheduleDecision()
    var dom = dominant_element(energies)
    d.dominant = dom
    for i in range(ELEMENT_COUNT):
        d.set_weight(i, energies[i] / total)
    d.confidence = energies[dom] / total

    # 相生决策链：dominant → 子 → 孙（母子相续动力链，长度 3）
    var cur = dom
    for _k in range(3):
        d.append_chain(cur)
        cur = sheng_next(cur)
    return d^


# 由 sixiang 四象相位种子派生调度决策：
# 四象 → 五行（四象 + 中土 = 五行）：老阴(0)→水、少阳(1)→木、老阳(2)→火、少阴(3)→金，越界→土(中枢)。
# 种子元素得满 intensity，其子(相生)得半 intensity，余者得基线 0.1*intensity。
def schedule_from_phase(quadrant_index: Int, intensity: Float64) raises -> ScheduleDecision:
    var seed: Int
    if quadrant_index == 0: seed = WATER
    elif quadrant_index == 1: seed = WOOD
    elif quadrant_index == 2: seed = FIRE
    elif quadrant_index == 3: seed = METAL
    else: seed = EARTH

    var base = 0.1 * intensity
    if base < 0.0:
        raise Error("wuxing: negative intensity is illegal")
    var e = List[Float64]()
    for _i in range(ELEMENT_COUNT):
        e.append(base)
    e[seed] = intensity if intensity > 0.0 else 1.0
    var child = sheng_next(seed)
    e[child] = 0.5 * e[seed]
    return schedule(e)
