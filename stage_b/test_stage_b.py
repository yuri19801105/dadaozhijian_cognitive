"""阶段 B 模块自包含测试（标准库 unittest，无需第三方依赖）。

设计要点：
  - 使用临时目录构造合成 fixture（sidecar_calls.jsonl / e2e_lineage.jsonl），
    因此即便仓库未携带真实 ledger（.gitignore 已排除），测试仍可在任意环境跑通。
  - 若项目真实 ledger 存在，也会额外做一次"真实数据"冒烟断言（不失败，
    仅打印规模），保证模块对真实数据可用。
运行: python3 stage_b/test_stage_b.py
"""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from config import load_config  # noqa: E402
from data_loader import (  # noqa: E402
    load_pairs,
    load_lineage,
    split_train_eval,
    validate_pairs,
)
from batch_runner import summarize  # noqa: E402
from faithfulness_eval import evaluate, meets_threshold, _plan_symbols  # noqa: E402
from report_generator import generate  # noqa: E402
from exporter import export_model, write_lineage_map  # noqa: E402
from trainer import train  # noqa: E402
from utils import write_jsonl, read_jsonl, write_text  # noqa: E402


def _make_fixtures(d: Path):
    sidecar = d / "sidecar_calls.jsonl"
    lineage = d / "e2e_lineage.jsonl"
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
                "response": "木 火 土 已覆盖",
            },
            {
                "call_id": "b1", "backend": "phi-4-mini", "ok": 1, "degraded": 1,
                "prompt": "phase=2 plan=[金→水]", "response": "降级不应入选",
            },
            {
                "call_id": "c1", "backend": "qwen3-4b-mlx", "ok": 1, "degraded": 0,
                "prompt": "phase=3 plan=[水→金]", "response": "",
            },
        ],
    )
    write_jsonl(
        str(lineage),
        [
            {"kind": 0, "lineage_id": 1, "phase": 0, "policy_id": 0,
             "plan": [4, 0, 1, -1, -1, -1, -1, -1], "plan_len": 3,
             "span_len": 3, "conf_milli": 555, "ok": 0, "degraded": 0,
             "status": 0, "latency_ms": 0},
            {"kind": 1, "lineage_id": 1, "phase": 0, "policy_id": 0,
             "plan": [-1, -1, -1, -1, -1, -1, -1, -1], "plan_len": 0,
             "span_len": 0, "conf_milli": 555, "ok": 1, "degraded": 0,
             "status": 1, "latency_ms": 0},
            {"kind": 0, "lineage_id": 2, "phase": 1, "policy_id": 0,
             "plan": [0, 1, 2, -1, -1, -1, -1, -1], "plan_len": 3,
             "span_len": 3, "conf_milli": 555, "ok": 0, "degraded": 0,
             "status": 0, "latency_ms": 0},
        ],
    )
    return sidecar, lineage


class DataLoaderTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = Path(self.tmp.name)
        sidecar, lineage = _make_fixtures(self.d)
        self.cfg = load_config({
            "ledger_sidecar": sidecar,
            "ledger_lineage": lineage,
            "output_dir": self.d / "artifacts",
        })

    def tearDown(self):
        self.tmp.cleanup()

    def test_load_pairs_filters_invalid(self):
        pairs = load_pairs(self.cfg)
        # 4 条中：b1 降级、c1 空响应 -> 仅 a1/a2 入选
        self.assertEqual(len(pairs), 2)
        for p in pairs:
            self.assertIn("plan", p)
            self.assertIn("response", p)
            self.assertIn("call_id", p)
        self.assertEqual(pairs[0]["call_id"], "a1")
        self.assertEqual(pairs[0]["plan"], "水→木→火")

    def test_load_lineage_merges(self):
        lin = load_lineage(self.cfg)
        # lineage_id 1 (trace+backfill) 与 2 (trace) 合并为 2 条
        self.assertEqual(len(lin), 2)
        by_id = {r["lineage_id"]: r for r in lin}
        self.assertTrue(by_id[1]["has_trace"])
        self.assertTrue(by_id[1]["has_backfill"])
        # backfill 的 status/ok 应覆盖到合并记录
        self.assertEqual(by_id[1]["status"], 1)
        self.assertEqual(by_id[1]["ok"], 1)
        self.assertTrue(by_id[2]["has_trace"])
        self.assertFalse(by_id[2]["has_backfill"])

    def test_split_train_eval_deterministic(self):
        pairs = load_pairs(self.cfg)
        tr, ev = split_train_eval(pairs, eval_ratio=0.5)
        self.assertEqual(len(tr) + len(ev), len(pairs))
        tr2, ev2 = split_train_eval(pairs, eval_ratio=0.5)
        self.assertEqual([p["call_id"] for p in tr], [p["call_id"] for p in tr2])
        # 空输入安全
        self.assertEqual(split_train_eval([]), ([], []))

    def test_validate_pairs(self):
        pairs = load_pairs(self.cfg)
        valid, issues = validate_pairs(pairs)
        self.assertEqual(valid, len(pairs))
        self.assertEqual(issues, [])
        bad, issues2 = validate_pairs([{"plan": ""}])
        self.assertEqual(bad, 0)
        self.assertTrue(issues2)

    def test_plan_symbols(self):
        self.assertEqual(_plan_symbols("水→木→火"), ["水", "木", "火"])
        self.assertEqual(_plan_symbols("[水, 木, 土]"), ["水", "木", "土"])


class BatchRunnerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = Path(self.tmp.name)
        sidecar, _ = _make_fixtures(self.d)
        self.cfg = load_config({
            "ledger_sidecar": sidecar,
            "output_dir": self.d / "artifacts",
        })

    def tearDown(self):
        self.tmp.cleanup()

    def test_summarize(self):
        s = summarize(self.cfg)
        self.assertEqual(s["counts"], 4)
        # 4 条全部 ok=1（含 1 条降级：降级仍属"调用成功"）
        self.assertEqual(s["ok"], 4)
        self.assertEqual(s["degraded"], 1)
        self.assertAlmostEqual(s["degraded_rate"], 0.25)
        self.assertEqual(s["phase_dist"].get("0"), 1)
        self.assertEqual(s["backends"].get("qwen3-4b-mlx"), 3)
        self.assertEqual(s["backends"].get("phi-4-mini"), 1)


class FaithfulnessTest(unittest.TestCase):
    def test_evaluate_full_coverage(self):
        cfg = load_config()
        pairs = [
            {"plan": "水→木→火", "response": "水 木 火 全覆盖", "call_id": "x"},
            {"plan": "金→水", "response": "金与水皆在", "call_id": "y"},
        ]
        m = evaluate(cfg, pairs, None)
        self.assertAlmostEqual(m["faithfulness"], 1.0)
        self.assertAlmostEqual(m["coverage"], 1.0)
        self.assertEqual(m["n"], 2.0)

    def test_evaluate_partial(self):
        cfg = load_config()
        pairs = [{"plan": "水→木→火", "response": "只提到水", "call_id": "z"}]
        m = evaluate(cfg, pairs, None)
        self.assertAlmostEqual(m["faithfulness"], 1 / 3)
        self.assertAlmostEqual(m["coverage"], 1.0)  # 至少覆盖一个词元

    def test_meets_threshold(self):
        cfg = load_config({"faithfulness_threshold": 0.9})
        self.assertTrue(meets_threshold({"faithfulness": 0.95}, cfg))
        self.assertFalse(meets_threshold({"faithfulness": 0.5}, cfg))


class ReportExporterTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = Path(self.tmp.name)
        sidecar, lineage = _make_fixtures(self.d)
        self.cfg = load_config({
            "ledger_sidecar": sidecar,
            "ledger_lineage": lineage,
            "output_dir": self.d / "artifacts",
        })

    def tearDown(self):
        self.tmp.cleanup()

    def test_full_pipeline_writes_outputs(self):
        pairs = load_pairs(self.cfg)
        tr, ev = split_train_eval(pairs)
        art = train(self.cfg, tr, ev)
        self.assertTrue((Path(str(art)) / "provenance.json").exists())
        metrics = evaluate(self.cfg, ev, art)
        stats = summarize(self.cfg)
        report = generate(self.cfg, metrics, stats)
        self.assertTrue(Path(str(report)).exists())
        self.assertIn("faithfulness", Path(str(report)).read_text(encoding="utf-8"))
        mp = write_lineage_map(self.cfg, metrics)
        self.assertTrue(Path(str(mp)).exists())
        # 即便未达标，也生成了报告（不抛异常）
        self.assertIn("lineage", Path(str(mp)).read_text(encoding="utf-8"))


class RealLedgerSmokeTest(unittest.TestCase):
    """若项目真实 ledger 存在，做一次规模冒烟（不失败，仅信息）。"""

    def test_real_ledger_smoke(self):
        cfg = load_config()
        sidecar = Path(str(cfg.ledger_sidecar))
        lineage = Path(str(cfg.ledger_lineage))
        if not sidecar.exists() and not lineage.exists():
            self.skipTest("无真实 ledger，跳过冒烟")
        pairs = load_pairs(cfg)
        lin = load_lineage(cfg)
        print("[smoke] 真实训练对=%d 血缘合并记录=%d" % (len(pairs), len(lin)))
        self.assertIsInstance(pairs, list)
        self.assertIsInstance(lin, list)


if __name__ == "__main__":
    unittest.main(verbosity=2)
