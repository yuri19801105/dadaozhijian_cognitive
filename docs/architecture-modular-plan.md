# 大道至简认知架构 · 模块化总体大规划

> 状态：**MVP → 生产级过渡 · 总体规划 v1.7（总纲 + 调研增补 + Phase 1 core 落地 + Phase 2 状态记忆落地 + Phase 3 算子层 liangyi✅ + sancai✅ + sixiang✅ + bagua✅ 全部落地 + Phase 4 调度脑 wuxing✅ + liuhe✅ + qixing✅ + scheduler✅ + pipeline✅ 全部落地 + Phase 5 执行层 shifang✅ + runtime✅ + observability✅ 全部落地 + **回灌衔接闭环收口**（taiji/reinjection，v1.3）✅ + **回灌真实化与可观测增强**（shifang 真实 LLM 侧车✅ + runtime 回灌健康/超时门控✅ + observability 跨进程溯源 ledger✅ + taiji 持久化格式迁移 v2/并发写锁✅）✅ + **io 输入分词模块 ✅**（BPE 迁自 src/bpe.mojo + regex 风格分词器从零实现，v1.5）+ **config 外置化配置模块 ✅**（schema 驱动 + 校验 + 最小 TOML + defaults.toml 外置，v1.5）+ **部署/运维脚手架 ✅**（多阶段 Dockerfile + systemd + supervisord + 运行手册 + Prometheus 文本指标导出 + 退出码健康检查，v1.6；容器化仅作可选分支，外部基建项单列阻塞）+ **Phase 7 旧 src/ 与 M1–M10 遗留 tests/tools 软归档 ✅**（单一天纲结构达成，v1.6））** + **metrics_exporter 接入真实 Metrics ✅**（Prometheus 文本导出改由 `observability.Metrics.to_prometheus()` 驱动，新增 8 断言验证导出格式，v1.7）+ **k8s 部署模板 ✅**（`deploy/k8s/dadaozhijian.yaml`：Namespace/Secret/ConfigMap/Deployment + node-exporter textfile sidecar/Service + CronJob 备选，infra-free 占位，v1.7））**
> 创建：2026-07-11　更新：2026-07-11（v0.5：在 v0.4 已落地 taiji/jiugong/liangyi 基础上，新增 Phase 3 算子层规划——§4.2.2 导出能力确认、§4.2.3 推进策略、§4.3/§4.4/§4.8 各模块对 liangyi 调用契约 + I/O + 错误处理）
> 更新：2026-07-11（v0.6：§4.3 sancai 三才 TDD 落地——layers/interface 14 用例全绿，补 §4.3.1 接口骨架；修正导入根约定 `core` 无 `__init__.mojo` → 以 `-I core` + `tensor.tensor`/`math.ops` 短路径导入）
> 更新：2026-07-11（v0.7：§4.4 sixiang 四象 TDD 落地——quadrant/phase 29 用例全绿 + 基准 classify+canonical≈10ns/op、advance≈67ns/op，补 §4.4.1 接口骨架；运行时确认 PhaseMachine 严格 classify 在长程耗散收敛到平衡态时按 §4.4.0「非收敛流转抛错」约定报错，属预期设计行为）
> 更新：2026-07-11（v0.8：§4.8 bagua 八卦 TDD 落地——trigrams/operators/combine 17 组测试全绿 + 基准 trigram_lines≈129ns/op、apply≈23ns/op、combine≈264ns/op，补 §4.8.1 接口骨架；算子严格以 YinYangGate.dual_gate 作激活门、Polarity(compose/reconcile/invert) 作变换/组合，sancai 三层派生卦象经 validate 校验后取 初=人/二=地/三=天 三相位，未知符号降级中性卦不静默丢弃）
> 更新：2026-07-11（v0.9：**Phase 4 调度脑启动**——§4.5 wuxing 五行 TDD 落地：elements/sheng_ke/scheduler_core/balance 四文件 + 32 组测试全绿（81 断言）+ 基准 sheng_ke≈5ns/op、schedule≈175ns/op、propagate/rebalance≈350ns/op，补 §4.5.0 调用契约 + §4.5.1 接口骨架；真调度策略派生（替代 M5 硬编码权重）：由五元素能量向量派生 { 主导元素/归一权重/主导优势度/相生决策链 }，相生正反馈 + 相克负反馈构成生克制化自调节网络，消费 liangyi.Dual 能量与 sixiang 四象相位种子（四象＋中土＝五行），未知符号降级中性元素土不静默丢弃；ScheduleDecision 用固定标量槽保 Movable 可按值返回）
> 更新：2026-07-12（v1.0：**Phase 4 调度脑收官**——§4.6 liuhe 六合·供给、§4.7 qixing 七星·排序、§4.11 scheduler 总调度 全部 TDD 落地（零桩函数）：liuhe directions/supply/harmony 三文件 + 57 断言（基准 build_supply≈178/merge≈0 ns/op）；qixing priority/ordering/sequence 三文件 + 18 断言（基准 order_chain≈476/priority_of≈181/build_sequence≈507 ns/op）；scheduler policy/dispatcher 两文件 + 16 断言（基准 dispatch≈487/dispatch_from_phase≈666 ns/op）。跨模块接口契约锁定：wuxing.ScheduleDecision → liuhe.SupplyVector(六向供给, build_supply 由能量+上下文派生, harmony 由方差倒数) → qixing.DecisionSequence(优先级=权重×容量折扣, 抽象度锚定) → scheduler.DispatchPlan(唯一派发器, policy_id 降级-1)。详见 `docs/phase4-scheduler-design.md` 规格文档。全项目 8 模块累计 249 断言全绿）
> 更新：2026-07-12（v1.1：**Phase 4 调度脑端到端编排落地**——§4.12 pipeline 流水线 TDD 落地（零桩函数）：stages（阶段图 DAG + StageGraph.can_run 依赖门控/断点重放）+ orchestrator（run_pipeline / run_pipeline_from_energies / run_pipeline_chains 迁自 MVP run_cycle_chains / run_pipeline_safe 中性降级）两文件 + 78 断言（基准 run_pipeline≈997/run_pipeline_from_energies≈917 ns/op）。由 MVP 线性 `run_cycle` 重构为阶段图驱动：解析→五行调度→六合供给→七星定序→总派发，全链路产物固化 `PipelineResult`（候选链/规划链/confidence/policy_id/失败阶段），消费 wuxing.ScheduleDecision+liuhe.SupplyVector+qixing.DecisionSequence 合成为 scheduler.DispatchPlan。详见 `docs/phase4-pipeline-design.md` 规格文档。全项目 9 模块累计 327 断言全绿）
> 更新：2026-07-12（v1.2：**Phase 5 执行层全落地**——§4.10 shifang（十方·执行扇出+真实连接器）、§4.13 runtime（生命周期/内存/并发）、§4.14 observability（指标/追踪/解释/渲染/审计）三模块 TDD 落地（零桩函数）：shifang protocol/dispatch/executor 三文件 + 27 断言（连接器熔断/重试/中性降级；`fanout` 把 `PipelineResult.plan` 周遍扇出十方并经 `call_external` 真实接入缝生成可读回复，架构首次"能说话"）；runtime lifecycle/memory/concurrency 三文件 + 41 断言（状态机 IDLE→RUNNING→PAUSED→STOPPED、内存预算、任务槽+超时守卫；基准 lifecycle≈0/memory≈2/concurrency≈4 ns/op）；observability metrics/tracing/explain/render/logging 五文件 + 21 断言（全链路决策溯源 + 内在可解释 + 文本/SVG 渲染 + 结构化日志/审计；基准 metrics≈39/trace≈2269/render≈9552 ns/op）。详见 `docs/phase5-execution-design.md` 规格文档。全项目 15 模块（19 测试套件）累计 531 断言全绿）
> 更新：2026-07-12（v1.3：**回灌衔接闭环收口**——新增 `taiji/reinjection.mojo`，把执行层产物（`PipelineResult`/`ShifangOutput`/`Tracer`/`Metrics`）安全回灌进 `FeedbackLoop`：字段映射对齐 `TaijiState.feedback(output, decision, phase, intensity)` 既有签名（`output` 可读串 / `decision` 优先 plan 退化为 candidates / `intensity` 由 confidence×(1−退化率) 并随扇出降级折半）、源校验 + `try/except` 全隔离 + `observability.logging` 结构化日志（INFO/WARN/ERROR/AUDIT）；纯增量、不改动 `TaijiState`/`FeedbackLoop`/`CognitiveCycle`，异常仅降级为 `False` 不向上传播。11 断言全绿 + 基准 reinject_safe≈2767 / map_primitives≈1293 ns/op。全项目 15 模块（20 测试套件）累计 542 断言全绿）
> 更新：2026-07-12（v1.4：**回灌真实化 + 可观测增强**——① `shifang` 真实 LLM 侧车经 Mojo→python3 子进程桥接落地（`setenv` 传 prompt / `system` 拉起 `llm_sidecar.py` / `fopen`+`fread` 读回；置 `LLM_API_KEY` 走真实 LLM，否则确定性降级；22 断言全绿）；② `observability/store.mojo` 跨进程溯源 ledger 以 `lineage_id` 串联回灌↔溯源，`to_jsonl()` 经 stdout 管道供下游进程消费（store 测试全绿）；③ `runtime` 回灌健康度（`record_backfill`/`backfill_success_rate` 纳入 `is_healthy`/`can_execute`）+ `BackfillGate` 超时门控 + `BackfillSupervisor` 端到端闭环（runtime 测试由 41→67 断言全绿）；④ `taiji` 持久化格式升 v2（`last_lineage` 跨进程串联键 + 16/17 字段向后兼容 + 快照版本头 + `migrate()` + advisory 并发写锁）。全项目 15 模块（22 测试套件）全量断言全绿，详见 §4.1.4 / §4.10.2 / §4.13.2 / §4.14.2）
> 更新：2026-07-13（v1.5：**io 输入分词 + config 外置化配置两模块落地**——① `io/`：BPE 字节级分词器（迁自 src/bpe.mojo，硬化 + 适配本构建 `Dict.find`/`Tuple` API，`train_tokenizer(mut,text,vocab)` 因 `Dict` 非 Movable 用 `mut` 参数原地训练）+ 正则风格分词器（**从零实现**，旧 §4.15 称「迁自 src/regex.mojo」不实——该文件不存在；确定性扫描：ASCII 词/数字段合并、CJK 逐字、空白与标点保留以保证 decode 精确还原）。4 断言全绿 + 基准 bpe encode+decode≈19127 / regex encode+decode≈996 ns/op；② `config/`：schema 驱动（索引函数返回 String 字面量 + Movable 数值，规避非 Movable `FieldSpec`/`List`，见约束）+ 边界校验 + 最小 TOML 解析（扁平 `key=value` + `#` 注释）+ `defaults.toml` 外置（运维免重编译）+ 8 断言全绿。全项目 17 模块（24 测试套件）全量断言全绿，详见 §4.15 / §4.16）
> 更新：2026-07-13（v1.6：**Phase 6 部署/运维脚手架 + Phase 7 遗留软归档收口**——① `deploy/`+`ops/` 按 GitHub/全网调研最优解落地：部署单元定为 `mojo build` 静态二进制（容器化仅作多服务编排可选分支，非默认）；交付多阶段 `Dockerfile`（朴素 ~4GB→多阶段 ~300–500MB）、`systemd` 单元、`supervisord` 配置、`ops/runbook.md` 运维手册、`ops/healthcheck.sh` 退出码健康检查、`ops/metrics_exporter.mojo`（自包含 Prometheus 文本导出，免 HTTP，node_exporter textfile 兼容，已验证可编译运行）；② Phase 7 旧 `src/` 12 文件 + M1–M10 遗留 `tests/*.mojo`（11）+ `tools/dump_emoji.mojo` 经引用核查零构建引用且各自被新模块完全取代，依「绞杀者/软删除」最优解整体软归档至 `archived/`（可逆、非破坏），并写 `docs/adr/0012-legacy-src-archive.md` 记录旧→新映射；现行 17 模块回归 0 破坏。需外部基建项（k8s 集群 / Prometheus+Grafana 栈 / CI Docker runner / LLM 凭证）单列阻塞，属「环境供给」非「不可能」）
> 更新：2026-07-13（v1.7：**metrics_exporter 接入真实 Metrics + k8s 部署模板**——① `ops/metrics_exporter.mojo` 由参数化骨架升级为真实落地：直接复用 `observability.Metrics.to_prometheus()`（新增 `_ftoa` 浮点格式化 + `seed`/`seed_latency` 外部回填 + `to_prometheus` 序列化），导出 3 counter（吞吐/ok/degraded）+ 4 gauge（p50/p95/退化比例/五行方差，未置均衡度时自动省略以免 -1.0 哨兵泄漏）；`observability` 测试套件新增 `test_metrics_prometheus` 8 断言全绿（21→29）；② 新增 `deploy/k8s/dadaozhijian.yaml`：按「Mojo 静态二进制 + node_exporter textfile 免 HTTP」最优解给出 Deployment（主服务 + node-exporter sidecar 共享 emptyDir 写/读 .prom）+ Service + ConfigMap/Secret + CronJob 备选，全部占位符化、YAML 已校验可解析。全项目 17 模块（24 测试套件）回归 0 破坏）
> 更新方式：每推进一个大模块，固化本章节细节并递增版本号
> 配套哲学依据：`docs/philosophy/*.md`（太极/两仪/三才/四象/五行/六合/七星/八卦/九宫/十方 + README 索引，共 11 篇）
> 配套调研依据：`docs/cognitive-model-architecture-research-2026-07-11.md`（5 维度认知模型调研 + 查漏补缺）
> 立场基线：以"真实性=忠实执行·无黑箱·全链路可审计"为口径；可解释性与可审计性为生产级硬性要求，合规层作为可审计一环保留（不去除、不绕过）。

---

## 0. 总纲与第一性原则（不可违背）

**万物皆数，认知即计算。**

本架构的根本立场不是"用 AI 解释玄学"，而是**用玄学的结构重构 AI 的底层调度逻辑**。十个东方哲学概念不是隐喻、不是装饰，而是**可计算数据结构的直接蓝图**——每个概念对应一类数值表示、一组算子、一段调度语义。认知过程被建模为这些数值结构之上的确定性计算。

三条第一性原则：

1. **一切皆为可计算的数（万物皆数）**
   任何概念（阴阳、五行、八卦…）最终都落为 `core/number` 定义的统一数值类型，向量化、可 SIMD、可持久化。不允许"不可计算"的黑箱。
2. **玄学结构 = 调度结构（认知即计算）**
   五行的生克是**调度策略**，六合的供给是**资源编排**，七星的定序是**优先级排序**，八卦是**算子集**，九宫是**工作记忆张量盘**，十方是**执行扇出**，太极是**跨轮全局状态根与回灌闭环**。调度逻辑由这些结构直接派生，而非事后套壳。
3. **可解释 · 可测量 · 可实时**
   每个调度决策必须能回溯到五行生克/八卦算子（可解释）；每个模块自带 benchmark + metrics（可测量）；热路径纳秒级、非阻塞（可实时）。

---

## 1. 设计原则

| 原则 | 落地方式 |
|---|---|
| 向量化优先 | 所有数值计算走 `core/simd` 的向量内建；标量仅为退化情形 |
| 扁平数组存储 | 遵循 Mojo 1.0.0b2 约束（`List[T: Movable]`；含 `List` 字段的 struct 不可 Movable ⇒ 嵌套 List 不可行）。一律用**扁平并行数组**，构造/渲染走 `mut self`/`self` 方法，禁按值返回/传参 |
| 单模块可独立验证 | 每模块自带 `tests/` + `benchmarks/`，可独立 `mojo test`/`bench`，失败可单独回滚 |
| 配置外置 | `config/` 统一加载，运行期不硬编码阈值 |
| 故障隔离 | 调度大脑（wuxing/liuhe/qixing）与执行层（shifang）解耦，执行器崩溃不影响状态根（taiji） |
| 目录即文档 | 目录结构本身表达架构意图；每个模块根含 `README.md` 说明职责与接口 |

---

## 2. 整体分层架构

```
L6  横切    runtime · observability · io(输入) · config
L5  编排    pipeline（端到端流水线）
L4  执行    shifang（十方·执行扇出 + 外部连接器）
L3  调度脑  wuxing(五行·策略) · liuhe(六合·供给) · qixing(七星·排序) · scheduler(总调度)
L2  算子    bagua(八卦·算子集) · liangyi(两仪·阴阳原语) · sancai(三才·分层) · sixiang(四象·四态)
L1  状态记忆 taiji(太极·全局根/回灌) · jiugong(九宫·工作记忆盘)
L0  数基    core(number · simd · tensor · math)
```

数据流（一次认知循环）：
`io(分词) → sancai(三才分层) → jiugong(九宫载入工作记忆) → bagua(八卦算子作用) → wuxing(五行生克定调度策略) → liuhe(六合供给资源) → qixing(七星排决策链序) → shifang(十方执行) → taiji(回灌闭环) → 下轮`

---

## 3. 模块总览表

