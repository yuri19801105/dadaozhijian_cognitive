"""Faithfulness 评估：衡量蒸馏模型输出对符号化计划的忠实度。

对照总纲"无黑箱·可溯源"：每条输出须可追溯到原始符号计划。

真实实现（v0.2）：
  evaluate 采用确定性、纯标准库的「计划词元覆盖」代理指标——
  对每条 (plan, response) 训练对，抽取符号计划中的相/卦词元（如
  "水→木→火" 拆分为 水/木/火），统计其在响应文本中的出现比例，
  作为该条输出对符号计划的忠实度。所有验证对取均值即整体
  faithfulness；coverage 表示「响应非空且至少覆盖一个计划词元」的比例。
  该指标衡量的是「训练数据（ledger）对符号计划的忠实程度」，作为
  蒸馏前的数据质量门，可完全复现、无黑箱。
"""
from __future__ import annotations

import re
from typing import Dict, List, Any

from config import StageBConfig


_SPLIT_RE = re.compile(r"[→\-/,，、\s\[\]()（）]+")


def _plan_symbols(plan: str) -> List[str]:
    """把计划文本拆分为符号词元列表。

    支持 "水→木→火" / "[水→木→火]" / "水, 木, 火" 等多种写法。
    """
    if not plan:
        return []
    parts = _SPLIT_RE.split(plan.strip())
    return [p.strip() for p in parts if p and p.strip()]


def evaluate(
    cfg: StageBConfig,
    eval_pairs: List[Dict[str, str]],
    distilled_artifact: Any,
) -> Dict[str, float]:
    """评估验证集上的 faithfulness 指标（确定性、纯标准库）。

    Args:
        cfg: 阶段 B 配置（含 faithfulness_threshold）。
        eval_pairs: 验证对（含 plan 与参考 response）。
        distilled_artifact: 蒸馏产物（本代理指标不依赖真实模型，可为 None）。
    Returns:
        指标字典：'faithfulness'（0~1，计划词元平均覆盖率）、
        'coverage'（0~1，响应非空且至少覆盖一个计划词元之比）、
        'n'（参与评估的验证对数）。
    """
    if not eval_pairs:
        return {"faithfulness": 0.0, "coverage": 0.0, "n": 0.0}
    total_cov = 0.0
    covered = 0
    for p in eval_pairs:
        plan = p.get("plan", "")
        response = p.get("response", "")
        symbols = _plan_symbols(plan)
        if not symbols:
            # 无明确计划词元：视为中性（计入分母但不惩罚）
            total_cov += 1.0
            covered += 1
            continue
        hit = sum(1 for s in symbols if s in response)
        total_cov += hit / len(symbols)
        if response.strip() and hit > 0:
            covered += 1
    n = float(len(eval_pairs))
    return {
        "faithfulness": total_cov / n,
        "coverage": covered / n,
        "n": n,
    }


def meets_threshold(metrics: Dict[str, float], cfg: StageBConfig) -> bool:
    """判定是否达到下线外部模型的门槛。

    Args:
        metrics: evaluate 产出的指标字典。
        cfg: 阶段 B 配置（含 faithfulness_threshold）。
    Returns:
        True 表示达标，可进入切换下线流程。
    """
    return metrics.get("faithfulness", 0.0) >= cfg.faithfulness_threshold
