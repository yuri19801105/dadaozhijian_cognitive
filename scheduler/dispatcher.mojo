# scheduler/dispatcher.mojo — 统一派发器（总调度总成）
# 把 wuxing(策略) + liuhe(供给) + qixing(排序) 合成为唯一派发器 DispatchPlan。
#   dispatch(energies, focus, max_depth, chain_depth, ground):
#     1. wuxing.schedule(energies)            → ScheduleDecision(策略)
#     2. liuhe.build_supply(...)               → SupplyVector(供给)
#     3. qixing.build_sequence(...)            → DecisionSequence(有序链)
#     4. 封装 DispatchPlan{ seq, confidence, policy_id }
# 错误处理: 子模块 raises 透传(调用方决定重试/静默); 策略装配失败 → policy_id=-1(降级)。
# 运行: mojo run -I . -I core scheduler/dispatcher.mojo
from wuxing import schedule, schedule_from_phase, ScheduleDecision
from liuhe import build_supply
from qixing import build_sequence, DecisionSequence
from .policy import SchedulerPolicy, default_policy

struct DispatchPlan(Movable):
    var s0: Int; var s1: Int; var s2: Int; var s3: Int
    var s4: Int; var s5: Int; var s6: Int; var s7: Int
    var s_len: Int
    var confidence: Float64
    var policy_id: Int
    def __init__(out self):
        self.s0 = -1; self.s1 = -1; self.s2 = -1; self.s3 = -1
        self.s4 = -1; self.s5 = -1; self.s6 = -1; self.s7 = -1
        self.s_len = 0; self.confidence = 0.0; self.policy_id = 0
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

def _copy_seq(mut plan: DispatchPlan, seq: DecisionSequence):
    for i in range(seq.s_len):
        plan.append(seq.step_at(i))

def _policy_id_safe() -> Int:
    # 策略装配: 默认策略(当前构造不会失败 → policy_id=0)。
    # 预留降级: 未来可插拔策略若装配失败, 此处回退 -1(降级, 不崩溃),
    # 调用方以 plan.policy_id >= 0 判定正常、== -1 判定降级。
    return default_policy().policy_id

def dispatch(energies: List[Float64], focus: Float64, max_depth: Int,
             chain_depth: Int, ground: Int) raises -> DispatchPlan:
    var decision = schedule(energies)                              # raises: 能量非法
    var supply = build_supply(energies, focus, max_depth, chain_depth, ground)  # raises: 上下文非法
    var seq = build_sequence(decision, supply)                     # raises: 空候选链
    var plan = DispatchPlan()
    _copy_seq(plan, seq)
    plan.confidence = decision.confidence
    plan.policy_id = _policy_id_safe()
    return plan^

def dispatch_from_phase(quadrant: Int, intensity: Float64, focus: Float64,
                        max_depth: Int, chain_depth: Int, ground: Int) raises -> DispatchPlan:
    var decision = schedule_from_phase(quadrant, intensity)        # raises: 相位/强度非法
    var energies = decision.weights_list()                        # 权重作能量代理供 build_supply
    var supply = build_supply(energies, focus, max_depth, chain_depth, ground)
    var seq = build_sequence(decision, supply)
    var plan = DispatchPlan()
    _copy_seq(plan, seq)
    plan.confidence = decision.confidence
    plan.policy_id = _policy_id_safe()
    return plan^

def apply_policy(mut plan: DispatchPlan, policy: SchedulerPolicy):
    plan.policy_id = policy.policy_id
