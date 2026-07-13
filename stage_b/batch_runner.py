"""批量运行器：驱动 Mojo e2e 收集更多 ledger，或遍历输入集汇总统计。

骨架定义采集与统计接口占位；真实实现调用 `mojo run e2e_demo.mojo`。
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from config import StageBConfig


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
        cfg: 阶段 B 配置。
    Returns:
        统计字典（counts / phase_dist / degraded_rate）。
    """
    # 骨架占位：真实实现读取 sidecar_calls.jsonl 计算分布。
    return {"counts": 0, "phase_dist": {}, "degraded_rate": 0.0}
