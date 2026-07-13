# Phase 4 调度脑 · 余下模块设计规格（liuhe / qixing / scheduler）

> 配套：`docs/architecture-modular-plan.md`（总体规划，本规格落地后同步至 v1.0）、`docs/philosophy/{liuhe,qixing,wuxing}.md`。
> 代码规范：Mojo 1.0.0b2；运行 `mojo run -I . -I core <file>`；core 子包走 `-I core` 短路径，项目包走 `-I .`。
> 已落地基础：`wuxing`（§4.5 v0.9）提供 `ScheduleDecision`、`schedule`、`schedule_from_phase`、`propagate`/`rebalance`/`normalize`/`is_balanced`。本规格在其上构建。

---

## 0. 当前进度总览

| 模块 | 规划状态 | MVP 既有代码（待迁移） | 哲学依据 | 本轮目标 |
|---|---|---|---|---|
| `liuhe` 六合·供给 | §4.6 占位 | `src/liuhe.mojo`：`context_vector(ws, chain_depth, ground, cfg) -> SIMD[int64,6]`（六向态势 [东,西,南,北,上,下]） | liuhe.md（六向空间＋地支和合） | TDD 落地：六向维度 + 供给向量 + 和合归并 |
| `qixing` 七星·排序 | §4.7 占位 | `src/qixing.mojo`：`plan(ctx, candidates) -> List[Int]`（剪枝＋冒泡按 `south-west+abstract_level` 评分＋抽象度锚定） | qixing.md（北斗定序·枢机） | TDD 落地：优先级赋值 + DP 排序 + 决策链序列 |
| `scheduler` 总调度 | §4.11 占位 | 无（需新建） | — | TDD 落地：统一派发器 + 可插拔策略 |

**结论**：三个模块均属"待 TDD"——仅有规划占位与 MVP 桩，无独立 TDD 模块。本轮按既定范式（零桩函数、红→绿→重构、32+ 组测试、基准、README、文档同步）逐一落地。

---

## 1. 总体架构约定与跨模块接口契约

### 1.1 数据流（调度脑内部）
```
输入(能量向量 List[Float64] 或 四象相位+强度)
   │
   ├─ wuxing.schedule ─────────────► ScheduleDecision { dominant, w0..w4, confidence, c0..c4, c_len }
   │                                        │  (策略：主导元素 / 归一权重 / 优势度 / 相生链)
   │                                        ▼
   ├─ liuhe.build_supply(decision, ctx) ─► SupplyVector { s0..s5, harmony }   (供给：六向容量)
   │                                        │  (六合：由策略+上下文派生六向资源可用度)
   │                                        ▼
   ├─ qixing.order_chain(decision, supply) ► DecisionSequence { s0..sN, s_len }  (排序：有序执行链)
   │                                        │  (七星：以 wuxing 权重为优先级源、liuhe 容量为上下文)
   │                                        ▼
   └─ scheduler.dispatch ──────────────► DispatchPlan { seq, confidence, policy_id }  (总派发)
```
- **单一事实源**：`wuxing.ScheduleDecision` 是策略契约；`liuhe.SupplyVector` 是资源契约；`qixing.DecisionSequence` 是排序契约；`scheduler.DispatchPlan` 是总成契约。
- **方向依赖**：`scheduler → {wuxing, liuhe, qixing}`；`qixing → {wuxing, liuhe}`；`liuhe → {wuxing}`。`scheduler` 为唯一对外入口，可热切换策略（§4.11 运维要求）。

### 1.2 共享载体约定（Movable 约束）
- 所有跨模块载体用**固定标量槽**（不用 `List` 字段），保证可按值返回：`SupplyVector{s0..s5, harmony}`、`DecisionSequence{s0..sN, s_len}`（N 取 `ELEMENT_COUNT` 上限链长，定长 8 槽留余量）、`DispatchPlan{seq 槽或内联 s0..sN, confidence, policy_id}`。
- `String` 字段破坏 Movable → 名称一律按需由 `xxx_name(id)` 派生。
- `Dual` 借入参数不可复制 → 字段落值一律 `Dual.from_parts(d.yin_part(), d.yang_part())` 重构。

