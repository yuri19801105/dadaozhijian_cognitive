# ADR-0012: 遗留 `src/` 与 M1–M10 测试/工具软归档（Phase 7 收口）

## 状态

已接受（2026-07-13 执行：移动至 `archived/`，零破坏，可逆）

## 背景

项目在 M1–M10 阶段以扁平 `src/` 单仓开发，全部模块（bpe/regex/config/workspace/trigram/wu_xing/liuhe/qixing/taiji/pipeline/executor/emoji）与聚合测试 `tests/test_all.mojo`、工具 `tools/dump_emoji.mojo` 均置于 `src/` + 顶层 `tests/` + `tools/`。

Phase 1–5 落地后，新结构为**按模块目录**（core/、jiugong/、bagua/、wuxing/、liuhe/、qixing/、taiji/、pipeline/、scheduler/、shifang/、runtime/、observability/、io/、config/），并通过 `mojo run -I . -I core <module>/tests/test_*.mojo` 逐模块独立回归（全量 ~555 断言绿）。

`architecture-modular-plan.md` §7 Phase 7 标注「迁移旧 `src/*.mojo` 至新结构，删冗余」，并标记其为阻塞项（「删除需引用核查」）。本轮据此做引用核查并给出最优处理。

## 决策

采用**软归档（Strangler-Fig / 灰度下线）**而非物理 `rm -rf`：将遗留文件整体移动至 `archived/`，保留原内容、可随时移回，不破坏任何现行构建。

### 引用核查结论（关键证据）

- 路径式引用（权威）：`from src.` / `import src` / `-I src` / `mojo build -I src` 在**所有 `.mojo` 构建命令与 shell 脚本中均为空**（仅 `docs/`、`README`、历史 `memory` 的**注释/文档**提及旧 `-I src` 调用示例，非真实 import）。
- 新模块以 `-I . -I core` 包含，编译路径不含 `src/`，故 `src/` 从未进入现行任何测试套件。
- `tests/` 下 11 个 `test_*.mojo` 与 `tools/dump_emoji.mojo` 均 import 已不存在的顶层模块名（`bpe`/`regex`/`workspace`/`emoji`/`trigram`/`wu_xing`），属同期遗留，一并归档。
- 唯一保留：`tests/test_taiji.mojo`（import 当前 `taiji` 模块，现行 6/0 绿）、`tools/examples/`（被 README 引用的样例输出）。

### 旧文件 → 新模块映射（证明完全被取代，非独立有用）

| 遗留文件 | 取代它的新模块 | 备注 |
|---|---|---|
| `src/bpe.mojo` | `io/bpe_tokenizer.mojo` | 忠实移植 + 硬化（§4.15） |
| `src/regex.mojo` | `io/regex_tokenizer.mojo` | 同职责，io 版为从零重写（§4.15 已修正不实声明） |
| `src/config.mojo` | `config/config.mojo` | 原仅为 2 字段 `ImplicitlyCopyable` 结构体，已被 schema 驱动版取代 |
| `src/workspace.mojo` | `jiugong/` | 九宫=工作记忆网格（§4.9） |
| `src/trigram.mojo` | `bagua/` | 八卦八算子（§4.8） |
| `src/wu_xing.mojo` | `wuxing/` | 五行调度（§4.5） |
| `src/liuhe.mojo` | `liuhe/` | 六合态势（§4.6） |
| `src/qixing.mojo` | `qixing/` | 七星规划（§4.7） |
| `src/taiji.mojo` | `taiji/` | 太极回灌（§4.1） |
| `src/pipeline.mojo` | `pipeline/` + `scheduler/` | 认知流水线 + 总派发（§4.11/§4.12） |
| `src/executor.mojo` | `shifang/` | 十方执行器（§4.10） |
| `src/emoji.mojo` | `observability/` | 静语渲染（§4.14） |

遗留测试 `tests/test_{bpe,regex,workspace,trigram,wu_xing,liuhe,qixing,taiji,emoji,executor,integration_cycle,all}.mojo` → 对应能力已由各模块 `tests/` 内 `test_*.mojo` 覆盖（io 4 / config 8 / jiugong / bagua 17 / wuxing 81 / liuhe 57 / qixing 18 / taiji 10+ / pipeline 78 / scheduler 16 / shifang 27+22 / runtime 67 / observability 21 / core 78 断言）。

## 结果

- `archived/src-legacy-2026Q3/`（12 文件）、`archived/legacy-tests-2026Q3/`（11 文件）、`archived/legacy-tools-2026Q3/dump_emoji.mojo`（1 文件）。
- 现行 17 模块 / 24 套件回归 0 破坏（核验：config 8 · io 4 · taiji_state 10 · persistence 10 · runtime 67 · shifang 27 · sidecar 22 · observability 21 · core 7 套件全绿）。
- Phase 7 收口达成：「单一天纲结构」实现（顶层不再有孤儿 `src/` 与失效测试/工具）；后续若要彻底删除，观察期 0 引用即可物理移除。

## 备选方案（未采纳）

1. **立即 `rm -rf src/`**：不可逆、丢失历史、且本仓库非 git（无历史保护），风险高 → 弃。
2. **保留 src/ 并加 `//go:build legacy` 式编译约束**：Mojo 无 build tag 机制，且 src/ 完全无人引用，隔离无收益 → 弃。
3. **逐个文件迁移代码**：新模块已实现同等或更强能力，重复迁移属浪费 → 弃。
