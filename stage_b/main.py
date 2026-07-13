"""阶段 B 入口：串联 数据加载 -> 训练 -> faithfulness 评估 -> 导出 -> 报告。

当前为骨架基线：各模块仅打印调用流程，不执行真实训练。
运行: python3 stage_b/main.py
"""
from __future__ import annotations

import sys
from pathlib import Path

# 确保 stage_b/ 在 sys.path 上，使包内绝对导入（from config import ...）可用。
sys.path.insert(0, str(Path(__file__).resolve().parent))

from config import StageBConfig, load_config  # noqa: E402
from data_loader import load_pairs, load_lineage, split_train_eval  # noqa: E402
from trainer import select_method, train  # noqa: E402
from faithfulness_eval import evaluate, meets_threshold  # noqa: E402
from exporter import export_model, write_lineage_map  # noqa: E402
from batch_runner import collect_ledger, summarize  # noqa: E402
from report_generator import generate  # noqa: E402
from utils import get_logger, ensure_dir  # noqa: E402


def main() -> int:
    """阶段 B 蒸馏管线主流程（骨架基线）。

    Returns:
        进程退出码（0 表示骨架调用链跑通）。
    """
    log = get_logger("stage_b.main")
    cfg = load_config()
    ensure_dir(cfg.output_dir)
    log.info("阶段 B 骨架基线启动; base=%s method=%s", cfg.base_model, cfg.method)

    # 1) 确保 ledger 已收集（骨架：仅打印意图，不实际调 Mojo）
    added = collect_ledger(cfg)
    log.info("ledger 新增记录(占位): %d", added)

    # 2) 加载训练对 + 血缘
    pairs = load_pairs(cfg)
    lineage = load_lineage(cfg)
    log.info("训练对(占位): %d, 血缘记录(占位): %d", len(pairs), len(lineage))

    # 3) 切分
    train_pairs, eval_pairs = split_train_eval(pairs)

    # 4) 训练
    method = select_method(cfg)
    artifact = train(cfg, train_pairs, eval_pairs)
    log.info("训练方法: %s, 产物路径: %s", method, artifact)

    # 5) faithfulness 评估
    metrics = evaluate(cfg, eval_pairs, artifact)
    ok = meets_threshold(metrics, cfg)
    log.info("faithfulness=%.3f 达标=%s", metrics.get("faithfulness", 0.0), ok)

    # 6) 导出 + 溯源
    model_dir = export_model(cfg, artifact)
    map_path = write_lineage_map(cfg, metrics)

    # 7) 报告
    stats = summarize(cfg)
    report_path = generate(cfg, metrics, stats)

    log.info("骨架基线完成; 产物目录=%s; 报告=%s", model_dir, report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
