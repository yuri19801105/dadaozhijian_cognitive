# === core/number/scalar.mojo ===
# 统一标量类型 —— 全项目唯一的数值入口 ("万物皆数" 的原子)。
# 所有概念(阴阳/五行/八卦...)最终都落为 Scalar; 向量化/张量只是它的批量形态。

from number.dtype import PRECISION_INT32, PRECISION_INT8

comptime Scalar = Float64
comptime Scalar32 = Float32

comptime ZERO: Float64 = 0.0
comptime ONE: Float64 = 1.0


# 在不同精度语义下做标量转换。整型精度做向零截断; 浮点/布尔精度保真。
def cast_scalar(v: Float64, p: Int) -> Float64:
    if p == PRECISION_INT32 or p == PRECISION_INT8:
        return Float64(Int(v))
    return v
