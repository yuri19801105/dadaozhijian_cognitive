"""阶段 B 工具函数：日志、计时、文件 IO。

纯标准库实现，无第三方依赖，保证骨架可在任意环境跑通。
"""
from __future__ import annotations

import json
import logging
import time
from pathlib import Path
from typing import Any, Dict, List


def get_logger(name: str, level: int = logging.INFO) -> logging.Logger:
    """返回统一格式的模块 logger。

    Args:
        name: logger 名称（通常为模块名）。
        level: 日志级别（默认 INFO）。
    Returns:
        配置好的 logging.Logger 实例。
    """
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )
    return logging.getLogger(name)


def time_block(label: str):
    """上下文管理器：测量代码块耗时并打印。

    Args:
        label: 计时标签，用于日志输出。
    Returns:
        上下文管理器对象（__enter__ 记录起点，__exit__ 打印耗时）。
    """

    class _Block:
        def __enter__(self):
            self._t = time.time()
            return self

        def __exit__(self, *exc):
            print("[time] %s: %.3fs" % (label, time.time() - self._t))

    return _Block()


def read_jsonl(path: str) -> List[Dict[str, Any]]:
    """逐行读取 JSON-Lines 文件，返回记录列表。

    Args:
        path: JSONL 文件路径。
    Returns:
        解析后的 dict 列表；文件不存在时返回空列表。
    """
    p = Path(path)
    if not p.exists():
        return []
    out: List[Dict[str, Any]] = []
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line:
            out.append(json.loads(line))
    return out


def write_jsonl(path: str, records: List[Dict[str, Any]]) -> None:
    """将记录列表以 JSON-Lines 格式写入文件（覆盖）。

    Args:
        path: 目标路径。
        records: 待写入的 dict 列表。
    """
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with p.open("w", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


def ensure_dir(path: str) -> Path:
    """确保目录存在（不存在则创建）。

    Args:
        path: 目录路径。
    Returns:
        目录的 Path 对象。
    """
    p = Path(path)
    p.mkdir(parents=True, exist_ok=True)
    return p


def write_text(path: str, text: str) -> None:
    """将文本写入文件（覆盖，UTF-8）。

    Args:
        path: 目标路径。
        text: 待写入的文本内容。
    """
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")
