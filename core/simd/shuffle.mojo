# === core/simd/shuffle.mojo ===
# 掩码 / 洗牌 / 聚集-散布 原语 —— 在 SIMD 向量之上提供数据重组能力。
# gather/scatter/reverse/rotate 以 lane 访问实现(可移植、可测); mask 归约走内建 reduce_or/and。

from simd.vector import Vector


# 聚集: 取 base[ Int(indices[i]) ], 越界 raise
def gather[size: Int](base: Vector[size], indices: Vector[size]) raises -> Vector[size]:
    var r = Vector[size]()
    for i in range(size):
        var idx = Int(indices.get(i))
        if idx < 0 or idx >= size:
            raise Error("gather: index out of bounds")
        r.set(i, base.get(idx))
    return r^


# 散布: dst[ Int(indices[i]) ] = src[i], 越界 raise
def scatter[size: Int](mut dst: Vector[size], src: Vector[size], indices: Vector[size]) raises:
    for i in range(size):
        var idx = Int(indices.get(i))
        if idx < 0 or idx >= size:
            raise Error("scatter: index out of bounds")
        dst.set(idx, src.get(i))


# 反转 lane 顺序
def reverse[size: Int](v: Vector[size]) -> Vector[size]:
    var r = Vector[size]()
    for i in range(size):
        r.set(i, v.get(size - 1 - i))
    return r^


# 循环左移 k 位
def rotate_left[size: Int](v: Vector[size], k: Int) -> Vector[size]:
    var r = Vector[size]()
    for i in range(size):
        var j = (i + k) % size
        if j < 0:
            j += size
        r.set(i, v.get(j))
    return r^


# 循环右移 k 位
def rotate_right[size: Int](v: Vector[size], k: Int) -> Vector[size]:
    return rotate_left(v, -k)


# 掩码归约: 任一为真
def mask_any[size: Int](mask: SIMD[DType.bool, size]) -> Bool:
    return mask.reduce_or()


# 掩码归约: 全部为真
def mask_all[size: Int](mask: SIMD[DType.bool, size]) -> Bool:
    return mask.reduce_and()


# 掩码中真值 lane 计数
def count_true[size: Int](mask: SIMD[DType.bool, size]) -> Int:
    var c = 0
    for i in range(size):
        if mask[i]:
            c += 1
    return c


# 首个真值 lane 索引, 无则 -1
def first_true_index[size: Int](mask: SIMD[DType.bool, size]) -> Int:
    for i in range(size):
        if mask[i]:
            return i
    return -1
