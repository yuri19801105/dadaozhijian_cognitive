# === scheduler/benchmarks/bench_scheduler.mojo ===
# 总调度基准：1M 次 ns/op。clock extern + sink 反馈 + 连续变化种子防 DCE。
# 运行: mojo run -I . -I core scheduler/benchmarks/bench_scheduler.mojo
from scheduler import dispatch, dispatch_from_phase

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

    # --- dispatch (端到端: wuxing+liuhe+qixing) ---
    var t0 = clock()
    var last_len: Int = 0
    for i in range(N):
        var plan = dispatch(make_energies(i), Float64(i % 10), 8, i % 8, (i * 5) % 50)
        last_len = plan.s_len
        sink_i = sink_i + last_len
        sink_f = sink_f + plan.confidence
    var t1 = clock()
    var ns_disp = (t1 - t0) * 1000 / N

    # --- dispatch_from_phase ---
    t0 = clock()
    for i in range(N):
        var plan = dispatch_from_phase(i % 4, Float64(i % 10), Float64(i % 10), 8, i % 8, (i * 5) % 50)
        sink_i = sink_i + plan.s_len
    t1 = clock()
    var ns_phase = (t1 - t0) * 1000 / N

    print("scheduler benchmark (N=", N, "):")
    print("  dispatch           ~ ", ns_disp, " ns/op")
    print("  dispatch_from_phase ~ ", ns_phase, " ns/op")
    print("  [sink f=", sink_f, " i=", sink_i, " last_len=", last_len, "]")
