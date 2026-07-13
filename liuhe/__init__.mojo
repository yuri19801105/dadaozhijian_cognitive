# liuhe/__init__.mojo — 六合包标记（供给/资源编排）
# 子模块: directions(六向空间) / supply(六向供给向量) / harmony(地支和合+多源归并)。
# 下游聚合导入: from liuhe import SupplyVector, build_supply, he_harmony, merge_supplies
from .directions import (
    EAST, WEST, SOUTH, NORTH, UP, DOWN, DIRECTION_COUNT,
    direction_name, opposite, axis_of, element_direction,
)
from .supply import SupplyVector, build_supply
from .harmony import he_harmony, harmony_index, merge_supplies, BRANCH_COUNT
