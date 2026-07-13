# === core/math/ops.mojo ===
# 基础数值运算 —— 本构建无 math 模块, 以下 sqrt/exp/sin/cos/log/pow 均为自实现。
# 标量函数 + 针对 List 数据的逐元素向量/张量运算(张量以 List[Float64] 数据载体)。

# 常量 (comptime 不可用于文件级 const, 用函数返回以保证可内联)
def LN2() -> Float64:
    return 0.6931471805599453

def PI() -> Float64:
    return 3.141592653589793

def TWO_PI() -> Float64:
    return 6.283185307179586


# ---- 标量 ----
def sqrt(x: Float64) raises -> Float64:
    if x < 0.0:
        raise Error("sqrt: negative argument")
    if x == 0.0:
        return 0.0
    var g = x * 0.5
    if g < 1.0:
        g = 1.0
    for _ in range(60):
        g = 0.5 * (g + x / g)
    return g


def exp(x: Float64) -> Float64:
    # 范围约简: x = k*LN2 + r, r ∈ [-LN2/2, LN2/2]
    var k = Int(x / LN2())
    if x < 0.0 and (Float64(k) * LN2()) > x:
        k = k - 1
    var r = x - Float64(k) * LN2()
    # e^r 泰勒展开
    var t = 1.0
    var term = 1.0
    for n in range(1, 20):
        term = term * r / Float64(n)
        t = t + term
    var result = t
    if k >= 0:
        for _ in range(k):
            result = result * 2.0
    else:
        for _ in range(-k):
            result = result / 2.0
    return result


def log(x: Float64) raises -> Float64:
    if x <= 0.0:
        raise Error("log: non-positive argument")
    # 范围约简: x = 2^k * m, m ∈ [1, 2)
    var k = 0
    var m = x
    for _ in range(2000):
        if m >= 2.0:
            m = m / 2.0
            k = k + 1
        elif m < 1.0:
            m = m * 2.0
            k = k - 1
        else:
            break
    # ln(m) = 2*(y + y^3/3 + y^5/5 + ...), y = (m-1)/(m+1)
    var y = (m - 1.0) / (m + 1.0)
    var y2 = y * y
    var s = y
    var term = y
    for i in range(1, 30):
        term = term * y2
        s = s + term / Float64(2 * i + 1)
    return Float64(k) * LN2() + 2.0 * s


def pow(x: Float64, y: Float64) raises -> Float64:
    if x < 0.0:
        raise Error("pow: negative base")
    if x == 0.0:
        if y > 0.0:
            return 0.0
        raise Error("pow: 0 raised to non-positive")
    return exp(y * log(x))


def sin(x: Float64) -> Float64:
    var r = x
    var n = Int(r / TWO_PI())
    if r < 0.0 and (Float64(n) * TWO_PI()) > r:
        n = n - 1
    r = r - Float64(n) * TWO_PI()
    var r2 = r * r
    var t = r
    var term = r
    for i in range(1, 16):
        term = term * r2 / Float64((2 * i) * (2 * i + 1))
        if (i % 2) == 1:
            t = t - term
        else:
            t = t + term
    return t


def cos(x: Float64) -> Float64:
    var r = x
    var n = Int(r / TWO_PI())
    if r < 0.0 and (Float64(n) * TWO_PI()) > r:
        n = n - 1
    r = r - Float64(n) * TWO_PI()
    var r2 = r * r
    var t = 1.0
    var term = 1.0
    for i in range(1, 16):
        term = term * r2 / Float64((2 * i - 1) * (2 * i))
        if (i % 2) == 1:
            t = t - term
        else:
            t = t + term
    return t


def clamp(x: Float64, lo: Float64, hi: Float64) -> Float64:
    var v = x
    if v < lo:
        v = lo
    if v > hi:
        v = hi
    return v


def abs_f64(x: Float64) -> Float64:
    if x < 0.0:
        return -x
    return x


# ---- 列表聚合 ----
def sum_list(data: List[Float64]) -> Float64:
    var s = 0.0
    for i in range(len(data)):
        s = s + data[i]
    return s


def mean_list(data: List[Float64]) -> Float64:
    if len(data) == 0:
        return 0.0
    return sum_list(data) / Float64(len(data))


# ---- 逐元素 (向量/张量数据) ----
def exp_list(data: List[Float64]) -> List[Float64]:
    var out = List[Float64]()
    for i in range(len(data)):
        out.append(exp(data[i]))
    return out^


def log_list(data: List[Float64]) raises -> List[Float64]:
    var out = List[Float64]()
    for i in range(len(data)):
        out.append(log(data[i]))
    return out^


def sqrt_list(data: List[Float64]) raises -> List[Float64]:
    var out = List[Float64]()
    for i in range(len(data)):
        out.append(sqrt(data[i]))
    return out^


def pow_list(data: List[Float64], exponent: Float64) raises -> List[Float64]:
    var out = List[Float64]()
    for i in range(len(data)):
        out.append(pow(data[i], exponent))
    return out^


def clamp_list(data: List[Float64], lo: Float64, hi: Float64) -> List[Float64]:
    var out = List[Float64]()
    for i in range(len(data)):
        out.append(clamp(data[i], lo, hi))
    return out^


def abs_list(data: List[Float64]) -> List[Float64]:
    var out = List[Float64]()
    for i in range(len(data)):
        out.append(abs_f64(data[i]))
    return out^
