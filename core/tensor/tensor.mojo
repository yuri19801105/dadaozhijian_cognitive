# === core/tensor/tensor.mojo ===
# 轻量 NDArray —— 因本构建无 mojo.tensor, 自建张量: 数据存 List[Float64], 形状/步长存 List[Int]。
# 受 Mojo Movability 约束(含 List 字段的结构不可按值移动), Tensor 以本地 var + mut self 方法使用,
# 张量间运算由调用方传入对方 List 分量(可移动)实现。九宫 3x3 / 六合 6 向 提供专用初始化。

struct Tensor:
    var data: List[Float64]
    var _shape: List[Int]
    var _strides: List[Int]

    def __init__(out self):
        self.data = List[Float64]()
        self._shape = List[Int]()
        self._strides = List[Int]()

    def _compute_strides(mut self):
        self._strides = List[Int]()
        for k in range(len(self._shape)):
            var s = 1
            for j in range(k + 1, len(self._shape)):
                s = s * self._shape[j]
            self._strides.append(s)

    # 按形状分配全 0 张量
    def init(mut self, sh: List[Int]) raises:
        var n = 1
        for i in range(len(sh)):
            if sh[i] <= 0:
                raise Error("Tensor.init: non-positive dimension")
            n = n * sh[i]
        self._shape = sh.copy()
        self.data = List[Float64]()
        for _ in range(n):
            self.data.append(0.0)
        self._compute_strides()

    # 从数据 + 形状构造 (长度须匹配)
    def from_list(mut self, d: List[Float64], sh: List[Int]) raises:
        var n = 1
        for i in range(len(sh)):
            if sh[i] <= 0:
                raise Error("Tensor.from_list: non-positive dimension")
            n = n * sh[i]
        if len(d) != n:
            raise Error("Tensor.from_list: data size != shape product")
        self.data = d.copy()
        self._shape = sh.copy()
        self._compute_strides()

    def rank(self) -> Int:
        return len(self._shape)

    def size(self) -> Int:
        return len(self.data)

    def shape(self) -> List[Int]:
        return self._shape.copy()

    def _shape_eq(self, other: List[Int]) -> Bool:
        if len(self._shape) != len(other):
            return False
        for i in range(len(self._shape)):
            if self._shape[i] != other[i]:
                return False
        return True

    # 多维索引 -> 扁平下标 (越界/秩不匹配 raise)
    def _flat_index(self, idx: List[Int]) raises -> Int:
        if len(idx) != len(self._shape):
            raise Error("Tensor: index rank mismatch")
        var flat = 0
        for i in range(len(idx)):
            if idx[i] < 0 or idx[i] >= self._shape[i]:
                raise Error("Tensor: index out of bounds")
            flat = flat + idx[i] * self._strides[i]
        return flat

    def at(self, idx: List[Int]) raises -> Float64:
        return self.data[self._flat_index(idx)]

    def set(mut self, idx: List[Int], v: Float64) raises:
        self.data[self._flat_index(idx)] = v

    def at_flat(self, i: Int) -> Float64:
        return self.data[i]

    def set_flat(mut self, i: Int, v: Float64):
        self.data[i] = v

    def to_list(self) -> List[Float64]:
        return self.data.copy()

    def fill(mut self, v: Float64):
        for i in range(len(self.data)):
            self.data[i] = v

    def scale(mut self, s: Float64):
        for i in range(len(self.data)):
            self.data[i] = self.data[i] * s

    def add_scalar(mut self, s: Float64):
        for i in range(len(self.data)):
            self.data[i] = self.data[i] + s

    # 按值相加 (形状须一致), 其他张量以 List 分量传入
    def add(mut self, other_data: List[Float64], other_shape: List[Int]) raises:
        if not self._shape_eq(other_shape):
            raise Error("Tensor.add: shape mismatch")
        if len(other_data) != len(self.data):
            raise Error("Tensor.add: data length mismatch")
        for i in range(len(self.data)):
            self.data[i] = self.data[i] + other_data[i]

    def sum(self) -> Float64:
        var s = 0.0
        for i in range(len(self.data)):
            s = s + self.data[i]
        return s

    def max(self) -> Float64:
        if len(self.data) == 0:
            return 0.0
        var m = self.data[0]
        for i in range(1, len(self.data)):
            if self.data[i] > m:
                m = self.data[i]
        return m

    def min(self) -> Float64:
        if len(self.data) == 0:
            return 0.0
        var m = self.data[0]
        for i in range(1, len(self.data)):
            if self.data[i] < m:
                m = self.data[i]
        return m

    def argmax_flat(self) -> Int:
        if len(self.data) == 0:
            return -1
        var bi = 0
        var bv = self.data[0]
        for i in range(1, len(self.data)):
            if self.data[i] > bv:
                bv = self.data[i]
                bi = i
        return bi

    # 取第 r 行 (仅 2D)
    def row(self, r: Int) raises -> List[Float64]:
        if len(self._shape) != 2:
            raise Error("Tensor.row: not 2D")
        if r < 0 or r >= self._shape[0]:
            raise Error("Tensor.row: row out of bounds")
        var cols = self._shape[1]
        var out = List[Float64]()
        for c in range(cols):
            out.append(self.at([r, c]))
        return out^

    # 九宫: 3x3 工作记忆盘
    def init_3x3(mut self) raises:
        self.init([3, 3])

    # 六合: 6 向资源向量
    def init_6dir(mut self) raises:
        self.init([6])
