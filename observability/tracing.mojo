# observability/tracing.mojo — 决策可追溯: 五行生克/八卦算子/合规判定 全链路原生溯源
# TraceSpan 固定槽; Tracer 以 mut self 累积(容量 16, 非 List 嵌套)。
# 运行: mojo run -I . -I core observability/tracing.mojo
from pipeline import PipelineResult
from shifang import ShifangOutput
from wuxing import element_name

struct TraceSpan(TrivialRegisterPassable):
    # 单步溯源: 链路 id / 父 id / 阶段 / 元素 / 决策码 / 置信度(×1000) / 策略 id。
    # 全 Int 字段 → 隐式可拷贝(供 _span_at 按值返回 / Tracer 按值传参)。
    var trace_id: Int
    var parent: Int
    var stage: Int
    var element: Int
    var decision: Int
    var confidence_milli: Int
    var policy_id: Int
    def __init__(out self):
        self.trace_id = 0; self.parent = -1; self.stage = 0
        self.element = -1; self.decision = 0
        self.confidence_milli = 0; self.policy_id = 0

struct Tracer(TrivialRegisterPassable):
    # 16 个固定容量 span(非 List 嵌套); 全 TraceSpan(Int) 字段 → 隐式可拷贝。
    var s0: TraceSpan; var s1: TraceSpan; var s2: TraceSpan; var s3: TraceSpan
    var s4: TraceSpan; var s5: TraceSpan; var s6: TraceSpan; var s7: TraceSpan
    var s8: TraceSpan; var s9: TraceSpan; var s10: TraceSpan; var s11: TraceSpan
    var s12: TraceSpan; var s13: TraceSpan; var s14: TraceSpan; var s15: TraceSpan
    var span_len: Int
    def __init__(out self):
        self.s0 = TraceSpan(); self.s1 = TraceSpan(); self.s2 = TraceSpan(); self.s3 = TraceSpan()
        self.s4 = TraceSpan(); self.s5 = TraceSpan(); self.s6 = TraceSpan(); self.s7 = TraceSpan()
        self.s8 = TraceSpan(); self.s9 = TraceSpan(); self.s10 = TraceSpan(); self.s11 = TraceSpan()
        self.s12 = TraceSpan(); self.s13 = TraceSpan(); self.s14 = TraceSpan(); self.s15 = TraceSpan()
        self.span_len = 0
    def _span_at(self, idx: Int) -> TraceSpan:
        # 返回可变视图(通过赋值回写实现更新)。
        if idx == 0: return self.s0
        if idx == 1: return self.s1
        if idx == 2: return self.s2
        if idx == 3: return self.s3
        if idx == 4: return self.s4
        if idx == 5: return self.s5
        if idx == 6: return self.s6
        if idx == 7: return self.s7
        if idx == 8: return self.s8
        if idx == 9: return self.s9
        if idx == 10: return self.s10
        if idx == 11: return self.s11
        if idx == 12: return self.s12
        if idx == 13: return self.s13
        if idx == 14: return self.s14
        if idx == 15: return self.s15
        return self.s0
    def _write_span(mut self, idx: Int, sp: TraceSpan):
        if idx == 0: self.s0 = sp
        elif idx == 1: self.s1 = sp
        elif idx == 2: self.s2 = sp
        elif idx == 3: self.s3 = sp
        elif idx == 4: self.s4 = sp
        elif idx == 5: self.s5 = sp
        elif idx == 6: self.s6 = sp
        elif idx == 7: self.s7 = sp
        elif idx == 8: self.s8 = sp
        elif idx == 9: self.s9 = sp
        elif idx == 10: self.s10 = sp
        elif idx == 11: self.s11 = sp
        elif idx == 12: self.s12 = sp
        elif idx == 13: self.s13 = sp
        elif idx == 14: self.s14 = sp
        elif idx == 15: self.s15 = sp
    def add_span(mut self, span: TraceSpan):
        if self.span_len >= 16:
            return
        self._write_span(self.span_len, span)
        self.span_len = self.span_len + 1
    def add_decision_spans(mut self, result: PipelineResult):
        # 把规划链每步固化为一个溯源 span(父=上一链位)。
        var parent = -1
        for i in range(result.plan_len):
            var sp = TraceSpan()
            sp.trace_id = i
            sp.parent = parent
            sp.stage = i
            sp.element = result.plan_at(i)
            sp.decision = result.plan_at(i)
            sp.confidence_milli = Int(result.confidence * 1000.0)
            sp.policy_id = result.policy_id
            self.add_span(sp)
            parent = i
    def render_trace(self) -> String:
        var out = String("[trace] spans=" + String(self.span_len) + "\n")
        for i in range(self.span_len):
            var sp = self._span_at(i)
            out = out + "  #" + String(sp.trace_id) + " parent=" + String(sp.parent)
            out = out + " stage=" + String(sp.stage)
            out = out + " element=" + element_name(sp.element)
            out = out + " conf=" + String(sp.confidence_milli) + "‰"
            out = out + " policy=" + String(sp.policy_id) + "\n"
        return out^
    def decision_lineage(self, result: PipelineResult, output: ShifangOutput) -> String:
        # 全链路溯源: 相位 → 主导元素 → 规划链 → 十方扇出 → 连接器(ok/degraded 来自 output)。
        # 注: ConnectorResponse 含 String 非 Movable, 不可按值传参; 其 ok/degraded 已固化于 ShifangOutput。
        var out = String("[lineage] phase=" + String(result.phase))
        out = out + " plan=["
        for i in range(result.plan_len):
            if i > 0:
                out = out + "→"
            out = out + element_name(result.plan_at(i))
        out = out + "]"
        out = out + "\n[lineage] 十方扇出 " + String(output.action_len) + " 向"
        out = out + " (ok=" + String(output.ok) + " degraded=" + String(output.degraded) + ")"
        out = out + "\n[lineage] 策略 policy=" + String(result.policy_id)
        out = out + " conf=" + String(Int(result.confidence * 1000.0)) + "‰"
        return out^
