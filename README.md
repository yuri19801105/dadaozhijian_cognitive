# 认知模型 · Cognitive Model

**基于数字宇宙观的实时认知引擎**  
将「太极 → 十方」的东方哲学映射为可执行的 AI 认知流水线，全认知周期 < 1µs。

![Mojo](https://img.shields.io/badge/Mojo-1.0.0b2-ff6b6b)

![Tests](https://img.shields.io/badge/Tests-116%2F116%20✅-brightgreen)

![License](https://img.shields.io/badge/License-MIT-blue)

---

## 🧠 核心理念

> 万物皆数，认知即计算。

本项目将**东方哲学**（太极、两仪、三才、四象、五行、六合、七星、八卦、九宫、十方）与**现代计算机科学**（向量化、SIMD、流水线、调度器）深度融合，构建了一套可解释、可测量、可实时运行的认知架构。

它不是「用 AI 解释玄学」，而是**用玄学的结构去重构 AI 的底层调度逻辑**。

---

## 🚀 性能一览

| 模块         | 功能           | 性能                                 |
| :--------- | :----------- | :--------------------------------- |
| **M1 BPE** | 字节级分词        | 78KB 文本训练 **21ms** (15× 快于 Python) |
| **M4 八卦**  | 8 种推理算子      | **3 亿 ops/s** (1M 调用 26ms)         |
| **M5 五行**  | 动态调度器        | **100 ns/次**                       |
| **M6 六合**  | 空间态势感知       | **12 ns/次**                        |
| **M7 七星**  | 动态规划排序       | **270 ns/次**                       |
| **全认知周期**  | 输入 → 规划 → 输出 | **< 1 µs** (786 ns)                |

📊 **全量回归**：11 个测试套件，**116/116 全绿**（早期 M1–M10 阶段；详见各模块 README 的现状口径）。

---

## 🆕 最新进展（v1.4 · 见各模块 README）

在 M1–M10 流水线之上，已落地三件跨模块增强（优先级经评估后按 ②→③→① 顺序推进）：

1. **② 回灌 × 溯源 跨进程持久化串联**（observability/store.mojo）：`TraceRecord`/`TraceLedger` 将 taiji 回灌事件与 observability 溯源链路以 `lineage_id` 配对，跨进程以 JSONL 落盘，可由 `store_reader.py` 独立校验（18 断言绿）。
2. **③ runtime 回灌健康/超时门控**（runtime/lifecycle.mojo）：`RuntimeState` 纳入 `record_backfill`/`backfill_success_rate`；`is_healthy`/`can_execute` 据此门控；新增 `BackfillGate`（复用 `TimeoutGuard`）+ `BackfillSupervisor` 端到端闭环（67 断言绿）。
3. **① shifang 真实 LLM 侧车**（shifang/sidecar.mojo + shifang/llm_sidecar.py）：以 **Mojo→python3 子进程桥接**（`setenv("LLM_PROMPT")` + `system` + 读回响应文件，UTF-8 解码）让 `call_external` 真正抵达真实 LLM；设 `LLM_API_KEY` 即调 OpenAI 兼容端点，否则优雅降级（22 断言绿，含桥接到达验证）。早期"C shim 覆盖 Mojo 符号"方案因 macOS 链接器不支持多定义覆盖而废弃。

> 当前 **30 个现行测试套件全绿**；另有 13 个顶层 `tests/` 遗留测试因引用早期 `src/` 布局模块（已迁移至 `core/`、`wuxing/`、`jiugong/` 等）而失效，属独立技术债，不在本次范围。

---

## 🗺️ 架构总览

```text
十方(多模态输入)
  ├─ M1 BPE / M2 Regex (分词入口)
  ↓
九宫 (M3 工作记忆)
  ↓
五行 (M5 调度器) ──→ 六合 (M6 态势地图) ──→ 七星 (M7 动态规划)
  ↓                                                     ↓
八卦 (M4 推理算子库) ←─────────────────────────────┘
  ↓
十方(多模态输出) ←── M10 执行器
  ↑
  └── M9 长期记忆 (固件层扩展)
```

**数据流**：  
`原始文本` → 分词 → 写入九宫 → 五行调度 → 六合建境 → 七星排序 → 八卦推理 → 执行器 → `结构化输出`

---

## 🛠️ 快速开始 (Mojo)

### 1. 环境准备

确保已安装 [Mojo SDK](https://docs.modular.com/mojo/) 1.0.0b2+。

### 2. 运行测试

```bash
cd /Users/caimi8848/dadaozhijian_cognitive
mojo -I src tests/test_all.mojo
# 预期输出: 116/116 tests passed ✅
```

### 3. 简单调用

```mojo
from pipeline import run_cycle
var result = run_cycle("天气太热了，开空调吧。")
print(result)
```

#### M8 静语可视化（调试 / 演示）

把任意输入文本经认知流水线（五行候选链 + 七星规划链）渲染为 emoji / 文本化图形并落盘：

```bash
mojo run -I src tools/dump_emoji.mojo "<文本>" [输出基名]
# 例: mojo run -I src tools/dump_emoji.mojo "项目快上线了，压力好大" tools/examples/emoji_demo
# 生成 tools/examples/emoji_demo.txt (文本行式) + emoji_demo.svg (可浏览器打开)
```

输出为确定性文件，纯观测层，不改变系统行为。范围裁剪与约束见 `docs/adr/0011-emoji-scope.md`。

---

## 📂 项目结构

```text
认知模型/
├── README.md             # 项目总览
├── CONTEXT.md            # 13 个哲学概念的工程定义
├── docs/
│   ├── architecture.md   # 完整架构设计 + Mojo API 签名
│   └── adr/              # 架构决策记录 (ADR-0001 ~ 0011)
├── src/                  # 核心源码 (Mojo)
│   ├── bpe.mojo          # M1 字节对编码
│   ├── regex.mojo        # M2 语义切分
│   ├── workspace.mojo    # M3 九宫工作记忆
│   ├── config.mojo       # 全局配置 (Config)
│   ├── trigram.mojo      # M4 八卦推理算子
│   ├── wu_xing.mojo      # M5 五行调度器
│   ├── liuhe.mojo        # M6 六合态势
│   ├── qixing.mojo       # M7 七星规划
│   ├── executor.mojo     # M10 执行器
│   ├── emoji.mojo        # M8 静语可视化 (EmojiGraph)
│   └── pipeline.mojo     # 端到端流水线
├── tests/                # 单元测试
├── benchmarks/           # 性能基准
└── pixi.toml             # Pixi 环境配置
```

---

## 📖 文档索引

- **概念定义**：[CONTEXT.md](./CONTEXT.md)
- **架构与契约**：[docs/architecture.md](./docs/architecture.md)
- **设计决策**：[docs/adr/](./docs/adr/)
  - ADR-0001: 数字宇宙观映射
  - ADR-0002: 单上下文布局
  - ADR-0003: 语言无关契约
  - ADR-0004: 六合→七星供给关系
  - ADR-0005: Mojo + TDD 里程碑
  - ADR-0006: 正则分词器实现 (M2)
  - ADR-0007: 六合维度映射
  - ADR-0008: 七星优先级算法
  - ADR-0009: 执行器算子映射
  - ADR-0010: 太极回灌闭环契约
  - ADR-0011: 静语可视化范围裁剪 + Mojo 约束适配

---

## 🧩 后续路线

- ✅ **M1–M10 核心认知流水线** (已完成)
- ✅ **M9 长期记忆增强** (已实现, 见 ADR-0010)
- ✅ **M8 可视化/序列化** (调试工具，优先级最低，见 ADR-0011)

---

## 📜 许可证

MIT License
