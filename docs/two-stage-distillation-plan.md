# 两阶段混合蒸馏计划（双后端选择器 + 专属小模型自蒸馏）

> 关联：`shifang/llm_sidecar.py`（双后端选择器，已落地）、`shifang/sidecar_config.json`、
> `observability/store.mojo`（ledger 溯源）、`taiji/reinjection.mojo`（回灌/数据飞轮）。
> 适用范围：在不改动 Mojo 框架其余代码的前提下，先以本地小模型跑通端到端，再蒸馏出唯一专属后端。

---

## 0. 第一性原则对齐（"无黑箱·全链路可审计"约束如何满足）

总纲 §0 三条第一性原则中，与本计划最相关的是：

1. **万物皆数**——"不允许不可计算的黑箱"。
2. **认知即计算**——调度逻辑由符号结构（五行/八卦/…）直接派生。
3. **可解释·可测量·可实时**——每个决策须回溯到五行/八卦；自带 benchmark+metrics。

**关键澄清（避免范畴错误）**：本框架的"认知"由 `core/taiji/wuxing/...` 这套**确定性 Mojo 符号引擎**承担，LLM 只处在 `shifang`（十方·执行扇出）的最末端，是一个**渲染器/执行器**，而非思考者。因此：

- 神经模型本身确实是"统计黑箱"，但它在架构中的角色被严格限定为**忠实的 NL 渲染层**，**绝不参与认知决策**——认知正确性是符号引擎保证的（可审计、可测量）。这正好满足"无黑箱"的第二层含义：**黑箱不持有任何认知权重**。
- "全链路可审计"在本计划中体现为：**每一次 LLM 输出都被记录并可追溯到其输入符号计划**。选择器（`llm_sidecar.py`）对每一次调用写入含 `call_id` 的 ledger 记录（`prompt`=符号计划文本，`response`=渲染文本），无论后端是 Qwen3 / Phi-4-mini / 最终蒸馏模型——**蒸馏模型上线后，这条审计链不降级，反而更强**（因为它直接对接自产数据）。

---

## 1. 阶段 A（当前）：接入 Qwen3-3B 作为默认本地连接器

**目标**：以最低改造成本跑通端到端，且全程可记录，为阶段 B 积累蒸馏数据。

### 1.1 落地内容（已完成）
- `shifang/llm_sidecar.py` 重构为**双后端选择器**：配置驱动、健康检查、故障转移、统一接口。
- `shifang/sidecar_config.json`：四后端 `qwen3-3b` / `qwen3-3b-thinking` / `phi-4-mini` / `phi-4-mini-reasoning`，全部本地 OpenAI 兼容端点（Ollama `:11434/v1`、vLLM/llama.cpp `:8000/v1`），`default_backend=qwen3-3b`，`failover_order=[phi-4-mini, qwen3-3b-thinking, phi-4-mini-reasoning]`。
- **框架其余代码零改动**：Mojo 侧 `sidecar.mojo`/`protocol.mojo` 仍经 `LLM_PROMPT`→`system("python3 shifang/llm_sidecar.py")`→stdout 读回，契约不变。已验证 `test_sidecar.mojo` 22 断言、`test_shifang.mojo` 27 断言全绿。

### 1.2 本地运行（零云依赖）
```bash
# 1) 拉起本地端点（二选一）
ollama pull qwen3:3b && ollama serve            # Ollama，默认 :11434/v1
# 或
python -m vllm.entrypoints.openai.api_server --model Qwen/Qwen3-3B --port 8000   # vLLM

# 2) 框架侧无需任何云 API Key；默认即走本地 qwen3-3b
mojo run -I . -I core runtime/integration.mojo   # 端到端

# 3) 临时强制其它后端（如算力够且需推理深度）
SIDECAR_BACKEND=phi-4-mini mojo run -I . -I core runtime/integration.mojo
```
- **许可**：Qwen3 系列 Apache 2.0；Phi-4-mini 系列 MIT。二者均本地、可商用、权重开放。
- **体积**：Qwen3-3B INT4 ≈ 2 GB；Phi-4-mini Q4_K_M ≈ 2.5 GB。单卡/笔记本可跑，零云依赖。

### 1.3 全量记录（阶段 B 数据前提）
选择器对**每一次调用**追加写入 `shifang/ledger/sidecar_calls.jsonl`（`ensure_ascii=False`，逐行 JSON）：
```json
{"call_id":"<uuid>","ts":"...","backend":"qwen3-3b","model":"qwen3:3b","forced":false,
 "reasoning":false,"prompt":"<符号化计划文本>","response":"<渲染文本>","ok":1,"degraded":0,
 "latency_ms":123,"prompt_tokens":..,"completion_tokens":..,"failover_path":["qwen3-3b"]}
```
- `prompt` 即 Mojo 侧由 `PipelineResult` 构造的**符号化调度计划文本**，`response` 是对它的渲染——这正是阶段 B 需要的 **(计划 → 忠实回复)** 配对。
- 每条记录带 `call_id`，**输出可溯源到该 ledger 记录**（满足"每条输出均可追溯到生成它的 ledger 记录"）。
- 即便降级也记录（仅标 `degraded=1`），保证数据集完整。

