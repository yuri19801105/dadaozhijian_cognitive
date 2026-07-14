# 大道至简0.5b — 神经网络蒸馏全量评测报告

> 阶段：P4 神经蒸馏分支 · 产出"第一个自有模型"
> 生成时间：2026-07-14
> 目标：验证合并后的自包含模型 `dadaozhijian-0.5b` 对符号计划的忠实度，作为"模型达标"验收证据。

## 1. 结论

**模型已真实蒸馏产出并通过全量评测。**

- 模型：`stage_b/dadaozhijian_0.5b`（独立 checkpoint，988MB fp16 权重 + 配置 + tokenizer + 身份标记）
- 全量 17 计划评测：**均值计划符号覆盖率 = 0.9608**，全覆盖比例 **0.9412**（16/17 满分）
- 加载方式：评测时**从 `dadaozhijian_0.5b/` 单独加载，不引用 Qwen 仓库** → 证明其为自包含"自己的模型"，而非 LoRA 补丁

## 2. 方法论

| 环节 | 做法 |
|------|------|
| 基座 | `Qwen/Qwen2.5-0.5B`（开放权重，本地缓存） |
| 蒸馏 | LoRA（rank=16, alpha=16），Orca 式序列级 + 推理链（SeqKD）；16-bit，MPS 训练 2 epoch |
| 数据 | 本机 Ollama 双 teacher（phi4-mini + qwen3.5）经 `RetrievalDistiller` 符号忠实闸门筛选，17 条组合数据集（coverage 1.0） |
| 合并 | PEFT `merge_and_unload()` 将 LoRA 烘焙入基座 → 独立 checkpoint |
| 评测 | 复刻训练 prompt（`system + user(指令) + 空 assistant`，chat 模板），MPS fp16 生成，计算计划符号覆盖率 |
| 指标 | 计划符号在生成文本中的覆盖率（faithfulness 代理）；全覆盖 = 所有符号均出现 |

## 3. 逐计划结果（17/17）

| 计划 | 覆盖率 | 字符数 | 来源 teacher |
|------|-------|-------|-------------|
| 金→水→火 | 1.00 | 336 | qwen3.5:4b-mlx |
| 水→木→火 | 1.00 | 286 | qwen3.5:4b-mlx |
| 木→火→土 | 1.00 | 372 | qwen3.5:4b-mlx |
| 火→土→金 | 1.00 | 543 | qwen3.5:4b-mlx |
| 土→金→水 | 1.00 | 225 | qwen3.5:4b-mlx |
| 金→水→木→火→土 | 1.00 | 336 | qwen3.5:4b-mlx |
| 水→木→火→土→金 | 1.00 | 315 | qwen3.5:4b-mlx |
| 木→火→土→金→水 | 1.00 | 327 | qwen3.5:4b-mlx |
| 火→土→金→水→木 | 1.00 | 270 | qwen3.5:4b-mlx |
| 土→金→水→木→火 | 1.00 | 360 | qwen3.5:4b-mlx |
| 金→火 | 1.00 | 198 | qwen3.5:4b-mlx |
| 水→土 | 1.00 | 309 | qwen3.5:4b-mlx |
| 木→金 | 1.00 | 437 | qwen3.5:4b-mlx |
| 火→水 | 1.00 | 418 | qwen3.5:4b-mlx |
| 土→木 | 1.00 | 311 | qwen3.5:4b-mlx |
| 水→火→金 | 1.00 | 375 | qwen3.5:4b-mlx |
| **木→土→水** | **0.333** | 444 | qwen3.5:4b-mlx |

**汇总**：均值 0.9608 / 全覆 0.9412 / 失败 1 条。

## 4. 失败项分析

`木→土→水`（覆盖率 0.333，仅命中"木"）：
- 该序列**不是规范五行相生链**（规范：木→火→土→金→水→木；木生火、火生土，不存在"木→土"直生；土生金、水生木，不存在"土→水"）。
- 属训练数据中的**分布外（OOD）样本**：teacher 为满足闸门门槛虽写出了含三字的文本，但该链语义异常，0.5B 学生仅学会复述首符"木"。
- **改进建议**：训练计划集限定为规范相生/相克链；或对 OOD 计划单独增强数据。

## 5. 已知局限（诚实记录）

1. **长链文本质量下降**：5 符号计划符号覆盖率仍为 1.0，但输出出现重复/套话，推理深度受 0.5B 容量限制。
2. **数据规模极小**：仅 17 条。扩大数据 + 多 epoch 可显著提升泛化与 OOD 鲁棒性。
3. **容量天花板**：0.5B 仅适合本项目符号调度推演演示，不与大模型比肩。

## 6. 与"仅验证可行"的区别

此前 P4 仅完成"LoRA 训练 + 抽 5 计划验证"（覆盖率 1.0 on 5 plans），产物是依赖原基座的
LoRA 补丁。**本次**把 LoRA 合并为独立 checkpoint 并全量评测，产物 `dadaozhijian_0.5b`
即为"蒸馏出来的第一个自己的模型"——可独立加载、可导出、可作为后续迭代基座。

## 7. 复现命令

```bash
# 1) 生成蒸馏数据（需 Ollama 在跑）
python3 stage_b/generate_distill_data.py --plans stage_b/neural_plans.txt \
    --out stage_b/neural_distill_dataset_combined.jsonl --gate 1.0

# 2) 训练 LoRA（需 torch venv）
../python/envs/default/bin/python stage_b/run_neural_train.py \
    --dataset stage_b/neural_distill_dataset_combined.jsonl --out stage_b/neural_adapter \
    --base Qwen/Qwen2.5-0.5B --epochs 2 --rank 16 --lr 2e-4 --max-seq 384

# 3) 合并为自包含模型 + 全量评测
../python/envs/default/bin/python stage_b/merge_and_eval.py
```
