"""P4 收尾 TDD：把自有模型「大道至简0.5b」接入 shifang 调度链路（neural 后端类型）。

对照 test_external_backend.py 的 distilled 后端：llm_sidecar 识别 type=="neural"
并离线加载自有模型渲染；零出站 HTTP、ledger 标记 backend_type=neural、degraded=0。

路由逻辑用 mock 自有模型验证（无需 torch，CI 友好）；真实子进程加载 988MB
模型仅当 torch 可用且自有模型目录存在时运行，否则自动跳过。

运行: python3 stage_b/test_neural_backend.py
"""
from __future__ import annotations

import os
import sys
import io
import json
import subprocess
import tempfile
import contextlib
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "shifang"))
sys.path.insert(0, str(ROOT / "stage_b"))

import llm_sidecar  # noqa: E402
from data_loader import load_pairs  # noqa: E402
from config import load_config  # noqa: E402
from distilled_model import RetrievalDistiller, DEFAULT_MODEL_FILENAME  # noqa: E402


class NeuralBackendTest(unittest.TestCase):
    _ENV_KEYS = ("SIDECAR_CONFIG", "LLM_PROMPT", "LLM_REQ_FILE")

    def setUp(self):
        self._saved = {k: os.environ.get(k) for k in self._ENV_KEYS}

    def tearDown(self):
        for k, v in self._saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v

    def _make_config(self, tmp, neural_entry, failover_entries):
        cfg = load_config()
        pairs = load_pairs(cfg)
        model = RetrievalDistiller(base_model=cfg.base_model).train(pairs)
        mp = tmp / DEFAULT_MODEL_FILENAME
        model.save(str(mp))
        backends = [neural_entry] + list(failover_entries)
        sc = {
            "version": 4,
            "default_backend": neural_entry["name"],
            "failover_order": [b["name"] for b in failover_entries],
            "ledger_path": str(tmp / "sidecar_calls.jsonl"),
            "backends": backends,
        }
        cf = tmp / "sc.json"
        cf.write_text(json.dumps(sc, ensure_ascii=False))
        return cf

    def _run_sidecar(self, prompt, tmp, cf):
        os.environ["SIDECAR_CONFIG"] = str(cf)
        os.environ["LLM_PROMPT"] = prompt
        os.environ.pop("LLM_REQ_FILE", None)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = llm_sidecar.main()
        out = buf.getvalue()
        recs = []
        ledger = tmp / "sidecar_calls.jsonl"
        if ledger.exists():
            recs = [json.loads(l) for l in ledger.read_text(encoding="utf-8").splitlines() if l.strip()]
        return rc, out, recs

    def test_neural_routing_offline(self):
        """mock 自有模型：验证 type==neural 走 _call_neural、零 /api/chat、backend_type=neural。"""
        with tempfile.TemporaryDirectory() as raw:
            d = Path(raw)
            calls = []

            class FakeModel:
                def __init__(self, model_dir):
                    calls.append(model_dir)

                def generate(self, plan):
                    return "符号推演：%s 形成相生链。" % plan

            neural_entry = {"name": "neural", "type": "neural", "interface": "neural",
                            "model_path": str(d / "dadaozhijian_0.5b"), "temperature": 0.0, "max_tokens": 512}
            failover_entries = [{"name": "distilled", "type": "distilled", "interface": "distilled",
                                 "model_path": str(d / DEFAULT_MODEL_FILENAME), "temperature": 0.0, "max_tokens": 512}]
            cf = self._make_config(d, neural_entry, failover_entries)
            with patch("dadaozhijian_model.DadaozhijianModel", FakeModel):
                rc, out, recs = self._run_sidecar("phase=0 plan=[水→木→火]", d, cf)
        self.assertEqual(rc, 0, "llm_sidecar.main 应返回 0")
        self.assertTrue(out.strip(), "neural 后端应返回非空渲染文本")
        self.assertNotIn("失败", out)
        self.assertNotIn("/api/chat", out)
        self.assertEqual(len(recs), 1)
        self.assertEqual(recs[0]["backend_type"], "neural")
        self.assertEqual(recs[0]["degraded"], 0)
        self.assertEqual(recs[0]["ok"], 1)
        self.assertTrue(calls, "应加载自有模型目录")

    def test_neural_failure_falls_back_to_distilled(self):
        """自有模型加载/生成异常 → 故障转移到 distilled，仍离线、ok=1。"""
        with tempfile.TemporaryDirectory() as raw:
            d = Path(raw)

            class BrokenModel:
                def __init__(self, model_dir):
                    pass

                def generate(self, plan):
                    raise RuntimeError("模型不可用")

            neural_entry = {"name": "neural", "type": "neural", "interface": "neural",
                            "model_path": str(d / "dadaozhijian_0.5b"), "temperature": 0.0, "max_tokens": 512}
            failover_entries = [{"name": "distilled", "type": "distilled", "interface": "distilled",
                                 "model_path": str(d / DEFAULT_MODEL_FILENAME), "temperature": 0.0, "max_tokens": 512}]
            cf = self._make_config(d, neural_entry, failover_entries)
            with patch("dadaozhijian_model.DadaozhijianModel", BrokenModel):
                rc, out, recs = self._run_sidecar("phase=0 plan=[水→木→火]", d, cf)
        self.assertEqual(rc, 0)
        self.assertTrue(out.strip())
        self.assertNotIn("/api/chat", out)
        self.assertEqual(recs[0]["backend_type"], "distilled")
        self.assertEqual(recs[0]["ok"], 1)

    def test_neural_greeting_no_plan_offline(self):
        """非计划指令（greeting）走确定性离线应答，不加载模型、backend_type=neural。"""
        with tempfile.TemporaryDirectory() as raw:
            d = Path(raw)

            class FakeModel:
                def __init__(self, model_dir):
                    pass

                def generate(self, plan):
                    return "x"

            neural_entry = {"name": "neural", "type": "neural", "interface": "neural",
                            "model_path": str(d / "dadaozhijian_0.5b"), "temperature": 0.0, "max_tokens": 512}
            cf = self._make_config(d, neural_entry, [])
            with patch("dadaozhijian_model.DadaozhijianModel", FakeModel):
                rc, out, recs = self._run_sidecar("世界", d, cf)
        self.assertEqual(rc, 0)
        self.assertTrue(out.strip())
        self.assertNotIn("失败", out)
        self.assertEqual(recs[0]["backend_type"], "neural")
        self.assertEqual(recs[0]["ok"], 1)

    def test_neural_via_real_subprocess(self):
        """真实子进程链路（受控）：仅当 torch 可用且自有模型目录存在时运行，否则跳过。"""
        model_dir = ROOT / "stage_b" / "dadaozhijian_0.5b"
        if not model_dir.exists():
            self.skipTest("自有模型目录不存在：%s" % model_dir)
        try:
            import torch  # noqa: F401
        except Exception:
            self.skipTest("torch 不可用，跳过真实神经后端子进程测试")
        with tempfile.TemporaryDirectory() as raw:
            d = Path(raw)
            sc = {
                "version": 4,
                "default_backend": "neural",
                "failover_order": [],
                "ledger_path": str(d / "ledger.jsonl"),
                "backends": [
                    {"name": "neural", "type": "neural", "interface": "neural",
                     "model_path": "stage_b/dadaozhijian_0.5b", "temperature": 0.0, "max_tokens": 512},
                ],
            }
            cf = d / "sc.json"
            cf.write_text(json.dumps(sc, ensure_ascii=False))
            # 用托管 python（含 torch）运行，确保真实加载自有模型
            py = os.environ.get("MANAGED_PYTHON") or sys.executable
            env = dict(os.environ, SIDECAR_CONFIG=str(cf),
                       LLM_PROMPT="phase=0 plan=[金→水→火]")
            r = subprocess.run([py, "shifang/llm_sidecar.py"],
                               capture_output=True, text=True, env=env, cwd=str(ROOT),
                               timeout=180)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertTrue(r.stdout.strip())
            self.assertNotIn("失败", r.stdout)
            self.assertNotIn("/api/chat", r.stdout)
            with open(d / "ledger.jsonl", encoding="utf-8") as _fh:
                recs = [json.loads(l) for l in _fh.read().splitlines() if l.strip()]
            self.assertEqual(recs[0]["backend_type"], "neural")
            self.assertEqual(recs[0]["degraded"], 0)
            self.assertEqual(recs[0]["ok"], 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