### 1.4 阶段 A 退出标准
- [ ] 本地 Qwen3-3B 端到端跑通，真实中文渲染正常；
- [ ] `sidecar_calls.jsonl` 持续累积（建议 ≥ 5k–20k 条高质量 (计划,响应) 对）；
- [ ] 抽样人工/自动校验：响应确实对应输入计划（faithfulness 初筛通过率 ≥ 95%）。

---

## 2. 阶段 B（数据积累后）：自蒸馏专属小模型

**目标**：从框架**自身**产出的数据蒸馏一个"严格按符号计划渲染"的专属小模型，全面碾压 Qwen3-3B 与 Phi-4-mini，随后从框架删除二者，仅留蒸馏模型作为唯一后端。

**约束（不可违背）**：
- 不从零训练基座（投入产出不划算）；
- 严格"无黑箱·全链路可审计"——蒸馏模型输出仍可溯源到符号计划；
- 最终产物单一、独立、完美适配框架，不依赖任何外部大模型。

### 2.1 数据来源与对齐
两路数据可 join，互为印证：

| 数据源 | 提供 | 形态 | 用途 |
|---|---|---|---|
| `shifang/ledger/sidecar_calls.jsonl` | (计划文本, 渲染文本) + `call_id` + 后端/时延 | JSONL（选择器写） | **主训练对（SFT/蒸馏核心）** |
| `observability/store.mojo` `to_jsonl()` | `kind/lineage_id/phase/policy_id/plan[]/span_len/conf_milli/status/latency_ms` | JSONL（标量，跨进程 stdout） | **元数据与血缘**：以 `lineage_id` 串联溯源↔回灌；可 enrich 主训练对（如标注 phase/policy 作为条件信号） |

- **对齐方式**：`store.mojo` 的 `plan[]`（五行元素序列）与选择器 `prompt` 中的 `plan=[木→火…]` 同源；可用 `lineage_id`（回灌轮次）或时间窗把两条 ledger 关联，给训练对附加 `phase`/`policy_id`/`confidence` 等结构化条件，提升蒸馏模型的"按结构说话"能力。
- **数据清洗**：丢弃 `degraded=1`、空响应、重复 `prompt`、超长样本；对高质量对做去重与平衡采样。

### 2.2 基座与蒸馏方法
- **基座**：`Qwen3-1.7B`（Apache 2.0，与默认后端同族，分布最接近，蒸馏损失最小；INT4 ≈ 1.3 GB）。也可评估 `Qwen3-0.6B` 作更轻基线。
- **方法**（均"不从零训基座"）：
  1. **监督微调（SFT）**：以 (计划, 响应) 对做指令微调，system 提示与 `sidecar_config.json` 中 `system_prompt` 一致，确保"依据五行生克/八卦把符号计划译为简体中文"的行为被固化。
  2. **知识蒸馏（可选增强）**：以阶段 A 中质量最高的 Qwen3-3B 输出（或经规则校验的响应）为 teacher 软标签，进一步对齐风格与忠实度。
  3. **参数高效**：优先 LoRA / QLoRA，显存占用低、可回滚；若质量达标再合并为完整权重。
- **训练目标不仅是"像"**：在 loss 之外加入 **faithfulness 奖励**——响应必须覆盖输入计划中的元素链（见 2.4 评测），迫使模型学会"按结构渲染"而非自由发挥。

### 2.3 复用 `taiji/reinjection.mojo` 作为数据飞轮
`reinjection.mojo` 现有职责是把 `PipelineResult + ShifangOutput + Tracer + Metrics` 经 `begin_lineage`/`reinject_safe` 安全回灌进太极长期记忆，并写入可跨进程 join 的 ledger。本计划将其作为**数据飞轮枢纽**：

```
运行 pipeline → shifang 选择器渲染（写 sidecar_calls.jsonl）
     → reinjection 回灌（写 store.mojo ledger，lineage_id 串联）
          → 周期性 harvest 两份 ledger → 清洗 → (计划,响应) 训练对
               → 蒸馏更新专属模型权重 → 选择器配置切到 distilled
                    → 下一轮运行即用蒸馏模型，继续产出新数据（飞轮自转）
```
- `reinject_safe` 的 `validate_source`（phase/confidence 越界拦截）天然充当**数据质量门**，脏数据不进 ledger。
- `last_lineage` 落库使 `taiji_state.json` 与 ledger 可经 `lineage_id` 跨进程 join，飞轮闭环可审计。

