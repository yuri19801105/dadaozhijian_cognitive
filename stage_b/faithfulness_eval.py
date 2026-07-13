"""Faithfulness 评估：衡量蒸馏模型输出对符号化计划的忠实度。

对照总纲"无黑箱·可溯源"：每条输出须可追溯到原始符号计划。
"""
from __future__ import annotations

from typing import Dict, List, Any

from config import StageBConfig


def evaluate(
    cfg: StageBConfig,
    eval_pairs: List[Dict[str, str]],
    distilled_artifact: Any,
) -> Dict[str, float]:
    """评估蒸馏模型在验证集上的 faithfulness 指标。

    Args:
        cfg: 阶段 B 配置（含 faithfulness_threshold）。
        eval_pairs: 验证对（含 plan 与参考 response）。
        distilled_artifact: 蒸馏产物（训练产出）。
    Returns:
        指标字典，含 'faithfulness'（0~1）、'coverage' 等。
    """
    # 骨架占位：真实实现比对蒸馏输出与符号计划/参考响应，计算忠实度。
    return {"faithfulness": 0.0, "coverage": 0.0}


def meets_threshold(metrics: Dict[str, float], cfg: StageBConfig) -> bool:
    """判定是否达到下线外部模型的门槛。

    Args:
        metrics: evaluate 产出的指标字典。
        cfg: 阶段 B 配置（含 faithfulness_threshold）。
    Returns:
        True 表示达标，可进入切换下线流程。
    """
    return metrics.get("faithfulness", 0.0) >= cfg.faithfulness_threshold
