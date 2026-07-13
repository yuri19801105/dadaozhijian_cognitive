"""数据加载：把 ledger 解析为 (plan, response) 训练对。

主数据源为侧车 ledger（plan -> response 配对）；血缘 ledger 提供溯源行。
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Tuple

from config import StageBConfig
from utils import read_jsonl


def load_pairs(cfg: StageBConfig) -> List[Dict[str, str]]:
    """从侧车 ledger 抽取有效 (plan, response) 训练对。

    过滤掉缺少 plan / response 或标记为降级的记录。

    Args:
        cfg: 阶段 B 配置（含 ledger_sidecar 路径）。
    Returns:
        每条为 {'plan': str, 'response': str, 'call_id': str} 的列表。
    """
    # 骨架占位：真实实现在此解析 JSONL 并抽取 plan/response 配对。
    return []


def load_lineage(cfg: StageBConfig) -> List[Dict[str, Any]]:
    """加载血缘 ledger，返回 (trace, backfill) 记录列表。

    Args:
        cfg: 阶段 B 配置（含 ledger_lineage 路径）。
    Returns:
        血缘记录字典列表（含 lineage_id 串联信息）。
    """
    # 骨架占位：真实实现在此加载 trace/backfill 并合并同源 lineage_id。
    return []


def split_train_eval(
    pairs: List[Dict[str, str]], eval_ratio: float = 0.1
) -> Tuple[List[Dict[str, str]], List[Dict[str, str]]]:
    """按比例切分训练集 / 验证集。

    Args:
        pairs: 全部训练对。
        eval_ratio: 验证集占比（默认 0.1）。
    Returns:
        (train_pairs, eval_pairs) 二元组。
    """
    # 骨架占位：真实实现按 eval_ratio 切分（建议按 lineage 分层）。
    return (pairs, [])
