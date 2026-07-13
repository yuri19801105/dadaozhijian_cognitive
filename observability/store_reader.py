#!/usr/bin/env python3
# === observability/store_reader.py ===
# 跨进程持久化消费端：从 stdin 读取 Mojo 侧导出的 JSON-Lines ledger
# （TraceLedger.to_jsonl() 的输出），校验"回灌 ↔ 溯源"链路串联。
#
# 架构说明（Mojo 1.0.0b2 真实约束）：
#   本构建无原生文件/HTTP/子进程 API；唯一可靠的跨进程通道是 stdout 管道。
#   Mojo 侧把 ledger 序列化为 JSON-Lines 字符串并 print，下游（本脚本）从
#   stdin 消费 —— 实现持久化链路追踪。
#
# 用法：
#   mojo run -I . -I core observability/store_demo.mojo | python3 observability/store_reader.py
#
# 校验逻辑：
#   - 每条记录必须有合法 JSON 与已知 kind（0=trace, 1=backfill）。
#   - 按 lineage_id 分组：同一 lineage 下应同时存在 trace 与 backfill 记录 → 链路串联成立。
#   - 输出每个 lineage 的溯源(plan/policy/phase)与回灌(status/conf/latency)对照，便于人工审计。

import sys
import json


REC_TRACE = 0
REC_BACKFILL = 1

KIND_NAME = {REC_TRACE: "trace", REC_BACKFILL: "backfill"}


def main() -> int:
    raw = sys.stdin.read()
    lines = [ln for ln in raw.splitlines() if ln.strip()]
    if not lines:
        print("[store_reader] 空输入：未收到任何 ledger 记录")
        return 1

    records = []
    skipped = 0
    for i, ln in enumerate(lines):
        stripped = ln.strip()
        # 容忍非 JSON 行（真实跨进程管道可能夹杂日志/空行）——跳过而非报错。
        if not stripped.startswith("{"):
            skipped += 1
            continue
        try:
            rec = json.loads(ln)
        except json.JSONDecodeError as e:
            print(f"[store_reader] 第 {i} 行 JSON 解析失败: {e} -> {ln!r}")
            return 2
        if "kind" not in rec or "lineage_id" not in rec:
            print(f"[store_reader] 第 {i} 行缺少 kind/lineage_id 字段: {ln!r}")
            return 2
        records.append(rec)

    # 按 lineage_id 分组
    groups = {}
    for rec in records:
        groups.setdefault(rec["lineage_id"], []).append(rec)

    print(f"[store_reader] 收到 {len(records)} 条记录，{len(groups)} 个 lineage"
          + (f"（跳过 {skipped} 行非 JSON 日志）" if skipped else ""))
    linked = 0
    broken = 0
    for lid in sorted(groups.keys()):
        recs = groups[lid]
        kinds = {r["kind"] for r in recs}
        has_trace = REC_TRACE in kinds
        has_backfill = REC_BACKFILL in kinds
        if has_trace and has_backfill:
            linked += 1
            # 取第一条 trace 与第一条 backfill 做对照
            tr = next(r for r in recs if r["kind"] == REC_TRACE)
            bf = next(r for r in recs if r["kind"] == REC_BACKFILL)
            plan = tr.get("plan", [-1, -1, -1, -1, -1, -1, -1, -1])
            plan = [p for p in plan if p >= 0]
            print(f"  lineage {lid}: 链路串联 ✅")
            print(f"    溯源  : phase={tr.get('phase')} policy={tr.get('policy_id')} plan={plan}")
            print(f"    回灌  : status={bf.get('status')} conf={bf.get('conf_milli')}‰ "
                  f"latency={bf.get('latency_ms')}ms ok={bf.get('ok')} degraded={bf.get('degraded')}")
        else:
            broken += 1
            print(f"  lineage {lid}: 链路不完整 ⚠ kind={[KIND_NAME.get(k, k) for k in kinds]}")

    print(f"[store_reader] 串联完整 {linked} / 不完整 {broken}")
    if broken > 0:
        print("[store_reader] 存在未串联 lineage，链路校验未通过")
        return 3
    print("[store_reader] 全部 lineage 溯源↔回灌串联成立 ✅")
    return 0


if __name__ == "__main__":
    sys.exit(main())
