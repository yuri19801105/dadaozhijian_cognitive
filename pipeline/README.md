# `pipeline/` — 流水线（端到端编排）【v1.1 已落地 ✅】

> **状态**：TDD 100% 落地（2026-07-12，规划 v1.1）。由 MVP 线性 `run_cycle` 重构为**阶段图（stage graph）**驱动的可观测、可断点重放流水线。
> 依赖：`wuxing`（策略）· `liuhe`（供给）· `qixing`（排序）· `scheduler`（总成）。
> 运行：`mojo run -I . -I core pipeline/tests/test_pipeline.mojo` → `pipeline -> passed: 78  failed: 0`

## 一、职责

将 L0–L5 串为可运行流水线：文本/能量 → **五行调度**（策略）→ **六合供给**（资源）→ **七星定序**（排序）→ **总派发**（唯一 `DispatchPlan`）。全链路产物固化于 `PipelineResult`，供 `observability` 溯源与 `shifang` 扇出消费。

## 二、阶段图（依赖 DAG）

```
   STAGE_PARSE ─► STAGE_SCHEDULE ─► STAGE_SUPPLY ─► STAGE_ORDER ─► STAGE_DISPATCH
   (解析相位/强度)  (五行调度)        (六合供给)       (七星定序)      (总派发)
```
- 依赖为线性紧邻链（`dep(stage)=stage-1`，PARSE 无前置）。
- `StageGraph.can_run(stage)`：前置完成才允许执行 → **依赖门控 + 断点重放**（某阶段失败后续自动停摆，记 `failed_stage`）。

## 三、接口（聚合导出）

```mojo
from pipeline import (
    run_pipeline, run_pipeline_from_energies, run_pipeline_chains, run_pipeline_safe,
    PipelineResult, StageGraph, stage_name, stage_depends_on,
    STAGE_PARSE, STAGE_SCHEDULE, STAGE_SUPPLY, STAGE_ORDER, STAGE_DISPATCH,
)

# 文本入口（raises 透传）
def run_pipeline(text: String, focus: Float64, max_depth: Int,
                 chain_depth: Int, ground: Int) raises -> PipelineResult
# 能量入口（主导元素派生相位，直接 wuxing.schedule）
def run_pipeline_from_energies(energies: List[Float64], focus, max_depth, chain_depth, ground) raises -> PipelineResult
# 可视化：返回 [候选链, 规划链]（迁自 MVP run_cycle_chains）
def run_pipeline_chains(text, focus, max_depth, chain_depth, ground) raises -> List[List[Int]]
# 中性降级（非 raises）：异常 → ok=0、相位回落水、强度下限 1，不崩溃
def run_pipeline_safe(text, focus, max_depth, chain_depth, ground) -> PipelineResult
```

`PipelineResult`：固定标量槽（`phase` / `intensity` / `candidate_len` + `c0..c7` / `plan_len` + `p0..p7` / `confidence` / `policy_id` / `ok` / `failed_stage`），Movable 可按值返回。

## 四、与调度脑的接口契约

```
text ─► [wuxing.ScheduleDecision] ─► [liuhe.SupplyVector] ─► [qixing.DecisionSequence] ─► [scheduler.DispatchPlan]
            (策略:主导/权重/优势度)      (六向容量+harmony)         (优先级=权重×容量折扣+锚定)        (唯一派发器)
                                          ▲ pipeline 在此固化 PipelineResult
```
- 载体统一固定标量槽（不用 `List` 字段）→ 保 Movable 可按值返回。
- 错误一致：子模块 `raises` 透传；`run_pipeline_safe` 兜底中性降级，**不静默丢弃**。

## 五、基准（1M 次，ns/op）

`run_pipeline ≈ 997` · `run_pipeline_from_energies ≈ 917`（见 `benchmarks/results_pipeline.json`）。

## 六、下一步

`shifang`（§4.10）消费 `PipelineResult.plan` 做十方扇出；`observability`（§4.14）溯源 `failed_stage`/`confidence`/`policy_id`；`taiji` 回灌以 `phase`/`intensity`/`plan` 写长期记忆（Phase 5 闭环）。
