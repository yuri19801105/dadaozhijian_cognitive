# === sancai/benchmarks/bench_sancai.mojo ===
# sancai 性能回归基准(纳秒级热路径设上限, 见规划 §6/§10.6)。
# 计时: C clock() 微秒, *1000 -> ns/op (对齐 core/benchmarks/bench_core.mojo 惯例)。
# 关键: 结果累加到 sink 并在结尾使用, 否则编译器会 DCE 掉未使用的计算结果。
# 运行: .venv/bin/mojo run -I . -I core sancai/benchmarks/bench_sancai.mojo

from sancai.layers import SanCai
from sancai.interface import LayerBus
from liangyi.dual import Dual
from tensor.tensor import Tensor
from math.ops import mean_list

@extern("clock")
def clock() abi("C") -> Int:
    ...


def make_vec(n: Int) -> List[Float64]:
    var v = List[Float64]()
    for i in range(n):
        v.append(Float64(i % 5) - 2.0)
    return v^


def main() raises:
    var N = 1000000
    var sink = 0.0
    var tian = make_vec(8)
    var di = make_vec(8)
    var ren = make_vec(8)

    # 系数池: 用 sink 驱动下标使输入在编译期不可预测, 阻止 DCE / 闭式优化
    var coeffs = List[Float64]()
    for i in range(16):
        coeffs.append(Float64(i) - 8.0)

    # 基准 1: from_layer_vectors (构造 + 派生三层 Dual + payload)
    var t0 = clock()
    for _ in range(N):
        var sc = SanCai()
        sc.from_layer_vectors(tian, di, ren)
        sink = sink + sc.tian.get_value()
    var t1 = clock()
    print("sancai.from_layer_vectors_ns_per_op:", (t1 - t0) * 1000 / N)

    # 基准 2: LayerBus.pass_tian_to_di (合并 + 门控) — sink 驱动输入防 DCE
    var t2 = clock()
    for _ in range(N):
        var idx = Int(sink) % 16
        if idx < 0:
            idx = -idx
        var aa = Dual(coeffs[idx])
        var bb = Dual(coeffs[(idx + 1) % 16])
        var msg = LayerBus.pass_tian_to_di(aa, bb, 0.5, 0.0)
        sink = sink + msg.gate
    var t3 = clock()
    print("sancai.pass_tian_to_di_ns_per_op:", (t3 - t2) * 1000 / N)

    # 健全性校验: 构造结果符合契约
    var sc = SanCai()
    sc.from_layer_vectors(tian, di, ren)
    if not approx(sc.tian.get_value(), mean_list(tian), 1e-9):
        raise Error("bench sanity: tian mean mismatch")
    _ = sink
    print("BENCH_SANCAI_OK")


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol
