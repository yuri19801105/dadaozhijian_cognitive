"""导出器：把达标的蒸馏产物固化为可部署单后端，并写入溯源映射。

达标后，框架将删除 Qwen3 / Phi 外部后端，仅保留此专属小模型。
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict

from config import StageBConfig


def export_model(cfg: StageBConfig, artifact: Any) -> Path:
    """导出蒸馏模型为部署就绪格式，返回模型目录。

    Args:
        cfg: 阶段 B 配置（output_dir 等）。
        artifact: 训练产出的产物对象。
    Returns:
        导出模型目录路径。
    """
    # 骨架占位：真实实现导出为 Ollama Modelfile / GGUF 等部署格式。
    return cfg.output_dir / "model"


def write_lineage_map(cfg: StageBConfig, metrics: Dict[str, float]) -> Path:
    """写入蒸馏模型 -> 血缘 ledger 的溯源映射文件。

    Args:
        cfg: 阶段 B 配置。
        metrics: 评估指标。
    Returns:
        溯源映射文件路径。
    """
    # 骨架占位：真实实现写 模型版本 -> ledger lineage_id 的映射，保证输出可溯源。
    return cfg.output_dir / "lineage_map.json"
