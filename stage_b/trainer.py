"""训练器：选择并执行蒸馏方法（SFT / LoRA）。

真实实现（v0.2）：基座加载与 SFT/LoRA 训练循环依赖 transformers/peft
训练栈（本环境未装）。此处保留接口与返回类型，并在产物目录写入真实的
provenance 元数据（方法 / 基座 / 超参 / 训练对规模 / 时间戳），供
exporter 溯源与审计使用。
"""
from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Dict, List

from config import StageBConfig
from utils import get_logger, ensure_dir, write_text
from distilled_model import RetrievalDistiller, DEFAULT_MODEL_FILENAME
from faithfulness_eval import _plan_symbols


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

    真实训练分两层落地（"先桩后真"）：
      (1) 当前环境：用纯标准库检索式蒸馏器（RetrievalDistiller）从训练对直接学出
          可溯源、可加载的小模型，落盘为 <checkpoint>/distilled_model.json；
          同时写入真实 provenance 元数据（超参 + 数据规模 + 时间戳）。
      (2) 待训练栈就绪：可平滑替换为 NeuralDistiller.train_torch（SFT/LoRA），
          上层调用（train 返回 Path）保持不变。
    接口与返回类型与空壳一致。

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
    ckpt = ensure_dir(str(cfg.output_dir / "checkpoint"))
    # 数据清洗：剔除"参考响应自身未含全部计划符号"的低质量样本，
    # 避免把不忠实目标学进检索索引（DATA-GATE 不完美样本）。
    clean = [
        p for p in train_pairs
        if all(s in p["response"] for s in _plan_symbols(p["plan"]))
    ]
    dropped = len(train_pairs) - len(clean)
    if dropped:
        log.info("数据清洗：剔除 %d 条参考响应不忠实样本（保留 %d）", dropped, len(clean))
    provenance = {
        "base_model": cfg.base_model,
        "method": cfg.method,
        "lora_rank": cfg.lora_rank,
        "max_epochs": cfg.max_epochs,
        "learning_rate": cfg.learning_rate,
        "num_train_pairs": len(train_pairs),
        "num_train_pairs_clean": len(clean),
        "num_dropped": dropped,
        "num_eval_pairs": len(eval_pairs),
        "distiller": "RetrievalDistiller",
        "status": "trained (pure-stdlib retrieval distiller; "
                  "real SFT/LoRA reserved via NeuralDistiller.train_torch)",
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    write_text(str(ckpt / "provenance.json"), json.dumps(provenance, ensure_ascii=False, indent=2))
    log.info("provenance 已写入: %s", ckpt / "provenance.json")
    dist = RetrievalDistiller(base_model=cfg.base_model, method="retrieval").train(clean)
    model_path = ckpt / DEFAULT_MODEL_FILENAME
    dist.save(str(model_path))
    log.info("蒸馏模型已落盘: %s", model_path)
    return ckpt