| 模块 | 哲学概念 | 工程角色 | 当前 MVP 状态 | 生产级缺口 |
|---|---|---|---|---|
| `core` | 万物皆数 | 统一数值/SIMD/张量基 | 无（散落各文件） | **需新建** |
| `taiji` | 太极 | 全局状态根 + 回灌闭环 | M9 实现（内存态） | **Phase 2 v0.4 已落地 ✅（回灌闭环+持久化落盘，37 用例全绿）+ 回灌衔接 v1.3 ✅（taiji/reinjection，11 断言全绿）** |
| `liangyi` | 两仪 | 阴阳二元原语/激活 | **v0.4 已落地 ✅（dual·polarity·activation，17 测全绿）** | 已落地，无需新建 |
| `sancai` | 三才 | 天地人分层接口 | 未独立 | **v0.5 已落地 ✅（layers·interface，14 测全绿）** |
| `sixiang` | 四象 | 四态/四象限 | 未独立 | **v0.6 已落地 ✅（quadrant·phase，29 测全绿 + 基准 10/67 ns/op）** |
| `wuxing` | 五行 | 调度策略核心 | M5 硬编码权重 | **v0.9 已落地 ✅（elements·sheng_ke·scheduler_core·balance，32 组测试全绿/81 断言 + 基准 5/175/350 ns/op；真调度策略派生替代硬编码权重）** |
| `liuhe` | 六合 | 供给/资源编排 | M6 实现 | **v1.0 已落地 ✅（directions·supply·harmony，57 断言全绿 + 基准 build_supply≈178/merge≈0 ns/op；六向供给向量 + 地支和合 + 多源归并）** |
| `qixing` | 七星 | 决策链排序 | M7 DP 排序 | **v1.0 已落地 ✅（priority·ordering·sequence，18 断言全绿 + 基准 order_chain≈476/priority_of≈181/build_sequence≈507 ns/op；优先级=权重×容量折扣＋抽象度锚定）** |
| `bagua` | 八卦 | 推理算子集 | M4 trigram | **v0.8 已落地 ✅（trigrams·operators·combine，17 组测试全绿 + 基准 23/129/264 ns/op）** |
| `jiugong` | 九宫 | 工作记忆 3×3 盘 | M3 workspace（List[Int] 占位） | **Phase 2 v0.4 已落地 ✅（3×3 真张量化）** |
| `shifang` | 十方 | 执行扇出 | M10 占位模板 | **【v1.2 已落地 ✅】十方扇出 + 真实连接器（熔断/重试/中性降级），架构"能说话" · 【v1.4 真实 LLM 侧车桥接 ✅】** |
| `scheduler` | 总调度 | 统一派发器 | 无 | **v1.0 已落地 ✅（policy·dispatcher，16 断言全绿 + 基准 dispatch≈487/dispatch_from_phase≈666 ns/op；wuxing+liuhe+qixing 合成唯一派发器 DispatchPlan）** |
| `pipeline` | 流水线 | 编排 | M1–M10 串联 | **【v1.1 已落地 ✅】阶段图驱动端到端编排** |
| `runtime` | 运行时 | 生命周期/内存 | 无 | **【v1.2 已落地 ✅】生命周期状态机 + 内存预算 + 任务槽/超时守卫 · 【v1.4 回灌健康度/超时门控 ✅】** |
| `observability` | 可观测 | M8 可视化+指标+**强制决策溯源/审计** | M8 emoji/SVG | **【v1.2 已落地 ✅】指标/追踪/解释/渲染/日志/审计 五子能力全绿 · 【v1.4 跨进程溯源 ledger ✅】** |
| `io` | 输入 | 分词（bpe/regex） | M1/M2 迁 bpe，regex 从零实现 | **【v1.5 已落地 ✅】BPE 字节级分词器（迁自 src/bpe.mojo，硬化）+ 正则风格分词器（从零实现，确定性扫描）+ 4 断言全绿** |
| `config` | 配置 | 全局配置 | config.mojo | **【v1.5 已落地 ✅】schema 驱动加载 + 校验 + 最小 TOML 解析 + 默认值外置 defaults.toml（免重编译）+ 8 断言全绿** |

---

## 4. 详细模块规划

> 每个模块给出：职责 / 目录树 / 文件职责 / 依赖 / 运维要点。MVP 已存在的内容标注"迁自"。

### 4.0 `core/` — 万物皆数（数基）【v0.3 已落地 ✅】

> **状态：Phase 1 完整实现（TDD 红-绿-重构，78 用例 / 7 套件全绿，0 warnings）**。详见 `core/README.md`、`core/benchmarks/results_core.json`。

**职责**：定义全局统一的数值类型、SIMD 向量原语、轻量张量、基础数值与激活函数。一切模块的数值皆源于此。

**Mojo 1.0.0b2 约束适配（已实证）**：无 `mojo.tensor`、无 `math` 模块 → 张量自建（`List[Float64]` 数据 + `List[Int]` 形状/步长），数值函数全自实现；含 `List` 字段的结构不可按值移动 → `Tensor` 以本地 `var` + `mut self` 方法使用，视图/广播以自由函数返回 `List[Float64]` 载体；`Vector[size](Movable)` 提供参数化 SIMD 封装。

**目录结构与接口（已落地）**
```
core/
├── number/
│   ├── scalar.mojo   # Scalar=Float64; Scalar32=Float32; ZERO/ONE; cast_scalar(v, prec)
│   └── dtype.mojo    # PRECISION_FLOAT64/FLOAT32/INT32/INT8/BOOL 常量; to_dtype(prec)->DType
├── simd/
│   ├── vector.mojo   # Vector[size](Movable): __init__(fill); get/set; add/sub/scale/add_scaled;
│   │                #   dot; reduce_add/max/min/mul; argmax; gt/lt 掩码; select(mask,a,b);
│   │                #   normalize; to_list; from_list
│   └── shuffle.mojo  # gather(data,idx); scatter; reverse; rotate_left/right; mask_any/mask_all/
│                     #   count_true/first_true(作用于 Vector 的掩码 List[Bool] 或 Bool 列表)
├── tensor/
│   ├── tensor.mojo   # Tensor: init/from_list(shape); at/set(多维); at_flat/set_flat; to_list;
│   │                #   fill/scale/add_scalar; add(other_data,other_shape); sum/max/min/argmax_flat;
│   │                #   row(r); init_3x3()(九宫)/init_6dir()(六合)
│   └── view.mojo     # transpose_2d(data,shape); slice_rows/slice_cols(data,shape,r0,r1);
│                     #   broadcast_add(data,shape,bdata,bshape) -> List[Float64]
├── math/
│   ├── ops.mojo      # sqrt/exp/sin/cos/log/pow/clamp/abs_f64 (均可 raises 参数校验);
│   │                #   sum_list/mean_list; exp_list/log_list/sqrt_list/pow_list/clamp_list/abs_list
│   └── activate.mojo # sigmoid/tanh/softmax_list (softmax 先减最大值, 数值稳定)
├── tests/   # 7 套件共 78 用例 (test_number/vector/shuffle/tensor/view/math_ops/math_activate + test_all)
├── benchmarks/  # bench_core.mojo + results_core.json
└── README.md
```

**验收（已实现）**
| 子模块 | 用例 | 关键覆盖 |
|---|---|---|
| number | 7 | 类型别名/常量/精度映射/cast |
| simd/vector | 13 | 构造/读写/elementwise/dot/reduce/argmax/mask-select/normalize/边界 |
| simd/shuffle | 10 | gather/scatter/reverse/rotate/mask-any-all/count/first/边界 |
| tensor | 12 | 形状/多维索引/加减/归约/行/3x3/6向/形状不匹配/越界 |
| tensor/view | 8 | 转置/切片/广播/越界/不兼容形状 |
| math/ops | 18 | sqrt/exp/sin/cos/log/pow/clamp/abs/sum/mean/逐元素/异常 raise |
| math/activate | 10 | sigmoid/tanh/softmax/归一化/稳定性/极值 |
| **合计** | **78** | **全绿, 0 warnings** |

**基准（1M 次, ns/op）**：vector_add_v8=6 / tensor_add_3x3=9 / softmax_len8≈599 / exp_scalar=14。热路径纳秒级，作为公共地基开销可忽略。

**依赖**：无（最底层）。**运维**：热路径零额外分配；`benchmarks/results_core.json` 锁性能回归门禁；任何下游模块改动触发 `mojo run -I core core/tests/test_all.mojo` 作为 CI 首关。

### 4.1 `taiji/` — 太极（全局状态根 + 长期记忆回灌闭环）【v0.4 已落地 ✅ · 回灌衔接 v1.3 已落地 ✅】

> **Phase 2 设计已细化至可落地接口骨架**（见 §4.1.1 回灌闭环 + §4.1.2 持久化落盘）。实现阶段严格 TDD，零桩函数。

> **实现状态（2026-07-11，零桩函数 TDD 全绿）**：`taiji_state.mojo` ✅ / `persistence.mojo` ✅（CRC32+WAL+崩溃恢复） / `feedback_loop.mojo` ✅ / `cycle.mojo` ✅（四步编排+落盘） / `consolidation.mojo` ✅（EWC 思路 Mojo 化，委派 `TaijiState.consolidate_in_place`）。`jiugong/board.mojo` ✅（3×3 真张量化）。六套件合计 **37 用例全绿**：taiji_state(10) / persistence(7) / feedback_loop(4) / consolidation(3) / cycle(5) / jiugong(8)。上游 `wuxing`/`shifang` 以确定性真实协作者占位（非桩），Phase 3/5 再落地。

**职责**：跨轮全局状态根；承载 `recall→plan→execute→feedback` 回灌闭环；**持久化长期记忆**（MVP 最大生产缺口，本版给出完整落盘方案）；承担**持续学习巩固/遗忘策略**（EWC/经验回放 Mojo 化）。

**第一性原理约束（来自 §0）**：太极为根，一切派生自太极、最终回灌太极（闭环）；与九宫分层——九宫承载单轮中间态，太极承载跨轮累积态，二者不重复造轮子。

#### 4.1.0 能量流转与状态反馈闭环模型

一次认知循环的能量/信息流（确定性、可审计）：

```
[输入文本] + [recall: 太极根注入记忆上下文]
   │
   ▼
[plan]    wuxing 依生克派生策略 + qixing 排决策链  →  plan(decision, phase)
   │
   ▼
[execute] shifang 依 plan 扇出执行  →  output(text, decision, phase, intensity)
   │
   ▼  ◄──────────── 回灌（feedback）─────────────┐
[feedback] 输出 → 更新太极根(energy/seed/历史) → 下一轮 recall 注入
```

- **能量流转**：每轮输出强度 `intensity` 经 `sigmoid` 归一为能量 `e∈[0,1]`，叠加进全局能量张量 `energy`（长期记忆态）；`energy` 经 `softmax` 得到能量分布，作为下一轮 `recall` 的偏置权重。
- **状态反馈闭环**：太极根在每轮 `feedback` 后确定性更新（seed 重算），并反作用于下一轮 `recall` 注入；循环闭合、可回溯。

**状态流转规则（四步契约）**

| 阶段 | 读 | 写 | 不变量 |
|---|---|---|---|
| recall | `phases / intensities / seed / intent_hash` | — | 首轮(`round==0`)返回 `""`（退化单轮） |
| plan | 注入记忆 + 当前 `energy` | — | plan 须可回溯到五行生克（可审计） |
| execute | plan | — | output 须带 `(text, decision, phase, intensity)` |
| feedback | 历史 | `decision_chains / phases / intensities / out_lengths / energy / seed / round` | seed 确定性派生；触发 consolidate 条件判定 |

**回灌触发条件（feedback trigger）**

1. **基础回灌（每轮必触发）**：`execute` 产出 output 后立即 `feedback()`，写入历史并重算 seed。
2. **巩固触发**：`energy` 总量越界（`> feedback_threshold`）或 `intensity` 方差超阈 → 触发 `consolidate()`（巩固重要轨迹、遗忘低权重）。
3. **快照触发（落盘）**：轮数达 `snapshot_every`（配置）或显式 `flush()` → 触发 `persistence.save_snapshot()`。
4. **关闭/检查点触发**：进程退出/checkpoint → 强制完整 snapshot（不丢最后 N 轮）。

#### 4.1.1 太极回灌闭环 — 接口骨架（函数签名 · 参数类型 · 返回值）

```mojo
# taiji/taiji_state.mojo  — 迁自 src/taiji.mojo, 升级为张量化能量态
from core.number.scalar import Scalar, ZERO, ONE
from core.tensor.tensor import Tensor
from core.math.activate import softmax_list

comptime TAIJI_MAGIC: Int = 0x5441494A            # "TAIJ", 落盘魔数
comptime TAIJI_FORMAT_VERSION: Int = 2            # 格式版本(v2 起含 last_lineage 跨进程串联键), 迁移依据（见 §4.1.4）

struct TaijiState:
    # —— 跨轮累积态（全局状态根）——
    var decision_chains: List[List[Int]]   # 每轮七星决策链（按轮存储）
    var phases: List[Int]                   # 每轮五行相位 (0..4)
    var intensities: List[Float64]          # 每轮强度（能量）(Scalar)
    var out_lengths: List[Int]              # 每轮十方输出字节长
    var energy: Tensor                      # 全局能量张量（长期记忆态, 默认 shape [9] 映射九宫）
    var round: Int                          # 已回灌轮数
    var seed: Int                           # 由历史派生的全局状态根种子（确定性）
    var intent_hash: Int                    # 意图哈希

    def __init__(out self, intent_hash: Int = 0) raises
    # 返回累积记忆上下文, 供下一轮派生（首轮返回 ""）
    def recall(self) -> String
    # 十方输出 → 回灌太极: 写入长期记忆 + 派生 seed + 叠加能量
    def feedback(mut self, output: String, decision: List[Int], phase: Int, intensity: Float64) raises
    # 最近一轮决策链副本（避免外移内部状态）
    def last_decision(self) -> List[Int]
    # 能量分布（softmax over intensities / energy）, 用于 recall 偏置
    def energy_distribution(self) -> List[Float64]
    # 序列化辅助: 导出/导入为扁平字节载体（供 persistence 落盘）
    def to_payload(self) -> List[Int]
    def from_payload(mut self, payload: List[Int]) raises
```

```mojo
# taiji/feedback_loop.mojo
from .taiji_state import TaijiState
from core.math.ops import sigmoid, clamp

struct FeedbackLoop:
    var state: TaijiState
    var energy_budget: Float64        # 每轮能量预算（配置化）
    var feedback_threshold: Float64   # 巩固触发阈值

    def __init__(out self, intent_hash: Int, energy_budget: Float64, feedback_threshold: Float64) raises
    # 回灌入口: 输出 → 归一能量 → 叠加进 state.energy → 写历史 → 重算 seed → 判定 consolidate
    def feedback(mut self, output: String, decision: List[Int], phase: Int, raw_intensity: Float64) raises
    # 注入: 下一轮派生输入
    def recall(self) -> String
    # 回灌触发条件判定（巩固）
    def should_consolidate(self) -> Bool
```

```mojo
# taiji/cycle.mojo  — 四步闭环编排（recall→plan→execute→feedback）
from .feedback_loop import FeedbackLoop
from core.tensor.tensor import Tensor
# 依赖（后续 Phase 实现, 此处仅为接口边界声明）:
#   from jiugong.board import WorkspaceBoard
#   from wuxing.scheduler_core import plan as wuxing_plan
#   from shifang.executor import execute as shifang_execute

struct CycleConfig:
    var energy_budget: Float64
    var feedback_threshold: Float64
    var snapshot_every: Int
    var enable_persistence: Bool

struct CycleResult:
    var output_text: String
    var decision: List[Int]
    var phase: Int
    var intensity: Float64
    var round: Int

struct CognitiveCycle:
    var loop: FeedbackLoop
    # var workspace: WorkspaceBoard   # 单轮工作记忆（jiugong, Phase 2 接入）
    var cfg: CycleConfig

    def __init__(out self, cfg: CycleConfig) raises
    # 四步闭环: recall -> plan -> execute -> feedback, 返回本轮结果
    def run(mut self, text: String) raises -> CycleResult
    # 显式落盘触发
    def flush(mut self) raises
```

```mojo
# taiji/consolidation.mojo  — 巩固/遗忘（防灾难性遗忘, 持续学习横切落地）
from .taiji_state import TaijiState
from core.math.ops import sigmoid

struct Consolidation:
    var keep_rate: Float64        # 重要轨迹保留率（配置化, 安全域偏保守）
    var forget_rate: Float64      # 低权重遗忘率

    def __init__(out self, keep_rate: Float64, forget_rate: Float64)
    # 巩固: 强化高能量轨迹, 衰减低权重历史（弹性权重巩固 EWC 思路 Mojo 化）
    def consolidate(mut self, state: TaijiState) raises
```

```mojo
# taiji/api.mojo  — 对外入口
from .cycle import CognitiveCycle, CycleConfig, CycleResult

# 端到端: 文本 + 配置 → 闭环结果（内部含 recall→plan→execute→feedback + 持久化）
def run_cycle(text: String, cfg: CycleConfig) raises -> CycleResult
```

#### 4.1.2 长期记忆持久化落盘（MVP 最大生产缺口 · 完整方案）

**职责**：将 `TaijiState`（跨轮全局根 + 能量态）序列化到磁盘，支持加载/恢复/版本迁移，保障数据一致性。落盘后太极具备「进程重启不丢记忆」的生产能力。

**存储格式（二进制 + 版本头 + 校验 + 人类可读 sidecar）**

```
taiji_state.bin (主快照, 原子写):
  [ MAGIC:        u32 = 0x5441494A ]   # 魔数, 防误读
  [ FORMAT_VER:   u32 = 1          ]   # 格式版本, 迁移依据
  [ HEADER_LEN:   u32              ]   # 头部长度, 向后兼容扩展
  [ PAYLOAD_CRC:  u32              ]   # CRC32(载荷), 一致性保障
  [ PAYLOAD:      bytes             ]  # 见下方序列化布局
taiji_journal.bin (WAL 增量日志, 追加写): 每轮一条 delta 记录（同上载荷格式, 仅含本轮增量）
taiji_state.json (sidecar, 人类可读/审计): 镜像关键字段, 供 observability/tracing 溯源
```

**载荷序列化布局（PAYLOAD）**：`intent_hash(i64) | round(i64) | seed(i64) | energy_shape[...] | energy_data[...] | decision_chains(展平+链长) | phases[] | intensities[] | out_lengths[]`（全部定长/长度前缀编码，自实现，无外部依赖）。

**落盘路径策略（path strategy）**

- 根目录由 `config` 提供（默认 `./state/`），按 `model_name` 隔离实例：`{base_dir}/{model_name}/`。
- 文件名固定：`taiji_state.bin` / `taiji_journal.bin` / `taiji_state.json` / `.lock`（写锁）。
- 临时文件：`taiji_state.bin.tmp`（原子 rename 覆盖，避免半写）。

**读写时机（read/write timing）**

- **写**：
  - 每轮 `feedback` 后 → 追加 `journal`（廉价 WAL，保证不丢轮）。
  - 轮数达 `snapshot_every` 或显式 `flush()` / 进程退出 → 全量 `save_snapshot()`（原子写）。
- **读**：
  - 启动 / 首次 cycle → `load()`：先读 snapshot，再重放 journal 至最新一致态。
  - 懒加载：首个 `run()` 前完成，避免阻塞热路径。

**数据一致性保障（consistency）**

1. **原子写**：临时文件写全 → `fsync` → `rename` 原子覆盖（POSIX rename 原子）。
2. **校验**：每文件 `CRC32` 尾部，加载时校验，损坏即报错（不静默）。
3. **版本迁移**：`FORMAT_VER` 头 + `migrate()` 升级旧版载荷，向后兼容。
4. **写锁**：`.lock` 防并发写者；读者可读旧 snapshot 而写者 rename 新文件（无锁读）。
5. **WAL 重放**：snapshot 后丢失的轮由 journal 补齐，保证「重启 = 最后一轮之后」。
6. **幂等加载**：重复 `load` 不产生副作用。

**接口骨架（函数签名）**

