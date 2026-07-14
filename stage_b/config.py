"""阶段 B 配置：路径、基座模型、训练方法、faithfulness 阈值。

所有可调项集中在此，便于阶段 B 试验不同蒸馏设置。
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Optional


@dataclass
class StageBConfig:
    """阶段 B 蒸馏管线的统一配置。

    Attributes:
        project_root: 项目根目录（stage_b 的父目录）。
        ledger_sidecar: 侧车 ledger 路径（主训练对：plan -> response）。
        ledger_lineage: 血缘 ledger 路径（溯源：trace + backfill）。
        base_model: 蒸馏基座（按规划用 Qwen3-1.7B）。
        method: 训练方法，'sft' / 'lora'（纯标准库检索蒸馏，默认）或 'neural'（真实 LoRA 蒸馏分支）。
        lora_rank: LoRA 秩（method='lora' 时生效）。
        max_epochs: 训练轮数。
        learning_rate: 学习率。
        faithfulness_threshold: faithfulness 达标阈值（0~1），低于则不允许下线外部模型。
        eval_ratio: 验证集占比（默认 0.1）。
        eval_pairs_min: 验证集最小条数下限（保证评估统计稳健，默认 30）。
        output_dir: 蒸馏产物输出目录。
        report_path: 评估报告路径。
    """
    project_root: Path = field(default_factory=lambda: Path(__file__).resolve().parent.parent)
    ledger_sidecar: Optional[Path] = None
    ledger_lineage: Optional[Path] = None
    base_model: str = "Qwen3-1.7B"
    method: str = "lora"
    lora_rank: int = 16
    max_epochs: int = 3
    learning_rate: float = 2.0e-4
    # 神经蒸馏分支（method='neural' 时生效）
    neural_base_model: str = "Qwen2.5-0.5B-Instruct"
    neural_gate: float = 1.0
    neural_max_seq_length: int = 512
    faithfulness_threshold: float = 0.95
    eval_ratio: float = 0.1
    eval_pairs_min: int = 30
    output_dir: Optional[Path] = None
    report_path: Optional[Path] = None

    def __post_init__(self) -> None:
        if self.ledger_sidecar is None:
            self.ledger_sidecar = self.project_root / "shifang" / "ledger" / "sidecar_calls.jsonl"
        if self.ledger_lineage is None:
            self.ledger_lineage = self.project_root / "shifang" / "ledger" / "e2e_lineage.jsonl"
        if self.output_dir is None:
            self.output_dir = self.project_root / "stage_b" / "artifacts"
        if self.report_path is None:
            self.report_path = self.output_dir / "stage_b_report.md"


def load_config(overrides: Optional[Dict[str, object]] = None) -> StageBConfig:
    """构造配置，支持以 dict 覆盖默认值。

    Args:
        overrides: 键为 StageBConfig 字段名、值为覆盖项的字典。
    Returns:
        填充后的 StageBConfig 实例。
    """
    cfg = StageBConfig()
    if overrides:
        for key, val in overrides.items():
            setattr(cfg, key, val)
    return cfg
