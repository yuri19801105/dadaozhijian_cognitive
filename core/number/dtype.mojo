# === core/number/dtype.mojo ===
# 精度/类型枚举与 DType 映射 —— "万物皆数" 的统一数值类型元数据。
# 注: 本构建不支持文件级 enum, 故以 comptime 常量表达枚举值(与项目既有 emoji.mojo 一致)。
# 用途: 让后续 SIMD / 张量 / 算子都引用同一套精度语义, 避免散落的 Float64/Int 混用。

comptime PRECISION_FLOAT64: Int = 0
comptime PRECISION_FLOAT32: Int = 1
comptime PRECISION_INT32: Int = 2
comptime PRECISION_INT8: Int = 3
comptime PRECISION_BOOL: Int = 4


# 把本项目精度值映射到 Mojo 内建 DType, 保证 SIMD/张量类型一致。
def to_dtype(p: Int) -> DType:
    if p == PRECISION_FLOAT64:
        return DType.float64
    if p == PRECISION_FLOAT32:
        return DType.float32
    if p == PRECISION_INT32:
        return DType.int32
    if p == PRECISION_INT8:
        return DType.int8
    return DType.bool
