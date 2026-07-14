"""报告生成：输出阶段 B 对比结果与 faithfulness 指标。

真实实现（v0.2）：依据配置、faithfulness 指标与 ledger 统计，写出
结构化 Markdown 评估报告到 cfg.report_path。接口与空壳一致。
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict

from config import StageBConfig
from utils import write_text, ensure_dir


def generate(
    cfg: StageBConfig,
    metrics: Dict[str, float],
    stats: Dict[str, Any],
    ci: Dict[str, float] = None,
) -> Path:
    """生成阶段 B 评估报告（Markdown）。

    Args:
        cfg: 阶段 B 配置（report_path）。
        metrics: faithfulness 评估指标（含 faithfulness / coverage / n）。
        stats: ledger 汇总统计（含 counts / ok / degraded / phase_dist /
               backends / degraded_rate）。
        ci: 可选 bootstrap 置信区间（含 lo / hi / mean / n）。
    Returns:
        报告文件路径。
    """
    faith = metrics.get("faithfulness", 0.0)
    coverage = metrics.get("coverage", 0.0)
    n_eval = int(metrics.get("n", 0) or 0)
    passed = faith >= cfg.faithfulness_threshold

    counts = stats.get("counts", 0)
    ok = stats.get("ok", 0)
    degraded = stats.get("degraded", 0)
    phase_dist = stats.get("phase_dist", {}) or {}
    backends = stats.get("backends", {}) or {}
    degraded_rate = stats.get("degraded_rate", 0.0)

    phase_lines = "\n".join(
        "- 相位 %s : %d 次" % (k, v) for k, v in sorted(phase_dist.items())
    ) or "- (无)"
    backend_lines = "\n".join(
        "- %s : %d 次" % (k, v) for k, v in sorted(backends.items())
    ) or "- (无)"

    status = "✅ 达标（可进入下线外部模型流程）" if passed else "⚠️ 未达标（保持外部后端）"
    ci_line = ""
    if ci:
        ci_line = (
            "- faithfulness bootstrap 95%% 置信区间: **[%.3f, %.3f]**"
            "（重采样 %d 次，mean=%.3f）\n"
            % (ci.get("lo", 0.0), ci.get("hi", 0.0), int(ci.get("n", 0) or 0), ci.get("mean", 0.0))
        )

    md = (
        "# 阶段 B 蒸馏管线评估报告\n\n"
        "## 运行配置\n"
        "- 基座模型: `%s`\n"
        "- 训练方法: `%s` (LoRA rank=%d)\n"
        "- 训练轮数: %d | 学习率: %.1e\n"
        "- faithfulness 达标阈值: %.2f\n\n"
        "## Ledger 数据质量\n"
        "- 侧车调用总数: %d（成功 %d / 降级 %d）\n"
        "- 降级率: %.3f\n"
        "- 后端分布:\n%s\n"
        "- 相位分布:\n%s\n\n"
        "## Faithfulness 评估\n"
        "- 验证对数量: %d\n"
        "- faithfulness（计划词元覆盖率）: **%.3f**\n"
        "- coverage（有效覆盖比例）: %.3f\n"
        "%s"
        "- 结论: %s\n\n"
        "> 说明：faithfulness 为「蒸馏模型输出对符号化计划的确定性词元覆盖」指标"
        "（纯标准库、无黑箱、可溯源），已接入真实蒸馏模型（RetrievalDistiller）；"
        "达标即可下线外部 LLM 后端，由自蒸馏小模型替代。\n"
    ) % (
        cfg.base_model,
        cfg.method,
        cfg.lora_rank,
        cfg.max_epochs,
        cfg.learning_rate,
        cfg.faithfulness_threshold,
        counts,
        ok,
        degraded,
        degraded_rate,
        backend_lines,
        phase_lines,
        n_eval,
        faith,
        coverage,
        ci_line,
        status,
    )

    ensure_dir(str(cfg.report_path.parent))
    write_text(str(cfg.report_path), md)
    print("[report_generator] 已写出报告: %s" % cfg.report_path)
    return cfg.report_path
