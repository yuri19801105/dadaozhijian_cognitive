"""P0 TDD：将 backend_shim 接入 shifang 生成链路，彻底脱离外部 LLM 后端。

RED: 在 llm_sidecar.py 尚未识别 type=="distilled" 时，配置 distilled 默认后端
     会因缺少 base_url / 无对应分支而失败（输出含"失败"或抛错）-> 测试 RED。
GREEN: 实现 _call_distilled + 在 _select_and_call 中分流后，distilled 后端
       离线生成、ledger 标记 backend_type=distilled、degraded=0，且零 /api/chat。

运行: python3 stage_b/test_external_backend.py
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

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "shifang"))
sys.path.insert(0, str(ROOT / "stage_b"))

import llm_sidecar  # noqa: E402
from data_loader import load_pairs  # noqa: E402
from config import load_config  # noqa: E402
from distilled_model import RetrievalDistiller, DEFAULT_MODEL_FILENAME  # noqa: E402


class DistilledBackendTest(unittest.TestCase):
    _ENV_KEYS = ("SIDECAR_CONFIG", "LLM_PROMPT", "LLM_REQ_FILE")

    def setUp(self):
        self._saved = {k: os.environ.get(k) for k in self._ENV_KEYS}

    def tearDown(self):
        for k, v in self._saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v

    def _make_distilled_config(self, tmp: Path) -> Path:
        cfg = load_config()
        pairs = load_pairs(cfg)
        model = RetrievalDistiller(base_model=cfg.base_model).train(pairs)
        mp = tmp / DEFAULT_MODEL_FILENAME
        model.save(str(mp))
        sc = {
            "version": 4,
            "default_backend": "distilled",
            "failover_order": [],
            "ledger_path": str(tmp / "sidecar_calls.jsonl"),
            "backends": [
                {
                    "name": "distilled",
                    "type": "distilled",
                    "interface": "distilled",
                    "model_path": str(mp),
                    "temperature": 0.0,
                    "max_tokens": 512,
                }
            ],
        }
        cf = tmp / "sc.json"
        cf.write_text(json.dumps(sc, ensure_ascii=False))
        return cf

    def _run_sidecar(self, prompt: str, tmp: Path):
        cf = self._make_distilled_config(tmp)
        ledger = tmp / "sidecar_calls.jsonl"
        os.environ["SIDECAR_CONFIG"] = str(cf)
        os.environ["LLM_PROMPT"] = prompt
        os.environ.pop("LLM_REQ_FILE", None)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = llm_sidecar.main()
        out = buf.getvalue()
        recs = [
            json.loads(l)
            for l in ledger.read_text(encoding="utf-8").splitlines()
            if l.strip()
        ]
        return rc, out, recs

    def test_distilled_backend_offline_no_external(self):
        with tempfile.TemporaryDirectory() as raw:
            d = Path(raw)
            rc, out, recs = self._run_sidecar(
                "phase=0 intensity=1 confidence=55% policy=0 plan=[水→木→火]", d
            )
        self.assertEqual(rc, 0, "llm_sidecar.main 应返回 0")
        self.assertTrue(out.strip(), "distilled 后端应返回非空渲染文本")
        # 关键：不得出现任何外部端点失败痕迹
        self.assertNotIn("失败", out)
        self.assertNotIn("/api/chat", out)
        self.assertEqual(len(recs), 1)
        self.assertEqual(recs[0]["backend_type"], "distilled")
        self.assertEqual(recs[0]["degraded"], 0)
        self.assertEqual(recs[0]["ok"], 1)

    def test_distilled_greeting_no_plan_still_offline(self):
        with tempfile.TemporaryDirectory() as raw:
            d = Path(raw)
            rc, out, recs = self._run_sidecar("世界", d)
        self.assertEqual(rc, 0)
        self.assertTrue(out.strip())
        self.assertNotIn("失败", out)
        self.assertEqual(recs[0]["backend_type"], "distilled")
        self.assertEqual(recs[0]["degraded"], 0)

    def test_distilled_via_real_subprocess(self):
        """真实子进程链路（与 shifang 调用方式一致）：验证 _call_distilled 以
        __file__ 为基准解析 stage_b（不依赖配置文件位置），防止回归。"""
        with tempfile.TemporaryDirectory() as raw:
            d = Path(raw)
            cfg = load_config()
            pairs = load_pairs(cfg)
            model = RetrievalDistiller(base_model=cfg.base_model).train(pairs)
            mp = d / DEFAULT_MODEL_FILENAME
            model.save(str(mp))
            sc = {
                "version": 4,
                "default_backend": "distilled",
                "failover_order": [],
                "ledger_path": str(d / "ledger.jsonl"),
                "backends": [
                    {
                        "name": "distilled", "type": "distilled", "interface": "distilled",
                        "model_path": str(mp), "temperature": 0.0, "max_tokens": 512,
                    }
                ],
            }
            cf = d / "sc.json"
            cf.write_text(json.dumps(sc, ensure_ascii=False))
            env = dict(os.environ, SIDECAR_CONFIG=str(cf),
                       LLM_PROMPT="phase=0 plan=[水→木→火]")
            r = subprocess.run(
                [sys.executable, "shifang/llm_sidecar.py"],
                capture_output=True, text=True, env=env, cwd=str(ROOT),
            )
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertTrue(r.stdout.strip())
            self.assertNotIn("失败", r.stdout)
            self.assertNotIn("/api/chat", r.stdout)
            with open(d / "ledger.jsonl", encoding="utf-8") as _fh:
                recs = [
                    json.loads(l)
                    for l in _fh.read().splitlines()
                    if l.strip()
                ]
            self.assertEqual(recs[0]["backend_type"], "distilled")
            self.assertEqual(recs[0]["degraded"], 0)
            self.assertEqual(recs[0]["ok"], 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
