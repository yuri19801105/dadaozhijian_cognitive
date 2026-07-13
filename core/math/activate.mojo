# === core/math/activate.mojo ===
# 激活函数 —— 依赖 ops 的自实现 exp/log。sigmoid/tanh 标量 + softmax 逐元素(列表/张量数据载体)。

from .ops import exp, log


def sigmoid(x: Float64) -> Float64:
    return 1.0 / (1.0 + exp(-x))


def tanh(x: Float64) -> Float64:
    var ep = exp(x)
    var en = exp(-x)
    return (ep - en) / (ep + en)


# 数值稳定 softmax: 先减最大值防止 exp 溢出, 再归一化。输入全同值应输出均匀分布。
def softmax_list(data: List[Float64]) -> List[Float64]:
    if len(data) == 0:
        return List[Float64]()
    var m = data[0]
    for i in range(1, len(data)):
        if data[i] > m:
            m = data[i]
    var exps = List[Float64]()
    var total = 0.0
    for i in range(len(data)):
        var e = exp(data[i] - m)
        exps.append(e)
        total = total + e
    var out = List[Float64]()
    for i in range(len(data)):
        out.append(exps[i] / total)
    return out^
