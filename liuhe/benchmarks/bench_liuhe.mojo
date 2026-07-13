# === liuhe/benchmarks/bench_liuhe.mojo ===
# 六合基准：1M 次 ns/op。用 sink 反馈 + 连续变化种子驱动输入防 DCE/常量折叠；
#   clock extern 计时（C clock() 微秒 ×1000 = ns 估算）。
# 运行: mojo run -I . -I core liuhe/benchmarks/bench_liuhe.mojo

from math import sqrt
from liuhe import build_supply, he_harmony, merge_supplies, SupplyVector, EAST
from wuxing.elements import WOOD, FIRE, EARTH, METAL, WATER

@extern("clock")
def clock() abi("C") -> Int:
    ...

def make_energies(seed: Int) -> List[Float64]:
    var l = List[Float64]()
    l.append(Float64((seed % 5) + 1))
    l.append(Float64(((seed * 3) % 5) + 1))
    l.append(Float64(((seed * 7) % 5) + 1))
    l.append(Float64(((seed * 11) % 5) + 1))
    l.append(Float64(((seed * 13) % 5) + 1))
    return l^

def main() raises:
    var N: Int = 1_000_000
    var sink_f: Float64 = 0.0
    var sink_i: Int = 0

    # --- build_supply ---
    var t0 = clock()
    for i in range(N):
        var e = make_energies(i)
        var sv = build_supply(e, Float64(i % 10), 8, i % 8, (i * 5) % 50)
        sink_f = sink_f + sv.harmony          # sink 反馈，防 DCE
        sink_i = sink_i + Int(sv.get(EAST))
    var t1 = clock()
    var ns_build = (t1 - t0) * 1000 / N

    # --- he_harmony (分支对) ---
    t0 = clock()
    var acc = 0
    for i in range(N):
        acc = acc + he_harmony(i % 12, (i + 1) % 12)
    t1 = clock()
    var ns_he = (t1 - t0) * 1000 / N
    sink_i = sink_i + acc

    # --- merge_supplies ---
    t0 = clock()
    for i in range(N):
        var a = SupplyVector()
        a.set(EAST, Float64(i % 7))
        var b = SupplyVector()
        b.set(EAST, Float64((i + 3) % 7))
        var m = merge_supplies(a, b)
        sink_f = sink_f + m.get(EAST)
    t1 = clock()
    var ns_merge = (t1 - t0) * 1000 / N

    print("liuhe benchmark (N=", N, "):")
    print("  build_supply ~ ", ns_build, " ns/op")
    print("  he_harmony   ~ ", ns_he, " ns/op")
    print("  merge        ~ ", ns_merge, " ns/op")
    print("  [sink f=", sink_f, " i=", sink_i, "]")
