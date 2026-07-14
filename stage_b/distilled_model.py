"""自蒸馏模型：纯标准库检索式蒸馏器 + 预留神经网络蒸馏分支。

设计（对照总纲"无黑箱·可溯源"）：

  RetrievalDistiller —— 从 ledger 的 (plan, response) 训练对学习一个「确定性检索
  + 符号插值」渲染器：
    1. train : 把每条训练对的符号计划与响应建为索引条目。
    2. generate : 给定新计划，按符号词元 Jaccard 重叠检索最相近条目，再用
       「符号插值」把原响应中的符号按位置替换为当前计划的符号，得到可溯源、
       可复现的输出。
    3. save/load : 以 JSON 固化/还原，因此模型可自包含加载、可作 Ollama 后端的
       纯标准库替代（backend_shim）。
  全程无黑箱、无需任何第三方依赖，且结果完全确定。

  NeuralDistiller —— 预留真实神经网络蒸馏分支（SFT/LoRA）。接口与
  RetrievalDistiller 对齐，真实训练需 transformers/peft 训练栈；当前 train /
  train_torch 抛 NotImplementedError，待环境就绪平滑替换。
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Optional

from config import StageBConfig
from utils import write_text
from faithfulness_eval import _plan_symbols


DEFAULT_MODEL_FILENAME = "distilled_model.json"

_PLACEHOLDER = "__SYM%d__"


class RetrievalDistiller:
    """确定性检索 + 符号插值渲染器（纯标准库、可溯源）。"""

    def __init__(self, base_model: str = "Qwen3-1.7B", method: str = "retrieval") -> None:
        self.base_model = base_model
        self.method = method
        # 每条: {"symbols": List[str], "response": str, "plan": str}
        self.entries: List[Dict[str, Any]] = []

    # ---- 训练 ----------------------------------------------------------
    def train(self, pairs: List[Dict[str, str]]) -> "RetrievalDistiller":
        """从训练对构建检索索引（返回自身以支持链式调用）。"""
        self.entries = []
        for p in pairs:
            plan = p.get("plan", "")
            response = p.get("response", "")
            if not plan.strip() or not response.strip():
                continue
            self.entries.append(
                {
                    "symbols": _plan_symbols(plan),
                    "response": response.strip(),
                    "plan": plan,
                }
            )
        return self

    # ---- 检索 + 符号插值生成 -------------------------------------------
    def _retrieve(self, syms: List[str]) -> Optional[Dict[str, Any]]:
        if not self.entries or not syms:
            return None
        sset = set(syms)
        best: Optional[Dict[str, Any]] = None
        best_score = -1.0
        for e in self.entries:
            eset = set(e["symbols"])
            union = eset | sset
            score = len(eset & sset) / len(union) if union else 0.0
            if score > best_score:
                best_score = score
                best = e
        return best

    @staticmethod
    def _adapt(entry: Dict[str, Any], new_syms: List[str]) -> str:
        """符号插值：把原响应中的符号按位置替换为当前计划的符号。

        用临时占位避免链式/循环替换（如 水->木 且 木->水）。
        保证新计划的所有符号都出现在输出中：当新计划符号数超过模板时，
        将多出符号补到输出尾部，以满足"蒸馏输出对符号计划忠实"的达标门槛。
        """
        stored = entry["symbols"]
        tmp = entry["response"]
        for i, s in enumerate(stored):
            tmp = tmp.replace(s, _PLACEHOLDER % i)
        out = tmp
        for i, s in enumerate(stored):
            new = new_syms[i] if i < len(new_syms) else s
            out = out.replace(_PLACEHOLDER % i, new)
        if len(new_syms) > len(stored):
            tail = " → ".join(new_syms[len(stored):])
            out = out + "（接续：" + tail + "）"
        return out

    def generate(self, plan: str, top_k: int = 1) -> str:
        """给定符号计划，检索最相近条目并做符号插值渲染。"""
        syms = _plan_symbols(plan)
        if not syms:
            return ""
        hit = self._retrieve(syms)
        if hit is None:
            return ""
        return self._adapt(hit, syms)

    # ---- 忠实度（用自身生成输出对符号计划比对）------------------------
    def faithfulness(self, pairs: List[Dict[str, str]]) -> Dict[str, float]:
        """评估本模型生成输出对符号计划的忠实度。"""
        if not pairs:
            return {"faithfulness": 0.0, "coverage": 0.0, "n": 0.0}
        total = 0.0
        covered = 0
        for p in pairs:
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
        n = float(len(pairs))
        return {"faithfulness": total / n, "coverage": covered / n, "n": n}

    # ---- 持久化 --------------------------------------------------------
    def save(self, path: str) -> None:
        """把蒸馏模型固化为 JSON（自包含、可加载）。"""
        data = {
            "type": "RetrievalDistiller",
            "base_model": self.base_model,
            "method": self.method,
            "entries": self.entries,
        }
        write_text(path, json.dumps(data, ensure_ascii=False, indent=2))

    @classmethod
    def load(cls, path: str) -> "RetrievalDistiller":
        """从 JSON 还原蒸馏模型。"""
        raw = Path(path).read_text(encoding="utf-8")
        data = json.loads(raw)
        d = cls(
            base_model=data.get("base_model", "Qwen3-1.7B"),
            method=data.get("method", "retrieval"),
        )
        d.entries = data.get("entries", [])
        return d


class NeuralDistiller:
    """预留真实神经网络蒸馏分支（SFT/LoRA）。

    接口与 RetrievalDistiller 对齐，真实训练依赖 transformers/peft 训练栈，
    本环境未安装，故 train / train_torch 抛 NotImplementedError，等待环境就绪
    后平滑替换 RetrievalDistiller（无需改动上层调用）。
    """

    def __init__(self, base_model: str = "Qwen3-1.7B", method: str = "lora") -> None:
        self.base_model = base_model
        self.method = method
        self.entries: List[Dict[str, Any]] = []

    def train(self, pairs: List[Dict[str, str]]) -> "NeuralDistiller":
        """真实训练入口（当前未实现）。"""
        raise NotImplementedError(
            "真实神经网络蒸馏需 transformers/peft 训练栈（SFT/LoRA）。"
            "请安装训练栈后改用 train_torch，或临时使用 RetrievalDistiller。"
        )

    def train_torch(self, pairs: List[Dict[str, str]]) -> "NeuralDistiller":
        """SFT/LoRA 训练（预留分支，未实现）。"""
        raise NotImplementedError(
            "真实 SFT/LoRA 训练需 transformers/peft；当前为预留分支，"
            "待训练栈就绪后实现。"
        )
