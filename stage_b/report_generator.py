"""报告生成：输出阶段 B 对比结果与 faithfulness 指标。

骨架定义报告结构与写出接口占位。
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List

from config import StageBConfig


def generate(
    cfg: StageBConfig,
    metrics: Dict[str, float],
    stats: Dict[str, Any],
) -> Path:
    """生成阶段 B 评估报告（Markdown）。

    Args:
        cfg: 阶段 B 配置（report_path）。
        metrics: faithfulness 评估指标。
        stats: ledger 汇总统计。
    Returns:
        报告文件路径。
    """
    # 骨架占位：真实实现写出 Markdown，含 训练对规模 / 相位覆盖 /
    # faithfulness 曲线 / 与外部模型(plan 维度)的对比表。
    print("[report_generator] 拟写出报告: %s （骨架占位）" % cfg.report_path)
    return cfg.report_path
