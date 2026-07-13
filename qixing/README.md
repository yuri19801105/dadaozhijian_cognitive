# qixing/ — 七星（决策链排序）

> **【v1.0 已落地 ✅】** TDD 零桩函数实现。`priority`/`ordering`/`sequence` 三文件 + 测试 **18 断言全绿** + 基准（见 `benchmarks/`）。

七星是认知架构的"定序枢机"：以**北斗定序**为隐喻，对 `wuxing` 派生的候选步骤按**优先级排序**，产出有序执行链。它不生产策略也不生产资源，而是消费上游：以 `wuxing.ScheduleDecision` 的归一权重为**优先级源**，以 `liuhe.SupplyVector` 的六向容量为**资源约束**（容量不足的方向其上步骤被折扣），最终用选择排序降序定序，同优先级以 `abstract_level` 锚定（高抽象优先）。详见 `docs/philosophy/qixing.md`。

## 子模块
- **`priority.mojo`** — `abstract_level(step)`（步骤抽象度：土5／火金3／水木2）；`capacity_factor(supply, step)`（五行配六合方向容量 ÷ 最大深度配额，截断 [0,1]）；`priority_of(step, decision, supply)` = 权重 × 容量折扣；`priority_list`。
- **`ordering.mojo`** — `order_chain(decision, supply) raises`：取相生链候选（去重／去 -1）→ 按 `priority_of` 降序选择排序（含抽象度锚定）；空候选链 `raises`。
- **`sequence.mojo`** — `DecisionSequence`（固定八槽 Movable 载体）；`build_sequence(decision, supply) raises` 包装 `order_chain` 结果为有序链。

## 与调度脑的数据流契约
```
wuxing.ScheduleDecision ─┐
                         ├─► qixing.order_chain / build_sequence ─► DecisionSequence(有序执行链)
liuhe.SupplyVector    ─┘        │  优先级 = weight × capacity_factor(element_direction)
```
- 依赖：`core`、`wuxing`、`liuhe`。
- 错误处理：空候选链 `raises`；越界元素 `capacity_factor=0`（不静默丢弃，显式降级为最低优先级）。

## 基准（1M 次，ns/op）
`order_chain≈476` / `priority_of≈181` / `build_sequence≈507`（见 `benchmarks/results_qixing.json`）。

## 测试
`mojo run -I . -I core qixing/tests/test_qixing.mojo` → `qixing -> passed: 18 failed: 0`。
