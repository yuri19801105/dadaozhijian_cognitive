# observability/store.mojo — 跨进程持久化 ledger（回灌 ↔ 溯源 链路串联）
#
# 真实约束（Mojo 1.0.0b2）：无原生文件/HTTP/子进程 API；@extern 的 fclose/fflush 被 FFI 判为
#   非法，system() 的字符串传递不可靠。因此"跨进程"经由**可靠的 stdout 管道**实现：
#   Mojo 侧把 ledger 序列化为 JSON-Lines 字符串（to_jsonl），由任意下游进程（如
#   observability/store_reader.py）从 stdin 消费 —— 这是本构建下唯一可靠的持久化/跨进程通道。
#   结构化记录全程在内存，序列化仅在导出时发生（不持有 String 字段，保证 Trivial/Movable）。
#
# 职责（对应需求 ②）：把"回灌结果"与"observability 溯源链路"以 lineage_id 关联，
#   使数据可跨进程追踪（同一 lineage_id 下既有溯源 span 记录，也有回灌落库记录）。
#
# 运行: mojo run -I . -I core observability/store.mojo

from pipeline import PipelineResult
from shifang import ShifangOutput
from observability.tracing import Tracer
from wuxing import element_name

comptime REC_TRACE: Int = 0        # 溯源记录（来自 Tracer + PipelineResult）
comptime REC_BACKFILL: Int = 1     # 回灌落库记录（来自 ReinjectionBridge）

struct TraceRecord(TrivialRegisterPassable):
    # 纯标量 → 隐式可拷贝 + Movable（可放入 List）；detail 文本在序列化时由标量推导，不存储。
    var kind: Int            # REC_TRACE / REC_BACKFILL
    var lineage_id: Int      # 关联键：同源的溯源与回灌共享同一 id
    var phase: Int
    var policy_id: Int
    var plan0: Int; var plan1: Int; var plan2: Int; var plan3: Int
    var plan4: Int; var plan5: Int; var plan6: Int; var plan7: Int
    var plan_len: Int
    var span_len: Int
    var conf_milli: Int      # 置信度 ×1000
    var ok: Int
    var degraded: Int
    var status: Int          # 回灌状态: 1 成功 / 0 拒绝 / -1 异常
    var latency_ms: Int
    def __init__(out self):
        self.kind = 0; self.lineage_id = 0; self.phase = 0; self.policy_id = 0
        self.plan0 = -1; self.plan1 = -1; self.plan2 = -1; self.plan3 = -1
        self.plan4 = -1; self.plan5 = -1; self.plan6 = -1; self.plan7 = -1
        self.plan_len = 0; self.span_len = 0; self.conf_milli = 0
        self.ok = 0; self.degraded = 0; self.status = 0; self.latency_ms = 0


