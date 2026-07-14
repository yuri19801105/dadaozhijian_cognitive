"""阶段 B 入口：串联 数据加载 -> 训练 -> faithfulness 评估 -> 导出 -> 报告。

运行:
  python3 stage_b/main.py                      # 默认检索式蒸馏(lora)
  python3 stage_b/main.py --method neural      # 接入自有模型「大道至简0.5b」
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

# 确保 stage_b/ 在 sys.path 上，使包内绝对导入（from config import ...）可用。
sys.path.insert(0, str(Path(__file__).resolve().parent))

from config import StageBConfig, load_config  # noqa: E402
from data_loader import load_pairs, load_lineage, split_train_eval  # noqa: E402
from trainer import select_method, train  # noqa: E402
from faithfulness_eval import evaluate, meets_threshold, bootstrap_ci  # noqa: E402
from exporter import export_model, write_lineage_map  # noqa: E402
from batch_runner import collect_ledger, summarize  # noqa: E402
from report_generator import generate  # noqa: E402
from backend_shim import load_model, generate as shim_generate  # noqa: E402
from utils import get_logger, ensure_dir  # noqa: E402


def main(argv=None) -> int:
    """阶段 B 蒸馏管线主流程（自包含闭环：含纯标准库蒸馏 + 后端替代）。

    Args:
        argv: 命令行参数（默认取 sys.argv[1:]，便于测试注入）。
    Returns:
        进程退出码（0 表示整条蒸馏闭环跑通）。
    """
    ap = argparse.ArgumentParser(description="阶段 B 蒸馏管线")
    ap.add_argument(
        "--method", choices=["sft", "lora", "neural"], default=None,
        help="覆盖配置中的训练方法（默认用 StageBConfig.method）",
    )
    args = ap.parse_args(argv)

    log = get_logger("stage_b.main")
    cfg = load_config()
    if args.method:
        cfg.method = args.method
    ensure_dir(cfg.output_dir)
    log.info("阶段 B 蒸馏闭环启动; base=%s method=%s", cfg.base_model, cfg.method)

    # 1) 确保 ledger 已收集（骨架：仅打印意图，不实际调 Mojo）
    added = collect_ledger(cfg)
    log.info("ledger 新增记录(占位): %d", added)

    # 2) 加载训练对 + 血缘
    pairs = load_pairs(cfg)
    lineage = load_lineage(cfg)
    log.info("训练对: %d, 血缘记录: %d", len(pairs), len(lineage))

    # 3) 切分（按配置比例 + 最小验证集下限，保证评估稳健）
    train_pairs, eval_pairs = split_train_eval(pairs, cfg.eval_ratio, cfg.eval_pairs_min)

    # 4) 训练（真实落盘自蒸馏模型 distilled_model.json）
    method = select_method(cfg)
    artifact = train(cfg, train_pairs, eval_pairs)
    log.info("训练方法: %s, 产物路径: %s", method, artifact)

    # 5) 加载蒸馏模型，用其生成输出做忠实度评估（蒸馏后模式）
    neural_eval = None
    if cfg.method == "neural":
        # 自有模型「大道至简0.5b」：从自包含合并目录独立加载，不引用原基座仓库
        from dadaozhijian_model import DadaozhijianModel, load_neural_eval_pairs
        distilled = DadaozhijianModel(model_dir=str(cfg.neural_merged_dir))
        # 自有模型的验证集 = 其蒸馏数据集的 28 个符号计划
        neural_eval = load_neural_eval_pairs()
        # 报告归因：用自有模型身份名覆盖默认 sft 基座名
        cfg.base_model = "%s (%s, %s)" % (
            distilled.display_name, distilled.identity.get("base_model", "Qwen2.5-0.5B"),
            distilled.identity.get("params", "0.5B"),
        )
        log.info("加载自有模型: %s (设备=%s)", distilled.display_name, distilled.device)
    else:
        distilled = load_model(cfg)
    if distilled is None:
        log.warning("未加载到蒸馏模型，回退为数据质量门模式")
    if cfg.method == "neural" and neural_eval is not None:
        # 神经模型生成昂贵，跳过 200 次 bootstrap（faithfulness 为确定性词元覆盖）
        metrics = distilled.evaluate(neural_eval)
        ci = None
    else:
        metrics = evaluate(cfg, eval_pairs, distilled)
        ci = bootstrap_ci(cfg, eval_pairs, distilled)
    ok = meets_threshold(metrics, cfg)
    if ci is not None:
        log.info("faithfulness=%.3f 达标=%s | bootstrap CI=[%.3f, %.3f]",
                 metrics.get("faithfulness", 0.0), ok, ci["lo"], ci["hi"])
    else:
        log.info("faithfulness=%.3f 达标=%s（神经模型跳过 bootstrap）",
                 metrics.get("faithfulness", 0.0), ok)

    # 6) 导出 + 溯源（导出可加载的自蒸馏模型，替代外部 LLM 后端）
    model_dir = export_model(cfg, artifact)
    map_path = write_lineage_map(cfg, metrics)

    # 7) 后端替代演示：用蒸馏模型（而非 Ollama）渲染一个符号计划
    demo_plan = "金→水→火"
    if cfg.method == "neural" and distilled is not None:
        demo_text = distilled.generate(demo_plan)
        log.info("神经蒸馏(自有模型)后端渲染 [%s] -> %s", demo_plan, demo_text)
    else:
        demo_text = shim_generate(cfg, demo_plan)
        log.info("蒸馏后端渲染 [%s] -> %s", demo_plan, demo_text)

    # 8) 报告
    stats = summarize(cfg)
    report_path = generate(cfg, metrics, stats, ci)
    log.info("蒸馏闭环完成; 模型目录=%s; 报告=%s", model_dir, report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
