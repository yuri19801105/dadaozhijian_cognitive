"""Faithfulness 评估：衡量蒸馏模型输出对符号化计划的忠实度。

对照总纲"无黑箱·可溯源"：每条输出须可追溯到原始符号计划。

    真实实现（v0.3）：
  evaluate 支持两种模式（对照总纲"无黑箱·可溯源"）：
    (a) 数据质量门（蒸馏前）：distilled_artifact 为 None 时，衡量 ledger 中
        参考 response 对符号计划的词元覆盖（确定性代理指标）。
    (b) 蒸馏后忠实度：distilled_artifact 为具备 generate() 的蒸馏模型时，
        用模型自身生成输出，再比对符号计划的词元覆盖——这才是「蒸馏模型
        输出对原始符号计划」的真实忠实度，可完全复现、无黑箱。
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
        distilled_artifact: 蒸馏产物。若为具备 generate() 的模型，则用模型
            生成输出做忠实度比对（蒸馏后模式）；否则衡量 ledger 参考 response
            对计划的覆盖（数据质量门模式）。
    Returns:
        指标字典：'faithfulness'（0~1，计划词元平均覆盖率）、
        'coverage'（0~1，响应非空且至少覆盖一个计划词元之比）、
        'n'（参与评估的验证对数）。
    """
    use_model = distilled_artifact is not None and hasattr(distilled_artifact, "generate")
    if not eval_pairs:
        return {"faithfulness": 0.0, "coverage": 0.0, "n": 0.0}
    total_cov = 0.0
    covered = 0
    for p in eval_pairs:
        plan = p.get("plan", "")
        if use_model:
            response = distilled_artifact.generate(plan)
        else:
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


def bootstrap_ci(
    cfg: StageBConfig,
    eval_pairs: List[Dict[str, str]],
    distilled_artifact: Any,
    n: int = 200,
    seed: int = 0,
) -> Dict[str, float]:
    """对 faithfulness 估计做 bootstrap 置信区间（评估统计稳健性）。

    通过对验证集有放回重采样 n 次，估计 faithfulness 的均值与 95% 区间。
    纯标准库（仅用 hash(plan) 做确定性伪随机），无第三方依赖。

    Args:
        cfg: 阶段 B 配置。
        eval_pairs: 验证对。
        distilled_artifact: 蒸馏模型（具备 generate）或 None（数据质量门）。
        n: bootstrap 重采样次数。
        seed: 确定性随机种子（保证结果可复现）。
    Returns:
        {'mean': float, 'lo': float, 'hi': float, 'n': float}
    """
    import random
    if not eval_pairs:
        return {"mean": 0.0, "lo": 0.0, "hi": 0.0, "n": 0.0}
    rng = random.Random(seed)
    scores = []
    for _ in range(n):
        sample = [rng.choice(eval_pairs) for _ in range(len(eval_pairs))]
        m = evaluate(cfg, sample, distilled_artifact)
        scores.append(m["faithfulness"])
    scores.sort()
    mean = sum(scores) / len(scores)
    lo = scores[max(0, int(0.025 * len(scores)))]
    hi = scores[min(len(scores) - 1, int(0.975 * len(scores)))]
    return {"mean": mean, "lo": lo, "hi": hi, "n": float(n)}
