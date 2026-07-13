# === wuxing/balance.mojo ===
# 五行均衡 / 负载再平衡：「亢则害，承乃制」——抑亢补弱以维持系统不致失衡。
# 提供总量 / 均值 / 方差 / 均衡判定 / 归一 / 再平衡（降方差、保总量）。
# 依赖：core（无外部）、elements（ELEMENT_COUNT）。

from .elements import ELEMENT_COUNT


def total_energy(energies: List[Float64]) -> Float64:
    var s = 0.0
    for i in range(len(energies)):
        s += energies[i]
    return s


def mean_energy(energies: List[Float64]) -> Float64:
    var n = len(energies)
    if n == 0:
        return 0.0
    return total_energy(energies) / Float64(n)


# 方差 = 各元素偏离均值平方的均值（越小越均衡）
def variance(energies: List[Float64]) -> Float64:
    var n = len(energies)
    if n == 0:
        return 0.0
    var m = mean_energy(energies)
    var acc = 0.0
    for i in range(n):
        var d = energies[i] - m
        acc += d * d
    return acc / Float64(n)


# 均衡判定：方差 < tol
def is_balanced(energies: List[Float64], tol: Float64) -> Bool:
    return variance(energies) < tol


# 归一到 sum=1（全零 raises）
def normalize(energies: List[Float64]) raises -> List[Float64]:
    var total = total_energy(energies)
    if total <= 0.0:
        raise Error("wuxing: cannot normalize zero total energy")
    var out = List[Float64]()
    for i in range(len(energies)):
        out.append(energies[i] / total)
    return out^


# 负载再平衡：抑亢补弱——从最旺(亢)元素抽取一部分补给最弱元素，降方差、保总量。
# amount = rate * (max - min) / 2；转移后二者向均值靠拢，总量不变。
def rebalance(energies: List[Float64]) raises -> List[Float64]:
    if len(energies) != ELEMENT_COUNT:
        raise Error("wuxing: rebalance requires exactly 5 element energies")
    var out = List[Float64]()
    for i in range(ELEMENT_COUNT):
        out.append(energies[i])

    # 找最旺 / 最弱
    var hi = 0
    var lo = 0
    for i in range(1, ELEMENT_COUNT):
        if out[i] > out[hi]: hi = i
        if out[i] < out[lo]: lo = i
    if hi == lo:
        return out^  # 已完全均衡

    var rate = 0.5
    var amount = rate * (out[hi] - out[lo]) / 2.0
    out[hi] = out[hi] - amount
    out[lo] = out[lo] + amount
    return out^
