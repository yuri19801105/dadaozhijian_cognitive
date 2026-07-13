# pipeline/__init__.mojo — 端到端编排包标记（阶段图驱动流水线）
# 子模块: stages(阶段图 DAG) / orchestrator(阶段编排)。
# 下游聚合导入:
#   from pipeline import (run_pipeline, run_pipeline_from_energies,
#                         run_pipeline_chains, run_pipeline_safe, PipelineResult,
#                         StageGraph, stage_name, stage_depends_on,
#                         STAGE_PARSE, STAGE_SCHEDULE, STAGE_SUPPLY, STAGE_ORDER, STAGE_DISPATCH)
from .stages import (
    STAGE_PARSE, STAGE_SCHEDULE, STAGE_SUPPLY, STAGE_ORDER, STAGE_DISPATCH, STAGE_COUNT,
    stage_name, stage_depends_on, StageGraph,
)
from .orchestrator import (
    PipelineResult, run_pipeline, run_pipeline_from_energies,
    run_pipeline_chains, run_pipeline_safe,
)
