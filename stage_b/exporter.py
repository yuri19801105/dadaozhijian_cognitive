"""导出器：把达标的蒸馏产物固化为可部署单后端，并写入溯源映射。

达标后，框架将删除 Qwen3 / Phi 外部后端，仅保留此专属小模型。

真实实现（v0.2）：
  - export_model      : 真实模型导出需 transformers/peft 等训练栈（本环境未装），
                        此处创建产物目录并写入部署就绪占位说明，返回目录路径。
  - write_lineage_map : 真实写出「模型版本 -> 血缘 ledger 映射 + 评估指标」的
                        JSON，保证蒸馏输出可追溯到原始符号计划（无黑箱·可溯源）。
"""
from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any, Dict

from config import StageBConfig
from utils import ensure_dir, write_text


def export_model(cfg: StageBConfig, artifact: Any) -> Path:
    """导出蒸馏模型为部署就绪格式，返回模型目录。

    真实模型导出（Ollama Modelfile / GGUF 等）依赖训练栈，本环境未安装，
    故创建产物目录并写入部署就绪占位说明，接口与返回类型保持不变。

    Args:
        cfg: 阶段 B 配置（output_dir 等）。
        artifact: 训练产出的产物对象（trainer 返回的 checkpoint 路径或元数据）。
    Returns:
        导出模型目录路径。
    """
    model_dir = ensure_dir(str(cfg.output_dir / "model"))
    placeholder = (
        "# 蒸馏模型导出占位\n\n"
        "真实导出需 transformers/peft 训练栈（SFT/LoRA -> GGUF/Modelfile）。\n"
        "训练产物元数据见同目录 ../checkpoint 的 provenance.json。\n"
        "达标后此处将生成可部署的单一小模型，并替换外部 LLM 后端。\n"
    )
    write_text(str(model_dir / "README.md"), placeholder)
    return model_dir


def write_lineage_map(cfg: StageBConfig, metrics: Dict[str, float]) -> Path:
    """写入蒸馏模型 -> 血缘 ledger 的溯源映射文件。

    Args:
        cfg: 阶段 B 配置（output_dir 等）。
        metrics: 评估指标（含 faithfulness / coverage）。
    Returns:
        溯源映射文件路径。
    """
    mapping = {
        "model_version": "%s-%s" % (cfg.base_model, cfg.method),
        "base_model": cfg.base_model,
        "method": cfg.method,
        "lora_rank": cfg.lora_rank,
        "faithfulness_threshold": cfg.faithfulness_threshold,
        "metrics": metrics,
        "lineage_source": str(cfg.ledger_lineage),
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "note": "蒸馏输出可经此映射溯源至原始符号计划血缘 ledger（无黑箱）。",
    }
    path = cfg.output_dir / "lineage_map.json"
    ensure_dir(str(path.parent))
    write_text(str(path), json.dumps(mapping, ensure_ascii=False, indent=2))
    return path
