# === bagua/benchmarks/bench_bagua.mojo ===
# 八卦基准：1M 次 ns/op。用 sink 反馈驱动输入防 DCE/常量折叠；clock extern 计时（微秒×1000=ns）。
# 运行: mojo run -I . -I core bagua/benchmarks/bench_bagua.mojo

from liangyi.dual import Dual
from math.ops import abs_f64
from bagua.trigrams import trigram_by_id
from bagua.operators import apply
from bagua.combine import combine


@extern("clock")
def clock() abi("C") -> Int:
    ...


def bench_trigram_lines(n: Int) raises -> Float64:
    var sink = 0.0
    var start = clock()
    for i in range(n):
        var t = trigram_by_id(i % 8)
        var ls = t.lines()
        sink += abs_f64(ls[0].get_value()) + abs_f64(ls[1].get_value()) + abs_f64(ls[2].get_value())
    var end = clock()
    var ns = Float64(end - start) * 1000.0
    if sink == 0.0:
        print("sink guard")
    return ns / Float64(n)


def bench_apply(n: Int) raises -> Float64:
    var sink = 0.0
    var start = clock()
    for i in range(n):
        var t = trigram_by_id(i % 8)
        var x = Dual(Float64(i % 11) - 5.0)
        var r = apply(t, x)
        sink += r.transformed.get_value() + r.activation.yang
    var end = clock()
    var ns = Float64(end - start) * 1000.0
    if sink == 0.0:
        print("sink guard")
    return ns / Float64(n)


def bench_combine(n: Int) raises -> Float64:
    var sink = 0.0
    var start = clock()
    for i in range(n):
        var a = trigram_by_id(i % 8)
        var b = trigram_by_id((i + 3) % 8)
        var h = combine(a, b)
        sink += h.essence.get_value() + Float64(h.code)
    var end = clock()
    var ns = Float64(end - start) * 1000.0
    if sink == 0.0:
        print("sink guard")
    return ns / Float64(n)


def main() raises:
    var n = 1000000
    var t_lines = bench_trigram_lines(n)
    var t_apply = bench_apply(n)
    var t_combine = bench_combine(n)
    print("bagua benchmark (ns/op, N=" + String(n) + "):")
    print("  trigram_lines : " + String(t_lines))
    print("  apply         : " + String(t_apply))
    print("  combine       : " + String(t_combine))
