"""合并 LoRA → 独立模型「大道至简0.5b」，并做全量忠实度评测。

设计目标：把 Qwen/Qwen2.5-0.5B 基座 + 我们的 LoRA 增量融为一个
**自包含 checkpoint**（stage_b/dadaozhijian_0.5b/），它不再依赖原基座
仓库即可单独加载——这才算"蒸馏出来的第一个自己的模型"。

流程：
  1) merge()：CPU 上 load 基座(fp16) + PeftModel.load_adapter → merge_and_unload
            → save_pretrained 到 dadaozhijian_0.5b/（含 config/tokenizer/权重）
  2) evaluate()：从 dadaozhijian_0.5b/ **独立**重新加载（不碰 Qwen 仓库），
            对 neural_distill_dataset_combined.jsonl 全部 17 条计划生成，
            复刻训练 prompt 格式，计算计划符号覆盖率（faithfulness 代理）。

用法（用已装 torch 的 venv 运行）：
  ../python/envs/default/bin/python merge_and_eval.py            # 合并+评测
  ../python/envs/default/bin/python merge_and_eval.py --skip-merge  # 仅评测
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from utils import get_logger, read_jsonl  # noqa: E402
from faithfulness_eval import _plan_symbols  # noqa: E402
from neural_distiller import (  # noqa: E402
    NeuralDistiller, build_instruction,
)

ADAPTER = "neural_adapter/adapter"
MERGED = "dadaozhijian_0.5b"
BASE = "Qwen/Qwen2.5-0.5B"


def merge() -> None:
    torch, transformers, peft = NeuralDistiller._ensure_torch()
    from transformers import AutoModelForCausalLM, AutoTokenizer
    from peft import PeftModel

    log = get_logger("stage_b.merge")
    log.info("加载基座 %s (CPU 合并, fp16)", BASE)
    base = AutoModelForCausalLM.from_pretrained(BASE, torch_dtype=torch.float16)
    tok = AutoTokenizer.from_pretrained(ADAPTER)
    model = PeftModel.from_pretrained(base, ADAPTER)

    log.info("merge_and_unload：将 LoRA 增量烘焙进基座权重")
    model = model.merge_and_unload()

    out = Path(MERGED)
    out.mkdir(parents=True, exist_ok=True)
    model.save_pretrained(str(out))
    tok.save_pretrained(str(out))

    # 身份标记：声明这是自包含模型
    identity = {
        "model_id": "dadaozhijian-0.5b",
        "display_name": "大道至简0.5b",
        "base_model": BASE,
        "method": "LoRA 蒸馏（Orca 式序列级 + 推理链 SeqKD，由 RetrievalDistiller 计划符号闸门过滤）",
        "merged_from": ADAPTER,
        "params": "0.5B",
        "note": "独立 checkpoint：LoRA 已合并入基座，无需原基座仓库即可加载。",
        "created_by": "stage_b/merge_and_eval.py",
    }
    (out / "dadaozhijian_identity.json").write_text(
        json.dumps(identity, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    log.info("自包含模型已保存 -> %s（%d 文件）", out, len(list(out.iterdir())))


def _generate_standalone(plan: str, tok, model, max_new_tokens: int = 256) -> str:
    """复刻训练 prompt 格式，从独立模型生成（不引用 Qwen 仓库）。"""
    prompt = NeuralDistiller._format_text(build_instruction(plan), "", tok)
    inputs = tok(prompt, return_tensors="pt").to(model.device)
    out = model.generate(
        **inputs, max_new_tokens=max_new_tokens, do_sample=False, temperature=1.0
    )
    return tok.decode(out[0][inputs["input_ids"].shape[1]:], skip_special_tokens=True)


def evaluate(max_new_tokens: int = 256) -> dict:
    torch, transformers, peft = NeuralDistiller._ensure_torch()
    from transformers import AutoModelForCausalLM, AutoTokenizer

    log = get_logger("stage_b.eval")
    recs = read_jsonl("neural_distill_dataset_combined.jsonl")
    if not recs:
        log.error("数据集为空")
        raise SystemExit(1)

    # 关键：从合并目录独立加载，证明不依赖原基座仓库
    tok = AutoTokenizer.from_pretrained(MERGED)
    model = AutoModelForCausalLM.from_pretrained(
        MERGED, torch_dtype=torch.float16
    ).to("mps")
    model.eval()

    results = []
    for r in recs:
        plan = r.get("plan", "")
        t0 = time.time()
        text = _generate_standalone(plan, tok, model, max_new_tokens)
        dt = time.time() - t0
        syms = _plan_symbols(plan)
        cov = sum(1 for s in syms if s in text) / len(syms) if syms else 1.0
        results.append({
            "plan": plan,
            "teacher": r.get("teacher"),
            "coverage": round(cov, 3),
            "gen_chars": len(text),
            "sec": round(dt, 2),
            "preview": text[:80].replace("\n", " "),
        })
        log.info("plan=[%s] cov=%.2f chars=%d (%.2fs) | %s",
                 plan, cov, len(text), dt, text[:50].replace("\n", " "))

    mean_cov = sum(x["coverage"] for x in results) / len(results)
    full_cov = sum(1 for x in results if x["coverage"] >= 0.999) / len(results)
    report = {
        "model": "dadaozhijian-0.5b",
        "base_model": BASE,
        "n": len(results),
        "mean_coverage": round(mean_cov, 4),
        "full_coverage_rate": round(full_cov, 4),
        "max_new_tokens": max_new_tokens,
        "per_plan": results,
    }
    Path(MERGED).mkdir(parents=True, exist_ok=True)
    (Path(MERGED) / "faithfulness_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    log.info("=== 大道至简0.5b 全量评测：均值覆盖率=%.4f，全覆盖比例=%.4f / %d 计划 ===",
             mean_cov, full_cov, len(results))
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description="合并 LoRA → 大道至简0.5b 并全量评测")
    ap.add_argument("--skip-merge", action="store_true", help="跳过合并，仅评测已存在的合并模型")
    ap.add_argument("--max-new-tokens", type=int, default=256)
    args = ap.parse_args()

    if not args.skip_merge:
        merge()
    evaluate(args.max_new_tokens)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