```mojo
# taiji/persistence.mojo
from .taiji_state import TaijiState, TAIJI_MAGIC, TAIJI_FORMAT_VERSION
from std.file import open, create_directory, rename, remove
from std.io import FileHandle

struct Persistence:
    var base_dir: String
    var model_name: String
    var format_version: Int

    def __init__(out self, base_dir: String, model_name: String)
    # 路径策略
    def snapshot_path(self) -> String
    def journal_path(self) -> String
    def sidecar_path(self) -> String
    def lock_path(self) -> String
    # 写: 全量快照（原子临时文件 + rename）+ sidecar JSON
    def save_snapshot(mut self, state: TaijiState) raises
    # 写: 增量日志（WAL, 追加）
    def save_journal(mut self, state: TaijiState) raises
    # 读: snapshot + journal 重放 → 一致态
    def load(mut self) raises -> TaijiState
    # 版本迁移
    def migrate(mut self, state: TaijiState) raises
    # 一致性: 自实现 CRC32（无外部依赖, 对齐 core 自实现精神）
    def checksum(self, data: List[Int]) -> UInt32
```

**依赖与接口边界（§4.1）**

- 依赖：`core`（number/tensor/math 提供数值与张量基底）；`jiugong`（单轮工作记忆载入 → 回灌前态）；`wuxing`（plan 派生策略，接口边界，Phase 3 落地）；`shifang`（execute 输出，接口边界，Phase 5 落地）；`config`（energy_budget/threshold/snapshot_every/base_dir 外置）。
- 边界：`taiji` 仅暴露 `run_cycle(text, cfg) -> CycleResult` 与 `Persistence` 对外；内部 state 不可被外部直接 mutate（经 `feedback` 受控写入）。
- 运维：`persistence` 需版本迁移工具；`cycle` 需超时与失败重试；状态根不可丢（快照 + journal 双保险）。

#### 4.1.3 回灌衔接（Phase 5 闭环收口 · v1.3 已落地 ✅）

**职责**：把「架构能说话 / 可审计」之后的全部执行层产物，安全回灌进太极长期记忆，闭合 `shifang→observability→taiji→下轮` 的元认知闭环（见 §0 第一性原理：一切最终回灌太极）。

**对接数据源（需求 1）**：`PipelineResult`（调度产物）/ `ShifangOutput`（十方扇出）/ `Tracer`（决策溯源）/ `Metrics`（运行指标）。

**字段映射（需求 2，对齐 `TaijiState.feedback(output, decision, phase, intensity)` 既有签名，`TaijiState`/`FeedbackLoop`/`CognitiveCycle` 零改动）**：
- `output: String` ← `[回灌] <输入> phase=.. conf=..% policy=.. plan=[木→火→土] 十方=N向(ok=.. degraded=..)`（`reinject_output`）
- `decision: List[Int]` ← 优先 `PipelineResult.plan`，缺失则退化为 `candidates`（`reinject_decision`）
- `phase: Int` ← `PipelineResult.phase`
- `intensity: Float64` ← `confidence × (1 − robustness_degradation)`，扇出 `degraded=1`/`ok=0` 再折半，钳制 (0,1)（`reinject_intensity`）

**异常处理与日志（需求 3）**：`validate_source()` 在接入前拦截非法源（相位/置信度越界、扇出计数/状态位非法）→ 记 `WARN` + `AUDIT REINJECT_REJECTED`，不触碰状态根；`reinject_safe()` 全程 `try/except` 隔离，任何异常 → 记 `ERROR` + `AUDIT REINJECT_DENIED` 并返 `False`，绝不向上传播；结构化日志缓冲（`observability.logging` 的 INFO/WARN/ERROR/AUDIT）便于排查，`summary()` 给出 `injected/rejected/errors/last_status`。

**不影响既有功能（需求 4）**：纯增量衔接层，仅复用 `FeedbackLoop.feedback` 公共入口；测试 `test_bridge_isolates_errors_and_keeps_existing_functional` 证明即便非法输入也仅返 `False`，独立 `CognitiveCycle` 照常推进、互不干扰。

**验收**：`taiji/tests/test_reinjection.mojo` 11 断言全绿；基准 `reinject_safe≈2767 / map_primitives≈1293 ns/op`（开销来自可读串拼装与日志 `append`，不进入 feedback 既有热路径）。详见 `taiji/README.md`。

#### 4.1.4 持久化格式迁移与并发写锁（v1.4 增强）

为支持**跨进程溯源串联**（见 §4.14.2 observability/store.mojo 的 `lineage_id`），v1.4 对太极持久化做了向后兼容的格式升级与并发护栏：

- **格式版本升 v2**：`TAIJI_FORMAT_VERSION` 由 1 → 2；`TaijiState` 新增 `last_lineage: Int` 字段（最近一次回灌关联的 observability 溯源 `lineage_id`，作为"状态根 ↔ 溯源 ledger"的跨进程串联键）。
- **`deserialize` 向后兼容**：v1 旧格式仅 16 字段（无 `last_lineage`），以 `0` 兜底补到 17；v2 为 17 字段；其余长度 `raises`（真·16 字段直载断言已覆盖）。
- **快照版本头（四行）**：魔数 `TAIJ` / 格式版本 / 载荷 / CRC32；`_parse_snapshot` 解析并输出 `version`，供 `migrate` 判定。
- **`migrate(mut state) -> Int`**：现存快照版本 `<` 当前版本 → 重落盘并返 `1`（已升级）；版本一致 → 返 `0`（幂等，可重复调用）。
- **advisory 并发写锁**（受 Mojo 无 `rename`/`fcntl` 约束，以读-判-写文件令牌实现软护栏）：`_acquire_lock()` 读取锁文件，若已持 `1` 返 `0`（拒绝），否则写 `1` 返 `1`；`_release_lock()` 写 `0`。避免并发快照/回灌落盘竞争。

**验收**：`taiji/tests/test_persistence.mojo` 含 `test_lock_advisory`（读-判-写互斥）+ `test_migrate_v1_to_v2`（含真·16 字段直载断言 `last_lineage` 兜底 0），全绿；`taiji_state`(10) / `persistence`(9) 套件随全量回归一并校验。

### 4.2 `liangyi/` — 两仪（阴阳二元原语）【v0.4 已落地 ✅】

> **实现状态（2026-07-11，零桩函数 TDD 全绿）**：`liangyi/dual.mojo` ✅（`Dual` 阴阳对双桶模型 + 算术 + `as_vector`）/ `polarity.mojo` ✅（invert/compose/classify/reconcile）/ `activation.mojo` ✅（`YinYangGate` 阴门/阳门/双门/平衡门，迁自 `core/math`）。**17 用例全绿**，零桩函数。详见 §4.2.0 子任务分解与 §4.2.1 接口骨架；导入口径与 `taiji` 一致（`core.tensor.*` 走 `-I .`，`math.*` 走 `-I core` 短路径）。

**职责**：万物最基础的阴阳/正负/激活原语。一切"有無/动静/显隐"的底层表示；阴阳同数异相、互为根，是上层 `sancai`/`sixiang`/`wuxing`/`bagua` 可组合原语的供给源。

**第一性原理约束（来自 §0）**：两仪为万物最基础的二元表示——阳为显/动/有，阴为隐/静/無；二者同数异相、互补互根，不可偏废。所有二元判定、激活门、极性变换皆以此为根，保证上层语义可解释、可溯源。

#### 4.2.0 目标 · 子任务分解 · 优先级 · 依赖

**4.2.0.1 具体目标（Goals）**
- **G1 — 阴阳对类型**：提供 `Dual` 阴阳对（同数异相），作为两仪核心数据结构，SIMD 友好。
- **G2 — 极性运算**：提供取反/合成/判别/调和，覆盖阴阳基本变换，可组合。
- **G3 — 阴阳激活门**：提供基于 `core/math` 之上的 gating 原语（`yin_gate`/`yang_gate`/`balance_gate`），为 `sancai`/`sixiang`/`wuxing` 提供激活基元。
- **G4 — 质量门禁**：全模块 TDD（RED→GREEN→清理），纳入性能回归核心门禁（最常用原语，热路径零额外分配）。

**4.2.0.2 关键工作项拆解（子任务）**

| 子任务 | 文件 | 关键内容 | 验收要点 |
|---|---|---|---|
| **T1** Dual 核心类型 | `dual.mojo` | `Dual` 结构 + 构造/同数异相访问/基础算术(add/sub/scale)/SIMD 视图 | 同数异相正确；算术保相；`as_vector` 打包正确 |
| **T2** 极性运算 | `polarity.mojo` | 取反(invert)/合成(compose)/判别(classify)/调和(reconcile) | 取反翻相；合成按 ratio 加权；判别三态(-1/0/1) |
| **T3** 阴阳激活门 | `activation.mojo` | `yin_gate`/`yang_gate`/`dual_gate`/`balance_gate`，迁自 `core/math` 之上 | 门控数值范围正确；相偏置调阈值；与 `Dual` 兼容 |
| **T4** 测试 | `tests/` | T1–T3 各测试（构造/边界/对称性/数值）+ `test_all` 聚合 | 零桩函数；全部通过 |
| **T5** 基准 | `benchmarks/` | dual 算术/SIMD、polarity、activation 基准 | 纳入回归门禁，热路径设上限 |
| **T6** 文档 | `README.md` | 目录即文档自述职责/接口 | 新人无需通读全局 |

**4.2.0.3 优先级（P0 / P1 / P2）**
- **P0**：T1（`Dual` 是一切基础，T2/T3 依赖）、T4（TDD，每模块先写测试）。
- **P1**：T2（`polarity` 依赖 T1）、T3（`activation` 依赖 T1 + `core/math`）、T5（benchmark 门禁）。
- **P2**：T6（`README`）。

**4.2.0.4 依赖关系（Dependencies）**
- **外部依赖**：`core`（`number/scalar`、`simd/vector`、`math/ops`、`math/activate`）。
- **模块内依赖**：T2/T3 依赖 T1（`Dual`）；T4/T5 依赖 T1–T3。
- **下游依赖（被谁用）**：`sancai`（层间消息用 `Dual` 表阴阳属性）、`sixiang`（四象由两仪派生）、`wuxing`（五行权重阴阳偏置）、`bagua`（算子 gating）。→ `liangyi` 须在 **Phase 3 最先落地**，是 `sancai`/`sixiang`/`bagua` 的前置。
- **无依赖**：`taiji`/`jiugong`（状态层不依赖原语层）；可独立测试、独立 `mojo run`。

#### 4.2.1 接口骨架（函数签名 · 参数类型 · 返回值）

```mojo
# liangyi/dual.mojo  — 阴阳对核心类型(同数异相), SIMD 友好
from core.number.scalar import Scalar, ZERO, ONE
from core.simd.vector import Vector

comptime YIN: Int = 0
comptime YANG: Int = 1

struct Dual:
    var value: Scalar       # 共享数值（阴阳同数）
    var phase: Int           # 相: YIN=0 / YANG=1
    var yin: Scalar          # 阴分量
    var yang: Scalar         # 阳分量

    def __init__(out self, value: Scalar, phase: Int = YANG) raises
    def from_parts(yin: Scalar, yang: Scalar) -> Dual
    def get_value(self) -> Scalar
    def get_phase(self) -> Int
    def yin_part(self) -> Scalar
    def yang_part(self) -> Scalar
    # 基础算术（阴阳分量各自运算, 结果仍为 Dual）
    def add(self, other: Dual) -> Dual
    def sub(self, other: Dual) -> Dual
    def scale(self, k: Scalar) -> Dual
    # SIMD 友好载体: 打包 [yin, yang] 供批量运算
    # (本构建 core.simd.vector 长路径导入不可用, 故以 List[Float64] 为载体, 同 core/tensor 视图惯例)
    def as_vector(self) -> List[Float64]
```

```mojo
# liangyi/polarity.mojo  — 极性运算
from .dual import Dual, YIN, YANG

struct Polarity:
    # 取反: 阴阳互换(phase 翻转, 分量交换)
    def invert(d: Dual) -> Dual
    # 合成: 按 ratio∈[0,1] 加权调和(0=纯阴, 1=纯阳)
    def compose(a: Dual, b: Dual, ratio: Scalar) -> Dual
    # 判别: 偏阴/平衡/偏阳 → -1 / 0 / 1
    def classify(d: Dual) -> Int
    # 调和: 一对 Dual 取均值 + 相位归中, 最小冲突
    def reconcile(a: Dual, b: Dual) -> Dual
```

```mojo
# liangyi/activation.mojo  — 阴阳激活门(迁自 core/math 之上)
from .dual import Dual, YIN, YANG
from core.number.scalar import ZERO
from core.math.activate import sigmoid
from core.math.ops import clamp

struct YinYangGate:
    # 阴门: 抑制(低激活) — 由阴分量驱动 gating
    def yin_gate(x: Dual, bias: Scalar = ZERO) -> Scalar
    # 阳门: 激发(高激活) — 由阳分量驱动 gating
    def yang_gate(x: Dual, bias: Scalar = ZERO) -> Scalar
    # 阴阳双门: 同时输出 (抑制量, 激发量), 供上层选择
    def dual_gate(x: Dual, bias: Scalar = ZERO) -> (Scalar, Scalar)
    # 平衡门: 阴阳归一后 sigmoid(相偏置调激活阈值)
    def balance_gate(x: Dual, threshold: Scalar = ZERO) -> Scalar
```

**依赖**：`core`、`liangyi`（自身三文件互依，见 §4.2.0.4）。**运维**：作为最常用原语，纳入性能回归核心门禁（§6）；接口变更走 ADR + 版本号；阈值/策略外置 `config/defaults.toml`（§6 配置外置）。

#### 4.2.2 导出能力确认（可作为基础原语被下游调用）

**下游导入契约（已在项目根 `-I .` 下验证可用，与 `taiji`/`jiugong` 同根）**
```mojo
from liangyi.dual import Dual, YIN, YANG            # 阴阳对核心类型 + 相位常量
from liangyi.polarity import Polarity              # 极性运算(@staticmethod 集)
from liangyi.activation import YinYangGate, GatePair  # 阴阳激活门 + 双门返回载体
# liangyi 内部互引: from .dual import Dual, YIN, YANG
```

**导出清单（对下游可见的接口面）**
- `Dual(Movable)`：`value/phase/yin/yang` 字段；`__init__(value, phase=YANG)` / `from_parts(yin, yang) -> Dual` / `get_value()` / `get_phase()` / `yin_part()` / `yang_part()` / `add/sub/scale(other / k)` / `as_vector() -> List[Float64]`。
- `YIN=0` / `YANG=1` 相位常量（`comptime`）。
- `Polarity`：`invert(d) -> Dual` / `compose(a, b, ratio) -> Dual` / `classify(d) -> Int(-1/0/1)` / `reconcile(a, b) -> Dual`（均 `@staticmethod`）。
- `YinYangGate`：`yin_gate(x, bias=0.0) -> Float64` / `yang_gate(x, bias=0.0) -> Float64` / `dual_gate(x, bias=0.0) -> GatePair` / `balance_gate(x, threshold=0.0) -> Float64`（均 `@staticmethod`）。
- `GatePair(Movable)`：`yin: Float64` / `yang: Float64`（双门返回载体，替代本构建不可用的元组返回）。

**结论（point 1）**：liangyi 三文件均为独立可导入模块（非 `__init__` 聚合导出），下游以 `from liangyi.<file> import <sym>` 直接取用，`-I .` 下可解析 `liangyi.*`。`Dual`/`GatePair` 显式 `(Movable)`，可作返回值按值传递；`Polarity`/`YinYangGate` 仅含 `@staticmethod`、无状态字段，天然可组合、可内联。**liangyi 已具备作为基础原语被 sancai/sixiang/bagua 直接调用的全部导出能力。**

> **建议（非强制）**：可在 `liangyi/__init__.mojo` 增加聚合导出（`from .dual import Dual, YIN, YANG` 等）以允许 `from liangyi import Dual`，提升下游可读性；当前不阻塞调用。

#### 4.2.3 Phase 3 算子层集成与推进策略（sancai · sixiang · bagua）

**4.2.3.1 依赖关系总览（对 liangyi 的调用契约）**

| 下游模块 | 对 liangyi 的依赖 | 主要调用的原语 | 是否仅依赖 liangyi |
|---|---|---|---|
| `sancai` | 每层（天/地/人）的阴阳属性以 `Dual` 承载；层间消息以 `Dual` 传递 | `Dual`(构造/算术) + `Polarity.compose/reconcile/classify` + `YinYangGate.balance_gate` | 是（仅 `core`+`liangyi`） |
| `sixiang` | 四象由两仪派生：每象为带相位标记的 `Dual`；状态机流转用极性运算 | `Dual` + `Polarity.invert/compose/classify` + `YinYangGate.dual_gate` | 是（仅 `core`+`liangyi`） |
| `bagua` | 每卦=3 条 `Dual` 爻线；算子激活以 `YinYangGate` 门控；卦线组合用 `Polarity` | `Dual` + `Polarity` + `YinYangGate` + `GatePair` | 否（另依赖 `sancai`，见 §4.8.0） |

**调用契约（强制）**：所有下游模块**禁止在 liangyi 之上重新实现阴阳表示**——阴阳属性一律用 `Dual`，极性变换一律走 `Polarity`，激活门一律走 `YinYangGate`。这保证上层语义可解释、可溯源（§0 第一性原理 + §8 #8 可审计）。

**4.2.3.2 实现顺序与并行开发策略**

```
Wave 1（可并行，两个根模块，仅依赖已落地的 liangyi）:
  Track A: sancai  (天地人分层)   ← 独立任务, 可并行
  Track B: sixiang (四象四态)     ← 独立任务, 可并行
Wave 2（串行, 依赖 Wave 1）:
  bagua (八卦算子)  ← 依赖 sancai(§4.8), 待 Track A 落地后启动
                       （sixiang 对 bagua 为可选增强, 不阻塞核心）
```

- **并行可行性**：`sancai` 与 `sixiang` 互不依赖——二者都是 liangyi 的"直接派生"，且分别服务不同下游 track（sancai→bagua，sixiang→wuxing/Phase 4），故可分配给两条独立开发流（或 Agent 子任务）并行 TDD，互不阻塞。
- **串行依赖点**：`bagua` 在 §4.8 明确依赖 `sancai`，须等 `sancai` 落地（测试全绿）后启动；建议 `bagua` 在 Wave 1 末尾即并行铺开与 sancai 无关的部分（trigram 定义 / 算子框架），`sancai` 一绿即接入。
- **统一 TDD 纪律**：每模块先写测试（RED 确认未实现/编译失败）→ 实现（GREEN）→ 全绿再进下一模块；零桩函数（与 Phase 2 一致）。

**4.2.3.3 统一 I/O 规范（算子层）**