### 1.3 错误处理契约（全局一致）
| 情形 | 行为 |
|---|---|
| 能量向量长度 ≠ 5 / 含负 / 零总量 | `raises`（`wuxing` 已强制） |
| 供给上下文非法（max_depth ≤ 0 / 容量越界） | `raises`；`build_supply` 对越界方向索引 `raises` |
| 排序空链 / 优先级长度不匹配 | `raises`；`order_chain` 空链 `raises` |
| 未知符号 / 中性降级 | 不静默丢弃：`element_by_symbol_safe` 降级 `NEUTRAL_ELEMENT`（土）；供给容量缺失时取中性 0 而非崩溃 |
| 总派发输入非法 | `raises`；策略装配失败时回退 `default_policy()` 并标注 `policy_id = -1`（降级而非崩溃） |

### 1.4 测试 / 基准 / 文档规范（同 wuxing）
- 测试：`struct Counter(Movable){passed,failed; def check(mut self, cond, name)}`；`def main() raises:`；`def test_*(mut c: Counter) raises:`；`raises` 函数须标 `raises`。
- 基准：`@extern("clock") def clock() abi("C") -> Int`（微秒×1000≈ns）；sink 反馈 + 连续变化种子防 DCE；输出 `results_*.json`。
- 文档：目录 `README.md` 标【v1.0 已落地 ✅】；规划文档 §4.x 头部【v1.0 已落地 ✅】+ 状态注记 + §4.x.0 调用契约 + §4.x.1 接口骨架。

---

## 2. `liuhe/` 六合·供给 / 资源编排（核心调度逻辑 + 接口定义）

### 2.1 核心调度逻辑
六合 = "六向空间整全 + 地支和合"。在调度脑中其职责是**把五行策略投影为六向资源供给向量**，并向 `qixing`/`scheduler` 提供"每个方向/上下文维度的可用容量"。

- **六向维度**：东(EAST)/西(WEST)/南(SOUTH)/北(NORTH)/上(UP)/下(DOWN) = 0..5，三组阴阳对待（东西、南北、上下），`DIRECTION_COUNT=6`。
- **供给派生** `build_supply`：由 `wuxing` 能量 + 上下文（focus 强度、max_depth、chain_depth、ground 输入规模）映射为六向容量：
  - `east`  ← 可用工作单元数（容量基）
  - `west`  ← 已用链深（越小越富余）
  - `south` ← 焦点强度（focus）
  - `north` ← 最大深度配额（max_depth）
  - `up`    ← 上升余量（chain_depth/2 截断）
  - `down`  ← 接地余量（ground/5 截断）
  - `harmony` ← 由能量均衡度（`wuxing.is_balanced` / 方差倒数）派生，0..1，表征供给整体健康度。
- **地支和合** `he_harmony(a,b)`：六组合化（子丑/寅亥/卯戌/辰酉/巳申/午未）→ 返回合化生成的五行 id（如寅亥合木=WOOD）；用于多源供给"和合化生"。
- **多源归并** `merge_supplies(a,b)`：两供给向量逐向取 `max`（容量并集）或按 `harmony` 加权；返回新 `SupplyVector`（守恒、Movable）。

### 2.2 接口定义（§4.6.1 骨架）
```mojo
# liuhe/directions.mojo
comptime EAST: Int = 0; WEST = 1; SOUTH = 2; NORTH = 3; UP = 4; DOWN = 5
comptime DIRECTION_COUNT: Int = 6
def direction_name(id: Int) -> String
def opposite(id: Int) -> Int          # 东西/南北/上下 互反
def axis_of(id: Int) -> Int           # 0=横(东西) 1=纵(南北) 2=竖(上下)

# liuhe/supply.mojo
struct SupplyVector(Movable):         # 固定六槽 + harmony(避免 List 字段)
    var s0..s5: Float64; var harmony: Float64
    def __init__(out self)                       # 全 0
    def get(self, dir: Int) -> Float64           # 越界 raises
    def set(mut self, dir: Int, v: Float64)      # 越界 raises
    def as_list(self) -> List[Float64]
    def capacity(self, dir: Int) -> Float64
    def is_valid(self) -> Bool                   # 全非负

def build_supply(energies: List[Float64], focus: Float64,
                 max_depth: Int, chain_depth: Int, ground: Int) raises -> SupplyVector
    # 须经 wuxing.is_balanced 风格校验(energy 合法由 wuxing 保证)；harmony 由能量方差倒数派生

# liuhe/harmony.mojo
comptime HARMONY_PAIRS: ...            # 六合(地支)配对表
def he_harmony(a: Int, b: Int) -> Int  # 合化生成的五行 id；非六合对返回 NEUTRAL_ELEMENT
def harmony_index(a: Int, b: Int) -> Float64   # 亲和度 0..1
def merge_supplies(a: SupplyVector, b: SupplyVector) -> SupplyVector  # 逐向 max 归并
```

