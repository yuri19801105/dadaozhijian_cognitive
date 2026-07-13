"""训练器：选择并执行蒸馏方法（SFT / LoRA）。

骨架仅定义接口与流程占位；真实实现接入 transformers/peft 等训练栈。
"""
from __future__ import annotations

from pathlib import Path
from typing import Dict, List

from config import StageBConfig
from utils import get_logger


def select_method(cfg: StageBConfig) -> str:
    """依据配置选择蒸馏方法。

    Args:
        cfg: 阶段 B 配置（method 字段）。
    Returns:
        方法标识：'sft' 或 'lora'。
    """
    return cfg.method


def train(
    cfg: StageBConfig,
    train_pairs: List[Dict[str, str]],
    eval_pairs: List[Dict[str, str]],
) -> Path:
    """执行蒸馏训练，返回产物（检查点/适配器）路径。

    Args:
        cfg: 阶段 B 配置（基座、方法、超参）。
        train_pairs: 训练对。
        eval_pairs: 验证对（用于训练中监控）。
    Returns:
        蒸馏产物目录路径。
    """
    log = get_logger("stage_b.trainer")
    log.info(
        "select_method=%s base=%s epochs=%d lr=%.1e rank=%d",
        cfg.method, cfg.base_model, cfg.max_epochs, cfg.learning_rate, cfg.lora_rank,
    )
    # 骨架占位：真实实现在此加载基座(CausalLM) + 构造 SFT/LoRA 训练循环。
    return cfg.output_dir / "checkpoint"
