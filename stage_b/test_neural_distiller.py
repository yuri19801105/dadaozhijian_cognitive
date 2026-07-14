"""NeuralDistiller 单元测试（mock Ollama，离线、无需 torch）。

覆盖：符号覆盖闸门、指令构造、双 teacher 组合择优、低于闸门丢弃、JSONL 落盘。
真实训练（MPS + LoRA）由集成验证脚本单独跑，不在此处（避免重依赖/长时）。
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

from neural_distiller import (  # noqa: E402
    NeuralDistiller,
    build_instruction,
    symbol_coverage,
    generate_distillation_data,
    TEACHER_MODELS,
)


class SymbolCoverageTest(unittest.TestCase):
    def test_full_coverage(self):
        self.assertAlmostEqual(symbol_coverage("金→水→火", "金生水，水生火。"), 1.0)

    def test_partial_coverage(self):
        self.assertAlmostEqual(symbol_coverage("金→水→火", "金生水。"), 2 / 3)

    def test_empty_plan(self):
        self.assertEqual(symbol_coverage("", "任意文本"), 1.0)

    def test_build_instruction_contains_plan(self):
        instr = build_instruction("金→水→火")
        self.assertIn("金→水→火", instr)
        self.assertIn("reasoning", instr)


def _fake_call_side_effect(plan, faithful_teacher):
    """构造 call_teacher 的假实现：指定 teacher 返回含全部符号的回答。

    faithful 回答由 plan 符号动态拼出（保证覆盖全部符号）；
    另一 teacher 返回缺末符号的回答（覆盖不足，作为对照）。
    """
    syms = [s for s in plan.split("→") if s.strip()]
    faithful_text = "根据计划，" + "，".join(syms) + " 形成相生链条。"
    partial_text = "，".join(syms[:-1]) + "。" if len(syms) > 1 else "无。"

    def _fake(model, prompt, *a, **k):
        if model == faithful_teacher:
            return (faithful_text, True)
        return (partial_text, True)  # 缺末符号，覆盖不足
    return _fake


class DistillationDataTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.out = Path(self.tmp.name) / "ds.jsonl"

    def tearDown(self):
        self.tmp.cleanup()

    def test_selects_faithful_teacher(self):
        plan = "金→水→火"
        # phi 忠实、qwen 不忠实 → 应选 phi
        with patch(
            "neural_distiller.call_teacher",
            side_effect=_fake_call_side_effect(plan, "phi4-mini:3.8b"),
        ):
            stats = generate_distillation_data([plan], str(self.out), gate=1.0)
        self.assertEqual(stats["n_kept"], 1)
        self.assertEqual(stats["dropped"], 0)
        recs = [json.loads(l) for l in self.out.read_text(encoding="utf-8").splitlines()]
        self.assertEqual(len(recs), 1)
        self.assertEqual(recs[0]["teacher"], "phi4-mini:3.8b")
        self.assertEqual(recs[0]["coverage"], 1.0)
        self.assertIn("金", recs[0]["response"])
        self.assertIn("火", recs[0]["response"])

    def test_drops_below_gate(self):
        plan = "金→水→火"
        # 两 teacher 都只返回"金生水。"（缺火）→ 都低于 gate=1.0 → 丢弃
        with patch(
            "neural_distiller.call_teacher",
            return_value=("金生水。", True),
        ):
            stats = generate_distillation_data([plan], str(self.out), gate=1.0)
        self.assertEqual(stats["n_kept"], 0)
        self.assertEqual(stats["dropped"], 1)
        lines = self.out.read_text(encoding="utf-8").splitlines() if self.out.exists() else []
        self.assertEqual(len(lines), 0)

    def test_per_teacher_counted(self):
        plan = "木→火→土"
        with patch(
            "neural_distiller.call_teacher",
            side_effect=_fake_call_side_effect(plan, "qwen3.5:4b-mlx"),
        ):
            stats = generate_distillation_data([plan], str(self.out), gate=1.0)
        self.assertEqual(stats["per_teacher"]["phi4-mini:3.8b"], 1)
        self.assertEqual(stats["per_teacher"]["qwen3.5:4b-mlx"], 1)
        self.assertEqual(stats["n_kept"], 1)


class NeuralDistillerInterfaceTest(unittest.TestCase):
    def test_constructable(self):
        nd = NeuralDistiller(base_model="Qwen2.5-0.5B-Instruct", method="lora", lora_rank=16)
        self.assertEqual(nd.base_model, "Qwen2.5-0.5B-Instruct")
        self.assertEqual(nd.lora_rank, 16)

    def test_train_without_torch_raises(self):
        nd = NeuralDistiller(base_model="Qwen2.5-0.5B-Instruct")
        with self.assertRaises(RuntimeError):
            nd.train("missing.jsonl", ".")


if __name__ == "__main__":
    unittest.main(verbosity=2)
