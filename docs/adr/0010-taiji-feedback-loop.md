# ADR-0010: 太极回灌闭环契约(长期记忆 ↔ 派生根)

## 状态

已接受(2026-07-10 落地实现, 全量 106 tests passed)

## 背景

整条架构的自洽性建立在 CONTEXT.md 的「太极为根: 一切派生自太极, 最终回灌太极(闭环)」上。但在 M9 之前, `pipeline` 的闭环是 **one-pass**: 每次 `run_full_cycle` 从干净 `Workspace` 起步, `execute()` 产出文本后直接丢弃, 下一轮完全无记忆。哲学层违背「回灌太极」, 工程层使系统退化为无状态函数。

M9 要补的正是这一唯一缺失环节: 让十方输出回灌太极, 下一轮能从此派生, 形成真实跨轮累积认知。落地前必须先锁定契约(README 称「设计就绪」但未给设计文档, 故本 ADR 补位), 避免拍脑袋。

## 决策

### 1. 回灌存什么 —— 只存「派生信号」, 不存原文

`TaijiState` 不持有任何 `String` / `List[String]`(本构建下含此类字段的 struct 不可 `Movable`, 无法在函数间传递/返回)。回灌写入的是**结构化派生信号**:

| 字段 | 类型 | 含义 |
|------|------|------|
| `decisions_flat` | `List[Int]` | 历史七星决策链, 按轮展平存储 |
| `decision_lens` | `List[Int]` | 每轮决策链长度(配合 `decisions_flat` 还原) |
| `phases` | `List[Int]` | 每轮五行相位(木/火/土/金/水) |
| `intensities` | `List[Int]` | 每轮强度 |
| `out_lengths` | `List[Int]` | 每轮十方输出字节长 |
| `round` | `Int` | 已回灌轮数 |
| `seed` | `Int` | 由历史派生的全局状态根种子 |
| `intent_hash` | `Int` | 意图规模哈希(派生自意图字节长) |

**理由**: 原文(自由文本)在 Mojo 1.0.0b2 下既不可 Movable、也不便做确定性派生; 存派生信号既能跨轮累积, 又能作为确定性调度的种子输入, 且内存固定、无外部依赖。这是「太极承载跨轮累积态」的最小可行表达。

### 2. 如何派生 —— 确定性根种子 + 紧凑记忆上下文

**根种子派生**(回灌时):
```
seed = (seed * 31 + phase * 7 + intensity * 3 + out_length) % 1_000_003
```
确定性、可复现, 反映认知轨迹(相位主导、强度/输出长为扰动)。`1000003` 为大素数, 降低碰撞与周期。

**记忆读取** `recall()`(下一轮派生前):
- 首轮(`round == 0`)返回 `""` → 等价于无记忆, 闭环退化为单轮流水线, 行为向后兼容。
- 有历史时返回紧凑 `String`: `[记忆 N 轮] 意图根=… 相位链=[…] 决策数=… 根种子=…`。该字符串被 `CognitiveCycle.run` **前置注入**下一轮输入文本, 从而让规划器(`_parse_text`→`schedule`→`plan`)间接读到累积上下文。

> 注: 本构建不支持 `String` 字节直接索引(`s[i]` 非法, 需 `s[byte=i]` 且返回 `String`, 脆弱), 故**放弃对原文做字节哈希**; `intent_hash` / `seed` 仅依赖已结构化的 `Int` 信号。

### 3. 太极 vs 九宫分层 —— 根在上, 草稿在下, 不重复造轮子

- **九宫(M3 `Workspace`)**: 单轮工作记忆, 3×3 草稿纸 + 注意力权重, 不参与跨轮。
- **太极(M9 `TaijiState`)**: 跨轮全局状态根, 累积记忆 + 派生种子, 不参与单轮注意力计算。
- 二者**不重复造轮子**: 太极不重写 `Workspace`; `CognitiveCycle` 同时持有 `Workspace`(每轮重建语义由 `schedule` 读取)与 `TaijiState`(跨轮累积), 边界清晰——九宫管「这一轮怎么想」, 太极管「之前都累积了什么」。

### 4. 跨轮状态载体 —— `CognitiveCycle`(holder struct + `mut self`)

本构建**不支持 `class`**, 且 **`inout` 参数不解析**、含 `String` 字段的 struct 不可 `Movable`。因此:

- 不复用旧 `run_full_cycle(inout TaijiState)`(无法编译)。
- 改用 **持有者 struct** `CognitiveCycle { ws: Workspace, state: TaijiState }`, 以 `def run(mut self, text, cfg) -> String` 方法在 `mut self` 体内完成「`recall` 注入 → `run_cycle` 规划 → `execute` 执行 → `feedback` 回灌」四步, 状态变更发生在方法内, 无需跨函数的 `inout` 传递。
- 不提供独立的 `create_taiji() -> TaijiState`(返回移动 struct 不可行); 改由 `CognitiveCycle.__init__(intent="")` 内部构造 `TaijiState`。

## 事实依据(已实测)

- `tests/test_taiji.mojo` 实跑 **6/6 passed, 0 warnings**(空状态、feedback、recall 连续性、last_decision、种子确定性、intent_hash)。
- `tests/test_integration_cycle.mojo` 新增 `test_run_full_cycle_end_to_end`: 空文本 → `[CHIEN, KAN]` → 精确输出, 验证闭环末端; 该文件共 **15/15 passed**。
- 全量 `mojo run -I src -I tests tests/test_all.mojo` → **106 tests ALL SUITES PASSED, 0 warnings**(2026-07-10)。
- 回灌开销 `benchmarks/bench_taiji.mojo`: recall+feedback × 1M, 见 `results_taiji.json`(<1µs/op, 计入全周期仍远低于 1µs 预算)。

## 理由

- **闭环自洽**: 从「一次性流水线」升级为「可累积认知」, 兑现 CONTEXT.md 的回灌承诺, 也是 README 排在待办首位的项。
- **约束驱动**: 在 Mojo 1.0.0b2 的 `Movable` / `inout` / 字符串索引限制下, holder-struct + 派生信号 是能编译且正确的最小方案。
- **向后兼容**: `recall()` 首轮返回 `""`, 干净 `Workspace` 起步的旧行为完全保留。

## 影响

- 所有「跨轮认知」需求(长期记忆、习惯形成、轨迹漂移检测)均以 `TaijiState` 的派生信号为基础, 不应再引入 `String` 历史字段。
- `CognitiveCycle` 是 E2E 闭环的唯一入口; `run_cycle`(只读规划器)仍保留供单轮/测试使用。
- 太极与九宫的分层边界(根/草稿)为本架构长期约定, 后续模块(含 M8 可视化)读取记忆须走 `recall()` 而非直读 `Workspace` 历史。
- 风险: 回灌仅存结构化信号, 丢失原文语义细节; 若未来需原文回溯, 须升级 Mojo 至支持 `Movable`/class 或引入外部存储, 届时另立 ADR。

## M9 基准结果(2026-07-10)

`recall() + feedback()` × 1,000,000 次(1 决策链 [0,1], 输出字节长 6):

| 操作 | ns/op |
|------|-------|
| taiji recall+feedback | 见 `benchmarks/results_taiji.json`(多次运行稳定区间, 取代表值) |

回灌延迟 <1µs, 计入全周期延迟后整体仍 <1µs 预算, 不影响 E2E 实时性。
