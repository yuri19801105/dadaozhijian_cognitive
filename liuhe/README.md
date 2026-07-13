# liuhe/ — 六合（供给 / 资源编排）

> **【v1.0 已落地 ✅】** TDD 零桩函数实现。`directions`/`supply`/`harmony` 三文件 + 测试 **57 断言全绿** + 基准（见 `benchmarks/`）。

六合是认知架构的"供给器"：以**六向空间整全**（上下四方）与**地支和合**（亲和—合化）为双重隐喻，把五行策略投影为**六向资源供给向量**，并向 `qixing`（排序）与 `scheduler`（总派发）提供"每个方向/上下文维度的可用容量"。详见 `docs/philosophy/liuhe.md`。

## 子模块
- **`directions.mojo`** — 六向维度常量（东0/西1/南2/北3/上4/下5）、`direction_name`/`opposite`/`axis_of`，以及 `element_direction`（五行配六合：木东·火南·金西·水北·土上）。
- **`supply.mojo`** — `SupplyVector`（固定六槽 + `harmony`，保 Movable 可按值返回）；`build_supply(energies, focus, max_depth, chain_depth, ground) raises` 由五行能量 + 上下文派生六向容量，并据能量方差派生整体和合度（越均衡越和合）。
- **`harmony.mojo`** — `he_harmony(a,b)` 十二地支六合配对→合化五行（非六合对显式降级 `NEUTRAL_ELEMENT`=土，不静默丢弃）；`harmony_index` 亲和度；`merge_supplies` 多源逐向归并（和合统一）。

## 与调度脑的接口契约
```
wuxing.ScheduleDecision ──► liuhe.build_supply(energies, ctx) ──► SupplyVector{s0..s5, harmony}
                                                                        │
                                            qixing.order_chain(decision, supply) 取 element_direction(step) 作容量折扣
```
- 依赖：`core`、`wuxing`（能量 + `total_energy`/`variance`）。
- 错误处理：`build_supply` 对 `max_depth<=0`/`chain_depth<0`/`ground<0` `raises`；`SupplyVector.get/set` 方向越界 `raises`；`he_harmony` 未知配对降级中性元素。

## 基准（1M 次，ns/op）
`build_supply≈178` / `he_harmony≈1` / `merge_supplies≈0`（见 `benchmarks/results_liuhe.json`）。

## 测试
`mojo run -I . -I core liuhe/tests/test_liuhe.mojo` → `liuhe -> passed: 57 failed: 0`。
