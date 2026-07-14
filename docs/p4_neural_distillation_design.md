# P4 神经蒸馏分支 — 模型架构与训练闭环设计

> 基于微软（Orca / MiniLLM / GKD）与 GitHub（Unsloth / TRL / TinyBERT / PEFT）调研，
> 结合本机 **Apple M4 / 16GB / MPS（无独显、无 CUDA）** 与 **Ollama 黑盒 teacher** 约束，
> 落地的"组合蒸馏 → 自有小模型"方案。

## 0. 调研要点与对本机的约束

| 来源 | 核心方法 | 本机可用性 |
|------|----------|-----------|
| **Orca / Orca-2**（MS, arXiv 2311.11045） | 渐进式蒸馏：teacher 生成 `(指令, 推理链, 回答)` 三元组，学生学"怎么推理/选策略" | ✅ 黑盒可做的序列级 + 推理链蒸馏 |
| **MiniLLM**（清华+MSR, ICLR'24, 2306.08543） | 生成式蒸馏用 **Reverse-KL** 替代前向 KL + on-policy 采样 | ❌ 需**白盒 teacher（logits）**，Ollama API 拿不到 |
| **GKD**（MS） | 前向 KL + on-policy + frozen teacher 软标签 | ❌ 同上，需白盒 |
| **Distilling Step-by-Step**（Google） | LLM→小模型，靠 rationale+label，数据量极少 | ✅ 思路可借鉴（rationale 增强） |
| **Unsloth** | 2–5× 提速、60–80% 省显存、可导出 GGUF | ❌ **仅 NVIDIA CUDA（Triton 内核），MPS 不可用** |
| **TRL（HF）** | `SFTTrainer` / 软标签蒸馏 | ✅ MPS 兼容（transformers Trainer 原生支持） |
| **TinyBERT** | 中间层隐状态 + 注意力 MSE 蒸馏 | ❌ 需**白盒 teacher（hidden states）** |
| **PEFT / LoRA / QLoRA** | 参数高效微调 | ⚠️ QLoRA 的 bitsandbytes 仅 CUDA；MPS 上跑 **16-bit LoRA** |

**两个硬约束（改写原方案）：**
1. **Unsloth / QLoRA / bitsandbytes 在 M4/MPS 上不可用** → 只能 **原生 PyTorch(MPS) + transformers + PEFT 16-bit LoRA + TRL**。
2. **Ollama teacher 是黑盒 API（只出文本）** → **MiniLLM 的 Reverse-KL、TinyBERT 隐层对齐都做不了**。可行且 SOTA 验证的，是 **Orca 式序列级 + 推理链蒸馏（SeqKD + rationale）**，再叠加 RetrievalDistiller 的"计划符号忠实闸门"。

## 1. 闭环核心问题 → 结论

| 问题 | 决策 |
|------|------|
| **Student 选型** | **Qwen2.5-0.5B-Instruct**（≤1B，16-bit LoRA 在 16GB MPS 稳跑；中文好、推理极省） |
| **蒸馏范式** | **组合蒸馏 → 自有小模型**：双 teacher 各生成，RetrievalDistiller 按忠实度筛选组队，蒸馏出"咱们自己的模型" |
| **训练策略** | Orca 式 **序列级 + 推理链（SeqKD）**（黑盒可行）；白盒 KL/隐层对齐本机不可行，明确记为 P5 待办（需白盒 teacher 或本地加载权重） |
| **Loss** | SeqKD = 教师文本上的标准自回归 CE（学生模仿教师回答）；推理链作为上下文一并学习。注：非 logit-KL（黑盒限制） |
| **数据** | 本机 Ollama `phi4-mini:3.8b` + `qwen3.5:4b-mlx` 生成（训练期），经忠实闸门过滤，量小质高（目标 0.5k–2k 条，首跑验证用 ~50 条） |
| **框架** | transformers + PEFT(LoRA) + TRL `SFTTrainer`，**MPS 后端** |
| **评估** | ① 内部忠实度闸门（计划符号覆盖率，复用 `faithfulness_eval`）；② 业务留出集；③（可选）本地 LLM-as-judge（某个 Ollama 模型，离线）。**不跑 MT-Bench**（需 GPT-4/联网，违背离线） |

## 2. 架构与数据流

