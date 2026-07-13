# === qixing/benchmarks/bench_qixing.mojo ===
# 七星基准：1M 次 ns/op。clock extern 计时 + sink 反馈 + 连续变化种子防 DCE。
# 运行: mojo run -I . -I core qixing/benchmarks/bench_qixing.mojo
from wuxing import schedule
from liuhe import build_supply, SupplyVector, EAST, WEST, SOUTH, NORTH, UP, DOWN
from qixing import order_chain, build_sequence, priority_of

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

def make_supply(seed: Int) raises -> SupplyVector:
    var sv = SupplyVector()
    sv.set(EAST, Float64((seed % 9) + 1))
    sv.set(WEST, Float64(((seed * 2) % 9) + 1))
    sv.set(SOUTH, Float64(((seed * 3) % 9) + 1))
    sv.set(NORTH, 8.0)
    sv.set(UP, Float64(((seed * 5) % 9) + 1))
    sv.set(DOWN, Float64(((seed * 7) % 9) + 1))
    return sv^

def main() raises:
    var N: Int = 1_000_000
    var sink_f: Float64 = 0.0
    var sink_i: Int = 0

    # --- order_chain ---
    var t0 = clock()
    var last_len: Int = 0
    for i in range(N):
        var dec = schedule(make_energies(i))
        var sv = make_supply(i)
        var ord = order_chain(dec, sv)
        last_len = len(ord)
        sink_i = sink_i + last_len
    var t1 = clock()
    var ns_order = (t1 - t0) * 1000 / N

    # --- priority_of (固定 step=0) ---
    t0 = clock()
    for i in range(N):
        var dec = schedule(make_energies(i))
        var sv = make_supply(i)
        sink_f = sink_f + priority_of(0, dec, sv)
    t1 = clock()
    var ns_pri = (t1 - t0) * 1000 / N

    # --- build_sequence ---
    t0 = clock()
    for i in range(N):
        var dec = schedule(make_energies(i))
        var sv = make_supply(i)
        var seq = build_sequence(dec, sv)
        sink_i = sink_i + seq.s_len
    t1 = clock()
    var ns_seq = (t1 - t0) * 1000 / N

    print("qixing benchmark (N=", N, "):")
    print("  order_chain    ~ ", ns_order, " ns/op")
    print("  priority_of    ~ ", ns_pri, " ns/op")
    print("  build_sequence ~ ", ns_seq, " ns/op")
    print("  [sink f=", sink_f, " i=", sink_i, " last_len=", last_len, "]")