- **输入**：各算子接收 `core` 数值基底（`Tensor`/`List[Float64]`/`Float64`）与 `Dual`（阴阳属性）；不接受"不可计算"的黑箱输入（§0 #1）。
- **输出**：结构化 `struct`（非裸元组，因本构建元组返回不可用）；数值结果统一 `Float64`/`List[Float64]`/`Tensor`，阴阳语义一律 `Dual`/`GatePair`。
- **确定性**：算子语义纯函数、无随机；如需随机性（探索）由 `config` 注入种子，保证可复现、可审计。
- **与上层衔接**：`sancai` 三层输出（天/地/人 各一 `Dual` + 张量）映射为 `jiugong` 的 3 行（`r=0 天 / r=1 地 / r=2 人`，见 §4.9 维度语义）；`bagua` 算子输出接入 `wuxing` 生克策略（Phase 4）与 `observability/tracing` 溯源。

**4.2.3.4 统一错误处理框架（算子层）**

- **失败即 `raises`**：所有可能因输入非法失败的算子函数标注 `raises`，抛 `Error` 并带描述性消息（如 `"sancai: layer count must be 3, got N"`）。
- **数值安全**：内部对 `NaN`/`Inf` 显式 `clamp`/`abs`（`core.math.ops`）校验，禁止静默 `NaN` 传播。
- **维度/范围校验**：层数=3、象限索引∈[0,3]、卦码∈[0,7] 等，越界立即 `raises`。
- **优雅降级（非崩溃）**：未知符号/缺省 → 映射为中性原语（`Dual(0)` 无极/太极中性，或最近有效态），不静默丢弃；降级事件记入 trace（接 `observability`）。
- **可审计**：每个算子调用产出一条 trace 记录（输入摘要 + 原语选择 + 输出），满足 §8 #8「不可审计即不部署」。
- **与 Phase 2 一致**：沿用 `taiji`/`jiugong` 的 `mut self` 就地改写习惯（含 `List`/非 Movable 字段的 struct 不按值返回），避免移动/拷贝报错。

### 4.3 `sancai/` — 三才（天地人分层接口）【v0.5 已落地 ✅】

> **实现状态（2026-07-11，零桩函数 TDD 全绿）**：`sancai/layers.mojo` ✅（`SanCai` 三层 `Dual`＋`payload Tensor`、构造/校验/取层/主导相）/`sancai/interface.mojo` ✅（`LayerMessage` 层间消息 + `LayerBus` 传递/门控/调和，调用 `Polarity` + `YinYangGate`）。**14 用例全绿**（layers 10 + interface 4），零桩函数。详见 §4.3.1 接口骨架与实现要点。

**职责**：把一次认知拆为 天(输入/上下文)·地(状态/根基)·人(行为/主体)三层，提供层间接口契约。
```
sancai/
├── layers.mojo            # 三层数据结构 + 边界定义
├── interface.mojo         # 层间消息契约(天→地→人 的传递类型)
├── tests/  benchmarks/
└── README.md
```
**依赖**：`core`、`liangyi`。**运维**：接口变更走 ADR + 版本号。

#### 4.3.0 Phase 3 规划：对 liangyi 的调用契约 · I/O · 错误处理

**对 liangyi 的依赖与调用契约**
- 三层（天/地/人）各持一个 `Dual` 表示其阴阳激活属性：`tian: Dual`（输入/上下文的显隐）、`di: Dual`（状态根基的动静）、`ren: Dual`（行为主体的有无）。
- 层间消息 `LayerMessage` 以 `Dual` 字段在层间传递；合并上下游用 `Polarity.compose(a, b, ratio)`，冲突调和用 `Polarity.reconcile(a, b)`，主导相判定用 `Polarity.classify(d)`。
- 层间门控（是否放行到下一层）用 `YinYangGate.balance_gate(d, threshold)`（阴阳归一后 sigmoid 阈值）。
- 导入：`from liangyi.dual import Dual, YIN, YANG`；`from liangyi.polarity import Polarity`；`from liangyi.activation import YinYangGate, GatePair`。

**I/O 规范**
- 输入：`Tensor`/`List[Float64]` 原始上下文（天）、派生状态张量（地）、行为向量（人）。
- 输出：`SanCai { tian: Dual, di: Dual, ren: Dual, payload: Tensor }`（结构化）；三层 `Dual` 直接映射 `jiugong` 的 3 行（`r=0 天 / r=1 地 / r=2 人`，见 §4.9 维度语义）。
- 确定性：纯函数派生，无随机。

**错误处理**
- `raises`：层数≠3、各层 `Dual` 含 `NaN`（`clamp` 校验失败）、层间消息字段缺失 → 抛 `Error`（带描述）。
- 降级：缺失层 → 以中性 `Dual(0)` 填充并记 trace，不静默丢弃。

#### 4.3.1 接口骨架（函数签名 · 参数类型 · 返回值）【已落地 ✅】

> **评估结论（对 §4.3 的需求满足度）**：§4.3.0 已给出**完整调用契约**——`SanCai{Dual×3, Tensor}` 数据模型、`LayerMessage` 层间消息、`liangyi` 调用契约（compose/reconcile/classify/balance_gate）、统一 I/O 规范与错误处理框架。其粒度已达可直接 TDD 的水平；本小节补齐**显式函数签名**以锁定 RED 目标，并修正一处关键导入根约定，使下游可无歧义复用。

**导入根约定（关键修正，适用于全部算子层）**：`core/` 下**没有** `__init__.mojo`，故 `from core.tensor...` / `from core.math...` **无法解析**。统一改为：以 `-I core` 激活 core 子包，按 `from tensor.tensor` / `from math.ops` / `from number.scalar` / `from simd.vector`（**无 `core.` 前缀**）导入；项目包（liangyi / sancai / …）以 `-I .` 按 `from liangyi` / `from sancai` 导入。运行测试：`.venv/bin/mojo run -I . -I core sancai/tests/test_sancai.mojo`。

```mojo
# sancai/layers.mojo
from liangyi.dual import Dual, YIN, YANG
from liangyi.polarity import Polarity
from liangyi.activation import YinYangGate
from tensor.tensor import Tensor
from math.ops import mean_list, abs_f64

comptime TIAN: Int = 0
comptime DI: Int = 1
comptime REN: Int = 2
comptime LAYER_COUNT: Int = 3

struct SanCai:        # 含 Tensor(payload) -> 非 Movable, 一律 mut self 就地构造/改写
    var tian: Dual    # 天: 输入/上下文 显隐 (yang=显 / yin=隐)
    var di: Dual      # 地: 状态/根基 动静 (yang=动 / yin=静)
    var ren: Dual     # 人: 行为主体 有无 (yang=有 / yin=無)
    var payload: Tensor   # [3,3] 张量(每层一行, 映射 jiugong 3 行 r=0/1/2)

    def __init__(out self) raises                        # 中性: 三层 Dual(0) + payload 3x3 零
    def from_layer_vectors(mut self, tian: List[Float64], di: List[Float64], ren: List[Float64]) raises
    def from_tensors(mut self, tian: Tensor, di: Tensor, ren: Tensor) raises
    def compose_layers(mut self, tian: Dual, di: Dual, ren: Dual, payload: Tensor) raises
    def validate(self) raises                            # 任意层 Dual 含 NaN / payload 首维 != 3 -> raises
    def layer(self, idx: Int) raises -> Dual             # idx 0=天 / 1=地 / 2=人
    def dominant_phase(self) -> Int                      # 绝对值最大层的相位, 供 recall 偏置
```

```mojo
# sancai/interface.mojo
from liangyi.dual import Dual, YIN, YANG
from liangyi.polarity import Polarity
from liangyi.activation import YinYangGate, GatePair
from .layers import SanCai, TIAN, DI, REN

struct LayerMessage(Movable):
    var source: Int
    var target: Int
    var content: Dual
    var gate: Float64
    def __init__(out self, source: Int, target: Int, content: Dual, gate: Float64)

struct LayerBus:
    @staticmethod
    def transmit(source: Int, target: Int, from_layer: Dual, to_layer: Dual,
                  ratio: Float64, threshold: Float64) raises -> LayerMessage
    @staticmethod
    def pass_tian_to_di(tian: Dual, di: Dual, ratio: Float64 = 0.5, threshold: Float64 = 0.0) raises -> LayerMessage
    @staticmethod
    def pass_di_to_ren(di: Dual, ren: Dual, ratio: Float64 = 0.5, threshold: Float64 = 0.0) raises -> LayerMessage
    @staticmethod
    def is_passed(msg: LayerMessage) -> Bool             # gate >= 0.5
    @staticmethod
    def harmonize(mut sc: SanCai) raises                 # 地(中) 由 天·人 调和, 同步 payload 中间行
```

**实现要点（Mojo 1.0.0b2 实证约束，已踩坑固化）**
- **`Dual` 参数 = 不可隐式复制的借入**：`def foo(d: Dual)` 中的 `d` 是不可 `^`-转移的只读借入；字段落值**禁止** `self.x = borrowed_d`（既不能隐式复制、也不能 `^` 转移）。统一以 `Dual.from_parts(d.yin_part(), d.yang_part())` 重构（同源不变），或直接移动自有局部（`^`）。`Polarity`/`LayerBus` 内部均遵循此式。
- **`Tensor` 非 Movable**：不可按值返回（返回 `t^` 编译失败）；字段初始化用 `self.payload = Tensor(); self.payload.init([3,3])`；外部 `Tensor` 经 `to_list()/shape()` 以 `List` 载体透传 `from_list`（对齐 `core` 惯例，避免按值传 Tensor）。
- **验收**：`sancai/tests/test_sancai.mojo` **14 用例全绿**（layers 10 + interface 4），零桩函数；覆盖构造/均值派生/空向量与 NaN 与形状越界校验/取层越界/主导相/天→地·地→人传递与门控/调和同步 payload。

### 4.4 `sixiang/` — 四象（四态/四象限）【v0.6 已落地 ✅】

> **实现状态（2026-07-11，零桩函数 TDD 全绿）**：`sixiang/quadrant.mojo` ✅（`Quadrant` 单象限载体 + `QuadrantClassifier` 判别/幅度/典型构造/降级）+ `sixiang/phase.mojo` ✅（`PhaseMachine` 四相流转状态机，调用 `Polarity.classify/invert/compose` 与 `YinYangGate.dual_gate`）。**29 用例全绿**（判别/幅度/构造往返/相位名/降级/四步循环/门控），零桩函数；基准 classify+canonical≈10 ns/op、advance≈67 ns/op。详见 §4.4.1 接口骨架与实现要点。
**职责**：四态（老少阴阳）或时空四象限，用于调度窗口/相位象限的离散化。
```
sixiang/
├── quadrant.mojo          # 四象限类型与索引
├── phase.mojo             # 四相状态机(老少阴阳流转)
├── tests/  benchmarks/
└── README.md
```
**依赖**：`core`、`liangyi`。

#### 4.4.0 Phase 3 规划：对 liangyi 的调用契约 · I/O · 错误处理

**对 liangyi 的依赖与调用契约**
- 四象由两仪派生：每象为带相位标记的 `Dual`。经典映射——老阳=`Dual(+v)`（纯阳）、老阴=`Dual(-v)`（纯阴）、少阳=`Dual` 且 `yang>yin`（阳生）、少阴=`Dual` 且 `yin>yang`（阴生）；相位由 `Polarity.classify` 判别。
- 状态机流转（老少阴阳循环：老阴→少阳→老阳→少阴→老阴）用 `Polarity.invert`/`compose` 在两仪层做相位翻转与插值；流转强度门控用 `YinYangGate.dual_gate`。
- 导入：`from liangyi.dual import Dual, YIN, YANG`；`from liangyi.polarity import Polarity`；`from liangyi.activation import YinYangGate, GatePair`。

**I/O 规范**
- 输入：一个 `Dual`（当前阴阳态）或两条 `Dual`（两虚线组合）。
- 输出：`Quadrant { index: Int(0..3), symbol: Dual, name: String }`；`index` 对应 老阴/少阳/老阳/少阴（或四象限坐标）。
- 确定性：纯函数派生，无随机。

**错误处理**
- `raises`：相位组合非法（非 0/1 线）、`NaN`、状态机非收敛流转 → 抛 `Error`。
- 降级：未知输入 → 映射中性象限（太极）并记 trace，不静默丢弃。

#### 4.4.1 接口骨架（函数签名 · 参数类型 · 返回值）【已落地 ✅】

> **评估结论（对 §4.4 的需求满足度）**：§4.4.0 已给出**完整调用契约**——四象由 `Dual` 派生的经典映射、状态机流转（老少阴阳循环）调用 `Polarity.invert/compose` 与 `YinYangGate.dual_gate`、统一 I/O 与错误处理框架。其粒度已达可直接 TDD 水平；本小节补齐**显式函数签名**以锁定 RED 目标（与 §4.3.1 同构）。

```mojo
# sixiang/quadrant.mojo
from liangyi.dual import Dual, YIN, YANG
from liangyi.polarity import Polarity

comptime OLD_YIN: Int = 0      # 老阴: 纯阴 (value<0, yang=0)
comptime YOUNG_YANG: Int = 1   # 少阳: 阳生 (value>0, yin>0)
comptime OLD_YANG: Int = 2     # 老阳: 纯阳 (value>0, yin=0)
comptime YOUNG_YIN: Int = 3    # 少阴: 阴生 (value<0, yang>0)
comptime QUADRANT_COUNT: Int = 4

def phase_name(index: Int) -> String          # 自由函数: 避免 String 进 struct 字段(Mojo 1.0.0b2 非 Movable)

struct Quadrant(Movable):                      # 单象限载体(不含 String 字段, 故可 Movable)
    var index: Int
    var symbol: Dual
    def __init__(out self, index: Int, symbol: Dual)
    def name(self) -> String                   # 由 phase_name(index) 派生, 不落字段

struct QuadrantClassifier:
    @staticmethod
    def classify(d: Dual) raises -> Int        # 四象判别(严格, NaN/平衡抛错)
    @staticmethod
    def safe_index(d: Dual) -> Int              # 非严格降级(默认老阴)
    @staticmethod
    def magnitude(d: Dual) -> Float64           # 阴+阳 守恒量(跨象幅度传递)
    @staticmethod
    def canonical(index: Int, magnitude: Float64) -> Dual   # 由 Polarity.invert/compose 构造典型象
    @staticmethod
    def from_dual(d: Dual) -> Quadrant          # 输出契约(降级保留原符号)
```

```mojo
# sixiang/phase.mojo
from liangyi.dual import Dual
from liangyi.polarity import Polarity
from liangyi.activation import YinYangGate, GatePair
from .quadrant import Quadrant, QuadrantClassifier, OLD_YIN, YOUNG_YANG, OLD_YANG, YOUNG_YIN, QUADRANT_COUNT

struct PhaseMachine:
    var current: Dual        # 当前阴阳态(Movable, 可作字段)
    var rounds: Int           # 已流转轮次
    def __init__(out self, start: Dual)
    def current_quadrant(self) -> Quadrant
    def current_index(self) -> Int
    def advance(mut self) raises                    # 流转一步(严格: 非法/NaN/平衡抛错)
    @staticmethod
    def next_dual(d: Dual) raises -> Dual           # 纯函数: 流转一步后的 Dual
```

**实现要点（Mojo 1.0.0b2 实证约束，已踩坑固化）**
- **`Dual` 参数 = 不可隐式复制的借入**：`Quadrant.__init__(symbol: Dual)` / `PhaseMachine.__init__(start: Dual)` 中字段落值**禁止** `self.x = borrowed_d`，统一以 `Dual.from_parts(d.yin_part(), d.yang_part())` 重构（同源不变），或直接移动自有局部（`^`）。
- **`String` 进 struct 字段 → 非 Movable**：故 `Quadrant` 不存 `name` 字段，改由 `name()` 实例方法 / `phase_name()` 自由函数按需派生 `String`（局部构造可返回）。这与 §4.4.0 输出契约 `Quadrant{index, symbol, name}` 等价（name 为派生而非存储）。
- **四象判定**：`Polarity.classify(d)`（-1/0/1 粗分阴阳）打底，再据 `yin_part()/yang_part()` 细化老/少；`canonical` 形状用 `Polarity.invert`（翻转） + `Polarity.compose`（插值）在两仪层构造，满足 §4.4.0 调用契约；流转强度以 `YinYangGate.dual_gate(d).yang` 门控（能量守恒：幅度守恒，门控只调流强）。
- **收敛性语义（重要）**：`advance` 的 `strength = m * (0.4 + 0.6 * gate.yang)` 中 `gate.yang < 1`（非纯阳时），故幅度逐步耗散；长程流转会收敛到平衡态（阴==阳），此时 `classify` 按 §4.4.0「非收敛流转抛错」约定**预期抛 `Error`**。这是设计内行为（非 bug），有限步循环（如 老阴→少阳→老阳→少阴→老阴 四步）与有限次 `advance` 均正常。
- **验收**：`sixiang/tests/test_sixiang.mojo` **29 用例全绿**（判别/幅度/构造往返/相位名/降级/四步循环/门控），零桩函数；覆盖 `NaN` 与平衡态严格抛错、`from_dual` 降级不抛。

### 4.5 `wuxing/` — 五行（调度策略核心）【v0.9 已落地 ✅】

> **实现状态（2026-07-11，零桩函数 TDD 全绿）**：`wuxing/elements.mojo` ✅（五行元素常量 + id↔名 + 符号映射 + `Element` 载体，能量以 `liangyi.Dual` 表阴阳偏置）+ `wuxing/sheng_ke.mojo` ✅（相生/相克关系表 + 5 类关系码 + `sheng_ke_gain` + 一轮 `propagate` 生克传播）+ `wuxing/scheduler_core.mojo` ✅（`ScheduleDecision` 固定标量槽载体 + `schedule` 由能量派生调度 + `schedule_from_phase` 四象种子调度）+ `wuxing/balance.mojo` ✅（总量/均值/方差/均衡判定/归一/`rebalance` 抑亢补弱）。**32 用例全绿（81 断言）**，零桩函数；基准 sheng_ke≈5 ns/op、schedule≈175 ns/op、propagate/rebalance≈350 ns/op（含 List 分配）。详见 §4.5.0 调用契约与 §4.5.1 接口骨架。
**职责**：**用五行生克直接定义调度策略**——木火土金水的生成/制约关系 = 任务流转与资源占用的转移规则。这是"玄学重构调度"的核心体现。
```
wuxing/
├── elements.mojo          # 五行元素类型 + 权重(迁自 src/wu_xing.mojo 权重逻辑, 升级为 Dual 阴阳偏置能量)
├── sheng_ke.mojo          # 生克转移规则 → 调度转移表(数据驱动, 非硬编码)
├── scheduler_core.mojo    # 由生克派生的真实派发策略(替代 MVP 硬编码 set_weight)
├── balance.mojo           # 五行均衡/负载再平衡(抑亢补弱)
├── tests/  benchmarks/
└── README.md
```
**依赖**：`core`（`math.ops.clamp`）、`liangyi`（Dual 能量）、`sixiang`（四象相位种子）。**运维**：生克表可配置化（接 `config`），策略变更可 A/B。

