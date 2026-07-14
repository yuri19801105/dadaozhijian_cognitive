"""后端垫片：用自蒸馏模型替代外部 LLM 后端（Ollama）。

蒸馏达标（faithfulness >= threshold）后，框架可下线 Qwen3 / Phi 等外部模型，
仅保留此自包含小模型后端。接口对齐 shifang 渲染调用约定：

    generate(cfg, plan: str) -> str

模型自包含、纯标准库、可 save/load，无任何第三方依赖。
"""
from __future__ import annotations

from pathlib import Path
from typing import List, Optional

from config import StageBConfig
from distilled_model import RetrievalDistiller, DEFAULT_MODEL_FILENAME
from utils import get_logger


def model_candidates(cfg: StageBConfig) -> List[Path]:
    """返回可能的蒸馏模型路径（按优先级）。"""
    od = Path(str(cfg.output_dir))
    return [
        od / DEFAULT_MODEL_FILENAME,
        od / "checkpoint" / DEFAULT_MODEL_FILENAME,
        od / "model" / DEFAULT_MODEL_FILENAME,
    ]


def load_model(cfg: StageBConfig) -> Optional[RetrievalDistiller]:
    """加载可用的蒸馏模型；若无产物则返回 None。"""
    for p in model_candidates(cfg):
        if p.exists():
            return RetrievalDistiller.load(str(p))
    return None


def generate(cfg: StageBConfig, plan: str) -> str:
    """用蒸馏模型替代外部 LLM 生成符号计划的自然语言渲染。

    Args:
        cfg: 阶段 B 配置（定位蒸馏模型产物）。
        plan: 符号计划文本，如 "金→水→火"。
    Returns:
        蒸馏模型生成的渲染文本；无模型产物时返回空串。
    """
    log = get_logger("stage_b.backend_shim")
    model = load_model(cfg)
    if model is None:
        log.warning("未找到蒸馏模型产物，返回空输出（请先运行 trainer）")
        return ""
    out = model.generate(plan)
    log.info("蒸馏后端生成: plan=%r -> %d 字符", plan, len(out))
    return out
