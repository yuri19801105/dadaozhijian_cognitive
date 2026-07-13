# === wuxing/__init__.mojo ===
# 五行包标记（调度策略核心）。子模块：elements（元素/能量）/ sheng_ke（生克网络）/
#   scheduler_core（生克派生调度策略）/ balance（均衡再平衡）。
# 下游聚合导入：from wuxing import schedule, ScheduleDecision, sheng_next, ke_target, Element

from .elements import (
    WOOD, FIRE, EARTH, METAL, WATER, ELEMENT_COUNT, NEUTRAL_ELEMENT,
    Element, element_name, element_glyph, element_by_symbol, element_by_symbol_safe,
)
from .sheng_ke import (
    sheng_next, sheng_prev, ke_target, ke_source, relation,
    REL_SAME, REL_GENERATED_BY, REL_GENERATES, REL_RESTRAINED_BY, REL_RESTRAINS,
    sheng_ke_gain, propagate,
)
from .scheduler_core import (
    ScheduleDecision, dominant_element, schedule, schedule_from_phase,
)
from .balance import (
    total_energy, mean_energy, variance, is_balanced, normalize, rebalance,
)
