# wuxing/ — 五行（调度策略核心）

> **【v0.9 已落地 ✅】** TDD 零桩函数实现。`elements`/`sheng_ke`/`scheduler_core`/`balance` 四文件 + 32 组测试全绿（81 断言，见 `tests/test_wuxing.mojo`）+ 基准（见 `benchmarks/`）。

五行是认知的"调度器"：木火土金水五类动态功能—关系模型，由**相生**（正反馈资生）与**相克**（负反馈约束）构成生克制化的自我调节网络。本项目将五行映射为**资源调度策略**——由五元素能量向量派生 { 主导元素, 归一权重, 主导优势度, 相生决策链 }，并以"抑亢补弱"维持系统均衡（详见 `docs/philosophy/wuxing.md`）。

## 目录

```
wuxing/
├── elements.mojo        # 五行元素定义 / id↔名 / 符号映射 / Element(id+Dual 能量)
├── sheng_ke.mojo        # 生克网络：相生/相克关系表 + 关系码 + 生克增益 + 一轮传播
├── scheduler_core.mojo  # 由生克派生调度决策(ScheduleDecision) + 四象相位种子调度
├── balance.mojo         # 总量/均值/方差/均衡判定/归一/再平衡(抑亢补弱)
├── tests/               # test_wuxing.mojo（32 组 TDD 用例 / 81 断言）
├── benchmarks/          # bench_wuxing.mojo + results_wuxing.json
└── README.md
```

## 五行与生克

木(WOOD=0) 火(FIRE=1) 土(EARTH=2) 金(METAL=3) 水(WATER=4)。每元素能量以 `liangyi.Dual` 表示（阳=生发力、阴=收敛力）。

| 关系 | 序列 | 语义 |
|------|------|------|
| 相生（母子相续，循环资生） | 木→火→土→金→水→木 | 正反馈：母生我、我生子，构成万物长养动力链 |
| 相克（间隔相制，彼此约束） | 木克土、火克金、土克水、金克木、水克火 | 负反馈：克我者制我，防亢盛失衡 |

`relation(a, b)` 在五元环上把 b 相对 a 划分为恰好 5 类（自身 / 生我(母) / 我生(子) / 克我 / 我克），构成完整划分。

## 调度决策（scheduler_core）

`schedule(energies)` 由五元素能量向量派生 `ScheduleDecision`：

- **主导元素** `dominant` = argmax（能量最高者，平局取小 id）；
- **归一权重** `w0..w4` = 各元素能量 / 总能量（sum=1）；
- **主导优势度** `confidence` = 主导能量占总能量份额（0..1）；
- **相生决策链** `c0..c4` = 沿相生序从主导起 3 位（母子相续动力链）。

> 约束（Mojo 1.0.0b2）：`ScheduleDecision` 用固定标量槽（`w0..w4` / `c0..c4`）而非 `List` 字段——`List` 字段会破坏 Movable，使其无法按值返回（同 `src/wu_xing.mojo` `BalanceDecision` 的做法）。

`schedule_from_phase(quadrant_index, intensity)` 由 `sixiang` 四象相位种子派生调度（四象＋中土＝五行）：

| 四象 quadrant | → 五行种子 | 说明 |
|---------------|-----------|------|
| 0 老阴 | 水 WATER | 极阴收藏 |
| 1 少阳 | 木 WOOD | 阳生升发 |
| 2 老阳 | 火 FIRE | 极阳炎上 |
| 3 少阴 | 金 METAL | 阴收肃降 |
| 越界 | 土 EARTH | 中枢承化 |

种子元素得满 `intensity`，其子(相生)得半 `intensity`，余者得基线 `0.1*intensity`，再走 `schedule` 归一。

## 均衡（balance）

「亢则害，承乃制」——`rebalance(energies)` 抑亢补弱：从最旺元素抽取 `0.5*(max-min)/2` 补给最弱元素，**降方差、保总量**。另提供 `total_energy`/`mean_energy`/`variance`/`is_balanced(tol)`/`normalize`。

## I/O 规范

- **输入**：五元素能量向量 `List[Float64]`（长度须为 5，非负）；或符号/令牌（"木"/"wood"/"春"/"青"…）→ `element_by_symbol`；或四象相位 → `schedule_from_phase`。
- **输出**：`ScheduleDecision`（主导/权重/优势度/决策链）；`propagate`/`normalize`/`rebalance` 返回新的 5 元素 `List[Float64]`。
- **确定性**：纯函数派生，无随机。

## 错误处理

- `raises`：`schedule`/`propagate`/`rebalance` 要求恰好 5 元素能量（否则报错）；`schedule` 拒绝负能量与零总量；`normalize` 拒绝零总量；`element_by_symbol` 无映射时报错。
- **降级**：`element_by_symbol_safe` 对未知符号映射中性元素（`NEUTRAL_ELEMENT`=土，居中承化），**不静默丢弃**。

## 依赖与边界

- 依赖：`core`（`math.ops.clamp`）、`liangyi`（Dual 能量）、`sixiang`（四象相位种子）。
- 边界：五行是调度策略层，向上供 `jiugong`/上层执行器消费调度决策；不反向依赖 `jiugong`/`bagua`。

## 验证

```bash
mojo run -I . -I core wuxing/tests/test_wuxing.mojo
# => wuxing -> passed: 81  failed: 0

mojo run -I . -I core wuxing/benchmarks/bench_wuxing.mojo
# => sheng_ke ~5ns/op, schedule ~175ns/op, propagate/rebalance ~350ns/op
```
