# === jiugong/board.mojo ===
# 九宫工作记忆 3×3 张量盘 —— 迁自 src/workspace.mojo（List[Int] 占位）升级为基于 core/tensor 的真实张量。
# 维度语义（见规划 §4.9）:
#   shape=[3,3] 行主序, flat=r*3+c
#   row r: 宫位类别(0=天/1=地/2=人, sancai 映射)
#   col c: 时态窗口(0=过去/1=现在/2=未来)
#   元素: Float64 激活/能量值; attention: Tensor([9]) 9 维注意力权重
from tensor.tensor import Tensor
from tensor.view import transpose_2d, slice_rows, slice_cols
from math.activate import softmax_list


struct WorkspaceBoard:
    var grid: Tensor          # 3x3 工作记忆盘 (shape [3,3])
    var attention: Tensor     # [9] 注意力权重 (shape [9])
    var focus_cell: Int       # 当前聚焦宫位 (0..8)
    var round: Int

    def __init__(out self) raises:
        self.grid = Tensor()
        self.grid.init_3x3()
        self.attention = Tensor()
        self.attention.init([9])
        self.attention.fill(1.0 / 9.0)
        self.focus_cell = 4
        self.round = 0

    def init_from(mut self, t: Tensor) raises:
        if t.rank() != 2 or t.size() != 9:
            raise Error("WorkspaceBoard.init_from: expected 3x3 tensor")
        self.grid = Tensor()
        self.grid.from_list(t.to_list(), [3, 3])
        self.attention = Tensor()
        self.attention.init([9])
        self.attention.fill(1.0 / 9.0)
        self.focus_cell = 4
        self.round = 0

    # —— 读写 ——
    def at(self, r: Int, c: Int) raises -> Float64:
        return self.grid.at([r, c])

    def set(mut self, r: Int, c: Int, v: Float64) raises:
        self.grid.set([r, c], v)

    def at_flat(self, i: Int) -> Float64:
        return self.grid.at_flat(i)

    def set_flat(mut self, i: Int, v: Float64):
        self.grid.set_flat(i, v)

    def row(self, r: Int) raises -> List[Float64]:
        return self.grid.row(r)

    def col(self, c: Int) raises -> List[Float64]:
        var out = List[Float64]()
        for r in range(3):
            out.append(self.grid.at([r, c]))
        return out^

    def to_list(self) -> List[Float64]:
        return self.grid.to_list()

    # —— 变换（张量操作）——
    # 返回扁平数据 List[Float64]（Tensor 含 List 字段不可 Movable, 不能按值返回; 调用方按需 from_list 重建）
    def transpose(self) raises -> List[Float64]:
        return transpose_2d(self.grid.to_list(), self.grid.shape())

    def slice_rows(self, r0: Int, r1: Int) raises -> List[Float64]:
        return slice_rows(self.grid.to_list(), self.grid.shape(), r0, r1)

    def slice_cols(self, c0: Int, c1: Int) raises -> List[Float64]:
        return slice_cols(self.grid.to_list(), self.grid.shape(), c0, c1)

    def add(mut self, other: Tensor) raises:
        self.grid.add(other.to_list(), other.shape())

    def broadcast_add(mut self, vec: Tensor) raises:
        # vec shape [3] 或 [1,3] -> 每列加 vec[c]（跨行广播）
        # vec shape [3,1]      -> 每行加 vec[r]（跨列广播）
        var vshape = vec.shape()
        var vdata = vec.to_list()
        var grid_data = self.grid.to_list()
        var out = List[Float64]()
        if (len(vshape) == 1 and vshape[0] == 3) or (len(vshape) == 2 and vshape[0] == 1 and vshape[1] == 3):
            for r in range(3):
                for c in range(3):
                    out.append(grid_data[r * 3 + c] + vdata[c])
        elif len(vshape) == 2 and vshape[0] == 3 and vshape[1] == 1:
            for r in range(3):
                for c in range(3):
                    out.append(grid_data[r * 3 + c] + vdata[r])
        else:
            raise Error("WorkspaceBoard.broadcast_add: unsupported vec shape (need [3],[1,3],[3,1])")
        self.grid.from_list(out, [3, 3])

    # —— 注意力 ——
    def update_attention(mut self, focus: Int) raises:
        if focus < 0 or focus >= 9:
            raise Error("WorkspaceBoard.update_attention: focus out of range [0,9)")
        self.focus_cell = focus
        var frow = focus // 3
        var fcol = focus % 3
        for i in range(9):
            var r = i // 3
            var c = i % 3
            var d2 = (r - frow) * (r - frow) + (c - fcol) * (c - fcol)
            # 9/(1+d^2) 高斯式注意力（距离越近权重越大）
            self.attention.set_flat(i, 9.0 / (1.0 + Float64(d2)))

    def attention_weights(self) -> List[Float64]:
        return softmax_list(self.attention.to_list())

    def weighted_state(self) raises -> List[Float64]:
        var w = softmax_list(self.attention.to_list())
        var g = self.grid.to_list()
        var out = List[Float64]()
        for i in range(9):
            out.append(g[i] * w[i])
        return out^

    def focus_strength(self) -> Float64:
        return self.attention.at_flat(self.focus_cell)

    # —— 维护 ——
    def clear_cell(mut self, r: Int, c: Int) raises:
        if r < 0 or r >= 3 or c < 0 or c >= 3:
            raise Error("WorkspaceBoard.clear_cell: out of bounds")
        self.grid.set([r, c], 0.0)

    def available_cells(self) -> Int:
        var n = 0
        var g = self.grid.to_list()
        for i in range(9):
            if g[i] == 0.0:
                n += 1
        return n