### 2.3 待完成功能点 / 验收
- [ ] `directions`：六向常量、name、opposite、axis_of。
- [ ] `supply`：`SupplyVector` 槽载体 + `build_supply`（六向映射 + harmony 派生）。
- [ ] `harmony`：六合配对 `he_harmony`、亲和 `harmony_index`、多源 `merge_supplies`。
- [ ] 测试：方向互反/轴向、build_supply 六向值合理、越界 raises、merge 守恒、he_harmony 合化正确、中性降级。
- [ ] 基准 + README + §4.6 文档同步。

---

## 3. `qixing/` 七星·决策链排序（与调度脑交互 + 数据流转）

### 3.1 与调度脑的交互方式
`qixing` 是调度脑的"定序枢机"：它**不生产策略也不生产资源**，而是消费上游产物：
- 输入契约①：`wuxing.ScheduleDecision`（提供每步归一权重 `w0..w4` = 优先级源；`c0..c4` = 相生候选链）。
- 输入契约②：`liuhe.SupplyVector`（提供六向容量，作为排序的上下文约束——容量越低的方向，其上步骤优先级打折）。
- 输出契约：`DecisionSequence`（有序执行链），交给 `scheduler`。

### 3.2 数据流转规则
1. **优先级赋值** `priority_of(step, decision, supply)`：
   `priority = decision.weight(step) * capacity_factor(supply, step)`
   其中 `capacity_factor = clamp(1 - deficit(dir_of(step)), 0, 1)`，`deficit` 由对应方向容量相对配额的比值决定（容量不足 → 该步降级，体现"六合供给约束七星排序"）。
2. **排序** `order_chain(decision, supply) raises -> List[Int]`：
   取 `decision` 的相生链 `c0..c4`（去重、去 -1）为候选步骤集 → 计算各步 `priority_of` → **降序排序**（DP/归并，非冒泡，O(n log n)）；同分以 `abstract_level`（迁自 MVP：步骤抽象度 5/3/2/1/0）锚定（高抽象优先）。
3. **序列产出** `DecisionSequence.build(decision, supply) raises`：包装有序链为固定槽载体。

### 3.3 接口定义（§4.7.1 骨架）
```mojo
# qixing/priority.mojo
def abstract_level(step: Int) -> Int            # 迁自 MVP: 步骤抽象度(5/3/2/1/0)
def capacity_factor(supply: SupplyVector, step: Int) -> Float64  # 六合容量→0..1 折扣
def priority_of(step: Int, decision: ScheduleDecision,
                supply: SupplyVector) -> Float64
def priority_list(decision, supply) -> List[Float64]

# qixing/ordering.mojo
def order_chain(decision: ScheduleDecision, supply: SupplyVector) raises -> List[Int]
    # 取相生链候选 → priority_of → 降序归并排序 → 同分 abstract_level 锚定

# qixing/sequence.mojo
struct DecisionSequence(Movable):     # 定长槽(链长上限 8)
    var s0..s7: Int; var s_len: Int
    def __init__(out self)
    def append(mut self, step: Int)
    def step_at(self, i: Int) -> Int
    def as_list(self) -> List[Int]
    def build(decision: ScheduleDecision, supply: SupplyVector) raises -> DecisionSequence
```

### 3.4 待完成功能点 / 验收
- [ ] `priority`：abstract_level、capacity_factor、priority_of、priority_list。
- [ ] `ordering`：order_chain（候选提取 + 优先级排序 + 抽象度锚定）。
- [ ] `sequence`：DecisionSequence 槽载体 + build。
- [ ] 测试：优先级随权重单调递增、容量不足导致降级、order_chain 降序且空链 raises、抽象度同分锚定、build 与 order_chain 一致。
- [ ] 基准 + README + §4.7 文档同步。