### 2.4 评测体系（"全面碾压"的量化定义）
蒸馏模型须在**全部维度**上 ≥ Qwen3-3B 与 Phi-4-mini（本地同规模），且关键维度显著更优：

| 维度 | 指标 | 方法 | 胜出判据 |
|---|---|---|---|
| **忠实度（核心）** | 计划覆盖率、元素链精确率 | 自动 rubric：响应须包含输入 `plan=[...]` 全部元素且不错配生克关系 | 蒸馏 ≥ 99%，两基线 ≤ 其原水平且蒸馏更高 |
| **中文流畅度** | 母语者评分 / LLM-as-judge | 对中文认知解释抽样盲评 | 蒸馏 > Qwen3-3B（弥补 Phi 中文弱项） |
| **推理/数学保真** | 含计算的计划解释正确率 | 注入带数值/调度量的计划，校验响应数值与关系正确 | 蒸馏 ≥ Phi-4-mini 水平 |
| **代码生成** | 若框架输出含代码片段：HumanEval 式通过率 | 框架相关 snippet 生成测试 | 蒸馏 ≥ 两基线 |
| **时延/吞吐** | 本地 p50/p95 生成延迟 | 同硬件基准（复用 `observability/metrics`） | 蒸馏（1.7B）< 两基线（3B/3.8B） |
| **体积/部署** | 权重体积、显存占用 | INT4 量化后比对 | 蒸馏更小 |
| **可溯源/审计** | 输出→ledger→计划 可追溯率 | 全量抽样验证 `call_id` 链路 | 蒸馏 100%（且直接对接自产数据） |

- 评测集**必须包含阶段 A 的 held-out (计划,响应) 对 + 人工构造的"陷阱"样本**（如生克反例、冲突计划），防止过拟合。
- 自动化：用 `observability/metrics` 的 `to_prometheus` + 现有 benchmark 框架跑回归，每次蒸馏迭代产出可比报表。

### 2.5 切换与下线（最终态：唯一专属后端）
1. 蒸馏模型经 2.4 全维度达标后，导出为 GGUF / vLLM 格式，本地服务（仍走 OpenAI 兼容 `/v1`）。
2. 在 `sidecar_config.json` 中将其作为**唯一**后端：`backends=[distilled]`、`default_backend=distilled`、`failover_order=[]`。
3. **删除** `qwen3-3b` / `phi-4-mini` 等外部后端条目（及其 reasoning 变体）——此时框架**不依赖任何外部大模型**，仅本地运行蒸馏模型。
4. 选择器架构本身保留（仍是统一接口 + 健康检查 + 故障转移），但运行期实际只有 1 个后端；将来若需灰度，配置即可加回，无需改代码。

### 2.6 约束符合性自检
- ✅ **不从零训基座**：仅 SFT/LoRA/蒸馏既有开放权重。
- ✅ **无黑箱·全链路可审计**：认知在 Mojo 符号引擎（可审计）；LLM 仅渲染；蒸馏模型输出仍经选择器写 ledger（call_id 溯源），且蒸馏数据源自框架自身。
- ✅ **可溯源到原始符号计划**：每条响应 ↔ `prompt`（符号计划）↔ `call_id` ↔（训练时）对应训练样本；`store.mojo` `lineage_id` 进一步串联回灌血缘。
- ✅ **单一独立产物**：最终仅本地蒸馏模型，无外部大模型依赖。

### 2.7 风险与缓解
| 风险 | 缓解 |
|---|---|
| 阶段 A 数据噪声（降级/低质响应混入） | `degraded` 过滤 + `validate_source` 门控 + 人工抽检 |
| 蒸馏后"自由发挥"偏离符号计划 | faithfulness 奖励 + 2.4 忠实度硬指标门禁 |
| 小基座容量不足，复杂计划渲染退化 | 控制计划复杂度分布；必要时升 3B 基座或 MoE |
| 评估主观（中文流畅度） | 固定盲评集 + LLM-as-judge 双校验，留存评分记录 |
| 切换期服务中断 | 先并行（distilled 作 failover 观察），达标再移除外部后端 |

---

## 3. 交付物清单
- [x] `shifang/llm_sidecar.py` — 双后端选择器（配置/健康/故障转移/ledger）
- [x] `shifang/sidecar_config.json` — 四后端 + 默认/故障转移
- [x] `shifang/ledger/sidecar_calls.jsonl` — 阶段 B 数据（运行期累积）
- [ ] `docs/two-stage-distillation-plan.md` — 本计划
- [ ] 阶段 B 训练脚本/配置（SFT + faithfulness 奖励）—— 数据达标后实施
- [ ] 蒸馏模型权重 + 对应 `sidecar_config.json` 单后端配置
- [ ] 评测报表（2.4 全维度对比）

> 状态：阶段 A 已落地并验证；阶段 B 待 `sidecar_calls.jsonl` 数据积累达标后启动。
