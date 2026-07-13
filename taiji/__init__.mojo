# === taiji/__init__.mojo ===
# 太极（全局状态根 + 长期记忆回灌闭环）包。
# 见规划 §4.1（v0.4 接口骨架）。本文件实现状态根与序列化；持久化见 persistence.mojo。
#
# 子模块：
#   taiji_state.mojo   全局状态根（张量化能量态 + 序列化/落盘载体）
#   feedback_loop.mojo  回灌闭环入口（归一能量 + 巩固判定）
#   consolidation.mojo  巩固/遗忘（EWC 思路防灾难性遗忘）
#   persistence.mojo    长期记忆持久化（魔数 + CRC32 + WAL 重放 + sidecar）
#   cycle.mojo          四步闭环编排（recall→plan→execute→feedback + 落盘）
#   reinjection.mojo    【v1.3 新增】回灌衔接：把执行层产物(PipelineResult/ShifangOutput/
#                       Tracer/Metrics)安全回灌进 FeedbackLoop（字段映射 + 源校验 + 异常/日志隔离）
#
# 下游聚合导入示例：
#   from taiji import (TaijiState, FeedbackLoop, Consolidation, Persistence,
#                      CognitiveCycle, CycleConfig, CycleResult, ReinjectionBridge,
#                      reinject_output, reinject_decision, reinject_intensity, validate_source,
#                      run_cycle)

# 包级聚合导入（供 `from taiji import TaijiState` 等使用）
from .taiji_state import TaijiState
