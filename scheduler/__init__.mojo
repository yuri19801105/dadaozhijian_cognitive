# scheduler/__init__.mojo — 总调度包标记（统一派发器）
# 子模块: policy(调度策略装配) / dispatcher(统一派发)。
# 下游聚合导入: from scheduler import dispatch, dispatch_from_phase, DispatchPlan, default_policy
from .policy import SchedulerPolicy, default_policy
from .dispatcher import DispatchPlan, dispatch, dispatch_from_phase, apply_policy
