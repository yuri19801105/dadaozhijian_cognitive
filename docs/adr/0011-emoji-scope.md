# ADR-0011: 静语 (M8) 可视化范围裁剪 + Mojo 约束下的存储/API 适配

## 状态

已接受(2026-07-10 落地实现, 全量 116 tests passed)

## 背景

`docs/architecture.md` 对 M8「静语」给出了**完整**设计, 但其大量内容是 **GUI 交互特性**:
鼠标悬停 (`handle_mouse_hover`)、节点点击 (`handle_node_click`)、拖拽重排
(`handle_drag_and_drop`)、实时动画、浏览器 SVG 事件循环等。

本项目已验证的工作模式是 **headless Mojo CLI + `mojo test` TDD**
(见 ADR-0005)。上述 GUI 交互特性在 headless CLI 中**既无法运行也无法单测**,
与项目纪律直接冲突。若首版就硬塞这些特性, 会导致:

- 无法写确定性断言(渲染出口不可测);
- 引入浏览器/事件循环依赖, 破坏「从干净 checkout 直接可复现、无外部依赖」原则;
- 拖慢 M8(优先级最低, 排在 M9 之后)的真正交付。

因此 M8 首版(下称 **M8-core**)必须**裁剪**到「可在 CLI 跑 + 可单测」的纯观测层。

## 决策

### 1. 范围裁剪: M8-core = 纯渲染观测层, GUI 交互推迟

**纳入 M8-core(已实现):**
- `EmojiGraph` 结构体(扁平并行数组存储, 见 §2);
- `EmotionType` 情绪类型(NEUTRAL / EXCITED / ANXIOUS / JOY / SAD / SURPRISED);
- `LayoutType` 布局类型(LINEAR / TREE / CIRCLE / HEATMAP);
- `build(chains)` —— 由推理链构造图形(等价 architecture 的 `create_emoji_graph(chains)`);
- `update_node_emotion` / `update_node_weight` —— 原地更新(等价 architecture 的 inout 自由函数);
- `render() -> String` —— 确定性文本行式可视化(CLI 友好);
- `render_svg() -> String` —— 确定性 SVG 字符串(可落盘成 .svg 文件)。

**推迟(不在 M8 首版, 留待独立前端 / Web 模块):**
- `handle_mouse_hover` / `handle_node_click` / `handle_drag_and_drop`;
- 实时动画 / 浏览器 SVG 交互事件循环。

**理由**: 渲染出口(`render` / `render_svg`)对确定性输入产生**确定性字符串**,
是唯一干净可测的渲染出口; 而 GUI 交互事件既无 CLI 运行环境也无确定性断言手段。
M8-core 已能「把抽象推理链渲染为直观 emoji / 文本化图形」, 满足调试与演示核心诉求,
且不阻塞 TDD 节奏。GUI 交互可在 Mojo 绑定浏览器/前端后另立 ADR-00xx 增补。

### 2. Mojo 1.0.0b2 约束下的存储与 API 适配(独立发现的硬约束)

M8 在落地时**独立撞上** ADR-0010 已记录的同一组约束, 并据此确定了存储/API 形态,
此处单独固化, 作为后续模块的复用范式:

- **硬约束 A —— `List[T: Movable]`**: 容器内元素 `T` 必须 `Movable`。
- **硬约束 B —— 「含 `List` 字段的 struct 不可 `Movable`」**(与 `String` 规则同源)。
- **叠加推论**: 一个 `List` **不能**容纳「自身含 `List` 字段的 struct」(嵌套 `List` 不可行)。
  → 因此 **`EmojiGraph` 采用扁平并行数组存储**: 节点/连线的各字段分别存于独立的
  `List[Int]`(权重以 0–100 百分比整数表示), `EmojiGraph` 仅持有这些数组。
  (同 M9 `TaijiState` 的扁平数组模式。)
- **硬约束 C —— 含 `List` 字段的 struct 不可 `Movable`**:
  → `EmojiGraph` 既**不可按值返回**也**不可按值传参**。
  → 构造改用 **`mut self` 方法 `build(chains)`**(等价 architecture 的 `create_emoji_graph`,
    同 M9 `CognitiveCycle` 的 `mut self` 模式), 而非返回移动 struct 的自由函数。
  → 渲染改用 **`self` 方法 `render()` / `render_svg()`**, 而非 `borrowed` 参数的自由函数
    (本构建 `borrowed` 关键字不解析)。
  → 更新改用 **`mut self` 方法 `update_node_emotion` / `update_node_weight`**
    (等价 architecture 的 inout 自由函数)。

> 复用提示: 任何在 Mojo 1.0.0b2 下需要「图 / 树 / 嵌套集合」且又要 `List` 存储的模块,
> 一律走「扁平并行数组 + `mut self` 构造/更新 + `self` 方法渲染, 禁止按值返回/传参」范式。

## 事实依据(已实测)

- `tests/test_emoji.mojo` 实跑 **10/10 passed, 0 warnings**(节点/连线计数、位置默认、trigram 映射、
  情绪更新含连线颜色同步、边界安全、权重换算、render/render_svg 确定性)。
- `pipeline.run_cycle_chains(ws, text, cfg) -> List[List[Int]]` 已暴露中间候选链/规划链,
  供 M8 可视化真实推理过程(`run_cycle` 只读规划器不受影响, 集成测试 15/15 仍全绿)。
- 全量 `mojo run -I src -I tests tests/test_all.mojo` → **116 tests ALL SUITES PASSED, 0 warnings**
  (2026-07-10, 含新增 emoji 套件 10 项)。
- 渲染开销 `benchmarks/bench_emoji.mojo`: build + render + render_svg × 500,000, 见
  `benchmarks/results_emoji.json`(渲染为确定性离线产出, 非运行时热点, 成本极低)。

## 理由

- **闭环自洽(对齐 M9)**: M8  visualizing 的是 `run_cycle_chains` 产出的**真实推理链**
  (五行调度候选链 + 七星规划链), 而非凭空造的样例; 与 M9 长期记忆闭环形成「可观、可累积」整体。
- **约束驱动**: 在 Mojo 1.0.0b2 的 `Movable` / `inout` / `borrowed` 限制下, 扁平并行数组 +
  `mut self` 方法是能编译且正确的最小方案(与 M9 一致, 降低认知负担)。
- **TDD 纪律不破**: 只保留确定性、可断言的渲染出口, GUI 交互推迟到能单测的环境再补。

## 影响

- M8-core 是**纯观测层**, 不改变系统功能行为(不写记忆、不改调度), 仅消费已有推理链做可视化。
- `EmojiGraph` 的扁平并行数组 + `mut self`/`self` 方法范式, 成为后续「图类」模块的既定约定。
- GUI 交互特性(悬停/点击/拖拽/动画)如需落地, 须另立 ADR, 且大概率在独立前端/Web 模块而非 core Mojo。
- 风险: 首版无交互, 调试体验为「跑出 .svg / 文本 → 人工查看」; 若需实时交互调试, 须升级到 Web 层。

## M8 基准结果(2026-07-10)

`build` + `render` + `render_svg` × 500,000 次(2 推理链, 6 节点, 4 连线), 见
`benchmarks/results_emoji.json`(多次运行稳定, 取代表值)。渲染为离线确定性产出, 成本极低,
不计入全周期 <1µs 实时性预算(debug-only 路径)。