#### 4.5.0 Phase 4 规划：对 liangyi/sixiang 的调用契约 · I/O · 错误处理

**对 liangyi/sixiang 的依赖与调用契约**
- 元素能量由两仪派生：每元素能量为一个 `liangyi.Dual`（阳分量=生发力、阴分量=收敛力）；`Element` 只存 `id: Int` + `energy: Dual`（均 Movable），name 按需由 `element_name(id)` 派生（String 字段会破坏 Movable）。
- 相生（正反馈资生）：木→火→土→金→水→木；相克（负反馈约束）：木克土、火克金、土克水、金克木、水克火。生克制化 = 正反馈(生) + 负反馈(克) 的自调节网络。
- 四象→五行种子（四象＋中土＝五行）：老阴(0)→水、少阳(1)→木、老阳(2)→火、少阴(3)→金，越界→土(中枢)；由 `schedule_from_phase(quadrant_index, intensity)` 消费 `sixiang` 相位。
- 导入：`from liangyi.dual import Dual, YIN, YANG`；`from math.ops import clamp`。

**I/O 规范**
- 输入：五元素能量向量 `List[Float64]`（长度须为 5，非负）；或符号/令牌（"木"/"wood"/"春"/"青"…）；或四象相位索引 + 强度。
- 输出：`ScheduleDecision { dominant: Int, w0..w4: Float64(归一权重 sum=1), confidence: Float64(主导份额 0..1), c0..c4: Int(相生决策链), c_len: Int }`；`propagate`/`normalize`/`rebalance` 返回新的 5 元素 `List[Float64]`。
- 确定性：纯函数派生，无随机。

**错误处理**
- `raises`：`schedule`/`propagate`/`rebalance` 要求恰好 5 元素能量；`schedule` 拒绝负能量与零总量；`normalize` 拒绝零总量；`element_by_symbol` 无映射时抛 `Error`。
- 降级：`element_by_symbol_safe` 对未知符号映射中性元素（`NEUTRAL_ELEMENT`=土，居中承化），**不静默丢弃**。

#### 4.5.1 接口骨架（函数签名 · 参数类型 · 返回值）【已落地 ✅】

> **评估结论（对 §4.5 的需求满足度）**：§4.5.0 给出完整调用契约——元素能量由 `Dual` 派生、生克网络双反馈、四象→五行种子映射、统一 I/O 与错误处理。本小节补齐显式函数签名以锁定 RED 目标（与 §4.4.1 同构）。

```mojo
# wuxing/elements.mojo
from liangyi.dual import Dual, YIN, YANG

comptime WOOD: Int = 0
comptime FIRE: Int = 1
comptime EARTH: Int = 2
comptime METAL: Int = 3
comptime WATER: Int = 4
comptime ELEMENT_COUNT: Int = 5
comptime NEUTRAL_ELEMENT: Int = EARTH   # 降级中性元素: 土居中央承化

def element_name(id: Int) -> String              # id -> 中文单字名(木火土金水)
def element_glyph(id: Int) -> String             # element_name 别名
def element_by_symbol(sym: String) raises -> Int # 符号/令牌 -> id(含中文/拼音/季节别名, 无映射抛错)
def element_by_symbol_safe(sym: String) -> Int   # 未知降级 NEUTRAL_ELEMENT

struct Element(Movable):                          # 元素载体(Int + Dual 皆 Movable)
    var id: Int
    var energy: Dual                              # 阳=生发力 / 阴=收敛力
    def __init__(out self, id: Int, energy: Dual) # 字段落值以 Dual.from_parts 重构
    def name(self) -> String
    def strength(self) -> Float64                  # 阴+阳 守恒量
    def bias(self) -> Int                          # 阴阳偏向(YIN/YANG)
    def is_valid(self) -> Bool
```

```mojo
# wuxing/sheng_ke.mojo
from math.ops import clamp
from .elements import WOOD, FIRE, EARTH, METAL, WATER, ELEMENT_COUNT

comptime REL_SAME: Int = 0            # a == b
comptime REL_GENERATED_BY: Int = 1    # b 生 a (b 是 a 的母)
comptime REL_GENERATES: Int = 2       # a 生 b (b 是 a 的子)
comptime REL_RESTRAINED_BY: Int = 3   # b 克 a (b 是 a 的克者)
comptime REL_RESTRAINS: Int = 4       # a 克 b (b 是 a 所克)

def sheng_next(id: Int) -> Int        # 我生者(子): 相生下一位
def sheng_prev(id: Int) -> Int        # 生我者(母): 相生上一位
def ke_target(id: Int) -> Int         # 我克者: 相克目标
def ke_source(id: Int) -> Int         # 克我者: 相克逆
def relation(a: Int, b: Int) -> Int   # a 相对 b 的关系码(五元环完整划分)
def sheng_ke_gain(a: Int, b: Int, gen_rate: Float64, ke_rate: Float64) -> Float64  # b 对 a 净贡献
def propagate(energies: List[Float64], gen_rate: Float64, ke_rate: Float64) raises -> List[Float64]
    # new[a] = clamp(old[a] + gen_rate*old[母] - ke_rate*old[克我者], 0, +inf); 须 5 长度
```

```mojo
# wuxing/scheduler_core.mojo
from .elements import WOOD, FIRE, EARTH, METAL, WATER, ELEMENT_COUNT, NEUTRAL_ELEMENT
from .sheng_ke import sheng_next

struct ScheduleDecision(Movable):     # 固定标量槽(避免 List 字段破坏 Movable)→ 可按值返回
    var dominant: Int
    var w0: Float64; var w1: Float64; var w2: Float64; var w3: Float64; var w4: Float64  # 归一权重
    var confidence: Float64            # 主导优势度(0..1)
    var c0: Int; var c1: Int; var c2: Int; var c3: Int; var c4: Int; var c_len: Int      # 相生决策链
    def weight(self, idx: Int) -> Float64
    def set_weight(mut self, idx: Int, v: Float64)
    def chain_at(self, i: Int) -> Int
    def append_chain(mut self, e: Int)
    def weights_list(self) -> List[Float64]
    def chain_list(self) -> List[Int]

def dominant_element(energies: List[Float64]) -> Int        # argmax(平局取小 id)
def schedule(energies: List[Float64]) raises -> ScheduleDecision
    # 权重=归一能量; confidence=主导份额; 决策链=相生序从主导起 3 位
def schedule_from_phase(quadrant_index: Int, intensity: Float64) raises -> ScheduleDecision
    # 四象→五行种子: 种子得满 intensity, 其子得半, 余得基线 0.1*intensity
```

```mojo
# wuxing/balance.mojo
from .elements import ELEMENT_COUNT

def total_energy(energies: List[Float64]) -> Float64
def mean_energy(energies: List[Float64]) -> Float64
def variance(energies: List[Float64]) -> Float64            # 越小越均衡
def is_balanced(energies: List[Float64], tol: Float64) -> Bool
def normalize(energies: List[Float64]) raises -> List[Float64]   # sum=1(全零抛错)
def rebalance(energies: List[Float64]) raises -> List[Float64]   # 抑亢补弱: 降方差保总量
```

**实现要点（Mojo 1.0.0b2 实证约束，已踩坑固化）**
- **`List` 字段 → 非 Movable**：`ScheduleDecision` 需按值返回且 Movable，故用**固定标量槽**（`w0..w4` / `c0..c4` + `c_len`）替代 `List[Float64]`/`List[Int]` 字段（迁自 `src/wu_xing.mojo` `BalanceDecision` 的做法）；`weights_list()`/`chain_list()` 按需导出 List。
- **`Dual` 参数 = 不可隐式复制借入**：`Element.__init__(energy: Dual)` 字段落值以 `Dual.from_parts(energy.yin_part(), energy.yang_part())` 重构（同源不变），禁止 `self.energy = borrowed_d`。
- **`String` 进 struct 字段 → 非 Movable**：`Element` 不存 name 字段，由 `name()` / `element_name()` 按需派生。
- **生克网络完整性**：`relation(a,b)` 在五元环上把 b 相对 a 划分为恰好 5 类（自身/母/子/克我/我克），构成完整划分（测试验证 5 元素分区总和）。
- **测试计数器**：本 build `global` 计数器不可靠，改用 `struct Counter(Movable){ passed, failed; def check(mut self, cond, name) }` 以 `mut` 传入各 `test_*` 函数；调用 `raises` 函数的测试函数须标 `raises`。
- **验收**：`wuxing/tests/test_wuxing.mojo` **32 组测试全绿（81 断言）**，零桩函数；覆盖元素常量/符号映射(严格+降级)/生克关系分区/传播/主导判别/调度(基本+相生链+零/长度抛错)/四象种子调度/均衡(方差降低+总量守恒+归一零抛错)。

### 4.6 `liuhe/` — 六合（供给/资源编排）【v1.0 已落地 ✅】
**职责**：六向空间整全 + 地支和合 → 对调度脑**供给**资源/上下文（六合→七星供给，见 ADR-0004）。
```
liuhe/
├── directions.mojo        # 六向空间维度(东0/西1/南2/北3/上4/下5) + 五行配六合
├── supply.mojo            # 六向供给向量(向 qixing/scheduler 提供资源向量)
├── harmony.mojo           # 地支和合(合化) + 多源归并
├── tests/  benchmarks/
└── README.md
```
**依赖**：`core`、`wuxing`。
> **实现状态（2026-07-12，零桩函数 TDD 全绿）**：`liuhe/directions.mojo` ✅（六向常量 + `direction_name`/`opposite`/`axis_of` + `element_direction` 五行配六合）+ `liuhe/supply.mojo` ✅（`SupplyVector` 固定六槽载体 + `build_supply` 由五行能量＋上下文派生六向容量、方差倒数派生 `harmony`）+ `liuhe/harmony.mojo` ✅（`he_harmony` 十二地支六合合化五行、`harmony_index` 亲和度、`merge_supplies` 多源逐向归并）。**57 用例全绿**，零桩函数；基准 build_supply≈178 ns/op、merge≈0 ns/op。详见 §4.6.0 调用契约与 §4.6.1 接口骨架。

#### 4.6.0 Phase 4 规划：对 wuxing 的调用契约 · I/O · 错误处理
- **对 wuxing 的依赖**：`build_supply` 消费 `wuxing.balance.total_energy`/`variance` 派生六向容量与和合度；能量合法性由 `wuxing.schedule` 保证（调用方先派生策略）。
- **I/O 规范**：输入 = 五行能量 `List[Float64]`（长度 5、非负）＋ 上下文 `focus:Float64, max_depth:Int, chain_depth:Int, ground:Int`；输出 = `SupplyVector{s0..s5:Float64(六向容量), harmony:Float64(0..1)}`。`he_harmony(a,b)` 输入十二地支索引 0..11、输出合化五行 id。
- **错误处理**：`build_supply` 对 `max_depth<=0`/`chain_depth<0`/`ground<0` `raises`；`SupplyVector.get/set` 方向越界 `raises`；`he_harmony` 非六合对显式降级 `NEUTRAL_ELEMENT`（土），不静默丢弃。

#### 4.6.1 接口骨架（函数签名 · 参数类型 · 返回值）【已落地 ✅】
```mojo
# liuhe/directions.mojo
comptime EAST=0; WEST=1; SOUTH=2; NORTH=3; UP=4; DOWN=5; DIRECTION_COUNT=6
def direction_name(id: Int) -> String
def opposite(id: Int) -> Int
def axis_of(id: Int) -> Int            # 0横(东西)/1纵(南北)/2竖(上下)/越界-1
def element_direction(id: Int) -> Int  # 木东/火南/金西/水北/土上; 越界-1

# liuhe/supply.mojo
struct SupplyVector(Movable):          # 固定六槽 + harmony(保 Movable 可按值返回)
    var s0..s5: Float64; var harmony: Float64
    def get(self, dir: Int) raises -> Float64
    def set(mut self, dir: Int, v: Float64) raises
    def as_list(self) -> List[Float64]
    def is_valid(self) -> Bool
def build_supply(energies: List[Float64], focus: Float64, max_depth: Int,
                 chain_depth: Int, ground: Int) raises -> SupplyVector

# liuhe/harmony.mojo
comptime BRANCH_COUNT: Int = 12
def he_harmony(a: Int, b: Int) -> Int          # 六合合化五行(非对降级 NEUTRAL_ELEMENT)
def harmony_index(a: Int, b: Int) -> Float64   # 亲和度 0/1
def merge_supplies(a: SupplyVector, b: SupplyVector) -> SupplyVector
```

### 4.7 `qixing/` — 七星（决策链排序）【v1.0 已落地 ✅】
**职责**：北斗定序 → 用选择排序对决策链**按优先级排序**（优先级源自 wuxing 权重、经 liuhe 容量折扣）。
```
qixing/
├── priority.mojo          # 优先级赋值(权重 × 容量折扣 + 抽象度)
├── ordering.mojo          # 选择排序(迁自 src/qixing.mojo 评分模型)
├── sequence.mojo          # 决策链序列产出
├── tests/  benchmarks/
└── README.md
```
**依赖**：`core`、`wuxing`、`liuhe`。
> **实现状态（2026-07-12，零桩函数 TDD 全绿）**：`qixing/priority.mojo` ✅（`abstract_level` 抽象度 土5/火金3/水木2 + `capacity_factor` 五行配六合方向容量÷配额 + `priority_of` 权重×折扣 + `priority_list`）+ `qixing/ordering.mojo` ✅（`order_chain` 取相生链候选→选择排序降序＋抽象度锚定、空链 `raises`）+ `qixing/sequence.mojo` ✅（`DecisionSequence` 固定八槽载体 + `build_sequence`）。**18 用例全绿**；基准 order_chain≈476 / priority_of≈181 / build_sequence≈507 ns/op。详见 §4.7.0 调用契约与 §4.7.1 接口骨架。

#### 4.7.0 Phase 4 规划：对 wuxing/liuhe 的调用契约 · I/O · 错误处理
- **消费上游**：输入 `wuxing.ScheduleDecision`（归一权重 `w0..w4`=优先级源、`c0..c4`=相生候选链）+ `liuhe.SupplyVector`（六向容量=资源约束）。
- **数据流转**：`priority_of(step) = decision.weight(step) × capacity_factor(supply, element_direction(step))`；`capacity_factor = clamp(方向容量 / 最大深度配额, 0, 1)`；`order_chain` 对候选步骤降序定序，同优先级以 `abstract_level` 锚定。
- **错误处理**：`order_chain` 空候选链 `raises`；越界元素 `capacity_factor=0`（显式降级为最低优先级，不静默丢弃）；`SupplyVector.get` 方向越界透传 `raises`。

#### 4.7.1 接口骨架（函数签名 · 参数类型 · 返回值）【已落地 ✅】
```mojo
# qixing/priority.mojo
def abstract_level(step: Int) -> Int
def capacity_factor(supply: SupplyVector, step: Int) raises -> Float64
def priority_of(step: Int, decision: ScheduleDecision, supply: SupplyVector) raises -> Float64
def priority_list(decision: ScheduleDecision, supply: SupplyVector) raises -> List[Float64]

# qixing/ordering.mojo
def order_chain(decision: ScheduleDecision, supply: SupplyVector) raises -> List[Int]

# qixing/sequence.mojo
struct DecisionSequence(Movable):      # 固定八槽(链长<=5 留余量)
    var s0..s7: Int; var s_len: Int
    def append(mut self, step: Int)
    def step_at(self, i: Int) -> Int
    def as_list(self) -> List[Int]
def build_sequence(decision: ScheduleDecision, supply: SupplyVector) raises -> DecisionSequence
```

### 4.8 `bagua/` — 八卦（推理算子集）【v0.8 已落地 ✅】

> **实现状态 2026-07-11（TDD 零桩函数，17 组测试全绿）**：`trigrams.mojo`(8 卦定义/id↔code/爻线/符号映射/sancai 派生) + `operators.mojo`(`TrigramOperatorResult`/`apply`/`apply_by_id`/`apply_chain`) + `combine.mojo`(`Hexagram`/64 卦) 三文件全绿；`benchmarks` 实测 apply≈23ns/op、trigram_lines≈129ns/op、combine≈264ns/op。算子严格以 `YinYangGate.dual_gate` 作激活门、`Polarity`(compose/reconcile/invert) 作变换与组合；sancai 三层经 `validate()` 校验后取 初=人/二=地/三=天 三相位派生卦象；未知符号降级中性卦(`NEUTRAL_ID`=坤)不静默丢弃。

**职责**：三爻成象的 8 个推理算子（乾·创造 / 坤·承载 / 震·雷动 / 巽·风入 / 坎·冒险 / 离·明辨 / 艮·山止 / 兑·泽悦），是认知的"指令集"。
```
bagua/
├── trigrams.mojo          # 8 卦定义(迁自 src/trigram.mojo)
├── operators.mojo         # 算子实现(迁自 src/executor.mojo 的 8 算子, 暂占位模板)
├── combine.mojo           # 重卦组合规则(64 卦衍生)
├── tests/  benchmarks/
└── README.md
```
**依赖**：`core`、`liangyi`、`sancai`。**运维**：算子语义变更需可解释性追踪（接 observability）。

#### 4.8.0 Phase 3 规划：对 liangyi 的调用契约 · I/O · 错误处理

**对 liangyi 的依赖与调用契约（另依赖 `sancai`，见 §4.8 依赖行）**
- 每卦=3 条 `Dual` 爻线（初/二/三爻，阴=`YIN`/阳=`YANG`），8 卦=3 位 yin/yang 码（0..7）的全组合。
- 算子激活门控用 `YinYangGate.dual_gate`（返回 `GatePair` 阴阳双门，供算子选择抑制/激发，对应原规划 `yin_gate/yang_gate/balance_gate` 的组合形态）；卦线组合 / 重卦用 `Polarity.compose/reconcile`。
- `dual_gate` 返回 `GatePair`（阴阳双门，供算子选择抑制/激发）。
- 导入：`from liangyi.dual import Dual, YIN, YANG`；`from liangyi.polarity import Polarity`；`from liangyi.activation import YinYangGate, GatePair`。

**I/O 规范**
- 输入：符号/令牌 → 映射为 3 位 yin/yang 卦码（0..7）；或直接从 `sancai` 三层 `Dual` 派生卦象。
- 输出：`TrigramOperatorResult { trigram: Int(0..7), activation: GatePair, transformed: Tensor/Dual }`（结构化）。
- 确定性：纯函数派生，无随机。

**错误处理**
- `raises`：卦码越界（∉[0,7]）、爻线非法、符号无映射 → 抛 `Error`。
- 降级：未知符号 → 映射中性卦（无极/太极，码=0 或保留位）并记 trace，不静默丢弃。

#### 4.8.1 接口骨架（函数签名 · 参数类型 · 返回值）【已落地 ✅】

