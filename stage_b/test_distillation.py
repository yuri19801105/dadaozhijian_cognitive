"""阶段 B 蒸馏闭环 TDD 测试（纯标准库检索式蒸馏器 + 预留神经网络分支）。

设计要点：
  - 蒸馏闭环目标：从 ledger 的 (plan, response) 训练对，学出一个「确定性检索
    + 符号插值」渲染器（RetrievalDistiller），可 save/load，并作为 Ollama 后端
    的自包含替代（backend_shim）。
  - NeuralDistiller 为预留分支（真实 SFT/LoRA），接口与 RetrievalDistiller 对齐，
    当前 train/train_torch 抛 NotImplementedError，待训练栈就绪平滑替换。
  - 全流程经 trainer 落盘 distilled_model.json -> exporter 导出可加载模型 ->
    backend_shim 生成 -> faithfulness_eval 用模型输出对符号计划做忠实度比对。
运行: python3 stage_b/test_distillation.py
"""
from __future__ import annotations

import sys
import json
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

# 蒸馏闭环核心模块（RED 阶段尚未实现 -> import 失败即 RED）
from config import load_config  # noqa: E402
from distilled_model import (  # noqa: E402
    RetrievalDistiller,
    NeuralDistiller,
    DEFAULT_MODEL_FILENAME,
)
from backend_shim import generate as shim_generate, load_model as shim_load  # noqa: E402
from trainer import train as trainer_train  # noqa: E402
from exporter import export_model  # noqa: E402
from faithfulness_eval import evaluate  # noqa: E402
from utils import read_jsonl, write_jsonl  # noqa: E402


def _make_fixtures(d: Path):
    sidecar = d / "sidecar_calls.jsonl"
    write_jsonl(
        str(sidecar),
        [
            {
                "call_id": "a1", "backend": "qwen3-4b-mlx", "ok": 1, "degraded": 0,
                "prompt": "phase=0 intensity=1 confidence=55% policy=0 plan=[水→木→火]",
                "response": "水 木 火 三相皆已解读",
            },
            {
                "call_id": "a2", "backend": "qwen3-4b-mlx", "ok": 1, "degraded": 0,
                "prompt": "phase=1 intensity=3 confidence=55% policy=0 plan=[木→火→土]",
                "response": "木 火 土 流转已明",
            },
            {
                "call_id": "b1", "backend": "phi-4-mini", "ok": 1, "degraded": 1,
                "prompt": "phase=2 plan=[金→水]", "response": "降级不应入选",
            },
        ],
    )
    return sidecar


class RetrievalDistillerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = Path(self.tmp.name)
        sidecar = _make_fixtures(self.d)
        self.cfg = load_config({
            "ledger_sidecar": sidecar,
            "output_dir": self.d / "artifacts",
        })
        self.pairs = [
            {"plan": "水→木→火", "response": "水 木 火 三相皆已解读", "call_id": "a1"},
            {"plan": "木→火→土", "response": "木 火 土 流转已明", "call_id": "a2"},
        ]

    def tearDown(self):
        self.tmp.cleanup()

    def test_train_builds_index(self):
        dist = RetrievalDistiller(base_model="Qwen3-1.7B", method="retrieval")
        ret = dist.train(self.pairs)
        # 返回自身以支持链式调用
        self.assertIs(ret, dist)

    def test_generate_adapts_symbols(self):
        dist = RetrievalDistiller().train(self.pairs)
        # 给一个未见过但符号相似的新计划，应检索最相近并替换符号
        out = dist.generate("金→水→火")
        self.assertIsInstance(out, str)
        self.assertTrue(out.strip())
        # 新计划符号应全部出现在输出中（符号插值渲染）
        for sym in ["金", "水", "火"]:
            self.assertIn(sym, out)

    def test_save_load_roundtrip(self):
        dist = RetrievalDistiller(base_model="Qwen3-1.7B").train(self.pairs)
        path = self.d / "distilled_model.json"
        dist.save(str(path))
        self.assertTrue(path.exists())
        loaded = RetrievalDistiller.load(str(path))
        self.assertEqual(loaded.base_model, "Qwen3-1.7B")
        out1 = dist.generate("金→水→火")
        out2 = loaded.generate("金→水→火")
        self.assertEqual(out1, out2)

    def test_faithfulness_of_generated(self):
        dist = RetrievalDistiller().train(self.pairs)
        # 用模型生成输出，再对符号计划做忠实度比对
        m = dist.faithfulness([
            {"plan": "金→水→火", "call_id": "x"},
            {"plan": "木→火→土", "call_id": "y"},
        ])
        self.assertIn("faithfulness", m)
        self.assertIn("coverage", m)
        self.assertEqual(m["n"], 2.0)
        self.assertAlmostEqual(m["faithfulness"], 1.0, places=4)


    def test_generate_contains_all_symbols_longer_plan(self):
        # 新计划符号数超过任一模板 -> 必须补尾，保证全部出现（达标门槛）
        dist = RetrievalDistiller().train(self.pairs)
        out = dist.generate("金→水→木→火→土")  # 5 符号，模板仅 3
        for sym in ["金", "水", "木", "火", "土"]:
            self.assertIn(sym, out)

    def test_faithfulness_one_on_longer_plan(self):
        dist = RetrievalDistiller().train(self.pairs)
        m = dist.faithfulness([{"plan": "金→水→木→火→土", "call_id": "z"}])
        self.assertAlmostEqual(m["faithfulness"], 1.0, places=4)


