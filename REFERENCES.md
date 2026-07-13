# REFERENCES.md — 已核实的参照与事实依据

> 本文件落实 `docs/implementation-plan.md` §1.4「记录核实过的参照链接」。
> 所有链接与数据均经调研核实,作为 M1–M7 各核心算法正确性 / 性能对比的基线。
> 版本与决策背景详见 `docs/adr/0005-mojo-tdd-bpe-mvp.md`。

## 1. 工具链 / 语言

| 项目 | 链接 / 说明 |
|---|---|
| Mojo 官方安装文档 | <https://docs.modular.com/mojo/manual/install/> |
| Mojo 1.0 beta 发布 | 2026-05-07 发布,目标 2026 秋定稿;Apple Silicon GPU 支持已于 2025-09 加入 |
| 本项目锁定版本 | **Mojo `v1.0.0b2`**(`2cf4d08a`)。原定 `v1.0.0b1` 因 conda 包服务器超时无法获取,改用已预装的 b2(见 ADR-0005 勘误) |

## 2. BPE / 分词器参照

| 项目 | 链接 | 用途 |
|---|---|---|
| Karpathy/minbpe | <https://github.com/karpathy/minbpe> | 字节级 BPE 参照,`BasicTokenizer` 用于 Mojo 正确性 + 性能对比。**已固化进仓库**:`benchmarks/references/minbpe/`(pinned @ `1acefe89412b20245db5a22d2a02001e547dc602`,MIT) |
| OpenAI GPT-2 encoder | <https://github.com/openai/gpt-2/blob/master/src/encoder.py> | minbpe 字节级 BPE 算法的算法来源(basic.py 头部引用) |
| dorjeduck/minbpe.mojo | <https://github.com/dorjeduck/minbpe.mojo> | Karpathy minbpe 的 Mojo 移植(基于 Mojo 25.5,trait 式 `Tokenizer`);初步基准比原始 Python 快约 **3x** |

## 3. Mojo 生态(选型调研)

| 项目 | 链接 | 备注 |
|---|---|---|
| dorjeduck/llm.mojo | <https://github.com/dorjeduck/llm.mojo> | llm.c 移植,M2 MacBook 训练循环 1732ms vs C+OpenMP 1836ms(快约 6%) |
| basalt-org/basalt | <https://github.com/basalt-org/basalt> | 纯 Mojo ML 框架,benchmark 接近 PyTorch |
| drobertson-dev/unsloth-mojo | <https://github.com/drobertson-dev/unsloth-mojo> | NF4→fp16 反量化内核,L4 上 2.47s 快于 Unsloth CUDA 3.02s |

## 4. 性能区间事实依据

- **数学内核**:Apple Silicon 上相对纯 Python 可达 **20–180x**(arXiv:2606.16059,2026-06,**限定为数学内核**)。
- **BPE 预期**:含大量字符串 / 字典操作,预期提速更接近 minbpe.mojo 的 **~3x**,而非极端 20–180x;本项目实测 Mojo BPE vs Python minbpe 约 **~15x**(因跳过了 GPT-2 式 regex 预分词,基准数据见 `benchmarks/results.json`)。

## 5. 本仓库决策记录(ADR)

`docs/adr/` 下各 ADR 为本项目技术决策的「真相源」:

- `0001-cosmology-as-architecture.md` — 宇宙观即架构
- `0003-language-agnostic-contracts.md` — 语言无关契约
- `0004-liuhe-feeds-qixing.md` — 六合→七星 供给关系
- `0005-mojo-tdd-bpe-mvp.md` — **Mojo 1.0 + TDD,MVP=BPE**(本 REFERENCES 的主要依据)
- `0006-regex-tokenizer-simplification.md` — Regex 分词器简化
- `0007-liuhe-dimensions.md` / `0008-qixing-priority-algorithm.md` / `0009-executor-mapping.md` — 六合 / 七星 / 十方执行器

## 6. 可复现性说明

- Mojo 基准:`mojo run -I src benchmarks/bench_bpe.mojo`
- Python 对照:`python benchmarks/bench_minbpe.py`(自动使用 `benchmarks/references/minbpe/` 内固定版本,无需外部 `/tmp` 依赖)
- 对比结果快照:`benchmarks/results.json`(`benchmarks/results_regex.json` 为 M2)