> **评估结论（对 §4.8 的需求满足度）**：§4.8.0 已给出**完整调用契约**——8 卦由 3 条 `Dual` 爻线（初/二/三=地/人/天）的全组合定义、算子以 `YinYangGate.dual_gate` 作激活门、以 `Polarity`(compose/reconcile/invert) 作变换与组合、统一 I/O 与错误处理框架。其粒度已达可直接 TDD 水平；本小节补齐**显式函数签名**以锁定 RED 目标（与 §4.3.1 / §4.4.1 同构）。

```mojo
# bagua/trigrams.mojo
from liangyi.dual import Dual, YIN, YANG
from liangyi.polarity import Polarity
from math.ops import abs_f64
from sancai.layers import SanCai

comptime QIAN, KUN, ZHEN, XUN, KAN, LI, GEN, DUI: Int   # 卦 id 0..7
comptime TRIGRAM_COUNT: Int = 8
comptime NEUTRAL_ID: Int = KUN                           # 降级中性卦(全阴·承载)

def trigram_name(id: Int) -> String
def trigram_code(id: Int) -> Int                         # 3 位 yao 码(初爻最低位, yang=1)
def trigram_id_from_code(code: Int) -> Int

struct Trigram(Movable):                                 # 仅存 id(Int) 保 Movable
    var id: Int
    def __init__(out self, id: Int)
    def code(self) -> Int
    def name(self) -> String
    def lines(self) -> List[Dual]                       # 初/二/三爻(地/人/天)
    def essence(self) -> Dual                            # 三爻两两 reconcile 代表

def trigram_by_id(id: Int) raises -> Trigram
def trigram_by_code(code: Int) raises -> Trigram
def trigram_from_lines(lines: List[Dual]) raises -> Trigram
def trigram_from_symbol(sym: String) raises -> Trigram
def trigram_from_symbol_safe(sym: String) -> Trigram     # 未知符号降级 NEUTRAL_ID
def trigram_from_sancai(sc: SanCai) raises -> Trigram    # 初=人/二=地/三=天, 含 NaN 校验

# bagua/operators.mojo
from liangyi.activation import YinYangGate, GatePair
from .trigrams import Trigram, trigram_by_id, ...

struct TrigramOperatorResult(Movable):
    var trigram: Int          # 卦 id (0..7)
    var code: Int            # 3 位 yao 码
    var activation: GatePair # 阴阳双门(抑制量, 激发量)
    var transformed: Dual    # 算子变换结果
    def __init__(out self, trigram: Int, code: Int, activation: GatePair, transformed: Dual)

def _transform(id: Int, x: Dual) -> Dual                         # 按卦性确定性变换
def apply(trig: Trigram, x: Dual) -> TrigramOperatorResult        # 激活门 + 变换
def apply_by_id(id: Int, x: Dual) raises -> TrigramOperatorResult
def apply_chain(chain: List[Trigram], x: Dual) -> List[TrigramOperatorResult]

# bagua/combine.mojo
from liangyi.polarity import Polarity
from .trigrams import Trigram, trigram_name

struct Hexagram(Movable):
    var lower: Int           # 下卦 id
    var upper: Int           # 上卦 id
    var code: Int            # lower.code + upper.code * 8 (0..63)
    var essence: Dual        # 两卦 essence 均权(Polarity.compose 0.5)合成
    def __init__(out self, lower: Int, upper: Int, code: Int, essence: Dual)
    def name(self) -> String                                 # 上下卦名拼接, 如 "乾坤"

def combine(lower: Trigram, upper: Trigram) -> Hexagram
```

> **Mojo 1.0.0b2 落地约束（与 liangyi/sancai/sixiang 同）**：
> - **`Trigram`/`Hexagram` 只存 `Int`/`Dual` 不可隐式复制字段、`String` 字段会破坏 Movable** → `name()`/`lines()`/`essence()`/`symbol` 全部按需派生（同 sancai `LayerMessage` 手法）。
> - **`Dual` 参数 = 只读借入**：`_transform(id, x: Dual)` 内 `x` 不可 `^` 转移；返回须以 `Dual.from_parts(x.yin_part(), x.yang_part())` 或构造新值（如 `x.scale(2.0)`）重构，禁止 `return x^`。
> - **`GatePair` / `Dual` 字段落值**：`TrigramOperatorResult.__init__` 内 `self.activation = GatePair(a.yin, a.yang)`、`self.transformed = Dual.from_parts(t.yin_part(), t.yang_part())`（同源不变重构），不能复制/转移借入。
> - **`SanCai` 按值传入（消费移动语义）**：`trigram_from_sancai(sc: SanCai) raises` 调 `sc.validate()` 校验 NaN/形状，再读 `sc.ren/di/tian` 相位派生爻线（`sc` 为 `Movable` 可移动消费，非 `Tensor` 字段按值透传）。
> - **`List[Dual].append` 移动语义**：`trigram_from_sancai` 内 `lines.append(ren_line^)` 须显式 `^` 转移（不可复制）。
> - **验收**：`bagua/tests/test_bagua.mojo` **17 组测试全绿**，零桩函数；覆盖 8 卦 by_id/by_code、爻线往返、符号映射与降级、sancai 派生、8 算子 transform/activation、combine 64 卦、essence、chain。

### 4.9 `jiugong/` — 九宫（工作记忆 3×3 张量盘）【v0.4 已落地 ✅】

> **Phase 2 设计已细化至可落地接口骨架**：由 `src/workspace.mojo` 的 `List[Int]` 占位升级为基于 `core/tensor` 的真实张量。实现阶段严格 TDD，零桩函数。

**职责**：洛书三三方阵，作为单轮**工作记忆张量盘**；承载 3×3 中间态 + 9 维注意力权重；注意力由占位注释升级为真张量运算。九宫与太极分层（见 §4.1）：九宫 = 单轮草稿纸，不参与跨轮。

**张量规格（维度语义 · 元素类型）**

- **形状**：`shape = [3, 3]`（行主序，`flat = r*3 + c`），对应洛书方阵。
- **维度语义**：
  - 行 `r∈{0,1,2}` = **宫位类别（sancai 映射）**：`0=天(输入/上下文)`、`1=地(状态/根基)`、`2=人(行为/主体)`。
  - 列 `c∈{0,1,2}` = **时态/信道窗口**：`0=过去`、`1=现在`、`2=未来`。
  - 例 `grid[1][2]` = 地(状态) 在 未来 窗口的激活值。
- **元素类型**：`Scalar = Float64`，语义为「该宫位-窗口的当前激活/能量值」。
- **注意力张量**：`attention: Tensor(shape=[9])`，9 维权重（softmax 归一），表示各宫位关注度。

**接口骨架（函数签名 · 参数类型 · 返回值）**

```mojo
# jiugong/board.mojo  — 迁自 src/workspace.mojo, 升级为真张量
from core.tensor.tensor import Tensor
from core.tensor.view import transpose_2d, slice_rows, slice_cols, broadcast_add
from core.math.activate import softmax_list
from core.math.ops import sigmoid

struct WorkspaceBoard:
    var grid: Tensor          # 3x3 工作记忆盘 (shape [3,3])
    var attention: Tensor     # [9] 注意力权重 (shape [9])
    var focus_cell: Int       # 当前聚焦宫位 (0..8)
    var round: Int

    def __init__(out self) raises                       # 全零 grid + 均匀 attention
    def init_from(mut self, t: Tensor) raises           # 从已有 3x3 张量载入
    # —— 读写 ——
    def at(self, r: Int, c: Int) raises -> Float64
    def set(mut self, r: Int, c: Int, v: Float64) raises
    def at_flat(self, i: Int) -> Float64
    def set_flat(mut self, i: Int, v: Float64)
    def row(self, r: Int) raises -> List[Float64]
    def col(self, c: Int) raises -> List[Float64]
    def to_list(self) -> List[Float64]
    # —— 变换（张量操作）——
    def transpose(self) -> Tensor                       # view.transpose_2d
    def slice_rows(self, r0: Int, r1: Int) raises -> Tensor
    def slice_cols(self, c0: Int, c1: Int) raises -> Tensor
    def add(mut self, other: Tensor) raises             # 形状校验后逐元素加
    def broadcast_add(mut self, vec: Tensor) raises     # 行/列广播加 (vec shape [3] 或 [1,3])
    # —— 注意力 ——
    def update_attention(mut self, focus: Int) raises   # 9/(1+d^2) 高斯式, d=棋盘距
    def attention_weights(self) -> List[Float64]        # softmax(attention)
    def weighted_state(self) -> Tensor                  # grid ⊙ reshape(attention,[3,3])
    def focus_strength(self) -> Float64
    # —— 维护 ——
    def clear_cell(mut self, r: Int, c: Int) raises
    def available_cells(self) -> Int
```

**依赖与接口边界（§4.9）**

- 依赖：`core`（tensor/view/math/number 提供张量与数值基底）。**不依赖** `taiji`（九宫为单轮态，太极跨轮；边界清晰，避免循环依赖）。
- 边界：对外暴露 `WorkspaceBoard`（张量 API）；`weighted_state()` 输出供 `taiji/cycle` 在 `feedback` 前读取单轮态；注意力运算结果可被 `observability/tracing` 溯源。
- 运维：九宫为单轮内存态，无需持久化自身（跨轮记忆由 `taiji` 负责）；注意力一致性纳入元认知验收（§10.3）。

### 4.10 `shifang/` — 十方（执行扇出 + 外部连接器）【v1.2 已落地 ✅】
**职责**：十向周遍 → 把 `pipeline.PipelineResult.plan`（七星定序后的元素链）**周遍扇出到十方**，并经**真实模型/API 连接器**生成可读回复——架构首次"能说话"。
```
shifang/
├── protocol.mojo          # 连接器统一接口/熔断/重试 + ConnectorResponse + call_external 真实接入缝
├── dispatch.mojo          # 十向扇出/路由(DIR_EAST..DIR_DOWN=10, fanout/fanout_safe)
├── executor.mojo          # execute_plan_to_text / render_reply / action_label
├── tests/  benchmarks/
└── README.md
```
**依赖**：`core`、`pipeline`、`scheduler`。**运维**：连接器需熔断/超时/降级（`with_retry` + `cb_open` 熔断 + `fanout_safe` 中性降级）；外部依赖不可阻塞状态根；真实 API 以 `call_external(prompt) raises -> String` 为唯一接入缝（当前返回确定性模板化响应，离线可测）。
> **实现状态（2026-07-12，零桩函数 TDD 全绿）**：`shifang/protocol.mojo` ✅（`Connector` 熔断/重试状态机 + `ConnectorResponse` 非 Movable 以 `mut resp` 传出 + `call_external` 真实接入缝）+ `shifang/dispatch.mojo` ✅（`ShifangOutput` 固定标量槽 + `fanout`/`fanout_safe` 把 plan 周遍扇出十方）+ `shifang/executor.mojo` ✅（`execute_plan_to_text` 渲染十方执行摘要）。**27 用例全绿**。详见 §4.10.0 调用契约与 §4.10.1 接口骨架。

#### 4.10.0 调用契约 · I/O · 错误处理
- **扇出策略**：`fanout(result, mut connector) raises -> ShifangOutput`，把 `result.plan` 的每个元素按 `(element*2+i)%DIR_COUNT=10` 映射到十方方向，逐方向经 `connector.dispatch` 取回复；连接器 `raises` 透传 + 熔断（`cb_open`）+ 重试（`with_retry`）；`fanout_safe` 异常→`ok=0/degraded=1` 中性降级不崩溃。
- **I/O 规范**：输入 = `PipelineResult`（phase/intensity/plan/confidence/policy_id/ok）；输出 = `ShifangOutput{ action0..action9:Int, action_len, ok, degraded, latency_ms, text }`；`ConnectorResponse{ text:String, ok, degraded, latency_ms, attempt }`（含 String → 非 Movable，以 `mut resp` 传参，不可按值返回/传参到需 Movable 处）。
- **故障隔离**：连接器失败不影响 `taiji` 状态根；降级事件记入 trace（接 `observability`）。

#### 4.10.1 接口骨架（函数签名 · 参数类型 · 返回值）【已落地 ✅】
```mojo
# shifang/protocol.mojo
comptime CONNECTOR_LOCAL=0; CONNECTOR_LLM=1
comptime DIR_EAST=0..DIR_DOWN=9; DIR_COUNT=10
def direction_name(id) -> String
struct ConnectorResponse:                 # 含 String → 非 Movable, 以 mut resp 传出
    var text: String; var ok: Int; var degraded: Int; var latency_ms: Int; var attempt: Int
    def __init__(out self)
struct Connector(Movable):                # 熔断/重试状态机
    var kind: Int; var fail_count: Int; var cb_open: Int; var last_latency: Int; var trip_threshold: Int
    def __init__(out self, kind: Int)
    def dispatch(mut self, prompt, result, timeout_ms, resp) raises
    def with_retry(mut self, prompt, result, timeout_ms, max_retries, resp)
def call_external(prompt) raises -> String        # ★ 真实 API 接入缝

# shifang/dispatch.mojo
struct ShifangOutput(Movable):            # 固定标量槽 a0..a9 + action_len + ok + degraded + latency_ms
    def action_at(self, dir) -> Int
def fanout(result, mut connector) raises -> ShifangOutput
def fanout_safe(result, mut connector) -> ShifangOutput

# shifang/executor.mojo
def execute_plan_to_text(result, input) -> String
def render_reply(result, out) -> String
def action_label(element) -> String
```

#### 4.10.2 真实 LLM 侧车桥接（v1.4 增强）

v1.2 的 `call_external` 仅为确定性模板缝；v1.4 落地**真实 LLM 侧车**，让架构真正"能说话"（需求 ①）。

- **桥接方式（Mojo 1.0.0b2 真实约束 + 端到端验证）**：本构建无原生 HTTP/子进程 API，故以 **Mojo→python3 子进程桥接**实现（`shifang/sidecar.mojo` + `shifang/llm_sidecar.py`）：
  1. Mojo 以 `setenv("LLM_PROMPT", prompt)` 把 prompt 交给侧车（UTF-8 安全，已验证）；
  2. `system("python3 shifang/llm_sidecar.py > /tmp/..._resp.txt 2>/dev/null")` 拉起真实侧车；
  3. Mojo 以 `fopen("r") + fread` 读回响应（`Span[UInt8] → StringSlice(unsafe_from_utf8) → String` 完成 UTF-8 解码）。
- **双模**：`LLMSidecar(SIDECAR_TEMPLATE=0)` 确定性模板（离线可测，默认）；`LLMSidecar(SIDECAR_EXTERNAL=1)` 经 `shifang_llm_call(prompt)` 缝调用真实侧车。`llm_sidecar.py` 检测到 `LLM_API_KEY` 时调用真实 LLM（OpenAI 兼容端点，urllib），否则优雅降级（确定性）。
- **健壮性**：任何环节失败 → 返回确定性降级串（非空，保证上层 `ok=1` 且测试稳定）；不阻塞 `taiji` 状态根。
- **早期方案废弃说明**：原"链接 C shim 覆盖 Mojo C-ABI 符号"方案因 macOS 链接器不支持多定义覆盖而废弃，改为纯 Mojo 桥接（无链接器 hack，`mojo run` 全面可用）。

**验收**：`shifang/tests/test_sidecar.mojo` 22 断言全绿（外部桥接返回非空、非模板，置 `LLM_API_KEY` 即真实 LLM）；`shifang/tests/test_shifang.mojo` 27 断言全绿；基准外部桥接 ≈381 µs/call（子进程启动开销）。

### 4.11 `scheduler/` — 总调度（统一派发器）【v1.0 已落地 ✅】
**职责**：把 `wuxing`(策略) + `liuhe`(供给) + `qixing`(排序) 合成为**唯一派发器** `DispatchPlan`，即"重构后的 AI 底层调度逻辑"总成。
```
scheduler/
├── dispatcher.mojo        # 统一派发: wuxing.schedule → liuhe.build_supply → qixing.build_sequence → DispatchPlan
├── policy.mojo            # 调度策略装配(可插拔)
├── tests/  benchmarks/
└── README.md
```
**依赖**：`wuxing`、`liuhe`、`qixing`。**运维**：调度延迟/吞吐为一级指标；策略可热切换。
> **实现状态（2026-07-12，零桩函数 TDD 全绿）**：`scheduler/policy.mojo` ✅（`SchedulerPolicy` 载体＋`default_policy`）+ `scheduler/dispatcher.mojo` ✅（`DispatchPlan` 固定八槽载体；`dispatch(energies,focus,max_depth,chain_depth,ground) raises` 串联三模块；`dispatch_from_phase` 经四象种子入口；`apply_policy` 装配策略；策略失败回退 `policy_id=-1` 降级）。**16 用例全绿**；基准 dispatch≈487 / dispatch_from_phase≈666 ns/op。详见 §4.11.0 调用契约与 §4.11.1 接口骨架。

#### 4.11.0 Phase 4 规划：跨模块调用契约 · I/O · 错误处理
- **编排策略**：`dispatch` 严格串行合成 `wuxing.ScheduleDecision → liuhe.SupplyVector → qixing.DecisionSequence → scheduler.DispatchPlan`，单一事实源、可回溯。
- **优先级机制**：端到端优先级源自 `wuxing` 归一权重（策略层）→ 经 `liuhe` 容量折扣（资源约束层）→ 由 `qixing` 定序（排序层），固化为 `DispatchPlan.seq` 顺序；`confidence` 沿用主导优势度。
- **I/O 规范**：`dispatch` 输入 = 五行能量 `List[Float64]`(5,非负,正总量) ＋ 上下文 `focus/max_depth/chain_depth/ground`；`dispatch_from_phase` 输入 = `quadrant_index:Int, intensity:Float64` ＋ 上下文；输出 = `DispatchPlan{ s0..s7:Int(有序链), s_len, confidence:Float64, policy_id:Int }`。
- **错误处理**：子模块 `raises` 透传（能量长度≠5/负/零总量、上下文非法、空候选链）；调用方决定重试或静默；**策略装配失败 → `policy_id=-1` 降级而非崩溃**（当前默认策略不会失败，预留可插拔策略）；全程确定性，故障隔离不影响 `taiji` 状态根。

#### 4.11.1 接口骨架（函数签名 · 参数类型 · 返回值）【已落地 ✅】
```mojo
# scheduler/policy.mojo
struct SchedulerPolicy(Movable):
    var gen_rate: Float64; var ke_rate: Float64; var policy_id: Int
def default_policy() -> SchedulerPolicy

# scheduler/dispatcher.mojo
struct DispatchPlan(Movable):         # 固定八槽(链长<=5 留余量)
    var s0..s7: Int; var s_len: Int
    var confidence: Float64; var policy_id: Int
    def append(mut self, step: Int)
    def step_at(self, i: Int) -> Int
    def as_list(self) -> List[Int]
def dispatch(energies: List[Float64], focus: Float64, max_depth: Int,
             chain_depth: Int, ground: Int) raises -> DispatchPlan
def dispatch_from_phase(quadrant: Int, intensity: Float64, focus: Float64,
                        max_depth: Int, chain_depth: Int, ground: Int) raises -> DispatchPlan
def apply_policy(mut plan: DispatchPlan, policy: SchedulerPolicy)
```

