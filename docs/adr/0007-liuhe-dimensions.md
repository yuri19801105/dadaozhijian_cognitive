# ADR-0007: 六合维度映射决策

## 状态

已采纳

## 背景

六合(LiuHe)作为认知模型第 6 层的空间感知模块,需要将当前认知状态压缩为 6 维态势向量,作为"地图"供给七星(M7)进行动态规划。ADR-0004 已规定六合→七星的供给关系,本 ADR 记录六维具体映射的实现决策。

## 决策

将六合的「东西南北上下」六维分别映射为:

| 维度 | 符号 | 哲学含义 | 工程映射 | 计算方式 |
|------|------|---------|---------|---------|
| **东** | `east` | 可用扩展空间 | 九宫空闲格子数 | `ws.available_cells()` 返回值(0–9) |
| **西** | `west` | 已消耗资源 | 推理链深度 | `chain_depth` 参数直接传递 |
| **南** | `south` | 焦点活跃度 | 注意力强度 | `ws.get_focus_strength()` (注意力焦点的 weight 值,0–9) |
| **北** | `north` | 外部约束层级 | 最大推理深度 | `cfg.max_depth` 配置值 |
| **上** | `up` | 抽象层级 | 链深/2 | `min(9, chain_depth / 2)` |
| **下** | `down` | 接地程度 | 输入文本粒度 | `min(9, byte_length / 5)` |

## 输出类型

- `SIMD[DType.int64, 6]` — 6 元素 int64 SIMD 向量,适配 Mojo 向量化优化
- 可通过 `vec[i]` 索引访问各维度

## 理由

1. **数据源零新增依赖**:6 个维度全部可从现有模块(Workspace、Config、chain_depth、ground_input)直接获取
2. **SIMD 向量化**:Mojo 的 SIMD[DType.int64, 6] 允许后续对态势向量做向量化比较和排序
3. **单一函数接口**:`context_vector(ws, chain_depth, ground_input, cfg)` 函数式 API,避免非 copyable 类型的所有权问题

## 不变量

- 所有维度值 ≥ 0
- `up` + `down` ≤ 18(分别 clamped 到 9)

## 影响

- Workspace 新增 `focus_strength` 字段 + `available_cells()`、`get_focus_strength()` 方法(向后兼容)
- 新增 `Config` 结构体(供六合引用外部约束)
- 七星(M7)应以 `SIMD[DType.int64, 6]` 作为输入类型,消费六合的输出

## 性能基准

| 场景 | 1M 次耗时 | 单次 |
|------|----------|------|
| context_vector(完整 6 维计算) | 12ms | **12ns** |

六合向量获取完全不是性能瓶颈。