```
                 ┌──────────────────── 训练期（仅此时用 Ollama）────────────────────┐
                 │                                                                │
  业务/符号计划  │   phi4-mini:3.8b ─┐                                           │
  (plan 列表) ──┼─► qwen3.5:4b-mlx ─┼─► call_teacher() ─► (reasoning, response)  │
                 │                   │                    │                       │
                 │            RetrievalDistiller 忠实闸门：                                  │
                 │            覆盖不足的计划符号 → 丢弃/降权，选更优 teacher 回答            │
                 │                    │                    │                       │
                 │                    ▼                    ▼                       │
                 │            蒸馏数据集 JSONL (instruction, plan, response, teacher)     │
                 └────────────────────────────┬───────────────────────────────────┘
                                              │  SFT 训练（MPS, 16-bit LoRA）
                                              ▼
                                   NeuralDistiller.train()
                                   Qwen2.5-0.5B + LoRA(r=16) ──► adapter/
                                              │
        ┌─────────────────────────────────────┴─────────────────────────────────────┐
        │  运行时（脱离 Ollama）：加载 base+adapter，generate(plan) 离线渲染          │
        │  评测：faithfulness_eval 比对计划符号覆盖率（达标闸门）                     │
        └──────────────────────────────────────────────────────────────────────────┘
```

**可插拔 & 回退**：`NeuralDistiller` 为可选分支，`stage_b/main.py` 仅当 `cfg.method == "neural"` 走此路；
默认 `method="lora"` 仍走纯标准库 `RetrievalDistiller`（离线闭环不变）。`torch` 缺失时
`NeuralDistiller` 给出明确安装提示并优雅降级，绝不破坏 pure-stdlib 路径。

## 3. 关键模块设计

- **`neural_distiller.py`**
  - `TEACHER_MODELS = ["phi4-mini:3.8b", "qwen3.5:4b-mlx"]`
  - `call_teacher(model, prompt, base_url, ...)`：urllib POST `http://localhost:11434/api/chat`（零额外依赖，复用项目既有 Ollama 桥约定）。
  - `generate_distillation_data(plans, out_path, teachers, gate=1.0)`：双 teacher 生成 → RetrievalDistiller 符号覆盖闸门 → 择优落 JSONL；返回 `{n_total, n_kept, per_teacher}`。
  - `class NeuralDistiller`：`_ensure_torch()`（惰性 import，缺则清晰报错）；`train(dataset_path, output_dir)`（LoRA SFT）；`generate(plan)`（MPS 推理）；`save/load`；`evaluate(eval_pairs)`（复用 `faithfulness_eval`）。
  - **所有 torch/transformers/peft/trl 导入惰性**，保证模块在无训练栈时可 import。
- **`generate_distill_data.py`**：CLI 包装，从 ledger 或给定计划文件读取 plans，产出数据集。
- **`trainer.py`**：新增 `train_neural(cfg, train_pairs, eval_pairs)`，内部调 `NeuralDistiller`；`train()` 按 `cfg.method` 分派（默认仍 RetrievalDistiller）。
- **`main.py`**：`cfg.method == "neural"` 时分派到 `train_neural`。

## 4. 与既有"脱离外部后端"闭环的关系

- **运行时**：最终产出的"咱们自己的模型"（Qwen2.5-0.5B + LoRA）替换 `backend_shim` 渲染，**不再依赖 Ollama**，与已达成闭环一致。
- **训练期**：Ollama 仅用于生成蒸馏数据（一次性），属开发期依赖，不进入运行时路径；且可通过 `generate_distill_data.py` 预先产好数据集后断开。
- **忠实度保证**：沿用 `faithfulness_eval` 的计划符号覆盖率作为达标闸门，确保神经学生同样"对符号计划忠实"。

## 5. 风险与应对

| 风险 | 应对 |
|------|------|
| MPS 训练慢 / 16GB 紧张 | 学生限 ≤1B；16-bit LoRA（非 QLoRA）；小 batch、短序列；首跑用小数据集验证 |
| Ollama teacher 黑盒，无法 logit/隐层蒸馏 | 明确采用 Orca 式 SeqKD+rationale；白盒增强记 P5 待办 |
| torch 未装导致导入失败 | 惰性 import + 清晰报错 + 默认分支不依赖 |
| 学生泛化偏离符号计划 | 忠实闸门过滤训练数据 + 训练后 faithfulness 评估，未达标不许"下线" |
| 权重/数据集下载需联网 | 仅训练期一次；可离线预置数据集与权重后断网运行 |

## 6. 验证清单（本次交付）

- [ ] 设计文档 `docs/p4_neural_distillation_design.md`
- [ ] `neural_distiller.py` 真实实现（惰性 torch、数据生成、LoRA 训练、推理、评估）
- [ ] `generate_distill_data.py` 数据集脚本
- [ ] `trainer.py` / `main.py` 接入（默认不改、neural 可选）
- [ ] `test_neural_distiller.py`（mock Ollama，离线测逻辑）
- [ ] 真实小批量验证：装 torch→Ollama 生成 ~50 条→MPS 上训 Qwen2.5-0.5B LoRA→faithfulness 评估
