"""自有模型「大道至简0.5b」运行时封装。

从 merge_and_eval.py 产出的**自包含模型目录**独立加载，零外部依赖、不引用
原基座仓库——这才是"蒸馏出的自己的模型"的运行时入口。

设计：
  - 惰性 torch：模块可被无训练栈环境 import（torch 仅在首次 generate 时加载）。
  - 与 RetrievalDistiller / NeuralDistiller 接口对齐：提供 generate(plan) /
    evaluate(eval_pairs)，可直接接入 stage_b 评测链路与 shifang 调度链路。
  - 复刻训练 prompt 格式（NeuralDistiller._format_text + build_instruction），
    保证生成分布与蒸馏训练一致。
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Dict, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))

from utils import get_logger, read_jsonl  # noqa: E402
from neural_distiller import NeuralDistiller, build_instruction  # noqa: E402
from faithfulness_eval import _plan_symbols  # noqa: E402

IDENTITY_FILE = "dadaozhijian_identity.json"
DEFAULT_DIR = "dadaozhijian_0.5b"
_DATASET = "neural_distill_dataset_combined.jsonl"


def _pick_device() -> str:
    """优先 MPS（Apple 神经网络引擎），否则 CPU。"""
    try:
        import torch
        if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
            return "mps"
    except Exception:
        pass
    return "cpu"


class DadaozhijianModel:
    """加载自包含合并模型目录，提供 generate / evaluate。"""

    def __init__(
        self,
        model_dir: str = DEFAULT_DIR,
        device: Optional[str] = None,
        max_new_tokens: int = 256,
    ) -> None:
        self.model_dir = model_dir
        self.device = device or _pick_device()
        self.max_new_tokens = max_new_tokens
        self._identity: Dict[str, object] = self._read_identity()
        self._tok = None
        self._model = None

    # ---- 身份 / 元数据 -------------------------------------------------
    def _read_identity(self) -> Dict[str, object]:
        p = Path(self.model_dir) / IDENTITY_FILE
        if p.exists():
            try:
                return json.loads(p.read_text(encoding="utf-8"))
            except Exception:
                return {}
        return {}

    @property
    def identity(self) -> Dict[str, object]:
        """自包含模型身份标记（dadaozhijian_identity.json）。"""
        return self._identity

    @property
    def display_name(self) -> str:
        return str(self._identity.get("display_name", "大道至简0.5b"))

    # ---- 惰性加载 -----------------------------------------------------
    def _ensure_loaded(self) -> None:
        if self._model is not None:
            return
        torch, transformers, peft = NeuralDistiller._ensure_torch()
        from transformers import AutoModelForCausalLM, AutoTokenizer
        tok = AutoTokenizer.from_pretrained(self.model_dir)
        model = AutoModelForCausalLM.from_pretrained(
            self.model_dir, torch_dtype=torch.float16
        ).to(self.device)
        model.eval()
        self._tok = tok
        self._model = model

    # ---- 推理 ---------------------------------------------------------
    def generate(self, plan: str, max_new_tokens: Optional[int] = None) -> str:
        """给定符号计划，用自包含模型离线渲染（复刻训练 prompt 格式）。

        Args:
            plan: 符号计划文本，如 "金→水→火"。
            max_new_tokens: 可选覆盖最大生成长度。
        Returns:
            模型生成的渲染文本。
        """
        self._ensure_loaded()
        n = max_new_tokens or self.max_new_tokens
        prompt = NeuralDistiller._format_text(build_instruction(plan), "", self._tok)
        inputs = self._tok(prompt, return_tensors="pt").to(self.device)
        out = self._model.generate(
            **inputs, max_new_tokens=n, do_sample=False, temperature=1.0
        )
        return self._tok.decode(
            out[0][inputs["input_ids"].shape[1]:], skip_special_tokens=True
        )

    # ---- 评估（复用 faithfulness_eval 的计划符号覆盖）-----------------
    def evaluate(self, eval_pairs: List[Dict[str, str]]) -> Dict[str, float]:
        """用本模型生成输出评估对符号计划的忠实度。

        Args:
            eval_pairs: 验证对（需含 'plan' 字段）。
        Returns:
            {'faithfulness', 'coverage', 'n'}。
        """
        if not eval_pairs:
            return {"faithfulness": 0.0, "coverage": 0.0, "n": 0.0}
        total = 0.0
        covered = 0
        for p in eval_pairs:
            plan = p.get("plan", "")
            out = self.generate(plan)
            syms = _plan_symbols(plan)
            if not syms:
                total += 1.0
                covered += 1
                continue
            hit = sum(1 for s in syms if s in out)
            total += hit / len(syms)
            if out.strip() and hit > 0:
                covered += 1
        n = float(len(eval_pairs)) or 1.0
        return {"faithfulness": total / n, "coverage": covered / n, "n": n}

    def plan_symbol_coverage(self, plan: str, text: Optional[str] = None) -> float:
        """计算单条计划符号覆盖率（faithfulness 代理）。"""
        text = self.generate(plan) if text is None else text
        syms = _plan_symbols(plan)
        if not syms:
            return 1.0
        return sum(1 for s in syms if s in text) / len(syms)


def load_neural_eval_pairs(dataset_path: Optional[str] = None) -> List[Dict[str, str]]:
    """读取神经蒸馏数据集，返回 [{plan: ...}] 作为自有模型的验证集。

    Args:
        dataset_path: 数据集 JSONL 路径（默认本模块同目录下的
            neural_distill_dataset_combined.jsonl，即 28 条计划）。
    Returns:
        验证对列表（仅含 plan 字段，供模型生成评估）。
    """
    path = Path(dataset_path) if dataset_path else (
        Path(__file__).resolve().parent / _DATASET
    )
    recs = read_jsonl(str(path))
    return [{"plan": r.get("plan", "")} for r in recs if r.get("plan")]
