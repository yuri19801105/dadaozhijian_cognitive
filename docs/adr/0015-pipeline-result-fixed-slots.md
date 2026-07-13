# ADR-0015: PipelineResult.plan 固定槽位设计（替代 List[Int]）

## 状态
Accepted (2026-07-13)

## 背景
`PipelineResult` 需在模块间按值传递（`Movable`），但含 `List[Int]` 字段会使其非 `Movable`。调度链最大长度固定（8 步），无需动态列表。

## 决策
`PipelineResult.plan` 设计为固定标量槽 `p0..p7 : Int` + `plan_len : Int`：
```mojo
struct PipelineResult:
    var p0: Int; var p1: Int; var p2: Int; var p3: Int
    var p4: Int; var p5: Int; var p6: Int; var p7: Int
    var plan_len: Int
    var candidates: List[Int]   # 仅候选集（非 Movable，仅内部用 mut 传递）
    var confidence: Float64
    var policy_id: Int
    var failed_stage: Int
```

## 序列化/反序列化
- `to_payload/from_payload` 仅序列化 `plan_len` 个有效槽位
- 下游 `scheduler/dispatcher`、`shifang/executor` 读取时按 `plan_len` 遍历 `p0..p{plan_len-1}`

## 影响
- `wuxing/scheduler_core.mojo` `ScheduleDecision` 同理固定槽
- `pipeline/orchestrator.mojo` 组装时按顺序填槽
- 测试 `pipeline/tests/test_pipeline.mojo` 显式验证槽位正确性

## 备选
- `SmallVector<8, Int>`：Mojo 无标准库实现
- 堆分配 + `OwnedRef`：引入生命周期复杂度