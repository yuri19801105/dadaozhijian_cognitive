# core 模块基准 —— 测量热路径开销 (ns/op)。
# 计时: C clock() 微秒, *1000 -> ns/op。每路径跑 1M 次避免 O(N^2) 叠加。
# 关键: 结果必须累加到 sink 并在结尾使用, 否则编译器会 DCE 掉未使用的计算结果。
from simd.vector import Vector
from tensor.tensor import Tensor
from math.activate import softmax_list
from math.ops import exp

@extern("clock")
def clock() abi("C") -> Int:
    ...


def main() raises:
    var N = 1000000
    var sink = 0.0

    # --- 向量加法 (SIMD Vector[8]) ---
    # 用 sink 驱动的下标取系数构造 b: sink 每轮变化使下标在编译期不可预测,
    # 阻止优化器把线性递推识别成闭式 O(1) 算术和。
    var coeffs = List[Float64]()
    for i in range(64):
        coeffs.append(Float64(i + 1))
    var a = Vector[8](1.0)
    var v = a^
    var t0 = clock()
    for _ in range(N):
        var idx = Int(sink) % 64
        if idx < 0:
            idx = -idx
        var b2 = Vector[8](coeffs[idx])
        v = v.add(b2)
        sink = sink + v.get(0)
    var t1 = clock()
    print("vector_add_v8_1M_ns:", (t1 - t0) * 1000 / N)

    # --- 张量逐元素加 (九宫 3x3) ---
    var d = List[Float64]()
    for i in range(9):
        d.append(Float64(i))
    var tc = Tensor()
    tc.from_list(d, [3, 3])
    var td = tc.to_list()
    var ts = tc.shape()
    var t2 = clock()
    for _ in range(N):
        tc.add(td, ts)
        sink = sink + tc.at_flat(0)
    var t3 = clock()
    print("tensor_add_3x3_1M_ns:", (t3 - t2) * 1000 / N)

    # --- softmax (长度 8) ---
    var sd = List[Float64]()
    for i in range(8):
        sd.append(Float64(i))
    var t4 = clock()
    for _ in range(N):
        var s = softmax_list(sd)
        sink = sink + s[0]
    var t5 = clock()
    print("softmax_len8_1M_ns:", (t5 - t4) * 1000 / N)

    # --- exp 标量 (激活热路径) ---
    var t6 = clock()
    for _ in range(N):
        sink = sink + exp(0.5)
    var t7 = clock()
    print("exp_scalar_1M_ns:", (t7 - t6) * 1000 / N)

    # 使用 sink, 防止 DCE
    print("sink_check:", sink)
