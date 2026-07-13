# 实施计划:用 Mojo + TDD 验证认知模型核心算法

本计划落实 ADR-0005。目标:以可度量、TDD 驱动的方式,从"十方"文本通道的 BPE 分词器起步,逐步验证认知模型各核心算法。所有事实依据与参照项目见 ADR-0005(均已调研核实)。

## 0. 范围与原则

- **语言锁定**:Mojo `v1.0.0b2`(2026-05-07 稳定版系列;原定 `v1.0.0b1` 因 conda 包服务器超时无法获取,改用已预装的 b2,见 ADR-0005 勘误);不追 nightly,避免 API 漂移。
- **验证纪律**:每个模块严格 TDD——先测试(红)→ 实现(绿)→ 重构(优化)。
- **对照基线**:每个 Mojo 模块都配一个 Python 参照(minbpe / 自写),既验正确性又测性能。
- **架构对齐**:每个算法映射到 `CONTEXT.md` 的某一层(见 §2),不发明游离于架构的模块。

## 1. 环境准备

1. 安装 `magic`(Modular 包管理器):参照官方 `docs.modular.com/mojo/manual/install/`。
2. 初始化项目:`magic init cognitive-model --format mojoproject`,依赖固定到 `mojo==1.0.0b1`。
3. 确认工具链:`mojo --version` 应显示 `1.0.0b1`;Apple Silicon 已支持 GPU,但 MVP(BPE)以 CPU 为主。
4. 在仓库内建目录:`src/`(Mojo 模块)、`tests/`(TestSuite)、`benchmarks/`(基准脚本)、`REFERENCES.md`(记录核实过的参照链接)。

## 2. 架构 → 实现里程碑映射

| 里程碑 | 目标架构层 | 算法/模块 | 类型 | 难度 |
|---|---|---|---|---|
| M1 | 十方(10)·文本入口 | BPE 基础分词器 | MVP | 低 |
| M2 | 十方(10)·文本入口 | RegexTokenizer(类别预切分)+ 特殊 token | 扩展 | 低 |
| M3 | 九宫(9) | 工作记忆网格 3×3 + 注意力权重 | 核心 | 中 |
| M4 | 八卦(8) | 八种推理算子(stub→实现) | 核心 | 中 |
| M5 | 五行(5) | 相生相克资源调度 | 核心 | 中高 |
| M6 | 六合(6) | 空间态势感知 / 六维态势向量 context_vector | 核心 | 中 |
| M7 | 七星(7) | 动态规划与任务调度 / 三阶段排序执行链 plan | 集成 | 高 |
| M8 | 静语(M8)·可视化 | 推理过程可视化/序列化(调试工具, 优先级最低) | 扩展 | 低(已实现) |
| M9 | 太极(0)·全局状态根 | 长期记忆 / 回灌闭环(TaijiState + CognitiveCycle) | 核心 | 中(已实现) |
| M10 | 十方(10)·Executor | 八卦算子→文本输出(认知→行动闭环末端) | 核心 | 中(已实现) |

本计划先展开 M1(已就绪可执行),M2–M7 给出形态与验收口径,待 M1 验收后再逐期细化。M9/M10 已于 2026-07-10 落地(见 ADR-0010 / ADR-0009);M8 为调试可视化, 优先级最低, 已于 2026-07-10 落地(范围裁剪见 ADR-0011, GUI 交互特性推迟)。

## 3. 里程碑 M1:BPE 基础分词器(TDD 详案)

### 3.1 模块契约(语言无关,见 architecture.md)

```
bpe.train(text, vocab_size) -> { merges: Dict[(int,int),int], vocab: Dict[int,bytes] }
bpe.encode(text)            -> List[Int]          # 文本→token id 序列
bpe.decode(ids)             -> String             # token id→文本
```

### 3.2 TDD 步骤

**第一步 — 写测试 `tests/test_bpe.mojo`(先红)**:

> 约定(Mojo 1.0.0b2):`fn` 已移除统一用 `def`;本项目测试用手写 `try/except` 运行器统计 passed/failed(非 `TestSuite.discover_tests` 自动发现,后者仍可用,见 ADR-0005 §2.7);模块暴露的是 `Tokenizer` 结构体(非骨架里的 `BasicTokenizer`)。
```mojo
from std.testing import assert_equal

def test_train_basic() raises:
    # 维基 BPE 经典例: "aaabdaaabac" 训练 256+3 次合并
    var tok = Tokenizer()
    tok.train("aaabdaaabac", 256 + 3)
    # 期望合并序列: aa→256, (256,97)→257, (257,98)→258
    assert_equal(tok.encode("aaabdaaabac"), [258, 100, 258, 97, 99])

def test_encode_decode_roundtrip() raises:
    var tok = Tokenizer()
    tok.train("the quick brown fox", 256 + 10)
    var ids = tok.encode("the quick brown fox")
    assert_equal(tok.decode(ids), "the quick brown fox")

def main() raises:
    var passed = 0
    var failed = 0
    try:
        test_train_basic(); passed += 1
    except e:
        failed += 1; print("FAIL test_train_basic:", e)
    try:
        test_encode_decode_roundtrip(); passed += 1
    except e:
        failed += 1; print("FAIL test_encode_decode_roundtrip:", e)
    print("BPE tests -> passed:", passed, " failed:", failed)
    if failed > 0:
        raise Error("BPE tests failed")
```

