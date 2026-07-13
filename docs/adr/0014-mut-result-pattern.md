# ADR-0014: 统一 `mut result` 回填范式替代按值返回

## 状态
Accepted (2026-07-13)

## 背景
Mojo 1.0.0b2 中含 `String`/`List` 字段的结构体非 `Movable`，不能按值返回/传参（如 `CycleResult`、`ConnectorResponse`、`PipelineResult`）。

## 决策
全项目统一改为“输出参数回填”范式：
```mojo
def run(text: String, cfg: CycleConfig, mut result: CycleResult) raises
def step(mut cycle_result: CycleResult) raises
```
所有原 `-> CycleResult` 的函数改为 `mut CycleResult` 参数，调用方先声明 `var result = CycleResult()` 再传入。

## 影响文件
- `taiji/cycle.mojo`：`CognitiveCycle.run` / `flush`
- `taiji/api.mojo`：`run_cycle`
- `runtime/integration.mojo`：`BackfillSupervisor.step`
- `shifang/dispatch.mojo`：移除 `fanout_with_response`，改内联 `conn.dispatch` + `build_prompt`

## 测试验证
所有测试套件（taiji 49、shifang 27、runtime 67、persistence 9 等）全绿。

## 备选
- 将结构体字段改为 `Tensor`/`Scalar`：破坏语义，工作量大
- 使用 `OwnedRef`/`Arc`：Mojo 当前不稳定