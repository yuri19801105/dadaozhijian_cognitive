"""神经蒸馏训练运行器（验证用）：加载已生成的蒸馏数据集，MPS 上 LoRA 训练 Qwen2.5-0.5B。

用于 P4 真实小批量验证，复用 generate_distill_data.py 已产出的数据集，避免重复调 Ollama。

用法（用已装 torch 的 venv python 运行）：
  ../python/envs/default/bin/python run_neural_train.py \
      --dataset neural_distill_dataset.jsonl \
      --out neural_adapter \
      --base Qwen2.5-0.5B-Instruct --epochs 2 --rank 16 --lr 2e-4 --max-seq 384

评估：对若干符号计划生成并报告计划符号覆盖率（faithfulness 代理）。
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from neural_distiller import NeuralDistiller  # noqa: E402
from utils import get_logger, read_jsonl  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description="神经蒸馏 LoRA 训练（MPS）")
    ap.add_argument("--dataset", default="neural_distill_dataset.jsonl")
    ap.add_argument("--out", default="neural_adapter")
    ap.add_argument("--base", default="Qwen/Qwen2.5-0.5B")
    ap.add_argument("--epochs", type=int, default=2)
    ap.add_argument("--rank", type=int, default=16)
    ap.add_argument("--lr", type=float, default=2.0e-4)
    ap.add_argument("--max-seq", type=int, default=384)
    args = ap.parse_args()

    log = get_logger("stage_b.run_neural_train")
    recs = read_jsonl(args.dataset)
    if not recs:
        log.error("数据集为空: %s", args.dataset)
        return 1
    log.info("加载数据集: %d 条", len(recs))

    nd = NeuralDistiller(
        base_model=args.base, method="lora",
        lora_rank=args.rank, max_epochs=args.epochs,
        learning_rate=args.lr, max_seq_length=args.max_seq,
    )
    adapter = nd.train(args.dataset, args.out)
    log.info("训练完成，adapter: %s", adapter)

    # 评估：对数据集里的计划做生成 + 符号覆盖
    from faithfulness_eval import _plan_symbols
    plans = [r["plan"] for r in recs if r.get("plan")][:5]
    ok = 0
    for p in plans:
        try:
            out = nd.generate(p)
        except Exception as e:  # 生成异常不阻断评估
            log.warning("generate(%s) 失败: %s", p, e)
            continue
        syms = _plan_symbols(p)
        cov = sum(1 for s in syms if s in out) / len(syms) if syms else 1.0
        ok += cov
        log.info("eval plan=[%s] coverage=%.2f | 输出前60字: %s", p, cov, out[:60].replace("\n", " "))
    if plans:
        log.info("平均计划符号覆盖率(学生): %.3f / %d 计划", ok / len(plans), len(plans))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
