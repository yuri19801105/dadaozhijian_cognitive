# bagua/ — 八卦（推理算子集）

> **【v0.8 已落地 ✅】** TDD 零桩函数实现。`trigram`/`operators`/`combine` 三文件 + 18 组测试全绿（见 `tests/test_bagua.mojo`）+ 基准（见 `benchmarks/`）。

八卦是认知的"指令集"：三爻成象的 8 个推理算子（创造·承载·雷动·风入·冒险·明辨·山止·泽悦），由阴阳爻三叠而成（2³=8），两两相重成六十四卦。本项目将八卦映射为 8 类基本推理算子，是把符号象数转化为可执行操作的关键一环（详见 `docs/philosophy/bagua.md`）。

## 目录

```
bagua/
├── trigrams.mojo      # 8 卦定义 / id↔code 映射 / 爻线 / 符号映射 / sancai 派生
├── operators.mojo     # 单卦推理算子 + 推理链（TrigramOperatorResult）
├── combine.mojo       # 重卦（64）组合规则
├── tests/             # test_bagua.mojo（18 组 TDD 用例）
├── benchmarks/        # bench_bagua.mojo + results_bagua.json
└── README.md
```

## 卦码与卦象

每卦 = 3 条 `Dual` 爻线（初/二/三爻 = 地/人/天），每条爻线阴=`YIN`/阳=`YANG`。3 位 yao 码（初爻为最低位，yang=1）：

| id | 卦 | 名 | 性质 | yao 码 | 初·二·三爻 |
|----|----|----|------|--------|------------|
| 0 | 乾 ☰ | 创造/天健 | 阳盛扩张 | 7 | 阳·阳·阳 |
| 1 | 坤 ☷ | 承载/地载 | 收敛容纳 | 0 | 阴·阴·阴 |
| 2 | 震 ☳ | 雷动/启动 | 注入阳动 | 1 | 阳·阴·阴 |
| 3 | 巽 ☴ | 风入/渗透 | 与逆调和 | 6 | 阴·阳·阳 |
| 4 | 坎 ☵ | 冒险/试探 | 倾向阳 | 2 | 阴·阳·阴 |
| 5 | 离 ☲ | 明辨/火丽 | 放大对比 | 5 | 阳·阴·阳 |
| 6 | 艮 ☶ | 山止/停止 | 归零 | 4 | 阴·阴·阳 |
| 7 | 兑 ☱ | 泽悦/交流 | 与逆取中 | 3 | 阴·阳·阳 |

> 注：8 卦映射采用先天八卦"阳=1"二进制编码（乾三阳=111=7…坤三阴=000=0），id 与 yao 码为一一对应；`name()` 由 id 查表派生，`Trigram` 仅存 `id`（Int）以保持 Movable（String 字段会破坏 Movable）。

## 算子语义（对输入 `Dual` 的确定性变换）

| 卦 | 变换 | 直觉 |
|----|------|------|
| 乾 | `x.scale(2)` | 创造：幅度翻倍 |
| 坤 | `x.scale(0.5)` | 承载：幅度减半 |
| 震 | `from_parts(yin, yang+1)` | 雷动：注入一单位阳 |
| 巽 | `reconcile(x, invert(x))` | 风入：与逆相调和→趋衡 |
| 坎 | `from_parts(yin*0.5, yang*1.5)` | 冒险：阳加权偏入未知 |
| 离 | `from_parts(yin*2, yang*2)` | 明辨：锐化阴阳对比 |
| 艮 | `Dual(0)` | 山止：归零终止 |
| 兑 | `compose(x, invert(x), 0.5)` | 泽悦：与逆取中交换 |

每个算子同时返回 `activation: GatePair`（由 `YinYangGate.dual_gate` 给出阴阳双门），供上层选择抑制/激发。

## I/O 规范

- **输入**：符号/令牌（如 "乾"/"天"/"qian"）→ `trigram_from_symbol` 映射为卦；或 `trigram_from_sancai(sc)` 由三才三层 `Dual` 派生（初=人, 二=地, 三=天）。
- **输出**：`TrigramOperatorResult { trigram, code, activation, transformed }`；重卦 `Hexagram { lower, upper, code, essence }`。
- **确定性**：纯函数派生，无随机。

## 错误处理

- `raises`：`trigram_by_id/by_code` 越界、`trigram_from_lines` 数量错/非法相位、`trigram_from_symbol` 无映射、`trigram_from_sancai` 含 NaN（先 `SanCai.validate()`）。
- **降级**：`trigram_from_symbol_safe` 对未知符号映射中性卦（`NEUTRAL_ID`=坤）并记 trace，**不静默丢弃**。

## 依赖与边界

- 依赖：`core`、`liangyi`（Dual/Polarity/YinYangGate/GatePair）、`sancai`（派生卦象）。
- 边界：八卦是算子层，向上接入 `wuxing` 生克策略与 `observability/tracing` 溯源；不反向依赖 `wuxing`/`jiugong`。

## 验证

```bash
mojo run -I . -I core bagua/tests/test_bagua.mojo
# => bagua -> passed: 18/18 (groups)  failed: 0
```