struct TraceLedger(Movable):
    # 追加式内存 ledger；导出为 JSON-Lines 字符串供跨进程消费。
    var recs: List[TraceRecord]
    var seq: Int

    def __init__(out self):
        self.recs = List[TraceRecord]()
        self.seq = 0

    def size(self) -> Int:
        return len(self.recs)

    # 单调 lineage 序号（回灌轮次与溯源成对关联）。
    def next_id(mut self) -> Int:
        self.seq = self.seq + 1
        return self.seq

    # 记录溯源：把规划链 + 决策 span 固化（与后续回灌共享 lineage_id）。
    def record_trace(mut self, t: Tracer, r: PipelineResult) -> Int:
        var id = self.next_id()
        var rec = TraceRecord()
        rec.kind = REC_TRACE
        rec.lineage_id = id
        rec.phase = r.phase
        rec.policy_id = r.policy_id
        rec.plan_len = r.plan_len
        if r.plan_len > 0:
            rec.plan0 = r.plan_at(0)
        if r.plan_len > 1:
            rec.plan1 = r.plan_at(1)
        if r.plan_len > 2:
            rec.plan2 = r.plan_at(2)
        if r.plan_len > 3:
            rec.plan3 = r.plan_at(3)
        if r.plan_len > 4:
            rec.plan4 = r.plan_at(4)
        if r.plan_len > 5:
            rec.plan5 = r.plan_at(5)
        if r.plan_len > 6:
            rec.plan6 = r.plan_at(6)
        if r.plan_len > 7:
            rec.plan7 = r.plan_at(7)
        rec.span_len = t.span_len
        rec.conf_milli = Int(r.confidence * 1000.0)
        self.recs.append(rec)
        return id

    # 记录回灌落库：以同一 lineage_id 与溯源关联（status: 1 成功/0 拒绝/-1 异常）。
    def record_backfill(mut self, lineage_id: Int, status: Int, ok: Int,
                        degraded: Int, conf_milli: Int, policy_id: Int,
                        latency_ms: Int):
        var rec = TraceRecord()
        rec.kind = REC_BACKFILL
        rec.lineage_id = lineage_id
        rec.status = status
        rec.ok = ok
        rec.degraded = degraded
        rec.conf_milli = conf_milli
        rec.policy_id = policy_id
        rec.latency_ms = latency_ms
        self.recs.append(rec)

    # 取某 lineage_id 的全部记录（证明溯源↔回灌跨记录关联）。
    def lineage(self, lineage_id: Int) -> String:
        var s = String("[lineage ")
        s = s + String(lineage_id) + "]\n"
        for i in range(len(self.recs)):
            var r = self.recs[i]
            if r.lineage_id != lineage_id:
                continue
            if r.kind == REC_TRACE:
                s = s + "  trace: phase=" + String(r.phase)
                s = s + " policy=" + String(r.policy_id)
                s = s + " plan=["
                var k = 0
                while k < r.plan_len:
                    if k > 0:
                        s = s + "→"
                    var el = -1
                    if k == 0: el = r.plan0
                    elif k == 1: el = r.plan1
                    elif k == 2: el = r.plan2
                    elif k == 3: el = r.plan3
                    elif k == 4: el = r.plan4
                    elif k == 5: el = r.plan5
                    elif k == 6: el = r.plan6
                    elif k == 7: el = r.plan7
                    s = s + element_name(el)
                    k = k + 1
                s = s + "] spans=" + String(r.span_len) + "\n"
            else:
                s = s + "  backfill: status=" + String(r.status)
                s = s + " ok=" + String(r.ok) + " degraded=" + String(r.degraded)
                s = s + " conf=" + String(r.conf_milli) + "‰"
                s = s + " latency=" + String(r.latency_ms) + "ms\n"
        return s^

    # —— 结构化访问器（供测试与下游消费，无需字符串解析）——
    def count_kind(self, lineage_id: Int, kind: Int) -> Int:
        var n = 0
        for i in range(len(self.recs)):
            if self.recs[i].lineage_id == lineage_id and self.recs[i].kind == kind:
                n = n + 1
        return n

    def backfill_status(self, lineage_id: Int) -> Int:
        for i in range(len(self.recs)):
            if self.recs[i].lineage_id == lineage_id and self.recs[i].kind == REC_BACKFILL:
                return self.recs[i].status
        return -2   # 未找到

    def backfill_latency(self, lineage_id: Int) -> Int:
        for i in range(len(self.recs)):
            if self.recs[i].lineage_id == lineage_id and self.recs[i].kind == REC_BACKFILL:
                return self.recs[i].latency_ms
        return -1

    def backfill_conf(self, lineage_id: Int) -> Int:
        for i in range(len(self.recs)):
            if self.recs[i].lineage_id == lineage_id and self.recs[i].kind == REC_BACKFILL:
                return self.recs[i].conf_milli
        return -1

    # 序列化为 JSON-Lines（跨进程消费格式；key 顺序稳定，便于下游解析）。
    def to_jsonl(self) -> String:
        var s = String()
        for i in range(len(self.recs)):
            var r = self.recs[i]
            s = s + "{"
            s = s + "\"kind\":" + String(r.kind)
            s = s + ",\"lineage_id\":" + String(r.lineage_id)
            s = s + ",\"phase\":" + String(r.phase)
            s = s + ",\"policy_id\":" + String(r.policy_id)
            s = s + ",\"plan_len\":" + String(r.plan_len)
            s = s + ",\"plan\":[" + String(r.plan0) + "," + String(r.plan1) + ","
            s = s + String(r.plan2) + "," + String(r.plan3) + "," + String(r.plan4)
            s = s + "," + String(r.plan5) + "," + String(r.plan6) + "," + String(r.plan7) + "]"
            s = s + ",\"span_len\":" + String(r.span_len)
            s = s + ",\"conf_milli\":" + String(r.conf_milli)
            s = s + ",\"ok\":" + String(r.ok)
            s = s + ",\"degraded\":" + String(r.degraded)
            s = s + ",\"status\":" + String(r.status)
            s = s + ",\"latency_ms\":" + String(r.latency_ms)
            s = s + "}\n"
        return s^

    # 跨进程导出：直接打印 JSON-Lines（由下游进程从 stdin 消费，实现持久化链路追踪）。
    def emit(self):
        print(self.to_jsonl())
