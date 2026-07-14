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
from distilled_model import RetrievalDistiller, DEFAULT_MODEL_FILENAME
from pathlib import Path
from typing import Any


def export_model(cfg: StageBConfig, artifact: Any) -> Path:
    """导出蒸馏模型为部署就绪格式，返回模型目录。

    若 trainer 已落盘自包含蒸馏模型（distilled_model.json），则将其导出为
    可加载的单一小模型（可作 Ollama 后端替代）；否则写入占位说明。接口与
    返回类型保持不变。

    Args:
        cfg: 阶段 B 配置（output_dir 等）。
        artifact: 训练产出的产物对象（trainer 返回的 checkpoint 路径或元数据）。
    Returns:
        导出模型目录路径。
    """
    model_dir = ensure_dir(str(cfg.output_dir / "model"))
    src = None
    if artifact is not None:
        cand = Path(str(artifact)) / DEFAULT_MODEL_FILENAME
        if cand.exists():
            src = cand
    if src is not None:
        loaded = RetrievalDistiller.load(str(src))
        loaded.save(str(model_dir / DEFAULT_MODEL_FILENAME))
        note = (
            "已导出自包含、可加载的检索式蒸馏模型（distilled_model.json）。\n"
            "该模型纯标准库、无黑箱、可溯源，可作为外部 LLM 后端（Ollama）的替代：\n"
            "  from backend_shim import generate\n"
            "  text = generate(cfg, plan)\n"
        )
    elif artifact is not None and (Path(str(artifact)) / "model.safetensors").exists():
        # 自包含神经网络模型（大道至简0.5b）：已是独立部署产物，不重复拷贝 988MB 权重，
        # 直接指向它；可由 shifang/llm_sidecar.py 的 neural 后端加载，无需原基座仓库。
        note = (
            "已导出「大道至简0.5b」自包含神经模型（model.safetensors + 配置 + 身份标记）。\n"
            "该目录即部署产物，可直接由 shifang/llm_sidecar.py 的 neural 后端加载，"
            "无需原基座仓库。\n"
            "路径: %s\n" % artifact
        )
        write_text(str(model_dir / "README.md"), "# 神经蒸馏模型导出\n\n" + note)
        return Path(str(artifact))
    else:
        note = (
            "未找到蒸馏模型产物（trainer 未落盘 distilled_model.json）。\n"
            "请先运行 trainer.train 生成自蒸馏模型，再执行导出。\n"
        )
    write_text(str(model_dir / "README.md"), "# 蒸馏模型导出\n\n" + note)
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
