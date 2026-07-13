# qixing/sequence.mojo — 决策链序列产出（七星·定序枢机之三）
# DecisionSequence 为有序执行链的 Movable 载体(固定八槽, 链长<=5 安全留余量)；
# build_sequence 包装 order_chain 结果为载体, 供 scheduler 派发。
# 运行: mojo run -I . -I core qixing/sequence.mojo
from wuxing.scheduler_core import ScheduleDecision
from liuhe import SupplyVector
from .ordering import order_chain

struct DecisionSequence(Movable):
    var s0: Int; var s1: Int; var s2: Int; var s3: Int
    var s4: Int; var s5: Int; var s6: Int; var s7: Int
    var s_len: Int
    def __init__(out self):
        self.s0 = -1; self.s1 = -1; self.s2 = -1; self.s3 = -1
        self.s4 = -1; self.s5 = -1; self.s6 = -1; self.s7 = -1
        self.s_len = 0
    def append(mut self, step: Int):
        if self.s_len == 0: self.s0 = step
        elif self.s_len == 1: self.s1 = step
        elif self.s_len == 2: self.s2 = step
        elif self.s_len == 3: self.s3 = step
        elif self.s_len == 4: self.s4 = step
        elif self.s_len == 5: self.s5 = step
        elif self.s_len == 6: self.s6 = step
        elif self.s_len == 7: self.s7 = step
        else: return
        self.s_len = self.s_len + 1
    def step_at(self, i: Int) -> Int:
        if i == 0: return self.s0
        if i == 1: return self.s1
        if i == 2: return self.s2
        if i == 3: return self.s3
        if i == 4: return self.s4
        if i == 5: return self.s5
        if i == 6: return self.s6
        if i == 7: return self.s7
        return -1
    def as_list(self) -> List[Int]:
        var l = List[Int]()
        for i in range(self.s_len):
            l.append(self.step_at(i))
        return l^

def build_sequence(decision: ScheduleDecision, supply: SupplyVector) raises -> DecisionSequence:
    var seq = DecisionSequence()
    var ordered = order_chain(decision, supply)
    for i in range(len(ordered)):
        seq.append(ordered[i])
    return seq^
