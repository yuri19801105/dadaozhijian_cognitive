# === core/tests/test_number.mojo ===
# TDD RED: 测试 core/number (scalar + dtype)。此时模块尚未实现, 应编译失败(RED)。
from std.testing import assert_equal

from number.scalar import Scalar, Scalar32, cast_scalar, ZERO, ONE
from number.dtype import (
    PRECISION_FLOAT64, PRECISION_FLOAT32, PRECISION_INT32, PRECISION_INT8,
    PRECISION_BOOL, to_dtype,
)


def test_scalar_is_float64() raises:
    # Scalar 是全项目统一数值入口, 语义上即 Float64
    var x: Scalar = 3.5
    var y: Scalar = 2.0
    if x + y != 5.5:
        raise Error("Scalar arithmetic broken")


def test_scalar32_alias() raises:
    var z: Scalar32 = 1.25
    if z != 1.25:
        raise Error("Scalar32 alias broken")


def test_constants() raises:
    if ZERO != 0.0:
        raise Error("ZERO constant wrong")
    if ONE != 1.0:
        raise Error("ONE constant wrong")


def test_precision_enum_values() raises:
    var pf: Int = PRECISION_FLOAT64
    var p32: Int = PRECISION_FLOAT32
    var pi: Int = PRECISION_INT32
    var pi8: Int = PRECISION_INT8
    var pb: Int = PRECISION_BOOL
    if pf != 0:
        raise Error("PRECISION_FLOAT64 != 0")
    if p32 != 1:
        raise Error("PRECISION_FLOAT32 != 1")
    if pi != 2:
        raise Error("PRECISION_INT32 != 2")
    if pi8 != 3:
        raise Error("PRECISION_INT8 != 3")
    if pb != 4:
        raise Error("PRECISION_BOOL != 4")


def test_to_dtype_mapping() raises:
    # Precision 必须能映射到 Mojo 内建 DType, 以保证后续 SIMD/张量一致
    var d0 = to_dtype(PRECISION_FLOAT64)
    var d1 = to_dtype(PRECISION_FLOAT32)
    var d2 = to_dtype(PRECISION_INT32)
    if d0 != DType.float64:
        raise Error("PRECISION_FLOAT64 -> DType.float64 mismatch")
    if d1 != DType.float32:
        raise Error("PRECISION_FLOAT32 -> DType.float32 mismatch")
    if d2 != DType.int32:
        raise Error("PRECISION_INT32 -> DType.int32 mismatch")


def test_cast_scalar_identity() raises:
    # cast_scalar 在不同精度间做安全转换, 这里验证浮点->浮点保真
    var v = cast_scalar(2.75, PRECISION_FLOAT64)
    if v < 2.7499999 or v > 2.7500001:
        raise Error("cast_scalar identity broken")


def test_cast_scalar_to_int_trunc() raises:
    # 浮点->整型精度: 截断到 INT32 范围语义
    var v = cast_scalar(7.9, PRECISION_INT32)
    if v != 7.0:
        raise Error("cast to INT32 should truncate toward zero: expected 7.0")


def main() raises:
    var failed = 0
    print("=== core/number tests ===")
    try: test_scalar_is_float64();      print("  passed: test_scalar_is_float64")
    except e: failed += 1; print("  FAILED: test_scalar_is_float64 ->", e)
    try: test_scalar32_alias();         print("  passed: test_scalar32_alias")
    except e: failed += 1; print("  FAILED: test_scalar32_alias ->", e)
    try: test_constants();               print("  passed: test_constants")
    except e: failed += 1; print("  FAILED: test_constants ->", e)
    try: test_precision_enum_values();   print("  passed: test_precision_enum_values")
    except e: failed += 1; print("  FAILED: test_precision_enum_values ->", e)
    try: test_to_dtype_mapping();        print("  passed: test_to_dtype_mapping")
    except e: failed += 1; print("  FAILED: test_to_dtype_mapping ->", e)
    try: test_cast_scalar_identity();    print("  passed: test_cast_scalar_identity")
    except e: failed += 1; print("  FAILED: test_cast_scalar_identity ->", e)
    try: test_cast_scalar_to_int_trunc();print("  passed: test_cast_scalar_to_int_trunc")
    except e: failed += 1; print("  FAILED: test_cast_scalar_to_int_trunc ->", e)
    if failed > 0:
        print("number -> passed: 0  failed:", failed)
        raise Error("core/number tests failed")
    print("number -> passed: 7  failed: 0")
