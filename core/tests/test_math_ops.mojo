# === core/tests/test_math_ops.mojo ===
# TDD RED: 测试 core/math/ops (标量与向量/张量数值运算)。模块未实现, 应编译失败。
from math.ops import (
    sqrt, exp, sin, cos, log, pow, clamp, abs_f64,
    sum_list, mean_list,
    exp_list, log_list, sqrt_list, pow_list, clamp_list, abs_list,
)


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol


def test_sqrt() raises:
    if not approx(sqrt(2.0), 1.41421356, 1e-5): raise Error("sqrt(2) wrong")
    if not approx(sqrt(4.0), 2.0, 1e-9): raise Error("sqrt(4) wrong")
    if not approx(sqrt(0.0), 0.0, 1e-12): raise Error("sqrt(0) wrong")
    if not approx(sqrt(1.0), 1.0, 1e-12): raise Error("sqrt(1) wrong")


def test_sqrt_negative_raises() raises:
    var caught = False
    try:
        _ = sqrt(-1.0)
    except:
        caught = True
    if not caught:
        raise Error("sqrt(negative) should raise")


def test_exp() raises:
    if not approx(exp(0.0), 1.0, 1e-12): raise Error("exp(0) wrong")
    if not approx(exp(1.0), 2.718281828, 1e-5): raise Error("exp(1) wrong")
    # exp(-1) = 1/e
    if not approx(exp(-1.0), 0.36787944, 1e-5): raise Error("exp(-1) wrong")
    # exp(ln2) ≈ 2
    if not approx(exp(0.69314718), 2.0, 1e-4): raise Error("exp(ln2) wrong")


def test_log() raises:
    if not approx(log(1.0), 0.0, 1e-9): raise Error("log(1) wrong")
    if not approx(log(2.718281828), 1.0, 1e-5): raise Error("log(e) wrong")
    if not approx(log(8.0), 2.07944154, 1e-5): raise Error("log(8) wrong")


def test_log_nonpositive_raises() raises:
    var caught = False
    try:
        _ = log(0.0)
    except:
        caught = True
    if not caught:
        raise Error("log(0) should raise")
    var caught2 = False
    try:
        _ = log(-1.0)
    except:
        caught2 = True
    if not caught2:
        raise Error("log(-1) should raise")


def test_pow() raises:
    if not approx(pow(2.0, 3.0), 8.0, 1e-9): raise Error("pow(2,3) wrong")
    if not approx(pow(9.0, 0.5), 3.0, 1e-9): raise Error("pow(9,0.5) wrong")
    if not approx(pow(2.0, 0.0), 1.0, 1e-9): raise Error("pow(x,0) wrong")
    if not approx(pow(1.0, 5.0), 1.0, 1e-9): raise Error("pow(1,y) wrong")


def test_sin() raises:
    if not approx(sin(0.0), 0.0, 1e-12): raise Error("sin(0) wrong")
    if not approx(sin(1.57079632679), 1.0, 1e-6): raise Error("sin(pi/2) wrong")
    if not approx(sin(3.14159265358), 0.0, 1e-6): raise Error("sin(pi) wrong")


def test_cos() raises:
    if not approx(cos(0.0), 1.0, 1e-12): raise Error("cos(0) wrong")
    if not approx(cos(3.14159265358), -1.0, 1e-6): raise Error("cos(pi) wrong")
    if not approx(cos(1.57079632679), 0.0, 1e-6): raise Error("cos(pi/2) wrong")


def test_clamp() raises:
    if not approx(clamp(5.0, 0.0, 3.0), 3.0, 1e-12): raise Error("clamp hi wrong")
    if not approx(clamp(-1.0, 0.0, 3.0), 0.0, 1e-12): raise Error("clamp lo wrong")
    if not approx(clamp(2.0, 0.0, 3.0), 2.0, 1e-12): raise Error("clamp mid wrong")


def test_abs_f64() raises:
    if not approx(abs_f64(-3.5), 3.5, 1e-12): raise Error("abs neg wrong")
    if not approx(abs_f64(3.5), 3.5, 1e-12): raise Error("abs pos wrong")
    if not approx(abs_f64(0.0), 0.0, 1e-12): raise Error("abs zero wrong")


def test_sum_list() raises:
    var d = List[Float64]()
    d.append(1.0); d.append(2.0); d.append(3.0); d.append(4.0)
    if not approx(sum_list(d), 10.0, 1e-12): raise Error("sum_list wrong")
    var e = List[Float64]()
    if not approx(sum_list(e), 0.0, 1e-12): raise Error("sum_list empty wrong")


def test_mean_list() raises:
    var d = List[Float64]()
    d.append(2.0); d.append(4.0); d.append(6.0)
    if not approx(mean_list(d), 4.0, 1e-12): raise Error("mean_list wrong")
    var e = List[Float64]()
    if not approx(mean_list(e), 0.0, 1e-12): raise Error("mean_list empty wrong")


