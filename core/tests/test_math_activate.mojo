# === core/tests/test_math_activate.mojo ===
# TDD RED: 测试 core/math/activate (sigmoid/tanh/softmax)。模块未实现, 应编译失败。
from math.activate import sigmoid, tanh, softmax_list


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol


def test_sigmoid_zero() raises:
    if not approx(sigmoid(0.0), 0.5, 1e-12): raise Error("sigmoid(0) wrong")


def test_sigmoid_pos_neg() raises:
    if not approx(sigmoid(1.0), 0.731058578, 1e-6): raise Error("sigmoid(1) wrong")
    if not approx(sigmoid(-1.0), 0.268941421, 1e-6): raise Error("sigmoid(-1) wrong")


def test_sigmoid_extremes() raises:
    if not approx(sigmoid(10.0), 0.9999546, 1e-5): raise Error("sigmoid(10) wrong")
    if not approx(sigmoid(-10.0), 0.0000454, 1e-5): raise Error("sigmoid(-10) wrong")


def test_tanh_zero() raises:
    if not approx(tanh(0.0), 0.0, 1e-12): raise Error("tanh(0) wrong")


def test_tanh_pos() raises:
    if not approx(tanh(1.0), 0.761594156, 1e-6): raise Error("tanh(1) wrong")


def test_tanh_extremes() raises:
    if not approx(tanh(10.0), 1.0, 1e-6): raise Error("tanh(10) wrong")
    if not approx(tanh(-10.0), -1.0, 1e-6): raise Error("tanh(-10) wrong")


def test_softmax_uniform() raises:
    var d = List[Float64]()
    d.append(1.0); d.append(1.0); d.append(1.0)
    var s = softmax_list(d)
    if not approx(s[0], 1.0 / 3.0, 1e-9): raise Error("softmax uniform[0] wrong")
    if not approx(s[1], 1.0 / 3.0, 1e-9): raise Error("softmax uniform[1] wrong")
    if not approx(s[2], 1.0 / 3.0, 1e-9): raise Error("softmax uniform[2] wrong")


def test_softmax_normalized() raises:
    var d = List[Float64]()
    d.append(2.0); d.append(5.0); d.append(1.0); d.append(9.0)
    var s = softmax_list(d)
    var total = s[0] + s[1] + s[2] + s[3]
    if not approx(total, 1.0, 1e-9): raise Error("softmax not normalized")
    # 最大输入应得到最大概率
    if s[3] <= s[1] or s[3] <= s[0]: raise Error("softmax argmax not boosted")


def test_softmax_stability() raises:
    # 大数值不应溢出成 NaN/Inf
    var d = List[Float64]()
    d.append(1000.0); d.append(1000.0)
    var s = softmax_list(d)
    if s[0] != s[0] or s[0] > 1.0 or s[0] < 0.0: raise Error("softmax unstable on large inputs")
    var total = s[0] + s[1]
    if not approx(total, 1.0, 1e-9): raise Error("softmax large not normalized")


def main() raises:
    var failed = 0
    print("=== core/math/activate tests ===")
    try: test_sigmoid_zero();          print("  passed: test_sigmoid_zero")
    except e: failed += 1; print("  FAILED: test_sigmoid_zero ->", e)
    try: test_sigmoid_pos_neg();       print("  passed: test_sigmoid_pos_neg")
    except e: failed += 1; print("  FAILED: test_sigmoid_pos_neg ->", e)
    try: test_sigmoid_extremes();      print("  passed: test_sigmoid_extremes")
    except e: failed += 1; print("  FAILED: test_sigmoid_extremes ->", e)
    try: test_tanh_zero();             print("  passed: test_tanh_zero")
    except e: failed += 1; print("  FAILED: test_tanh_zero ->", e)
    try: test_tanh_pos();              print("  passed: test_tanh_pos")
    except e: failed += 1; print("  FAILED: test_tanh_pos ->", e)
    try: test_tanh_extremes();         print("  passed: test_tanh_extremes")
    except e: failed += 1; print("  FAILED: test_tanh_extremes ->", e)
    try: test_softmax_uniform();       print("  passed: test_softmax_uniform")
    except e: failed += 1; print("  FAILED: test_softmax_uniform ->", e)
    try: test_softmax_normalized();    print("  passed: test_softmax_normalized")
    except e: failed += 1; print("  FAILED: test_softmax_normalized ->", e)
    try: test_softmax_stability();     print("  passed: test_softmax_stability")
    except e: failed += 1; print("  FAILED: test_softmax_stability ->", e)
    if failed > 0:
        print("math_activate -> passed: 0  failed:", failed)
        raise Error("core/math/activate tests failed")
    print("math_activate -> passed: 10  failed: 0")
