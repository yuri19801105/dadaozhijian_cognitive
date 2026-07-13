# scheduler/tests/test_scheduler.mojo — 总调度模块 TDD 测试（零桩函数）
# 运行: mojo run -I . -I core scheduler/tests/test_scheduler.mojo
from scheduler import (
    dispatch, dispatch_from_phase, DispatchPlan, default_policy, apply_policy, SchedulerPolicy,
)
from wuxing import schedule, schedule_from_phase
from liuhe import build_supply, SupplyVector
from qixing import build_sequence

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

def _supply(e: List[Float64], focus: Float64, md: Int, cd: Int, g: Int) raises -> SupplyVector:
    return build_supply(e, focus, md, cd, g)

# ---------- DispatchPlan 载体 ----------
def test_plan_vector(mut c: Counter):
    var p = DispatchPlan()
    c.check(p.s_len == 0 and p.confidence == 0.0 and p.policy_id == 0, "初始化")
    p.append(3); p.append(1); p.append(4)
    c.check(p.s_len == 3, "append 后长度3")
    c.check(p.step_at(0) == 3 and p.step_at(2) == 4, "step_at 顺序")
    var lst = p.as_list()
    c.check(len(lst) == 3 and lst[1] == 1, "as_list 正确")
    c.check(p.step_at(99) == -1, "step_at 越界=-1")

# ---------- dispatch 端到端 ----------
def test_dispatch(mut c: Counter) raises:
    var e = _energies(4.0, 1.0, 1.0, 1.0, 1.0)
    var plan = dispatch(e, 5.0, 8, 3, 25)
    c.check(plan.s_len > 0, "dispatch 产出非空链")
    # confidence 透传 wuxing
    var dec = schedule(e)
    c.check(plan.confidence == dec.confidence, "confidence 透传")
    # seq 与 qixing.build_sequence 一致
    var expected = build_sequence(dec, _supply(e, 5.0, 8, 3, 25)).as_list()
    var got = plan.as_list()
    var same = len(got) == len(expected)
    for i in range(len(expected)):
        if got[i] != expected[i]:
            same = False
    c.check(same, "dispatch 链=qixing 排序结果")
    # 策略装配: 正常路径 policy_id>=0(降级也不崩溃)
    c.check(plan.policy_id >= 0, "policy_id 装配成功(>=0)")

# ---------- dispatch 错误处理 ----------
def test_dispatch_errors(mut c: Counter) raises:
    var bad = List[Float64]()
    bad.append(1.0); bad.append(2.0); bad.append(3.0)   # 长度=3 ≠ 5
    var raised = False
    try:
        var _ = dispatch(bad, 5.0, 8, 3, 25)
    except:
        raised = True
    c.check(raised, "能量长度≠5 → dispatch raises")
    # 上下文非法
    raised = False
    try:
        var _ = dispatch(_energies(1.0,1.0,1.0,1.0,1.0), 5.0, 0, 3, 25)
    except:
        raised = True
    c.check(raised, "max_depth<=0 → dispatch raises")

# ---------- dispatch_from_phase ----------
def test_dispatch_from_phase(mut c: Counter) raises:
    var plan = dispatch_from_phase(2, 5.0, 5.0, 8, 3, 25)   # 老阳→火
    c.check(plan.s_len > 0, "from_phase 产出非空链")
    c.check(plan.confidence >= 0.0 and plan.confidence <= 1.0, "confidence ∈ [0,1]")
    c.check(plan.policy_id >= 0, "from_phase policy_id 装配成功")

# ---------- policy ----------
def test_policy(mut c: Counter):
    var pol = default_policy()
    c.check(pol.policy_id == 0 and pol.gen_rate > 0.0 and pol.ke_rate > 0.0, "默认策略")
    var p = DispatchPlan()
    p.append(1)
    apply_policy(p, pol)
    c.check(p.policy_id == 0, "apply_policy 设置 policy_id")

def main() raises:
    var c = Counter()
    test_plan_vector(c)
    test_dispatch(c)
    test_dispatch_errors(c)
    test_dispatch_from_phase(c)
    test_policy(c)
    print("scheduler -> passed: ", c.passed, " failed: ", c.failed)
