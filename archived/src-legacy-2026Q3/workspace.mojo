# 九宫 - 工作记忆网格与注意力机制 (M3, 重做版)
# 承载中间状态(3x3 草稿纸) + 每格注意力权重(9 维, Tensor[9] 类比)
# 语言: Mojo 1.0.0b2 | 验证: TDD (对照计划 §4 九宫)
#
# 注: Mojo 标准库无 Tensor 类型, 此处用长度 9 的 List[Int] 表示 9 维注意力向量
#     (即计划 §4 的 attention: Tensor[9], 每格一个权重).

def _copy_grid(g: List[List[Int]]) -> List[List[Int]]:
    var out = List[List[Int]]()
    for r in range(3):
        var row = List[Int]()
        for c in range(3):
            var v = g[r][c]
            row.append(v)
        out.append(row^)
    return out^

struct Workspace:
    var grid: List[List[Int]]
    var attention: List[Int]
    var history: List[List[List[Int]]]
    var focus_cell: Int

    def __init__(out self):
        self.grid = List[List[Int]]()
        for _ in range(3):
            var row = List[Int]()
            for _ in range(3):
                row.append(-1)
            self.grid.append(row^)
        self.attention = List[Int]()
        for _ in range(9):
            self.attention.append(1)
        self.history = List[List[List[Int]]]()
        self.focus_cell = 0

    def _grid_copy(self) -> List[List[Int]]:
        return _copy_grid(self.grid)

    def hold(mut self, action: Int) -> Tuple[List[List[Int]], List[Int]]:
        var placed = False
        for r in range(3):
            for c in range(3):
                if self.grid[r][c] < 0:
                    self.grid[r][c] = action
                    placed = True
                    break
            if placed:
                break
        if not placed:
            var min_idx = 0
            var min_w = self.attention[0]
            for i in range(9):
                if self.attention[i] < min_w:
                    min_w = self.attention[i]
                    min_idx = i
            self.grid[min_idx // 3][min_idx % 3] = action
        self.history.append(self._grid_copy())
        return (self._grid_copy(), self.attention.copy())

    def update_attention(mut self, focus: Int):
        self.focus_cell = focus
        var frow = focus // 3
        var fcol = focus % 3
        for i in range(9):
            var r = i // 3
            var c = i % 3
            var d2 = (r - frow) * (r - frow) + (c - fcol) * (c - fcol)
            self.attention[i] = 9 / (1 + d2)

    def get_weighted_state(mut self) -> List[List[Int]]:
        var res = List[List[Int]]()
        for r in range(3):
            var row = List[Int]()
            for c in range(3):
                row.append(self.grid[r][c] * self.attention[r * 3 + c])
            res.append(row^)
        return res^

    def retrieve_history(self, step: Int) -> List[List[Int]]:
        return _copy_grid(self.history[step])

    def attention_retrieve(self) -> List[List[Int]]:
        var best_step = 0
        var best_score = -2000000000
        for s in range(len(self.history)):
            var score = 0
            for r in range(3):
                for c in range(3):
                    score += self.history[s][r][c] * self.attention[r * 3 + c]
            if score > best_score:
                best_score = score
                best_step = s
        return _copy_grid(self.history[best_step])

    def clear_cell(mut self, row: Int, col: Int):
        if 0 <= row < 3 and 0 <= col < 3:
            self.grid[row][col] = -1

    def available_cells(self) -> Int:
        var count = 0
        for r in range(3):
            for c in range(3):
                if self.grid[r][c] < 0:
                    count += 1
        return count

    def get_focus_strength(self) -> Int:
        return self.attention[self.focus_cell]