def test_elementwise_exp() raises:
    var d = List[Float64]()
    d.append(0.0); d.append(1.0)
    var r = exp_list(d)
    if not approx(r[0], 1.0, 1e-9): raise Error("exp_list[0] wrong")
    if not approx(r[1], 2.718281828, 1e-5): raise Error("exp_list[1] wrong")


def test_elementwise_sqrt() raises:
    var d = List[Float64]()
    d.append(4.0); d.append(9.0)
    var r = sqrt_list(d)
    if not approx(r[0], 2.0, 1e-9): raise Error("sqrt_list[0] wrong")
    if not approx(r[1], 3.0, 1e-9): raise Error("sqrt_list[1] wrong")


def test_elementwise_pow() raises:
    var d = List[Float64]()
    d.append(2.0); d.append(3.0)
    var r = pow_list(d, 2.0)
    if not approx(r[0], 4.0, 1e-9): raise Error("pow_list[0] wrong")
    if not approx(r[1], 9.0, 1e-9): raise Error("pow_list[1] wrong")


def test_elementwise_clamp() raises:
    var d = List[Float64]()
    d.append(-1.0); d.append(5.0); d.append(2.0)
    var r = clamp_list(d, 0.0, 3.0)
    if not approx(r[0], 0.0, 1e-12): raise Error("clamp_list[0] wrong")
    if not approx(r[1], 3.0, 1e-12): raise Error("clamp_list[1] wrong")
    if not approx(r[2], 2.0, 1e-12): raise Error("clamp_list[2] wrong")


def test_elementwise_abs() raises:
    var d = List[Float64]()
    d.append(-3.0); d.append(3.0)
    var r = abs_list(d)
    if not approx(r[0], 3.0, 1e-12): raise Error("abs_list[0] wrong")
    if not approx(r[1], 3.0, 1e-12): raise Error("abs_list[1] wrong")


def main() raises:
    var failed = 0
    print("=== core/math/ops tests ===")
    try: test_sqrt();                         print("  passed: test_sqrt")
    except e: failed += 1; print("  FAILED: test_sqrt ->", e)
    try: test_sqrt_negative_raises();         print("  passed: test_sqrt_negative_raises")
    except e: failed += 1; print("  FAILED: test_sqrt_negative_raises ->", e)
    try: test_exp();                          print("  passed: test_exp")
    except e: failed += 1; print("  FAILED: test_exp ->", e)
    try: test_log();                          print("  passed: test_log")
    except e: failed += 1; print("  FAILED: test_log ->", e)
    try: test_log_nonpositive_raises();       print("  passed: test_log_nonpositive_raises")
    except e: failed += 1; print("  FAILED: test_log_nonpositive_raises ->", e)
    try: test_pow();                          print("  passed: test_pow")
    except e: failed += 1; print("  FAILED: test_pow ->", e)
    try: test_sin();                          print("  passed: test_sin")
    except e: failed += 1; print("  FAILED: test_sin ->", e)
    try: test_cos();                          print("  passed: test_cos")
    except e: failed += 1; print("  FAILED: test_cos ->", e)
    try: test_clamp();                        print("  passed: test_clamp")
    except e: failed += 1; print("  FAILED: test_clamp ->", e)
    try: test_abs_f64();                      print("  passed: test_abs_f64")
    except e: failed += 1; print("  FAILED: test_abs_f64 ->", e)
    try: test_sum_list();                     print("  passed: test_sum_list")
    except e: failed += 1; print("  FAILED: test_sum_list ->", e)
    try: test_mean_list();                    print("  passed: test_mean_list")
    except e: failed += 1; print("  FAILED: test_mean_list ->", e)
    try: test_elementwise_exp();              print("  passed: test_elementwise_exp")
    except e: failed += 1; print("  FAILED: test_elementwise_exp ->", e)
    try: test_elementwise_sqrt();             print("  passed: test_elementwise_sqrt")
    except e: failed += 1; print("  FAILED: test_elementwise_sqrt ->", e)
    try: test_elementwise_pow();              print("  passed: test_elementwise_pow")
    except e: failed += 1; print("  FAILED: test_elementwise_pow ->", e)
    try: test_elementwise_clamp();            print("  passed: test_elementwise_clamp")
    except e: failed += 1; print("  FAILED: test_elementwise_clamp ->", e)
    try: test_elementwise_abs();              print("  passed: test_elementwise_abs")
    except e: failed += 1; print("  FAILED: test_elementwise_abs ->", e)
    if failed > 0:
        print("math_ops -> passed: 0  failed:", failed)
        raise Error("core/math/ops tests failed")
    print("math_ops -> passed: 18  failed: 0")
