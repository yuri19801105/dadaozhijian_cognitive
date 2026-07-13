# === pipeline/benchmarks/bench_pipeline.mojo ===
# 端到端编排基准：1M 次 ns/op。clock extern + sink 反馈 + 连续变化种子防 DCE。
# 运行: mojo run -I . -I core pipeline/benchmarks/bench_pipeline.mojo
from pipeline import run_pipeline, run_pipeline_from_energies

@extern("clock")
def clock() abi("C") -> Int:
    ...

def make_text(seed: Int) -> String:
    var s = String("")
    var n = seed % 20 + 5
    for _i in range(n):
        s = s + "a"
    return s^

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

    # --- run_pipeline (文本入口: 解析→五行→六合→七星→总派发) ---
    var t0 = clock()
    var plen: Int = 0
    for i in range(N):
        var txt = make_text(i)
        var r = run_pipeline(txt, Float64(i % 10), 8, i % 8, (i * 5) % 50)
        plen = r.plan_len
        sink_i = sink_i + plen
        sink_f = sink_f + r.confidence
    var t1 = clock()
    var ns_text = (t1 - t0) * 1000 / N

    # --- run_pipeline_from_energies (能量入口) ---
    t0 = clock()
    for i in range(N):
        var e = make_energies(i)
        var r = run_pipeline_from_energies(e, Float64(i % 10), 8, i % 8, (i * 5) % 50)
        sink_i = sink_i + r.plan_len
        sink_f = sink_f + r.confidence
    t1 = clock()
    var ns_energy = (t1 - t0) * 1000 / N

    print("pipeline benchmark (N=", N, "):")
    print("  run_pipeline          ~ ", ns_text, " ns/op")
    print("  run_pipeline_from_energy ~ ", ns_energy, " ns/op")
    print("  [sink f=", sink_f, " i=", sink_i, " last_len=", plen, "]")
