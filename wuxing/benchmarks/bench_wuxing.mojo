# === wuxing/benchmarks/bench_wuxing.mojo ===
# 五行基准：1M 次 ns/op。用 sink 反馈 + 连续变化种子驱动输入防 DCE/常量折叠；
#   clock extern 计时（C clock() 微秒 ×1000 = ns 估算）。
# 运行: mojo run -I . -I core wuxing/benchmarks/bench_wuxing.mojo

from math.ops import abs_f64
from wuxing.sheng_ke import sheng_next, ke_target, relation, propagate
from wuxing.scheduler_core import schedule, dominant_element
from wuxing.balance import variance, rebalance, normalize


@extern("clock")
def clock() abi("C") -> Int:
    ...


# 生克关系表查询（sheng_next + ke_target + relation）——纯整型热路径
def bench_sheng_ke(n: Int) raises -> Float64:
    var sink = 0
    var start = clock()
    for i in range(n):
        var a = i % 5
        var b = (i + 2) % 5
        sink += sheng_next(a) + ke_target(a) + relation(a, b)
    var end = clock()
    var ns = Float64(end - start) * 1000.0
    if sink == 0:
        print("sink guard")
    return ns / Float64(n)


# 一轮生克传播（5 元素正/负反馈）——含 List 分配
def bench_propagate(n: Int) raises -> Float64:
    var sink = 0.0
    var start = clock()
    for i in range(n):
        var e = List[Float64]()
        e.append(Float64(i % 7) + 1.0)
        e.append(Float64(i % 5) + 1.0)
        e.append(Float64(i % 3) + 1.0)
        e.append(Float64(i % 11) + 1.0)
        e.append(Float64(i % 13) + 1.0)
        var out = propagate(e, 0.3, 0.2)
        sink += out[0] + out[4]
    var end = clock()
    var ns = Float64(end - start) * 1000.0
    if sink == 0.0:
        print("sink guard")
    return ns / Float64(n)


# 由能量向量派生调度决策（argmax + 归一 + 相生链）
def bench_schedule(n: Int) raises -> Float64:
    var sink = 0.0
    var start = clock()
    for i in range(n):
        var e = List[Float64]()
        e.append(Float64(i % 7) + 1.0)
        e.append(Float64(i % 5) + 1.0)
        e.append(Float64(i % 3) + 1.0)
        e.append(Float64(i % 11) + 1.0)
        e.append(Float64(i % 13) + 1.0)
        var d = schedule(e)
        sink += d.confidence + Float64(d.dominant) + Float64(d.chain_at(1))
    var end = clock()
    var ns = Float64(end - start) * 1000.0
    if sink == 0.0:
        print("sink guard")
    return ns / Float64(n)


# 均衡再平衡（抑亢补弱，降方差保总量）
def bench_rebalance(n: Int) raises -> Float64:
    var sink = 0.0
    var start = clock()
    for i in range(n):
        var e = List[Float64]()
        e.append(Float64(i % 17) + 1.0)
        e.append(Float64(i % 5) + 1.0)
        e.append(Float64(i % 3) + 1.0)
        e.append(Float64(i % 11) + 1.0)
        e.append(Float64(i % 2) + 1.0)
        var out = rebalance(e)
        sink += variance(out)
    var end = clock()
    var ns = Float64(end - start) * 1000.0
    if sink == 0.0:
        print("sink guard")
    return ns / Float64(n)


def main() raises:
    var n = 1000000
    var t_sk = bench_sheng_ke(n)
    var t_prop = bench_propagate(n)
    var t_sched = bench_schedule(n)
    var t_reb = bench_rebalance(n)
    print("wuxing benchmark (ns/op, N=" + String(n) + "):")
    print("  sheng_ke   : " + String(t_sk))
    print("  propagate  : " + String(t_prop))
    print("  schedule   : " + String(t_sched))
    print("  rebalance  : " + String(t_reb))
