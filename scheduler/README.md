# scheduler/ — 总调度（统一派发器）

> **【v1.0 已落地 ✅】** TDD 零桩函数实现。`policy`/`dispatcher` 两文件 + 测试 **16 断言全绿** + 基准（见 `benchmarks/`）。

总调度是认知架构的"调度总成"：把 `wuxing`(策略) + `liuhe`(供给) + `qixing`(排序) 合成为**唯一派发器** `DispatchPlan`，即"重构后的 AI 底层调度逻辑"。详见 `docs/philosophy/` 与 `docs/phase4-scheduler-design.md`。

## 子模块
- **`policy.mojo`** — `SchedulerPolicy`（gen_rate/ke_rate/policy_id，可插拔策略载体）；`default_policy()`（默认策略，policy_id=0）。
- **`dispatcher.mojo`** — `DispatchPlan`（固定八槽 Movable 载体：有序链 + `confidence` + `policy_id`）；`dispatch(energies, focus, max_depth, chain_depth, ground) raises`：
  1. `wuxing.schedule` → 策略；2. `liuhe.build_supply` → 供给；3. `qixing.build_sequence` → 有序链；4. 封装 `DispatchPlan`。
  `dispatch_from_phase(quadrant, intensity, ...)` 经四象→五行种子入口。`apply_policy(mut, policy)` 装配策略。

## 编排策略 · 优先级机制 · 错误处理
- **编排策略**：三模块严格串行合成，单一事实源（`ScheduleDecision`→`SupplyVector`→`DecisionSequence`→`DispatchPlan`）。
- **优先级机制**：端到端优先级源自 `wuxing` 归一权重（策略层）→ 经 `liuhe` 容量折扣（资源约束层）→ 由 `qixing` 定序（排序层），最终固化为 `DispatchPlan.seq` 顺序；`confidence` 沿用主导优势度作派发可信度指标。
- **错误处理**：子模块 `raises` 透传（能量长度≠5/负/零总量、上下文非法、空候选链）；调用方决定重试或静默；**策略装配失败回退 `policy_id=-1`**（降级而非崩溃，当前默认策略不会失败，预留给未来可插拔策略）；全程确定性，故障隔离不影响 `taiji` 状态根。

## 基准（1M 次，ns/op）
`dispatch≈487` / `dispatch_from_phase≈666`（见 `benchmarks/results_scheduler.json`）。

## 测试
`mojo run -I . -I core scheduler/tests/test_scheduler.mojo` → `scheduler -> passed: 16 failed: 0`。
