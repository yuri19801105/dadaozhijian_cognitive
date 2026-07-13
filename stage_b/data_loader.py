"""数据加载：把 ledger 解析为 (plan, response) 训练对。

主数据源为侧车 ledger（plan -> response 配对）；血缘 ledger 提供溯源行。

真实实现（v0.2）：
  - load_pairs      : 解析 sidecar_calls.jsonl，抽取 (plan, response, call_id)，
                      过滤降级 / 缺字段 / 空响应的记录，并做基本校验。
  - load_lineage    : 解析 e2e_lineage.jsonl，按 lineage_id 合并同源
                      trace(kind=0) 与 backfill(kind=1)。
  - split_train_eval: 确定性切分（按索引，便于复现）。

接口与空壳保持一致：签名、返回形状、外部调用方式均不变。
"""
from __future__ import annotations

import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from config import StageBConfig
from utils import read_jsonl


_PLAN_RE = re.compile(r"plan\s*=\s*\[([^\]]*)\]")


def _extract_plan(prompt: str) -> str:
    """从侧车 prompt 中抽取符号计划文本。

    prompt 形如 "phase=0 intensity=1 confidence=55% policy=0 plan=[水→木→火]"。
    抽取中括号内的内容；若无 plan 字段，则回退为整条 prompt。
    """
    if not prompt:
        return ""
    m = _PLAN_RE.search(prompt)
    if m:
        return m.group(1).strip()
    return prompt.strip()


def _is_valid_call(rec: Dict[str, Any]) -> bool:
    """基本校验一条侧车调用记录是否可作训练对。

    规则：必须是成功调用（ok 真、degraded 假），且 prompt / response /
    call_id 均非空字符串。
    """
    if not isinstance(rec, dict):
        return False
    if not rec.get("call_id"):
        return False
    prompt = rec.get("prompt")
    response = rec.get("response")
    if not isinstance(prompt, str) or not prompt.strip():
        return False
    if not isinstance(response, str) or not response.strip():
        return False
    # ok 字段缺失视为失败；degraded 非 0 视为降级（不可用）
    if not rec.get("ok"):
        return False
    if rec.get("degraded"):
        return False
    return True


def load_pairs(cfg: StageBConfig) -> List[Dict[str, str]]:
    """从侧车 ledger 抽取有效 (plan, response) 训练对。

    过滤掉缺少 plan / response 或标记为降级的记录。

    Args:
        cfg: 阶段 B 配置（含 ledger_sidecar 路径）。
    Returns:
        每条为 {'plan': str, 'response': str, 'call_id': str} 的列表。
    """
    raw = read_jsonl(str(cfg.ledger_sidecar))
    out: List[Dict[str, str]] = []
    for rec in raw:
        if not _is_valid_call(rec):
            continue
        prompt = str(rec.get("prompt", ""))
        response = str(rec.get("response", ""))
        out.append(
            {
                "plan": _extract_plan(prompt),
                "response": response.strip(),
                "call_id": str(rec.get("call_id")),
            }
        )
    return out


def load_lineage(cfg: StageBConfig) -> List[Dict[str, Any]]:
    """加载血缘 ledger，按 lineage_id 合并 (trace, backfill) 记录。

    Args:
        cfg: 阶段 B 配置（含 ledger_lineage 路径）。
    Returns:
        合并后的血缘记录字典列表（含 lineage_id 串联信息与 has_* 标记）。
    """
    raw = read_jsonl(str(cfg.ledger_lineage))
    groups: Dict[int, Dict[str, Any]] = {}
    for rec in raw:
        if not isinstance(rec, dict):
            continue
        lid = rec.get("lineage_id")
        if lid is None:
            continue
        lid = int(lid)
        bucket = groups.setdefault(
            lid,
            {
                "lineage_id": lid,
                "phase": rec.get("phase"),
                "policy_id": rec.get("policy_id"),
                "plan": rec.get("plan"),
                "plan_len": rec.get("plan_len"),
                "span_len": rec.get("span_len"),
                "conf_milli": rec.get("conf_milli"),
                "ok": rec.get("ok"),
                "degraded": rec.get("degraded"),
                "status": rec.get("status"),
                "latency_ms": rec.get("latency_ms"),
                "has_trace": False,
                "has_backfill": False,
                "num_records": 0,
            },
        )
        bucket["num_records"] += 1
        kind = rec.get("kind")
        if kind == 0:
            bucket["has_trace"] = True
            # trace 提供 plan 结构，优先以 trace 的字段为准
            if bucket["plan"] is None:
                bucket["plan"] = rec.get("plan")
            if bucket["phase"] is None:
                bucket["phase"] = rec.get("phase")
        elif kind == 1:
            bucket["has_backfill"] = True
            # backfill 提供最终 status / ok 结果
            if rec.get("status") is not None:
                bucket["status"] = rec.get("status")
            if rec.get("ok") is not None:
                bucket["ok"] = rec.get("ok")
    return list(groups.values())


def split_train_eval(
    pairs: List[Dict[str, str]], eval_ratio: float = 0.1
) -> Tuple[List[Dict[str, str]], List[Dict[str, str]]]:
    """按比例切分训练集 / 验证集（确定性，按索引）。

    Args:
        pairs: 全部训练对。
        eval_ratio: 验证集占比（默认 0.1）。
    Returns:
        (train_pairs, eval_pairs) 二元组。
    """
    if not pairs:
        return ([], [])
    n_eval = int(round(len(pairs) * float(eval_ratio)))
    n_eval = max(0, min(n_eval, len(pairs)))
    eval_pairs = pairs[:n_eval]
    train_pairs = pairs[n_eval:]
    return (train_pairs, eval_pairs)


def validate_pairs(pairs: List[Dict[str, str]]) -> Tuple[int, List[str]]:
    """对训练对做基本校验，返回 (有效数, 问题描述列表)。

    供流水线在训练前确认数据质量；不影响返回形状。
    """
    issues: List[str] = []
    valid = 0
    for i, p in enumerate(pairs):
        if not isinstance(p, dict):
            issues.append("pair[%d]: 非 dict" % i)
            continue
        if not p.get("plan"):
            issues.append("pair[%d]: 缺 plan" % i)
            continue
        if not p.get("response"):
            issues.append("pair[%d]: 缺 response" % i)
            continue
        if not p.get("call_id"):
            issues.append("pair[%d]: 缺 call_id" % i)
            continue
        valid += 1
    return (valid, issues)
