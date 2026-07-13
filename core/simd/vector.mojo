# === core/simd/vector.mojo ===
# SIMD 向量类型 + 算术/比较/归约原语 —— "万物皆数" 的批量形态。
# 以 Mojo 内建 SIMD[DType.float64, size] 为存储, 显式 (Movable) 以支持按值传递/返回。
# 所有向量运算走硬件向量内建, 满足计划"向量化优先"原则。

struct Vector[size: Int](Movable):
    var data: SIMD[DType.float64, Self.size]

    # 零向量
    def __init__(out self):
        self.data = SIMD[DType.float64, Self.size](0.0)

    # 全填充向量
    def __init__(out self, fill: Float64):
        self.data = SIMD[DType.float64, Self.size](fill)

    # 从 List 前 size 个元素构造 (不足补 0)
    def __init__(out self, src: List[Float64]):
        self.data = SIMD[DType.float64, Self.size](0.0)
        for i in range(Self.size):
            if i < len(src):
                self.data[i] = src[i]

    # 向量长度 (编译期常量, 运行时可读)
    def length(self) -> Int:
        return Self.size

    # 越界检查访问 (异常场景)
    def at(self, i: Int) raises -> Float64:
        if i < 0 or i >= Self.size:
            raise Error("Vector.at: index out of bounds")
        return self.data[i]

    # 普通访问 (无检查, 热路径用)
    def get(self, i: Int) -> Float64:
        return self.data[i]

    # 普通写入 (无检查)
    def set(mut self, i: Int, v: Float64):
        self.data[i] = v

    # 元素级算术
    def add(self, other: Vector[Self.size]) -> Vector[Self.size]:
        var r = Vector[Self.size]()
        r.data = self.data + other.data
        return r^

    def sub(self, other: Vector[Self.size]) -> Vector[Self.size]:
        var r = Vector[Self.size]()
        r.data = self.data - other.data
        return r^

    def mul(self, other: Vector[Self.size]) -> Vector[Self.size]:
        var r = Vector[Self.size]()
        r.data = self.data * other.data
        return r^

    def div(self, other: Vector[Self.size]) -> Vector[Self.size]:
        var r = Vector[Self.size]()
        r.data = self.data / other.data
        return r^

    # 标量乘
    def scale(self, s: Float64) -> Vector[Self.size]:
        var r = Vector[Self.size]()
        r.data = self.data * s
        return r^

    # 融合乘加: self + other * s
    def add_scaled(self, other: Vector[Self.size], s: Float64) -> Vector[Self.size]:
        var r = Vector[Self.size]()
        r.data = self.data + other.data * s
        return r^

    # 点积
    def dot(self, other: Vector[Self.size]) -> Float64:
        return (self.data * other.data).reduce_add()

    # 归约
    def sum(self) -> Float64:
        return self.data.reduce_add()

    def max(self) -> Float64:
        return self.data.reduce_max()

    def min(self) -> Float64:
        return self.data.reduce_min()

    def prod(self) -> Float64:
        return self.data.reduce_mul()

    # 最大元素索引 (平局取首个)
    def argmax(self) -> Int:
        var best_i = 0
        var best_v = self.data[0]
        for i in range(1, Self.size):
            var v = self.data[i]
            if v > best_v:
                best_v = v
                best_i = i
        return best_i

    # 比较 -> 布尔掩码 (SIMD[DType.bool, size])
    def lt(self, other: Vector[Self.size]) -> SIMD[DType.bool, Self.size]:
        return self.data.lt(other.data)

    def gt(self, other: Vector[Self.size]) -> SIMD[DType.bool, Self.size]:
        return self.data.gt(other.data)

    # 按掩码混合: mask 为 True 取 self, 否则取 other
    def select(self, mask: SIMD[DType.bool, Self.size], other: Vector[Self.size]) -> Vector[Self.size]:
        var r = Vector[Self.size]()
        r.data = mask.select(self.data, other.data)
        return r^

    # 导出为 List (与其它模块/持久化互操作)
    def to_list(self) -> List[Float64]:
        var out = List[Float64]()
        for i in range(Self.size):
            out.append(self.data[i])
        return out^

    # L2 范数
    def norm(self) -> Float64:
        return _sqrt((self.data * self.data).reduce_add())

    # 单位化 (零向量返回零向量)
    def normalize(self) -> Vector[Self.size]:
        var n = self.norm()
        var r = Vector[Self.size]()
        if n <= 0.0:
            return r^
        r.data = self.data / n
        return r^


# 私有: 牛顿法开平方 (无 math 模块, 自实现)
def _sqrt(v: Float64) -> Float64:
    if v <= 0.0:
        return 0.0
    var x = v
    for _ in range(32):
        x = 0.5 * (x + v / x)
    return x