---

## 4. `scheduler/` 总调度·统一派发器（编排策略 + 优先级 + 错误处理）

### 4.1 任务编排策略
`scheduler` 把三模块合成为**唯一派发器**（"重构后的 AI 底层调度逻辑"总成）：
- `dispatch(energies, focus, max_depth, chain_depth, ground) raises -> DispatchPlan`：
  1. `wuxing.schedule(energies)` → `ScheduleDecision`（策略）。
  2. `liuhe.build_supply(energies, focus, max_depth, chain_depth, ground)` → `SupplyVector`（供给）。
  3. `qixing.DecisionSequence.build(decision, supply)` → 有序执行链（排序）。
  4. 封装 `DispatchPlan{ seq, confidence=decision.confidence, policy_id }`。
- `dispatch_from_phase(quadrant, intensity, ...) raises`：先 `wuxing.schedule_from_phase` 再走同上流程（四象→五行种子入口）。

### 4.2 优先级机制
- 端到端优先级源自 `wuxing` 归一权重（策略层），经 `liuhe` 容量折扣（资源约束层），由 `qixing` 定序（排序层）——三层优先级在 `DispatchPlan.seq` 中已固化为顺序。
- `confidence` 沿用 `wuxing` 主导优势度，作为派发可信度指标（一级观测指标，§4.11 运维）。

### 4.3 错误处理方案
- 输入非法（能量长度≠5/负/零总量、max_depth≤0、chain_depth<0、ground<0）→ 各子模块 `raises`，`scheduler` 透传并附上下文。
- **策略降级**：`policy.mojo` 提供 `default_policy()`；若 `policy_id` 装配失败 → `DispatchPlan.policy_id = -1`（降级默认策略，不崩溃）。
- **空链降级**：若 `qixing` 排出空链（极端均衡/total=0 被 wuxing 拒）→ `raises`（调用方决定重试或静默空计划，不静默吞错）。
- 全程确定性（无随机），故障隔离：编排错误不影响 `taiji` 状态根（§9 横切硬层）。

### 4.4 接口定义（§4.11.1 骨架）
```mojo
# scheduler/policy.mojo
struct SchedulerPolicy(Movable):
    var gen_rate: Float64; var ke_rate: Float64; var policy_id: Int
    def __init__(out self)                       # 默认 gen_rate/ke_rate
def default_policy() -> SchedulerPolicy
def apply_policy(mut plan: DispatchPlan, policy: SchedulerPolicy)

# scheduler/dispatcher.mojo
struct DispatchPlan(Movable):        # 内联有序链(定长槽) + 置信 + 策略id
    var s0..s7: Int; var s_len: Int
    var confidence: Float64; var policy_id: Int
    def step_at(self, i: Int) -> Int
    def as_list(self) -> List[Int]

def dispatch(energies: List[Float64], focus: Float64, max_depth: Int,
             chain_depth: Int, ground: Int) raises -> DispatchPlan
def dispatch_from_phase(quadrant: Int, intensity: Float64, focus: Float64,
                        max_depth: Int, chain_depth: Int, ground: Int) raises -> DispatchPlan
```

### 4.5 待完成功能点 / 验收
- [ ] `policy`：SchedulerPolicy 载体 + default_policy + apply_policy。
- [ ] `dispatcher`：DispatchPlan 槽载体 + dispatch / dispatch_from_phase（编排三模块）。
- [ ] 测试：dispatch 端到端产出有序链且 = qixing 结果、confidence 透传、policy_id 默认、非法输入 raises、降级路径（policy_id=-1）、dispatch_from_phase 经四象种子。
- [ ] 基准 + README + §4.11 文档同步。

---

## 5. 实施顺序与里程碑
1. **liuhe**（基础供给，被 qixing/scheduler 依赖）→ 2. **qixing**（排序，被 scheduler 依赖）→ 3. **scheduler**（总成）→ 4. 规划文档 v0.9→v1.0 + 全回归。
- 每模块独立 TDD 红绿重构，互不影响；接口以上述契约锁定，避免返工。
- 全项目回归目标：liangyi 17 + sancai 14 + sixiang 29 + bagua 17 + wuxing 81 + liuhe + qixing + scheduler **全绿 0 失败**。
