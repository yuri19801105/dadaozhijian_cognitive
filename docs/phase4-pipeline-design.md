# Phase 4 · L5 流水线 `pipeline/` 端到端编排 — 设计规格（v1.1）

> 配套落地任务：将 MVP 线性 `run_cycle` 重构为**阶段图（stage graph）**驱动的可观测、可断点重放流水线。
> 依赖：wuxing（策略）· liuhe（供给）· qixing（排序）· scheduler（总成）。运行：`mojo run -I . -I core pipeline/tests/test_pipeline.mojo`。
> 代码规范遵循 `skill: mojo-modular-tdd`（Mojo 1.0.0b2）。

---

## 一、当前进度 / 待完成功能点

| 项 | 落地前状态 | 本轮目标 |
|---|---|---|
| 模块目录 | 仅规划占位（§4.12）+ MVP `src/pipeline.mojo` 线性 `run_cycle` 桩 | 从零 TDD 落地 `stages.mojo` + `orchestrator.mojo` |
| 阶段图 | MVP 无（线性顺序硬编码） | 显式 DAG（`StageGraph`）+ 依赖门控 + 断点重放 |
| 可观测中间态 | MVP `run_cycle_chains` 仅返回链 | `PipelineResult` 固化「候选链 / 规划链 / confidence / policy / 失败阶段」 |
| 错误处理 | MVP 无降级 | `raises` 透传 + `run_pipeline_safe` 中性降级（不崩溃） |

**待完成功能点（本轮逐一实现并验证）：**
1. 阶段定义与依赖图（`stages.mojo`）：5 阶段常量、`stage_name`、`stage_depends_on`、`StageGraph`（`can_run`/`mark_done`/`validate`/`run_order`）。
2. 编排器（`orchestrator.mojo`）：文本入口 `run_pipeline`、能量入口 `run_pipeline_from_energies`、可视化中间链 `run_pipeline_chains`、安全入口 `run_pipeline_safe`。
3. `PipelineResult`（固定标量槽，Movable，可按值返回）承载全链路产物。

---

## 二、pipeline 阶段图（依赖 DAG）

```
        (无前置)
   STAGE_PARSE ─┐
               ↓
  STAGE_SCHEDULE ─┐       五行调度: wuxing.schedule_from_phase
                  ↓
     STAGE_SUPPLY ─┐       六合供给: liuhe.build_supply
                   ↓
    STAGE_ORDER ─┐         七星定序: qixing.build_sequence
                 ↓
  STAGE_DISPATCH            总派发: 封装 DispatchPlan
```
- 依赖为 **线性紧邻链**：`dep(stage) = stage - 1`（PARSE 无前置）。
- `StageGraph.can_run(stage)`：前置完成（或 PARSE）才允许执行 → 实现**依赖门控 + 断点重放**（某阶段失败时后续阶段自动停摆，结果记 `failed_stage`）。

---

## 三、orchestrator 编排逻辑与接口定义

### 3.1 入口函数
| 函数 | 签名 | 说明 |
|---|---|---|
| `run_pipeline` | `(text, focus, max_depth, chain_depth, ground) raises -> PipelineResult` | 文本入口：解析相位/强度 → 五行调度 → 六合供给 → 七星定序 → 总派发 |
| `run_pipeline_from_energies` | `(energies: List[Float64], focus, max_depth, chain_depth, ground) raises -> PipelineResult` | 能量入口：主导元素派生相位，直接 `wuxing.schedule` |
| `run_pipeline_chains` | `(...) raises -> List[List[Int]]` | 可视化：返回 `[候选链, 规划链]`（迁自 MVP `run_cycle_chains`） |
| `run_pipeline_safe` | `(...) -> PipelineResult`（非 raises） | 中性降级：内部 `try/except`，失败返回 `ok=0` 不抛 |

### 3.2 编排步骤（每个 stage 在 `StageGraph.run_order()` 循环中按 `can_run` 门控执行）
1. **PARSE**：`_detect_phase(text)`（空→水/短→木/中→火/长→土/极长→金），`_compute_intensity(text)`（字节长/10 截断 1..9；空输入下限 1 防止 `schedule_from_phase` 全零 raise）。
2. **SCHEDULE**：`wuxing.schedule_from_phase(phase, intensity)` → `ScheduleDecision`；候选链 = `decision.chain_list()`。
3. **SUPPLY**：`liuhe.build_supply(decision.weights_list(), focus, max_depth, chain_depth, ground)` → `SupplyVector`。
4. **ORDER**：`qixing.build_sequence(decision, supply)` → `DecisionSequence`。
5. **DISPATCH**：将 `seq` 装入 `DispatchPlan`，`confidence = decision.confidence`，`policy_id = default_policy().policy_id`。

### 3.3 `PipelineResult`（固定标量槽 · Movable）
```
phase, intensity, candidate_len, c0..c7, plan_len, p0..p7,
confidence, policy_id, ok(1/0), failed_stage(-1 或阶段 id)
```
方法：`append_candidate`/`candidate_at`/`append_plan`/`plan_at`（八槽留余量，链长 ≤5 安全）。

---

## 四、跨模块接口契约（与已落地模块一致）

```
text ──► [wuxing.ScheduleDecision] ──► [liuhe.SupplyVector] ──► [qixing.DecisionSequence] ──► [scheduler.DispatchPlan]
            (策略:主导/权重/优势度)      (六向容量+harmony)         (优先级=权重×容量折扣+抽象度锚定)    (唯一派发器)
                                          ▲ pipeline 在此固化 PipelineResult
```
- **载体统一固定标量槽**（不用 `List` 字段）→ 保 Movable 可按值返回（`ScheduleDecision`/`SupplyVector`/`DecisionSequence`/`DispatchPlan`/`PipelineResult` 同范式）。
- **错误一致**：子模块 `raises` 透传（调用方决定重试/静默）；`run_pipeline_safe` 兜底中性降级（相位回落水、强度下限 1、`ok=0`、`failed_stage` 标记），**不静默丢弃**。
- **确定性**：纯函数变换，无随机；故障隔离（pipeline 异常不影响 `taiji` 状态根——状态回灌由 Phase 5 的 `runtime`/`shifang` 衔接）。

---

## 五、实现要求（Mojo 1.0.0b2 硬约束，已实证）
- 禁 `let`/`fn`/`alias`/`inout`/`bitcast`/`String.strip`/`List[Int](...)` 构造 → 用 `var`/`def`/`comptime`/`mut`/`List.append`/`String(Float64)`。
- `Dual` 借入参数落字段 → `from_parts` 重构（本模块不直接持有 `Dual`，能量以 `Float64` 传递）。
- `global` 计数器不稳 → 测试用 `struct Counter(Movable)` 以 `mut` 传入。
- `raises` 函数须标注 `raises`（编排器 `run_pipeline` 等标 `raises`；`run_pipeline_safe` 用 `try/except` 兜）。
- 基准 DCE：`@extern("clock") def clock() abi("C") -> Int` + sink 反馈 + 连续变化种子。

---

## 六、下一步（规划已就绪，待确认）
1. `shifang`（§4.10）消费 `PipelineResult.plan` 做十方扇出（真实模型/API 连接器）——pipeline 已为其实例化 `DispatchPlan`。
2. `runtime`（§4.13）生命周期/超时；`observability`（§4.14）全链路溯源 `failed_stage`/`confidence`/`policy_id`。
3. `taiji` 回灌：以 `phase`/`intensity`/`plan` 写长期记忆（Phase 5 闭环）。
