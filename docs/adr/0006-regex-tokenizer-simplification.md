# ADR-0006: M2 正则分词器实现

> 状态：已采纳（实际实现已落地）。
> 本文件描述的是**当前真实实现**。初版曾设想「以 ASCII 空格 + 标点拆分的简化方案」(`_split_text`)，但该方案已被下述手工复刻实现取代，因简化方案对连续小写字母切分粒度偏粗、且无法覆盖 GPT-4 的完整切分语义。特此更正。

## 背景

十方(10)文本入口需要支持中英文混合与特殊 token 的预切分。对标 minbpe 的 `RegexTokenizer`，原方案依赖 Python 的 regex 预分词（如 GPT-4 的 `'s|'t|'re|...|\p{L}+|\p{N}{1,3}|...` 模式）。但在 Mojo 1.0.0b2 中 stdlib 未提供正则引擎，也不支持第三方 regex 绑定。

## 决策（实际落地）

采用**手工复刻 GPT-4 split pattern** 的方案：在 BPE 核心（`src/bpe.mojo`）之上叠加 `RegexTokenizer`（`src/regex.mojo`），以纯 Mojo 字符串扫描复刻 GPT-4 的切分语义，**不引入任何第三方正则引擎**。

具体要点：

1. **手工复刻正则切分** — `_pretokenize(text)` 将文本按 GPT-4 split pattern 的 7 条分支（`_alt1`…`_alt7` + `_best_match` 最长匹配 / POSIX 式）逐字符扫描切分，等价于 `regex` 库的 `re.findall(GPT4_SPLIT_PATTERN, text)`。
2. **特殊 token 支持** — `<|endoftext|>` 等预定义特殊 token 在 `encode_ordinary` 前直接映射为独立 token ID，不参与 BPE 合并（对应 minbpe 的 `encode(text, allowed_special)`）。
3. **复用 BPE 合并核心** — 每个 chunk 内部复用 `_encode_chunk` 的变长合并（按 merge rank 贪心），与 minbpe 的 `_encode_chunk` 一一对应。
4. **契约对齐** — `train(text, vocab_size)` / `encode_ordinary(text)` / `encode(text, allowed_special)` / `decode(ids)` 与 minbpe `RegexTokenizer` 同名方法语义一致。

## 理由

- Mojo 1.0.0b2 stdlib 未提供正则引擎，手工复刻是最低风险的可用替代，且零第三方依赖、完全可复现。
- 手工复刻的切分结果与 minbpe（`regex` 库）逐 token 一致 —— 由 `tests/test_regex.mojo` 的 9 个用例（含中英文混合、特殊 token、与 minbpe 等价序列）验证。
- 因实现等价于 BPE 核心循环 + 正则预切分，已编写独立基准 `benchmarks/bench_regex.mojo` 与 Python 对照 `benchmarks/bench_minbpe_regex.py`（后者依赖固化进 `benchmarks/references/minbpe` 的 minbpe `RegexTokenizer` 与第三方 `regex` 库）。

## 影响

- `src/regex.mojo` 的 `RegexTokenizer` 结构体在 BPE 之上提供 `train` / `encode_ordinary` / `encode` / `decode`。
- 性能：正则切分 + 每 chunk 多次扫描合并带来额外开销，故加速比约 **2–2.5x**（Mojo vs Python minbpe），显著低于 M1 BasicTokenizer 的 ~15x（见 ADR-0005 / `benchmarks/results_regex.json`）。这是预期内的，并非回归。
- 后续若 Mojo 引入原生正则能力，可经新 ADR 用正则引擎替换 `_pretokenize` 内部实现，而保持上层契约不变。

## 关键约束

- Mojo 侧 `compiled_pattern: String` 仅存储模式表示，切分由 `_pretokenize` 手工完成，无内建正则对象。
- Python 对照侧（`bench_minbpe_regex.py`）需要第三方 `regex` 库，已从 `benchmarks/references/requirements.txt` 固化版本（`regex==2026.6.28`）安装进项目 venv。
