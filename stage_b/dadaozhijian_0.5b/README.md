# 大道至简0.5b (dadaozhijian-0.5b)

本项目蒸馏出的**第一个自包含自有模型**。

## 身份

| 字段 | 值 |
|------|-----|
| 模型 ID | `dadaozhijian-0.5b` |
| 中文名 | 大道至简0.5b |
| 基座 | `Qwen/Qwen2.5-0.5B`（开放权重） |
| 蒸馏方法 | LoRA 蒸馏（Orca 式序列级 + 推理链 SeqKD），由 `RetrievalDistiller` 计划符号忠实闸门过滤训练数据 |
| 参数量 | 0.5B |
| 权重精度 | fp16（合并后） |
| 是否自包含 | **是**——LoRA 已 `merge_and_unload` 入基座，加载时**无需原基座仓库**，可独立 `from_pretrained("stage_b/dadaozhijian_0.5b")` |

## 与"LoRA 补丁"的区别

此前 `neural_adapter/adapter/` 是"Qwen 基座 + 我们的 LoRA 增量"两块拼起来的补丁，
加载时还要找回原基座权重。本目录是**合并烘焙后的单一 checkpoint**，
它就是"蒸馏出来的第一个自己的模型"，可作为后续迭代的基座或导出（GGUF/Ollama）对象。

## 训练数据

- 来源：本机 Ollama 双 teacher（`phi4-mini:3.8b` + `qwen3.5:4b-mlx`）生成，
  `RetrievalDistiller` 生成计划符号并对 teacher 回答做忠实度过滤（覆盖率门槛 1.0）。
- 组合择优：覆盖率并列时取更详尽的回答（本次 17 条全来自 qwen3.5 的五行推演）。
- 规模：17 条 `(instruction, plan, response)` 高质量指令对。
- 生成脚本：`stage_b/generate_distill_data.py`；合并+评测脚本：`stage_b/merge_and_eval.py`。

## 评测结果（全量 17 计划）

| 指标 | 值 |
|------|-----|
| 均值计划符号覆盖率 | **0.9608** |
| 全覆盖比例（=1.0） | **0.9412**（16/17） |
| 失败计划 | `木→土→水`（0.333，非规范相生序列，分布外样本） |

评测方式：从本目录**独立加载**模型，对 17 个符号计划用训练同款 prompt 生成，
计算计划符号在输出中的覆盖率（faithfulness 代理指标）。详见 `docs/neural_faithfulness_report.md`。

## 已知局限（诚实记录）

1. **分布外序列弱**：`木→土→水` 这类非规范相生链（木生火生土、土生金，并不存在木→土→水）
   覆盖率骤降到 0.333，0.5B 学生学不会异常链。建议训练数据只保留规范相生/相克链。
2. **长链文本质量下降**：5 符号计划虽符号覆盖率仍 1.0，但输出出现重复/套话，
   推理深度受 0.5B 容量限制。
3. **容量天花板**：0.5B 仅适合本项目的符号调度推演演示，不与大模型比肩。
4. **数据规模极小**：17 条。扩大数据 + 多 epoch 可显著提升泛化。

## 使用方式

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch
tok = AutoTokenizer.from_pretrained("stage_b/dadaozhijian_0.5b")
model = AutoModelForCausalLM.from_pretrained(
    "stage_b/dadaozhijian_0.5b", torch_dtype=torch.float16
).to("mps")  # 或 "cpu" / "cuda"
# 输入需与训练一致：system + user(指令) + 空 assistant，走 chat 模板
```

权重文件 `model.safetensors`（约 988MB）不纳入 git 主仓，由 `merge_and_eval.py` 重新生成；
本目录其余元数据/模型卡/配置纳入版本管理，保证可复现。
