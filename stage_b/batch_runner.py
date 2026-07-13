"""批量运行器：驱动 Mojo e2e 收集更多 ledger，或遍历输入集汇总统计。

真实实现（v0.2）：
  - collect_ledger : 仍保留占位（真实采集需 mojo 工具链，按需启用）。
  - summarize      : 解析 sidecar_calls.jsonl，计算 调用数 / 成功数 / 降级数 /
                     相位分布 / 后端分布 / 降级率，返回真实统计字典。
"""
from __future__ import annotations

import re
from typing import Any, Dict, List, Optional

from config import StageBConfig
from utils import read_jsonl


_PHASE_RE = re.compile(r"phase\s*=\s*(\d+)")


def collect_ledger(cfg: StageBConfig, inputs: Optional[List[str]] = None) -> int:
    """运行 e2e 联调以累积 ledger，返回新增记录数。

    Args:
        cfg: 阶段 B 配置（project_root 定位 e2e_demo.mojo）。
        inputs: 可选输入列表；为 None 时使用 e2e_demo 内置默认集。
    Returns:
        本次新增的 ledger 记录数。
    """
    # 骨架占位：真实实现经 subprocess 调用
    #   mojo run -I . -I core e2e_demo.mojo
    # 并解析其输出统计新增条数。此处仅打印意图，不实际调用。
    cmd = "mojo run -I . -I core e2e_demo.mojo"
    print("[batch_runner] 拟执行采集命令: %s （骨架占位，未实际调用）" % cmd)
    return 0


def summarize(cfg: StageBConfig) -> Dict[str, Any]:
    """汇总当前 ledger 的统计信息（调用数、相位分布、降级率）。

    Args:
        cfg: 阶段 B 配置（含 ledger_sidecar 路径）。
    Returns:
        统计字典：counts(总调用数) / ok / degraded / phase_dist(相位->次数) /
        backends(后端->次数) / degraded_rate(降级率 0~1)。
    """
    raw = read_jsonl(str(cfg.ledger_sidecar))
    total = len(raw)
    ok = 0
    degraded = 0
    phase_dist: Dict[str, int] = {}
    backends: Dict[str, int] = {}
    for rec in raw:
        if not isinstance(rec, dict):
            continue
        if rec.get("ok"):
            ok += 1
        if rec.get("degraded"):
            degraded += 1
        backend = rec.get("backend")
        if backend:
            backends[str(backend)] = backends.get(str(backend), 0) + 1
        pm = _PHASE_RE.search(str(rec.get("prompt", "")))
        if pm:
            ph = pm.group(1)
            phase_dist[ph] = phase_dist.get(ph, 0) + 1
    degraded_rate = (degraded / total) if total else 0.0
    return {
        "counts": total,
        "ok": ok,
        "degraded": degraded,
        "phase_dist": phase_dist,
        "backends": backends,
        "degraded_rate": degraded_rate,
    }