**第二步 — 实现 `src/bpe.mojo`(转绿)**:
- `train`:`text.encode("utf-8")` → 字节列表;循环 `num_merges = vocab_size - 256` 次:`get_stats` 统计相邻对频率 → 取最频繁对 → 全序列 `merge` → 记录 `merges[(a,b)]=新id`,扩展 `vocab`。
- `encode`:字节序列按 `merges`(按优先级)递归合并为 id 序列。
- `decode`:id 经 `vocab` 还原字节并 utf-8 解码。
- 类型用 `List[Int]`、`Dict[(Int,Int),Int]`;`fn` 强类型;先求正确,不求快。

**第三步 — 重构/优化(绿后)**:在测试保护下,尝试 Mojo 特性(`@parameter`、向量化、`struct` 封装、`String` 操作),并对比 minbpe.mojo 的实现风格。

### 3.3 基准对比 `benchmarks/bench_bpe.mojo`

- 数据集:一段长文本(如 Taylor Swift 维基页,复用 minbpe.mojo 的 `train.mojo` 思路)。
- 对照:同文本跑 Python `minbpe` 的 `BasicTokenizer.train`,计时对比。
- **预期**:Mojo 约 3x 于 Python(minbpe.mojo 已实测);BPE 含字符串/字典操作,**不应预期 20–180x**(那是数学内核数字,见 ADR-0005)。
- 输出:`benchmarks/results.json`,记录 {数据集, Mojo 耗时, Python 耗时, 加速比}。

### 3.4 M1 验收口径

- [ ] `tests/test_bpe.mojo` 全绿(手写运行器,0 失败)
- [ ] `test_train_basic` 的 `[258,100,258,97,99]` 断言通过(与 minbpe 一致)
- [ ] 编解码往返一致
- [ ] `benchmarks` 产出 Mojo vs Python 对比数据,加速比记录并落入合理区间(~3x)

## 4. M2–M10 形态与验收口径(概要)

