# qixing/ordering.mojo — 决策链排序（七星·定序枢机之二）
# 取 wuxing.ScheduleDecision 的相生链为候选步骤集 → 按 priority_of 降序选择排序
# （含 abstract_level 同优先级锚定）；空候选链 raises。纯函数、确定性。
# 运行: mojo run -I . -I core qixing/ordering.mojo
from wuxing.scheduler_core import ScheduleDecision
from liuhe import SupplyVector
from .priority import abstract_level, priority_of

def _better(a: Int, b: Int, decision: ScheduleDecision, supply: SupplyVector) raises -> Bool:
    # a 应排在 b 之前? 优先级高者前; 同优先级抽象度高者前
    var pa = priority_of(a, decision, supply)
    var pb = priority_of(b, decision, supply)
    if pa != pb:
        return pa > pb
    return abstract_level(a) > abstract_level(b)

def order_chain(decision: ScheduleDecision, supply: SupplyVector) raises -> List[Int]:
    # 1. 取相生链候选, 去重, 去 -1
    var chain = decision.chain_list()
    var steps = List[Int]()
    for i in range(len(chain)):
        var s = chain[i]
        if s < 0:
            continue
        var dup = False
        for j in range(len(steps)):
            if steps[j] == s:
                dup = True
        if not dup:
            steps.append(s)
    if len(steps) == 0:
        raise Error("order_chain: 候选链为空")
    # 2. 选择排序(降序, 含抽象度锚定)
    var n = len(steps)
    for i in range(n):
        var bi = i
        for j in range(i + 1, n):
            if _better(steps[j], steps[bi], decision, supply):
                bi = j
        if bi != i:
            var tmp = steps[i]
            steps[i] = steps[bi]
            steps[bi] = tmp
    return steps^
