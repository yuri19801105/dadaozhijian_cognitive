# qixing/__init__.mojo — 七星包标记（决策链排序）
# 子模块: priority(优先级赋值) / ordering(DP 排序) / sequence(序列产出)。
# 下游聚合导入: from qixing import order_chain, build_sequence, DecisionSequence, priority_of
from .priority import abstract_level, capacity_factor, priority_of, priority_list
from .ordering import order_chain
from .sequence import DecisionSequence, build_sequence
