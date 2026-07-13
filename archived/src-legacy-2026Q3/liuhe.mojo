# 六合 - 空间感知与上下文建模
# 将认知状态压缩为 6 维态势向量 [东,西,南,北,上,下]
# 语言: Mojo 1.0.0b2 | 验证: TDD

from workspace import Workspace
from config import Config

def _min(a: Int, b: Int) -> Int:
    return a if a < b else b

def context_vector(ws: Workspace, chain_depth: Int, ground_input: String, cfg: Config) -> SIMD[DType.int64, 6]:
    var east = ws.available_cells()
    var west = chain_depth
    var south = ws.get_focus_strength()
    var north = cfg.max_depth
    var up = _min(9, chain_depth / 2)
    var down = _min(9, ground_input.byte_length() / 5)
    return SIMD[DType.int64, 6](Int64(east), Int64(west), Int64(south), Int64(north), Int64(up), Int64(down))