class NeuralDistillerReservedTest(unittest.TestCase):
    def test_train_raises_not_implemented(self):
        nd = NeuralDistiller(base_model="Qwen3-1.7B", method="lora")
        with self.assertRaises(NotImplementedError):
            nd.train([
                {"plan": "水→木→火", "response": "x", "call_id": "a"},
            ])

    def test_train_torch_raises_not_implemented(self):
        nd = NeuralDistiller(base_model="Qwen3-1.7B", method="lora")
        with self.assertRaises(NotImplementedError):
            nd.train_torch([
                {"plan": "水→木→火", "response": "x", "call_id": "a"},
            ])


class TrainerExportClosureTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = Path(self.tmp.name)
        sidecar = _make_fixtures(self.d)
        self.cfg = load_config({
            "ledger_sidecar": sidecar,
            "output_dir": self.d / "artifacts",
        })

    def tearDown(self):
        self.tmp.cleanup()

    def test_trainer_writes_loadable_distilled_model(self):
        from data_loader import load_pairs, split_train_eval
        pairs = load_pairs(self.cfg)
        tr, ev = split_train_eval(pairs)
        ckpt = trainer_train(self.cfg, tr, ev)
        model_path = Path(str(ckpt)) / DEFAULT_MODEL_FILENAME
        self.assertTrue(model_path.exists(), "trainer 应落盘 distilled_model.json")
        # 落盘模型应可加载并生成
        loaded = RetrievalDistiller.load(str(model_path))
        self.assertTrue(loaded.generate("金→水→火").strip())

    def test_exporter_writes_loadable_model(self):
        from data_loader import load_pairs, split_train_eval
        pairs = load_pairs(self.cfg)
        tr, ev = split_train_eval(pairs)
        artifact = trainer_train(self.cfg, tr, ev)
        model_dir = export_model(self.cfg, artifact)
        out = Path(str(model_dir)) / DEFAULT_MODEL_FILENAME
        self.assertTrue(out.exists(), "export_model 应导出可加载蒸馏模型")
        loaded = RetrievalDistiller.load(str(out))
        self.assertTrue(loaded.generate("金→水→火").strip())

    def test_backend_shim_generates(self):
        from data_loader import load_pairs, split_train_eval
        pairs = load_pairs(self.cfg)
        tr, ev = split_train_eval(pairs)
        trainer_train(self.cfg, tr, ev)
        out = shim_generate(self.cfg, "金→水→火")
        self.assertIsInstance(out, str)
        self.assertTrue(out.strip())
        for sym in ["金", "水", "火"]:
            self.assertIn(sym, out)


class FaithfulnessWithModelTest(unittest.TestCase):
    def test_evaluate_uses_model_output(self):
        pairs = [
            {"plan": "水→木→火", "response": "水 木 火 三相皆已解读", "call_id": "a1"},
            {"plan": "木→火→土", "response": "木 火 土 流转已明", "call_id": "a2"},
        ]
        dist = RetrievalDistiller().train(pairs)
        cfg = load_config()
        # 传入蒸馏模型 -> 用模型生成输出对符号计划做忠实度比对
        m = evaluate(cfg, [{"plan": "金→水→火", "call_id": "x"}], dist)
        self.assertAlmostEqual(m["faithfulness"], 1.0, places=4)


class EvalRobustnessTest(unittest.TestCase):
    def test_split_enforces_min_eval(self):
        from data_loader import load_pairs, split_train_eval
        cfg = load_config({"eval_pairs_min": 30})
        pairs = load_pairs(cfg)
        tr, ev = split_train_eval(pairs, cfg.eval_ratio, cfg.eval_pairs_min)
        self.assertGreaterEqual(len(ev), 30, "验证集应不低于下限 30")
        self.assertGreaterEqual(len(tr), 1, "应至少保留 1 条训练对")

    def test_bootstrap_ci_shape(self):
        from faithfulness_eval import bootstrap_ci
        pairs = [
            {"plan": "水→木→火", "response": "水 木 火", "call_id": "a1"},
            {"plan": "木→火→土", "response": "木 火 土", "call_id": "a2"},
        ]
        dist = RetrievalDistiller().train(pairs)
        ci = bootstrap_ci(load_config(), [{"plan": "金→水→火", "call_id": "x"}], dist)
        self.assertIn("lo", ci)
        self.assertIn("hi", ci)
        self.assertLessEqual(ci["lo"], ci["hi"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
