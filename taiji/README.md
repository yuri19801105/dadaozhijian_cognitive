# `taiji/` — 太极（全局状态根 + 长期记忆回灌闭环）

太极为「至大无外」的全局状态根：一切派生自太极、最终回灌太极（闭环）。
与九宫分层——九宫承载单轮中间态，太极承载跨轮累积态，二者不重复造轮子。

## 模块构成（v1.4）

| 文件 | 职责 |
|---|---|
| `taiji_state.mojo` | 全局状态根：张量化能量态 `Tensor[9]`、决策链/相位/强度累积、`recall`/`feedback`/序列化 |
| `feedback_loop.mojo` | 回灌闭环入口：输出 → 归一能量(sigmoid) → 叠加 energy → 写历史 → 重算 seed → 巩固判定 |
| `consolidation.mojo` | 巩固/遗忘：EWC 思路 Mojo 化，强化高能量/近期轨迹，衰减低权重历史 |
| `persistence.mojo` | 长期记忆持久化：魔数 + CRC32 + WAL 重放 + sidecar，跨轮一致态恢复 |
| `cycle.mojo` | 四步闭环编排：`recall → plan → execute → feedback` + 自动/手动落盘 |
| `reinjection.mojo` | **【v1.3 新增】回灌衔接**：把执行层产物安全回灌进 `FeedbackLoop` |

## `reinjection.mojo` — 回灌衔接（Phase 5 闭环收口）

把「架构能说话 / 可审计」之后的全部执行层产物，安全回灌进太极长期记忆。

### 对接的数据源（§4 需求 1：对接回灌数据源）
- `PipelineResult`（调度产物：相位/强度/置信度/策略/规划链）
- `ShifangOutput`（十方扇出：十向动作码/ok/degraded/latency）
- `Tracer`（决策溯源：与规划链对应的 span 覆盖度校验）
- `Metrics`（运行指标：鲁棒性退化率 → 回灌强度权重）

### 字段映射（§4 需求 2：数据格式转换与字段映射）
对齐 `TaijiState.feedback(output, decision, phase, intensity)` 既有签名（**不改动** `TaijiState`/`FeedbackLoop`/`CognitiveCycle`）：

| 目标字段 | 来源映射 |
|---|---|
| `output: String` | `[回灌] <输入> phase=.. conf=..% policy=.. plan=[木→火→土] 十方=N向(ok=.. degraded=..)` |
| `decision: List[Int]` | 优先 `PipelineResult.plan`，缺失则退化为 `candidates`（七星决策链） |
| `phase: Int` | `PipelineResult.phase` |
| `intensity: Float64` | `confidence * (1 - robustness_degradation)`，扇出 `degraded=1`/`ok=0` 再折半，钳制 (0,1) |

### 异常处理与日志（§4 需求 3：异常处理与日志记录）
- `validate_source()` 在接入前拦截非法源（相位/置信度越界、扇出计数/状态位非法）→ 记 `WARN` + `AUDIT REINJECT_REJECTED`，**不触碰**状态根。
- `reinject_safe()` 全程 `try/except` 隔离：任何异常 → 记 `ERROR` + `AUDIT REINJECT_DENIED`，返回 `False`，**绝不向上传播**。
- 结构化日志缓冲（`logs: List[String]`，`observability.logging` 的 `INFO/WARN/ERROR/AUDIT`）便于排查；`summary()` 给出 `injected/rejected/errors/last_status`。

### 不影响既有功能（§4 需求 4）
纯增量衔接层，仅复用 `FeedbackLoop.feedback` 公共入口；`TaijiState`/`FeedbackLoop`/`CognitiveCycle` 零改动。
测试 `test_bridge_isolates_errors_and_keeps_existing_functional` 证明：即便非法输入也仅返回 `False`；独立的 `CognitiveCycle` 照常推进，互不干扰。

## 持久化格式迁移与并发写锁（v1.4 增强）

`persistence.mojo` 在 v1.4 完成两项 hardening（对应 `docs/architecture-modular-plan.md` §4.1.4）：

### 格式版本迁移（TAIJI_FORMAT_VERSION 1 → 2）
- 快照文件头部为四行：魔数 `TAIJ` / 格式版本 / 载荷 / `CRC:<crc32>`（IEEE 802.3 自实现）。
- v2 起 `TaijiState` 新增 `last_lineage: Int`（跨进程 observability 溯源串联键），序列化为第 17 字段。
- `TaijiState.deserialize` 向后兼容：旧 v1 仅 16 字段（无 `last_lineage`）以 `0` 兜底补到 17，使真·16 字段 v1 快照可载入并升级。
- `Persistence.migrate(state) -> Int`：快照版本 < 当前版本则重新落盘为 v2 并返回 1；已最新返回 0。
- `test_roundtrip_v1_16field_snapshot` 端到端验证：16 字段 v1 快照真实落盘 → `load` 读回（`last_lineage=0`）→ 重新 `save`（升级 v2/17 字段）→ 再 `load` 字段不丢、能量守恒。

### 并发写锁（advisory 互斥）
- `_acquire_lock() -> Int`：读锁文件，已持 `1` 视为冲突返回 0，否则写 `1` 返回 1；`_release_lock()` 写 `0`。
- 受 Mojo 1.0.0b2 无 `rename`/`fcntl` 约束，以"读-判-写"最佳努力 advisory 锁模拟软护栏（单进程顺序执行可正确互斥）。
- `test_lock_advisory` 验证未释放不可二次获取、释放后可再获取。

测试：`taiji/tests/test_persistence.mojo`（10 断言全绿，含上述两项 + 快照/WAL/崩溃恢复/CRC）。

## 测试与基准

```
mojo run -I . -I core taiji/tests/test_reinjection.mojo     # 11 断言全绿
mojo run -I . -I core taiji/benchmarks/bench_reinjection.mojo
```

| 基准 | ns/op |
|---|---|
| `reinject_safe`（校验+映射+feedback+日志） | ≈ 2767 |
| `map_primitives`（输出串+决策链+强度） | ≈ 1293 |

开销主要来自可读串拼装与日志 `append`，**不进入** `feedback` 既有热路径（sub-ns 级）。

## 运行约束（Mojo 1.0.0b2 已验证）
- `PipelineResult`/`ShifangOutput`/`Metrics` 为 `(Movable)`；`Tracer`/`TraceSpan` 为 `TrivialRegisterPassable`——在 `_reinject` 中因被多次读取，Mojo 自动借入，可安全传给多个映射 helper。
- `List[Int]` 非 Movable → `reinject_decision` 以 `^` 移动返回；`feedback` 的 `decision` 参数为最后一次使用，自动移动入参。
- `List.append` 为 `raises`，故 `_log` 标记 `raises`，由 `reinject_safe` 的 `try` 统一兜住。