- **M2 RegexTokenizer**:GPT-2 类别正则预切分,保证跨类别不合并;引入特殊 token。测试:对照 minbpe `RegexTokenizer` 输出。
- **M3 九宫**:`Workspace` struct 持有 3×3 网格 + `attention: Tensor[9]`;`hold(action) -> (grid, attention)`。验收:注意力权重可检索历史中间态。
- **M4 八卦**:函数式实现八推理算子 `apply_chien…apply_dui` + 调度 `apply_trigram(type, ws, param)` + 推理链 `apply_chain(ws, chain, param)`(注: 因 Mojo 1.0 trait 支持有限, 未定义 `ReasoningOp` trait, 亦无 `reason()` 函数, 改用函数式; 计划 §5 原稿描述的 trait/reason 为设想, 以实现为准)。验收:单测覆盖八算子语义 —— 已实现, `tests/test_trigram.mojo` 实跑 21/21 passed(2026-07-10 修复测试框架后)。
- **M5 五行**:`schedule(ws: Workspace, signal: PhaseSignal) -> BalanceDecision`(按相设五行权重 w0..w4 → 相生 +1 / 相克 -2 → `_clamp(0,9)` → `OverloadCounter` 过载过滤 trigram chain)+ `wu_xing_cycle` 五相循环。相生相克网络 `generate_next`/`restrain_target`。验收:相生相克网络五相全覆盖 + 过载保护(连续同 trigram >3 次过滤) —— 已实现, `tests/test_wu_xing.mojo` 实跑 11/11 passed。(注: 原稿 `schedule(label)->allocation` / 「资源守恒」为早期设想, 实际实现为权重分配 + trigram chain 调度, 以实现为准。)
- **M6 六合**:`context_vector(ws, chain_depth, ground_input, cfg) -> SIMD[int64, 6]` 六维态势向量(东=available_cells / 西=chain_depth / 南=focus_strength / 北=max_depth / 上=chain_depth/2 / 下=byte_length/5),作为「地图」供给 M7。验收:`tests/test_liuhe.mojo` 实跑 8/8 passed(2026-07-10)。—— 已实现, `benchmarks/results_liuhe.json` 记录 ~12ns/次(与 ADR-0007 一致)。
- **M7 七星**:`plan(context, candidates) -> List[Int]` 三阶段流水线(剪枝 by max_depth → bubble 排序 score=south-west+abstract_level 降序 → 同分锚定 abstract_level 高者优先),消费六合态势 + 五行候选,产出有序执行链。验收:`tests/test_qixing.mojo` 实跑 7/7 passed(2026-07-10)。—— 二者「六合→七星」供给关系已在 `src/pipeline.mojo` 的 `run_cycle`(只读规划器)中真实落地:解析文本→五行 `schedule` 候选链→`context_vector` 态势→`plan` 排序执行链(见 ADR-0004 / ADR-0007 / ADR-0008)。`tests/test_integration_cycle.mojo` 的 `run_cycle_*` 用例虽覆盖该路径,但断言仅为 `len(result) >= 0`(冒烟级),尚未对剪枝/排序行为做断言(2026-07-10 M7 修复阶段已补 `test_run_cycle_prunes_by_max_depth`,对剪枝行为做了真实断言)。
- **M8 静语(可视化/序列化)**:`EmojiGraph`(扁平并行数组: 节点 trigram/position/emotion/weight + 连线 from/to/strength/color 各存独立 `List[Int]`,权重以 0–100 百分比整数表示; 此存储形态由 Mojo 1.0.0b2 的 `List[T:Movable]` + 含 List 字段不可 Movable 硬约束决定,见 ADR-0011) + `build(chains)`(`mut self` 构造,等价 architecture 的 `create_emoji_graph`) + `update_node_emotion`/`update_node_weight`(`mut self` 原地更新,含连线颜色同步) + `render()`(确定性文本行式)/`render_svg()`(确定性 SVG 字符串)。纯观测层,不改变系统功能行为。验收:`tests/test_emoji.mojo` 实跑 10/10 passed;`benchmarks/results_emoji.json` 记录渲染成本极低(离线确定性产出,非热点)。范围裁剪(GUI 交互推迟)见 ADR-0011。—— 已实现。`pipeline.run_cycle_chains` 已暴露中间候选/规划链,供 M8 可视化**真实**推理过程(见 ADR-0011)。
- **M9 太极(长期记忆/回灌闭环)**:`TaijiState`(`Int`/`List[Int]` 派生信号:决策链展平、相位、强度、输出长、轮数、根种子、意图哈希) + `CognitiveCycle` holder(`Workspace` + `TaijiState`, `mut self run` 完成 `recall` 注入 → `run_cycle` 规划 → `execute` 执行 → `feedback` 回灌四步)。太极为跨轮全局状态根,九宫为单轮工作记忆,分层不重复造轮子(见 ADR-0010)。验收:`tests/test_taiji.mojo` 实跑 6/6 passed;`tests/test_integration_cycle.mojo` 含 `test_run_full_cycle_end_to_end` 验证闭环末端,该文件共 15/15 passed;`benchmarks/results_taiji.json` 记录回灌 <1µs/op。全量 106 tests 全绿(2026-07-10)。—— 已实现,闭环自洽(系统从「一次性流水线」升级为「可累积认知」)。
- **M10 十方 Executor(闭环末端执行器)**:`execute(chain, ws, raw_input) -> String`, 八八卦算子→文本动作映射 + 未知回退(见 ADR-0009)。验收:`tests/test_executor.mojo` 实跑 12/12 passed;`benchmarks/results_executor.json` 记录 ~350ns/次。已接入 `src/pipeline.mojo` 的 `CognitiveCycle.run`(经 `execute`),与 `run_cycle`(只读规划器)串成 认知→行动→回灌 完整闭环(见 ADR-0004 / ADR-0009 / ADR-0010)。—— 已实现。

> 注: 原稿 M6/M7 描述为「三才/四象」「太极→闭环」,与 architecture.md 第 6/7 层(六合/七星)及实际实现(`src/liuhe.mojo` / `src/qixing.mojo`)不符,已于 2026-07-10 校准为六合/七星;M9 即为原稿所述「太极→闭环」的真实落地。

## 5. 风险与对策

- **Mojo 1.0 仍 beta**:锁 `v1.0.0b2`(原 `v1.0.0b1` 无法获取,见 ADR-0005 勘误);遇 API 变更升版时另立 ADR。
- **生态未成熟**(张量/高阶原语缺失):必要时经 Python 互操作桥接,记录于对应 ADR。
- **BPE 提速有限**:M1 价值在"打通 TDD 流程 + 验证十方入口",不在极致性能;极端加速预期留给 M3+ 计算密集模块。
- **参照项目版本漂移**:minbpe.mojo/llm.mojo 基于 Mojo 25.5,与本项目的 1.0.0b1 可能有 API 差异,以本项目测试为真相源,参照仅作思路。

## 6. 任务跟踪

按全局 Matt Pocock 配置(本地 Markdown),本期任务入 `.scratch/`:
- `.scratch/m1-bpe/PRD.md`(M1 产品需求)
- `.scratch/m1-bpe/issues/01-install-toolchain.md`(环境)
- `.scratch/m1-bpe/issues/02-write-bpe-tests.md`(红)
- `.scratch/m1-bpe/issues/03-implement-bpe.md`(绿)
- `.scratch/m1-bpe/issues/04-benchmark.md`(对比)

技术栈选型(Mojo+TDD)与 MVP(BPE)已定,后续 M2–M7 在 M1 验收后逐期展开。
