# stage_b/ — 阶段 B 专属小模型蒸馏管线（骨架基线 v0.1）
# 语义重映射（对照原"校对/diff"方案）：
#   diff_engine        -> data_loader        （ledger -> (plan,response) 训练对）
#   strategy_selector  -> trainer            （选择并执行 SFT/LoRA 蒸馏）
#   diff_formatter     -> faithfulness_eval （衡量输出对符号计划的忠实度）
#   report_generator   -> 保留（评估报告）
#   + exporter         （导出蒸馏产物 + 溯源映射）
# 运行: python3 stage_b/main.py