### 4.12 `pipeline/` — 流水线（端到端编排）【v1.1 已落地 ✅】
**职责**：将 L0–L5 串为可运行流水线；由 MVP 的线性 `run_cycle` 重构为**阶段图**（可观测、可断点重放）。
**状态（v1.1）**：TDD 100% 落地（零桩函数）。`stages.mojo`（阶段图 DAG + `StageGraph.can_run` 依赖门控/断点重放）+ `orchestrator.mojo`（`run_pipeline` 文本入口 / `run_pipeline_from_energies` 能量入口 / `run_pipeline_chains` 迁自 MVP `run_cycle_chains` 供可视化 / `run_pipeline_safe` 中性降级）+ 测试 78 断言全绿 + 基准 `run_pipeline≈997 / run_pipeline_from_energies≈917 ns/op`。全链路产物固化于 `PipelineResult`（候选链/规划链/confidence/policy_id/失败阶段）。
```
pipeline/
├── orchestrator.mojo      # 阶段编排(run_pipeline / run_pipeline_from_energies / run_pipeline_chains / run_pipeline_safe)
├── stages.mojo            # 阶段定义与依赖图(StageGraph DAG + can_run 门控)
├── tests/  benchmarks/
└── README.md
```
**依赖**：`wuxing`、`liuhe`、`qixing`、`scheduler`。**运维**：`failed_stage`/`confidence`/`policy_id` 供 `observability` 溯源；`PipelineResult.plan` 供 `shifang` 扇出。

#### 4.12.0 调用契约 · I/O · 错误处理
- **入口 I/O**：`run_pipeline(text, focus, max_depth, chain_depth, ground) raises -> PipelineResult`；`run_pipeline_from_energies(energies, focus, max_depth, chain_depth, ground) raises -> PipelineResult`（主导元素派生相位，直接 `wuxing.schedule` 避免 quadrant/element 映射错位）；`run_pipeline_chains(...) raises -> List[List[Int]]` 返回 `[候选链, 规划链]`；`run_pipeline_safe(...) -> PipelineResult`（非 raises，异常→`ok=0`、相位回落水、强度下限 1，不崩溃）。
- **错误策略**：子模块 `raises` 透传（调用方决定重试/静默）；`run_pipeline_safe` 兜底中性降级，**不静默丢弃**；`StageGraph` 依赖门控实现断点重放（前置未完成则后续停摆，记 `failed_stage`）。
- **确定性**：纯函数变换、无随机；故障隔离（pipeline 异常不影响 `taiji` 状态根——回灌由 Phase 5 `runtime`/`shifang` 衔接）。

#### 4.12.1 接口骨架
```mojo
comptime STAGE_PARSE=0; STAGE_SCHEDULE=1; STAGE_SUPPLY=2; STAGE_ORDER=3; STAGE_DISPATCH=4; STAGE_COUNT=5
def stage_name(id) -> String
def stage_depends_on(id) -> Int            # -1=无前置, -2=非法
struct StageGraph(Movable):               # f0..f4 完成标记(固定标量槽)
    def is_done(stage) -> Int
    def mark_done(mut self, stage)
    def can_run(stage) -> Int             # 依赖门控/断点重放
    def all_done() -> Int
    def validate() -> Int                 # 依赖须线性紧邻链
    def run_order() -> List[Int]          # 拓扑序 0..4
struct PipelineResult(Movable):           # 固定标量槽: phase/intensity/candidate(c0..c7)/plan(p0..p7)/confidence/policy_id/ok/failed_stage
    def append_candidate(mut self, e); def candidate_at(self, i) -> Int
    def append_plan(mut self, e);      def plan_at(self, i) -> Int
def run_pipeline(text, focus, max_depth, chain_depth, ground) raises -> PipelineResult
def run_pipeline_from_energies(energies, focus, max_depth, chain_depth, ground) raises -> PipelineResult
def run_pipeline_chains(text, focus, max_depth, chain_depth, ground) raises -> List[List[Int]]
def run_pipeline_safe(text, focus, max_depth, chain_depth, ground) -> PipelineResult
```

### 4.13 `runtime/` — 运行时（生命周期/内存）【v1.2 已落地 ✅】
**职责**：对象生命周期、内存/所有权、并发与超时管理——执行层的"薄守护层"，不触碰 `taiji` 状态根。
```
runtime/
├── lifecycle.mojo         # 模块启停/健康检查(IDLE→RUNNING→PAUSED→STOPPED)
├── memory.mojo            # 内存预算/回收策略
├── concurrency.mojo       # 并发模型(任务槽 + 超时守卫, 非阻塞热路径)
├── tests/  benchmarks/
└── README.md
```
**依赖**：`core`。
> **实现状态（2026-07-12，零桩函数 TDD 全绿）**：`runtime/lifecycle.mojo` ✅（`RuntimeState` 状态机 IDLE→RUNNING→PAUSED→STOPPED，`start/tick/record_error/pause/resume/stop`，`is_healthy = errors < 5`）+ `runtime/memory.mojo` ✅（`MemoryBudget(capacity)` alloc/free/available/utilization）+ `runtime/concurrency.mojo` ✅（`TaskSlot(cap)` acquire/release + `TimeoutGuard(sec)` tick/expired）。**41 用例全绿**；基准 lifecycle≈0 / memory≈2 / concurrency≈4 ns/op（纯寄存器整数操作，符合"薄守护层"定位）。详见 §4.13.0 调用契约与 §4.13.1 接口骨架。

#### 4.13.0 调用契约 · I/O · 错误处理
- **状态机**：`start` 仅 IDLE→RUNNING；`pause/resume` 在 RUNNING/PAUSED 间切换；`stop` 终态；`record_error` 累计错误，`is_healthy` 在 `errors < 5` 时为真（超出→不健康，触发降级/熔断）。
- **内存预算**：`alloc(n)` 仅在 `available >= n` 时成功并返回 1，否则返回 0；`free(n)` 回退 `used`；`utilization = used/capacity`。
- **并发**：`TaskSlot.acquire()` 在 `active < cap` 时占用并返回 1；`release()` 释放；`TimeoutGuard.tick(elapsed)` 累加，`expired()` 在 `elapsed >= sec` 时为真。

#### 4.13.1 接口骨架（函数签名 · 参数类型 · 返回值）【已落地 ✅】
```mojo
# runtime/lifecycle.mojo
comptime RT_IDLE=0; RT_RUNNING=1; RT_PAUSED=2; RT_STOPPED=3
struct RuntimeState(Movable):
    var state: Int; var errors: Int; var ticks: Int
    def __init__(out self)
    def start(mut self); def tick(mut self); def record_error(mut self)
    def pause(mut self); def resume(mut self); def stop(mut self)
    def is_healthy(self) -> Int
# runtime/memory.mojo
struct MemoryBudget(Movable):
    var capacity: Int; var used: Int
    def __init__(out self, cap: Int)
    def alloc(mut self, n: Int) -> Int      # 1=成功 0=超额
    def free(mut self, n: Int)
    def available(self) -> Int
    def utilization(self) -> Float64
# runtime/concurrency.mojo
struct TaskSlot(Movable):
    var cap: Int; var active: Int
    def __init__(out self, cap: Int)
    def acquire(mut self) -> Int; def release(mut self)
struct TimeoutGuard(Movable):
    var sec: Int; var elapsed: Int
    def __init__(out self, sec: Int)
    def tick(mut self, dt: Int); def expired(self) -> Int
```

#### 4.13.2 回灌健康度 + 超时门控（v1.4 增强）

把"回灌闭环"纳入 runtime 健康度检查与超时门控（需求 ③），并以 `BackfillSupervisor` 驱动端到端闭环（需求 ②）。

- **回灌健康度信号**：`RuntimeState` 新增 `backfill_total / backfill_ok / backfill_errors / backfill_latency_sum / backfill_latency_samples`；`record_backfill(success, latency_ms)` 记录一次回灌结果；`backfill_success_rate()`（无样本返 1.0）；`backfill_avg_latency()`。
- **纳入健康度**：`is_healthy()` 在样本 `≥4` 且 `backfill_success_rate() < 0.5` 时判为不健康；`can_execute()` 经 `is_healthy()` 一并纳入回灌健康度——回灌持续失败即降级、不扇出。
- **超时门控 `BackfillGate(budget_ms)`**：`allow(rt, last_latency_ms)` 在 runtime 可执行 **且** 上次耗时未超预算时放行（返 1），否则降级（返 0）并累计违规；连续违规 `> max_violations(3)` → `tripped()` 熔断，由上层介入（不阻塞状态根）。
- **端到端驱动 `BackfillSupervisor`**（`runtime/integration.mojo`，L6 横切统一驱动点）：每步 `step()` 先经 `BackfillGate.allow` 判定 → 放行则跑完整认知闭环（含回灌）并经 `RuntimeState.record_backfill` 上报健康度 + 落盘 `observability` 溯源 ledger；门控关闭则记一次失败、保持上一轮状态（降级，不崩溃）。

**验收**：`runtime/tests/test_runtime.mojo` 由 41 → **67 断言全绿**（`test_backfill_health` / `test_backfill_gate` / `test_backfill_supervisor`）；其中 `test_backfill_supervisor` 验证 lineage_id 已写入太极状态根 + ledger 跨进程落盘（需求 ②）。

### 4.14 `observability/` — 可观测（M8 升级 · 生产级审计硬性要求）【v1.2 已落地 ✅】
**职责**：可视化(M8 emoji/SVG) + 指标(metrics) + 追踪(tracing) + 结构化日志 + **强制决策溯源与审计**。
> **立场基线**：真实性 = 忠实执行·无黑箱·全链路可审计；可解释性与可审计性为生产级硬性要求（不可审计即不部署，见 §8 #8）。合规审查作为可审计的横切层保留，不去除、不绕过；其判定同样纳入 `tracing` 溯源。
```
observability/
├── metrics.mojo           # 运行时指标(延迟滑动窗/吞吐/五行均衡度/鲁棒性退化%)
├── tracing.mojo           # 决策可追溯: 五行生克/八卦算子/合规判定 全链路原生溯源
├── explain.mojo           # 标准化可解释接口: 内在(符号中间表示)+事后(决策链)统一出口
├── render.mojo            # 迁自 src/emoji.mojo: 文本摘要 + 轻量 SVG 渲染
├── logging.mojo           # 结构化日志(合规判定同样留痕, 可独立审查)
├── __init__.mojo          # 聚合导出
├── tests/  benchmarks/
└── README.md
```
**依赖**：全部模块（采集侧）。**运维**：指标导出 Prometheus 格式；追踪接 tracing 后端；审计覆盖率纳入上线门禁。
> **实现状态（2026-07-12，零桩函数 TDD 全绿）**：`observability/metrics.mojo` ✅（`Metrics` 延迟窗 8 样本 + p50/p95 + 五行均衡度方差 + 鲁棒性退化%）+ `tracing.mojo` ✅（`TraceSpan`/`Tracer` 16 固定槽全链路溯源 + `decision_lineage`）+ `explain.mojo` ✅（`explain_decision` 内在可解释）+ `render.mojo` ✅（`render_summary` 文本 + `render_svg` 轻量 SVG）+ `logging.mojo` ✅（`log_line`/`audit` 结构化日志/审计）。**21 用例全绿**；基准 metrics≈39 / trace≈2269 / render≈9552 ns/op。详见 §4.14.0 调用契约与 §4.14.1 接口骨架。

#### 4.14.0 调用契约 · I/O · 错误处理
- **指标**：`Metrics.record(latency_ms, ok, degraded)` 循环写入容量 8 窗口；`p95/p50` 选择排序取百分位；`robustness_degradation = degraded/(ok+degraded)`；`set_balance(energies)` 以五行方差作均衡度代理。
- **追踪**：`Tracer.add_decision_spans(result)` 把规划链逐点固化为 `TraceSpan`（父=上一链位）；`decision_lineage(result, output)` 输出 相位→规划链→十方扇出 全链路（ok/degraded 取自 `ShifangOutput`，规避 `ConnectorResponse` 非 Movable 传参坑）。
- **解释/渲染**：`explain_decision(result, output, resp_text)` 生成内在可解释文本；`render_summary(result, output, trace)` 文本摘要；`render_svg(result, output)` 轻量 SVG（相位节点→规划链流→十方向点亮）。
- **日志/审计**：`log_line(INFO/WARN/ERROR, module, msg)` 结构化日志；`audit(event)` 合规判定强制 AUDIT 留痕，可独立审查。

#### 4.14.1 接口骨架（函数签名 · 参数类型 · 返回值）【已落地 ✅】
```mojo
# observability/metrics.mojo
struct Metrics(Movable):                     # 延迟窗 8 样本 + 计数 + 吞吐 + 五行方差
    def record(mut self, latency_ms: Int, ok: Int, degraded: Int)
    def p95(self) -> Int; def p50(self) -> Int
    def robustness_degradation(self) -> Float64
    def set_balance(self, energies: List[Float64])
    def snapshot(self) -> String
# observability/tracing.mojo
struct TraceSpan(TrivialRegisterPassable):   # 全 Int 字段 → 隐式可拷贝(按值返回/传参)
    var trace_id, parent, stage, element, decision, confidence_milli, policy_id: Int
struct Tracer(TrivialRegisterPassable):     # 16 固定槽(非 List 嵌套)
    var s0..s15: TraceSpan; var span_len: Int
    def add_decision_spans(mut self, result: PipelineResult)
    def render_trace(self) -> String
    def decision_lineage(self, result: PipelineResult, output: ShifangOutput) -> String
# observability/explain.mojo
def explain_decision(result: PipelineResult, output: ShifangOutput, resp_text: String) -> String
# observability/render.mojo
def render_summary(result: PipelineResult, output: ShifangOutput, trace: Tracer) -> String
def render_svg(result: PipelineResult, output: ShifangOutput) -> String
# observability/logging.mojo
comptime LOG_INFO=0; LOG_WARN=1; LOG_ERROR=2; LOG_AUDIT=3
def log_line(level: Int, module: String, msg: String) -> String
def audit(event: String) -> String
```

#### 4.14.2 跨进程溯源 ledger（v1.4 增强）

把"回灌结果"与"决策溯源链路"以 `lineage_id` 关联，使数据可**跨进程追踪**（需求 ②），对应 `runtime/integration.mojo` 的 `BackfillSupervisor` 落盘动作。

- **`observability/store.mojo`**：`TraceLedger` 追加式内存 ledger，承载两类记录——
  - `REC_TRACE`：来自 `Tracer` + `PipelineResult` 的规划链/决策 span 固化（`record_trace(t, r) -> lineage_id`）；
  - `REC_BACKFILL`：来自回灌闭环的落库记录（`record_backfill(lineage_id, status, ok, degraded, conf, policy_id, latency)`）。
- **关联键 `lineage_id`**：同一回灌轮次下既有溯源 span、也有回灌落库记录，`lineage(id)` 可一并回放证明"溯源 ↔ 回灌"成对关联（`status: 1 成功 / 0 拒绝 / -1 异常`）。
- **跨进程通道（Mojo 1.0.0b2 真实约束）**：本构建无原生文件/HTTP/子进程 API 可靠持久化，故 `to_jsonl()` 序列化为稳定键序的 JSON-Lines 字符串，由 `emit()` 经 **stdout 管道**导出，供任意下游进程（如 `observability/store_reader.py`）从 stdin 消费——这是本构建下唯一可靠的跨进程持久化链路。结构化记录全程在内存，仅导出时序列化（不持有 `String` 字段，保 `Trivial`/`Movable`）。

**验收**：`observability/tests/test_store.mojo` 全绿（含 `lineage` 关联回放、`to_jsonl` 稳定键序、跨进程导出）；与 `runtime/test_backfill_supervisor` 的 ledger 落盘断言端到端串联。

### 4.15 `io/` — 输入（分词）【v1.5 已落地 ✅】
**职责**：字节级/正则分词，认知流水线的输入层。
```
io/
├── bpe_tokenizer.mojo     # 迁自 src/bpe.mojo（硬化 + 适配本构建 API）
├── regex_tokenizer.mojo   # 从零实现（src/regex.mojo 在本项目不存在）
├── tests/test_io.mojo     # 4 断言
├── benchmarks/bench_io.mojo
└── README.md
```
**依赖**：`core`。

**接口骨架**：
```mojo
from io import Tokenizer, train_tokenizer, RegexTokenizer

# BPE（字节级，encode→decode 精确还原）
struct Tokenizer:
    var vocab: Dict[Int, List[Int]]
    var merge_order: List[Tuple[Int, Int]]
    def __init__(out self)
    def train(mut self, text: String, vocab_size: Int) raises
    def encode(self, text: String) raises -> List[Int]
    def decode(self, ids: List[Int]) raises -> String
def train_tokenizer(mut t: Tokenizer, text: String, vocab_size: Int) raises

# 正则风格（确定性扫描：ASCII 词/数字段合并、CJK 逐字、空白与标点保留）
struct RegexTokenizer:
    def __init__(out self)
    def encode(self, text: String) -> List[String]
    def decode(self, toks: List[String]) -> String
```
**审计修正**：旧文档称「迁自 src/regex.mojo」——该文件在本项目**不存在**，regex 分词器为从零实现。详见 `io/README.md`。

### 4.16 `config/` — 配置（外置化）【v1.5 已落地 ✅】
**职责**：全局阈值、生克表、调度策略参数、连接器凭证的外部配置（运维改 `defaults.toml` 免重编译）。
```
config/
├── config.mojo            # 加载器 + 校验 + 最小 TOML 解析（迁自 src/config.mojo，升级）
├── schema.mojo            # 字段规格（索引函数，规避非 Movable FieldSpec/List）
├── defaults.toml          # 默认配置(不进代码)
├── tests/test_config.mojo # 8 断言
└── README.md
```
**依赖**：无。

**接口骨架**：
```mojo
from config import Config, from_str, from_toml

struct Config:
    var values: Dict[String, String]
    def __init__(out self)                       # 载入 schema 默认值
    def get_int(self, name: String) raises -> Int
    def get_float(self, name: String) raises -> Float64
    def get_str(self, name: String) raises -> String
    def validate(self) raises                    # 边界复查
    def to_toml(self) raises -> String           # round-trip
def from_str(mut c: Config, s: String) raises    # 文件缺失/越界 → raise
def from_toml(mut c: Config, path: String) raises
```
详见 `config/README.md`。

---

