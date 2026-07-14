"""蒸馏数据集生成 CLI：用本机 Ollama 双 teacher 生成并忠实闸门筛选。

用法（在 stage_b/ 目录或任意位置，脚本自动把自身目录加入 sys.path）：
  python3 generate_distill_data.py \
      --plans plans.txt \        # 每行一个符号计划，如 "金→水→火"
      --out distill_dataset.jsonl \
      --gate 1.0

若不传 --plans，则从 stage_b 配置的侧车 ledger 中抽取 plan 列表。

仅训练期使用 Ollama（localhost:11434），运行时无需。
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

# 确保 stage_b/ 在 sys.path 上（支持 from config import ...）
sys.path.insert(0, str(Path(__file__).resolve().parent))

from config import load_config  # noqa: E402
from data_loader import load_pairs  # noqa: E402
from neural_distiller import generate_distillation_data, TEACHER_MODELS  # noqa: E402
from utils import get_logger  # noqa: E402


def _read_plans(path: str) -> list[str]:
    return [ln.strip() for ln in Path(path).read_text(encoding="utf-8").splitlines()
            if ln.strip()]


def main() -> int:
    ap = argparse.ArgumentParser(description="生成神经蒸馏数据集（双 teacher + 忠实闸门）")
    ap.add_argument("--plans", help="计划文件（每行一个符号计划）；缺省从 ledger 抽取")
    ap.add_argument("--out", default="distill_dataset.jsonl", help="输出 JSONL")
    ap.add_argument("--gate", type=float, default=1.0, help="符号覆盖率门槛(0~1)")
    ap.add_argument("--teachers", default=",".join(TEACHER_MODELS),
                    help="teacher 模型名，逗号分隔")
    ap.add_argument("--temperature", type=float, default=0.3)
    ap.add_argument("--max-tokens", type=int, default=512)
    ap.add_argument("--timeout", type=float, default=90.0)
    args = ap.parse_args()

    log = get_logger("stage_b.generate_distill_data")
    cfg = load_config()

    if args.plans:
        plans = _read_plans(args.plans)
    else:
        pairs = load_pairs(cfg)
        plans = [p["plan"] for p in pairs if p.get("plan")]
    log.info("待生成计划数: %d", len(plans))

    teachers = [t.strip() for t in args.teachers.split(",") if t.strip()]
    stats = generate_distillation_data(
        plans, args.out,
        teachers=teachers, gate=args.gate,
        temperature=args.temperature, max_tokens=args.max_tokens, timeout=args.timeout,
    )
    log.info("完成: 保留 %d / 丢弃 %d / 总 %d | 每 teacher 调用 %s",
             stats["n_kept"], stats["dropped"], stats["n_total"], stats["per_teacher"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
