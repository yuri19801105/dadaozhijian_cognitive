# `io/` — 输入（分词）【v1.5 已落地 ✅】

> 文本输入通道的符号化入口。解锁 `docs/architecture-modular-plan.md` §4.15「输入分词」模块。
> **审计修正**：旧文档 §4.15 称「迁自 src/regex.mojo」——该文件在本项目**不存在**；regex 分词器实为**从零实现**（`io/regex_tokenizer.mojo`）。

## 一、模块构成
| 文件 | 职责 |
|---|---|
| `bpe_tokenizer.mojo` | Byte-level BPE 分词器（迁自 src/bpe.mojo，硬化 + 适配本构建 API） |
| `regex_tokenizer.mojo` | 轻量「正则风格」分词器（从零实现，确定性扫描，无外部正则引擎） |
| `tests/test_io.mojo` | TDD 套件（4 断言） |
| `benchmarks/bench_io.mojo` | 基准 |
| `__init__.mojo` | 聚合导出 |

## 二、BPE 分词器（`Tokenizer`）
- 字节级 BPE：基础词表为 0..255 字节；`train(text, vocab_size)` 统计相邻字节对频次，逐轮合并最高频对，记录 `merge_order`。
- `encode(text) -> List[Int]`：按 `merge_order` 顺序归并；`decode(ids) -> String`：展开回字节并 UTF-8 解码。**字节级保证 encode→decode 精确还原原文**。
- 设计约束：`Dict` 非 Movable → `Tokenizer` 不可按值返回；`train_tokenizer(mut t, text, vocab_size)` 用 `mut` 参数原地训练（同 `Config`/`TaijiState` 惯例）。
- 计数段以 `Dict.find()` 取 `Optional`（本构建无 `Dict.get(key, default)`）。

## 三、正则风格分词器（`RegexTokenizer`）
确定性扫描规则（无正则引擎）：
- ASCII 字母 / 数字连续段 → 各合并为一个 token（单词 / 数字）；
- CJK 统一表意文字（U+4E00–U+9FFF）→ 逐字成 token；
- 空白 / 标点 → 逐字符成 token（**空白保留**，保证 `decode` 精确还原）。
- `encode(text) -> List[String]`（非 raises）；`decode(toks) -> String` 拼接还原。

## 四、API 速查
```mojo
from io import Tokenizer, train_tokenizer, RegexTokenizer

# BPE
var t = Tokenizer()
train_tokenizer(t, corpus, 300)
var ids = t.encode("阴阳调和")
var text = t.decode(ids)            # == "阴阳调和"

# 正则风格
var rt = RegexTokenizer()
var toks = rt.encode("Hello 世界 123!")   # ["Hello"," ","世","界"," ","123","!"]
var s = rt.decode(toks)                   # == "Hello 世界 123!"
```

## 五、实现状态（v1.5 · 零桩函数 TDD 全绿）
**4 断言全绿**（bpe_roundtrip / bpe_deterministic / regex_chinese / regex_roundtrip）。基准实测：bpe encode+decode ≈ 19,127 ns/op，regex encode+decode ≈ 996 ns/op（UTF-8 中文串，具体见 `bench_io.mojo` 运行结果）。详见 `docs/architecture-modular-plan.md` §4.15。