## 5. 目录树总览（目标态）

```
dadaozhijian_cognitive/
├── README.md
├── pixi.toml
├── docs/
│   ├── architecture.md           # 现有架构说明(保留)
│   ├── architecture-modular-plan.md  # 本文(总纲, 持续细化)
│   ├── implementation-plan.md    # 现有里程碑(保留/逐步并入本文)
│   ├── audit-m1-m10-2026-07-10.md
│   ├── project-maturity-assessment-2026-07-11.md
│   ├── adr/                      # 架构决策记录(持续追加)
│   ├── philosophy/               # 11 篇哲学依据
│   └── operations/               # 运维手册/部署说明(随 Phase 5/6 填充)
├── src/                          # 【将按模块目录重构】
│   ├── core/ liangyi/ sancai/ sixiang/ wuxing/ liuhe/ qixing/
│   ├── bagua/ jiugong/ taiji/ shifang/ scheduler/ pipeline/
│   ├── runtime/ observability/ io/ config/
│   └── README.md (或 module READMEs)
├── tests/                        # 按模块归集(或各模块内 tests/)
├── benchmarks/                   # 按模块归集(或各模块内 benchmarks/)
├── tools/                        # CLI 开发工具(dump_emoji 等)
├── deploy/                       # Docker / k8s / compose (Phase 6)
├── ops/                          # 运行手册 / 监控配置 (Phase 5+)
└── .scratch/                     # 任务 PRD/issue 草稿
```

---

## 6. 横切关注点

- **测试策略**：每模块 `tests/` 独立可跑；顶层 `tests/test_all.mojo` 聚合。覆盖率门禁随生产化提高。
- **基准策略**：每模块 `benchmarks/` 锁性能回归；纳秒级热路径设上限告警。
- **文档(ADR)**：重大结构变更先写 ADR（编号顺延 0012+）。
- **配置外置**：所有阈值/策略入 `config/defaults.toml`，运行期不硬编码。
- **日志**：统一结构化日志（`observability/logging.mojo`），运维可检索。
- **学习/适应**：持续学习防遗忘策略统一落于 `taiji/consolidation.mojo`；在线/迁移/少样本策略由 `config` 切换，安全域偏保守（多检索、少更新）。
- **鲁棒性/安全合规**：合规审查作为可审计的横切层（不去除、不绕过）；所有判定（含合规层）须纳入 `observability/tracing.mojo` 溯源，满足"可独立审查验证"。

---

## 7. 阶段性推进路线（MVP → 生产级）

| Phase | 目标 | 主要交付 | 验收 |
|---|---|---|---|
| **0 规划** | 总体大纲 + 调研增补 | 本文 v0.3 | 模块边界/职责清晰；已对齐认知模型调研结论 |
| **1 数基** | `core/` 落地 | number/simd/tensor/math + 测试+基准 | ✅ **已完成**：78 用例/7 套件全绿；热路径 SIMD 跑通（vector_add 6ns/op） |
| **2 状态记忆** | `taiji/` + `jiugong/` | 太极回灌闭环 + 九宫真张量化 + **持久化** | **✅ 已落地（v0.4）**：`taiji`(回灌+持久化)+`jiugong`(张量化) 已 TDD 落地（见 §4.1 / §4.9） |
| **3 算子层** | `liangyi/` `sancai/` `sixiang/` `bagua/` | 阴阳原语 + 三才分层 + 四象 + 八卦算子迁移 | **liangyi ✅ 已落地（v0.4，17 用例全绿）+ sancai ✅ 已落地（v0.5，14 用例全绿）+ sixiang ✅ 已落地（v0.6，29 用例全绿 + 基准 10/67 ns/op）+ bagua ✅ 已落地（v0.8，17 组测试全绿 + 基准 trigram_lines≈129/apply≈23/combine≈264 ns/op）** |
| **4 调度脑** | `wuxing/` `liuhe/` `qixing/` `scheduler/` | 五行生克派生真调度策略 + 供给 + 排序 + 总派发 | **全部已落地（v1.0）**：wuxing✅（§4.5，81 断言+基准 5/175/350 ns/op）· liuhe✅（§4.6，57 断言+基准 178/0 ns/op）· qixing✅（§4.7，18 断言+基准 476/181/507 ns/op）· scheduler✅（§4.11，16 断言+基准 487/666 ns/op）。调度决策可回溯到生克表；A/B 可切换 |
| **5 执行与编排** | `shifang/` `pipeline/` `runtime/` `observability/` `taiji/`(回灌衔接) | 十方扇出 + **真实模型/API 连接器** + 阶段图编排 + 运行时 + 可观测 + **回灌闭环收口** | **全部已落地（v1.2→v1.4）**：pipeline✅（§4.12.1，78 断言 + 基准 run_pipeline≈997/run_pipeline_from_energies≈917 ns/op）· shifang✅（§4.10.1/§4.10.2，27+22 断言，十方扇出+连接器熔断/重试/中性降级 + 真实 LLM 侧车桥接，架构首次"能说话"且可接真实 LLM）· runtime✅（§4.13.1/§4.13.2，67 断言 + 基准 lifecycle≈0/memory≈2/concurrency≈4 ns/op + 回灌健康度/超时门控）· observability✅（§4.14.1/§4.14.2，21+ 断言 + 基准 metrics≈39/trace≈2269/render≈9552 ns/op + 跨进程溯源 ledger）· **回灌衔接 taiji/reinjection✅（§4.1.3，v1.3，11 断言）** + **taiji 持久化格式迁移 v2/并发写锁✅（§4.1.4，v1.4）**。可端到端跑、非阻塞、可溯源、异常隔离 |
| **6 生产硬化** | `observability/` 升级 + `deploy/` + `ops/` | 指标/追踪/日志 + **部署/运维脚手架** + 运行手册 | **脚手架已交付（v1.6）**：静态二进制部署单元 + 多阶段 Dockerfile（可选）+ systemd/supervisord + `ops/runbook.md` + 退出码健康检查 + Prometheus 文本指标导出（免 HTTP）。**v1.7 增强**：`ops/metrics_exporter.mojo` 已接入真实 `observability.Metrics.to_prometheus()`（非参数化骨架），并新增 `deploy/k8s/dadaozhijian.yaml` 部署模板（占位符化、YAML 已校验可解析；主服务写 .prom + node-exporter sidecar 读，免 HTTP）。**阻塞（需环境供给，非不可能）**：k8s 集群 / Prometheus+Grafana 栈 / CI Docker runner / LLM 凭证 |
| **7 收口** | 迁移旧 `src/*.mojo` 至新结构，删冗余 | 单一天纲结构；旧文件归档 | **✅ 已收口（v1.6）**：旧 `src/` 12 文件 + M1–M10 遗留 `tests/*.mojo`（11）+ `tools/dump_emoji.mojo` 经引用核查零构建引用，整体软归档至 `archived/`（可逆），写 ADR-0012 记录旧→新映射；顶层仅留现行 `tests/test_taiji.mojo` 与被 README 引用的 `tools/examples/`，单一天纲结构达成 |

**本次完成：Phase 0（总纲）+ Phase 1（core/ 数基）+ Phase 2 接口骨架（§4.1 太极回灌闭环+持久化、§4.9 九宫真张量化，v0.4）+ Phase 3 算子层全部 TDD 落地（liangyi/sancai/sixiang/bagua，v0.4→v0.8）+ Phase 4 调度脑全部 TDD 落地（wuxing v0.9 §4.5 → liuhe/qixing/scheduler v1.0 §4.6/§4.7/§4.11 → pipeline v1.1 §4.12 端到端编排，2026-07-12 收官）+ Phase 5 执行层全落地（shifang/runtime/observability v1.2 → 回灌衔接 v1.3 → 回灌真实化+可观测增强 v1.4）+ **v1.5（2026-07-13）io/config 两模块 TDD 落地**（§4.15/§4.16）。** **v1.5（2026-07-13）io 分词 + config 外置化**：① `io` BPE 分词器（迁自 src/bpe.mojo，硬化）+ 正则风格分词器（从零实现，修正 §4.15「迁自 src/regex.mojo」不实声明），4 断言全绿；② `config` schema 驱动加载 + 校验 + 最小 TOML 解析 + `defaults.toml` 外置（免重编译），8 断言全绿。全项目 17 模块（24 测试套件）全量断言全绿。**v1.6（2026-07-13）部署/运维脚手架 + Phase 7 软归档**：① `deploy/`+`ops/` 按 GitHub/全网调研最优解落地——部署单元为 `mojo build` 静态二进制（容器化仅作多服务编排可选分支），交付多阶段 Dockerfile（~4GB→~300–500MB）、systemd 单元、supervisord、运维手册、退出码健康检查、自包含 Prometheus 文本指标导出（免 HTTP，已验证可编译）；② Phase 7 旧 `src/` 与 M1–M10 遗留 tests/tools 经引用核查零构建引用，整体软归档至 `archived/`（可逆），写 ADR-0012 记录旧→新模块映射，单一天纲结构达成。需外部基建项（k8s/Prometheus 栈/CI Docker runner/LLM 凭证）单列阻塞，属环境供给非不可能。后续每推进一个大模块落地（TDD），将在本文对应 §4.x 补全实现细节与验收并递增版本。

---

## 8. 运维导向设计决策

1. **目录即文档**：每个模块根 `README.md` 自述职责/接口，新人无需通读全局。
2. **故障隔离**：调度脑与执行层解耦——executor/连接器崩溃不影响 `taiji` 状态根；状态根独立快照。
3. **可回滚**：生克表/调度策略/配置均可版本化与热切换，策略回归可一键回退。
4. **配置外置**：阈值与策略不入代码，运维改 `defaults.toml` 即可，免重编译。
5. **可观测优先**：M8 从"调试可视化"升级为"运维可观测"（指标/追踪/日志导出标准格式）。
6. **性能回归门禁**：每模块 benchmark 设上限，CI 超阈即阻断。
7. **单模块独立验证**：任一模块可独立 `mojo test`/`bench`，故障定位到模块级。
8. **不可审计即不部署**：任何模块若无法输出可溯源决策链（五行生克/八卦算子/合规判定），不得进入生产；审计覆盖率为上线门禁。
9. **鲁棒性/合规为横切硬层**：安全合规审查作为可审计一环保留，不去除、不绕过；对抗/分布偏移/OOD 须有量化退化上限。
10. **性能预算门禁量化**：以 P50/P99 延迟、吞吐(token/s, req/s)、显存(GB)、鲁棒性退化% 设上限，CI 超阈即阻断（标准见 §10.6）。

---

## 10. 基于认知模型调研的增补与优化（v0.2）

> 来源：`docs/cognitive-model-architecture-research-2026-07-11.md`。本章将调研的 5 维度结论映射到本架构，形成可执行的增补项，使总纲与学界认知模型范式对齐。

### 10.1 认知五层 ↔ 本架构分层对齐
调研提出 感知/记忆/推理/决策/元认知 五层。映射验证本架构分层与其一致，**无需新增顶层**：
- 感知 ↔ `io/`(分词编码) + `core/`(数值嵌入)
- 记忆 ↔ `jiugong/`(工作记忆) + `taiji/`(长期记忆根)
- 推理 ↔ `bagua/`(算子) + `wuxing/`(生克调度)
- 决策 ↔ `qixing/`(排序) + `scheduler/`(总派发) + `shifang/`(执行)
- 元认知 ↔ `taiji/`(回灌闭环/自我修正) + `observability/`(监控溯源)

### 10.2 调研六大缺失 → 本架构对应增补
| 调研缺失/瓶颈 | 本架构增补 |
|---|---|
| 统一记忆架构缺失 | `jiugong`(工作)+`taiji`(长期) 双记忆 + `sancai` 层间契约，统一抽象 |
| 因果推理深度不足 | `wuxing/sheng_ke.mojo` 生克转移表 = 结构化因果；`bagua/combine.mojo` 重卦衍生 |
| 元认知闭环薄弱 | `taiji/feedback_loop` 回灌 + `observability/tracing` 自我修正触发 |
| 持续学习防遗忘 | `taiji/consolidation.mojo`（EWC/经验回放 Mojo 化）|
| 可解释性接口非标准化 | `observability/explain.mojo` 强制决策溯源（§4.14）|
| 实时—质量无权衡框架 | §8 #10 性能预算门禁 + `config` 策略切换 |

### 10.3 七项核心能力 → 各模块验收标准
调研 §2 的 7 能力评估标准下沉为模块验收：
- 多模态/上下文 → `io/`、`sancai/`（跨模态召回、长程依赖准确率）
- 长期记忆 → `taiji/`+`jiugong/`（回忆准确率、遗忘率）
- 知识推理 → `bagua/`+`wuxing/`（推理基准准确率）
- 自主决策 → `scheduler/`+`shifang/`（任务成功率、约束满足率）
- 注意力 → `jiugong/attention.mojo`（注意力一致性）
- 元认知 → `taiji/`+`observability/`（ECE 校准误差、OOD AUROC）

### 10.4 学习/适应范式 → 横切落地
调研 §3 四范式（在线/迁移/少样本/持续）以 `config` 切换策略；持续学习防遗忘落 `taiji/consolidation`；安全域偏保守（多检索少更新）。

### 10.5 可解释性方法分类 → observability 落地
- 内在可解释：`bagua/operators`（模块化算子集）+ 符号中间表示（八卦/五行数值）
- 事后局部：决策链记录（`observability/tracing`）
- 事后全局：探针/行为聚类（未来 `observability/metrics` 扩展）
- 结构化溯源：全局工作空间(`jiugong`) + 回灌(`taiji`) 原生记录

### 10.6 量化性能预算门禁（标准）
| 指标 | 目标参考（按模块定预算） |
|---|---|
| 首 token 延迟 P50/P99 | 交互 <500ms(P99) |
| 吞吐 | >100 token/s（生成）/ 按模块 req/s |
| 显存 | 量化(Int8/4) 降本 2–4× |
| 鲁棒性退化% | 对抗/OOD 退化 <10% |
各模块 `benchmarks/` 据此设上限，CI 超阈阻断（§8 #6/#10）。

### 10.7 鲁棒性/安全合规横切层（立场基线）
真实性 = 忠实执行·无黑箱·全链路可审计。合规审查作为**可审计的横切层**保留，不去除、不绕过；其判定同样纳入 `tracing` 溯源，使系统行为"可被独立审查验证"。这同时满足用户的真实性、可解释性、可审计性三项要求。

---

## 9. 本次细化范围说明

本文为 **总体规划 v0.8（总纲 + 调研增补 + Phase 1 落地 + Phase 2 状态记忆落地 + Phase 3 算子层 liangyi/sancai/sixiang/bagua 全部落地）**。v0.4 在 v0.3 基础上，将 Phase 2 的核心三任务（太极回灌闭环、九宫真张量化、长期记忆持久化）固化为**可落地的接口骨架**（见 §4.1 / §4.9）并**已 TDD 落地**；v0.5 在 v0.4 已落地 `taiji`/`jiugong`/`liangyi` 基础上，将 Phase 3 算子层（sancai/sixiang/bagua）细化为**对 liangyi 的调用契约 + 统一 I/O 规范 + 错误处理框架 + 实现顺序/并行开发策略**（见 §4.2.2 / §4.2.3 / §4.3.0 / §4.4.0 / §4.8.0），并自 v0.5→v0.8 逐模块 TDD 落地：
- 第一性原则与分层；
- 16 个模块的**职责边界与目录/文件职责草案**；
- **§4.1 太极回灌闭环 + 长期记忆持久化落盘**：能量流转模型、四步状态流转契约、回灌触发条件（基础/巩固/快照/关闭）、二进制+版本头+CRC32+WAL 的存储格式与一致性保障、完整函数签名；
- **§4.9 九宫真张量化**：3×3 张量规格（维度语义=宫位类别×时态窗口、元素=Float64）、读写/变换/注意力接口签名、与太极的分层边界；
- **§4.2 liangyi 阴阳原语**：已 TDD 落地（17 用例全绿，v0.4 已落地 ✅）；
- **§4.2.2 / §4.2.3 + §4.3.0 / §4.3.1 / §4.4.0 / §4.4.1 / §4.8.0 / §4.8.1 Phase 3 算子层（v0.5/v0.6/v0.7/v0.8）**：liangyi 导出能力确认（下游 `from liangyi.<file> import <sym>` 已验证）、sancai/sixiang/bagua 对 liangyi 的依赖关系与调用契约、实现顺序（Wave 1 sancai+sixiang 并行 → Wave 2 bagua 串行依赖 sancai）与并行开发策略、统一 I/O 规范与错误处理框架；**其中 `sancai` 已于 v0.5 完成 TDD 落地（14 用例全绿，见 §4.3.1），`sixiang` 已于 v0.6 完成 TDD 落地（29 用例全绿 + 基准 10/67 ns/op，见 §4.4.1），`bagua` 已于 v0.8 完成 TDD 落地（17 组测试全绿 + 基准 trigram_lines≈129/apply≈23/combine≈264 ns/op，见 §4.8.1）**；
- 阶段路线与运维决策。

**尚未细化**（将在 TDD 落地对应模块时填充）：性能预算数字、迁移旧代码（`src/taiji.mojo`、`src/workspace.mojo`、`src/trigram.mojo`、`src/executor.mojo`）的逐步 diff、deploy/ops 具体配置（算子层 liangyi/sancai/sixiang/bagua 已全部 TDD 落地，见 §4.2.1/§4.3.1/§4.4.1/§4.8.1）。届时本文对应章节将补全实现细节与验收并递增版本号（v0.3, v0.4, v0.5, v0.6, v0.7, v0.8…）。

---

## 附录：与 11 份哲学文档的映射

| 哲学文档 | 对应模块 | 核心启示（用于架构约束） |
|---|---|---|
| `taiji.md` | `taiji/` | 至大无外的状态根，回灌闭环之源 |
| `liangyi.md` | `liangyi/` | 阴阳二元是一切表示的原子 |
| `sancai.md` | `sancai/` | 天地人分层 = 输入/状态/行为三层契约 |
| `sixiang.md` | `sixiang/` | 四象 = 相位/象限离散化 |
| `wuxing.md` | `wuxing/` | 生克 = 调度转移规则（核心） |
| `liuhe.md` | `liuhe/` | 空间整全 = 资源供给 |
| `qixing.md` | `qixing/` | 北斗定序 = 优先级排序 |
| `bagua.md` | `bagua/` | 三爻成象 = 算子指令集 |
| `jiugong.md` | `jiugong/` | 洛书方阵 = 工作记忆盘 |
| `shifang.md` | `shifang/` | 十向周遍 = 执行扇出 |
| `README.md` | 全局 | 由一到十的生成链与首尾圆合 |

> "万物皆数，认知即计算"——十个概念不是被解释的玄学，而是被直接编译进调度逻辑的结构。
