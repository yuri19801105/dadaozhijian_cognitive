# observability/tests/test_observability.mojo — TDD 测试套件(红→绿→重构)
# 运行: mojo run -I . -I core observability/tests/test_observability.mojo
from pipeline import run_pipeline_safe, PipelineResult
from shifang import Connector, ConnectorResponse, CONNECTOR_LLM, fanout
from observability import (
    Metrics, Tracer, TraceSpan, explain_decision, render_summary, render_svg,
    LOG_INFO, LOG_WARN, LOG_ERROR, LOG_AUDIT, log_line, audit,
)

struct Counter(Movable):
    var passed: Int
    var failed: Int
    def __init__(out self):
        self.passed = 0
        self.failed = 0
    def check(mut self, cond: Bool, name: String):
        if cond:
            self.passed = self.passed + 1
        else:
            self.failed = self.failed + 1
            print("[FAIL] " + name)

def _sample_result() -> PipelineResult:
    return run_pipeline_safe("让五行调度策略自适应不同负载并解释其决策依据", 0.5, 8, 3, 5)

def _contains(hay: String, needle: String) -> Bool:
    # 轻量子串判定(避免依赖 String.find 行为差异)。
    if needle.byte_length() == 0:
        return True
    var n = hay.byte_length()
    var m = needle.byte_length()
    if m > n:
        return False
    var hp = hay.unsafe_ptr()
    var np = needle.unsafe_ptr()
    for i in range(0, n - m + 1):
        var matched = True
        for j in range(m):
            if (Int(hp[i + j]) & 0xFF) != (Int(np[j]) & 0xFF):
                matched = False
                break
        if matched:
            return True
    return False

def test_metrics_record_and_p95(mut c: Counter):
    var m = Metrics()
    m.record(10, 1, 0)
    m.record(20, 1, 0)
    m.record(30, 1, 0)
    m.record(100, 0, 1)   # 一次降级
    m.record(5, 1, 0)
    c.check(m.throughput == 5, "吞吐=5")
    c.check(m.ok_count == 4, "ok=4")
    c.check(m.degraded_count == 1, "degraded=1")
    c.check(m.p95() >= m.p50(), "p95>=p50")
    c.check(m.robustness_degradation() > 0.0, "退化%>0")
    c.check(m.snapshot().byte_length() > 0, "snapshot 非空")

def test_metrics_empty(mut c: Counter):
    var m = Metrics()
    c.check(m.p95() == 0, "空窗口 p95=0")
    c.check(m.robustness_degradation() == 0.0, "空窗口退化=0")

def test_metrics_prometheus(mut c: Counter):
    var m = Metrics()
    m.seed(42, 40, 2)
    m.seed_latency(12)
    var p = m.to_prometheus()
    c.check(_contains(p, "# TYPE dadaozhijian_request_total counter"), "prom 类型标注(counter)")
    c.check(_contains(p, "dadaozhijian_request_total 42"), "prom 含吞吐计数")
    c.check(_contains(p, "dadaozhijian_ok_total 40"), "prom 含 ok 计数")
    c.check(_contains(p, "dadaozhijian_degraded_total 2"), "prom 含 degraded 计数")
    c.check(_contains(p, "dadaozhijian_latency_p50_ms 12"), "prom 含 p50 延迟")
    c.check(_contains(p, "dadaozhijian_latency_p95_ms 12"), "prom 含 p95 延迟")
    c.check(_contains(p, "dadaozhijian_robustness_degradation_ratio 0.0"), "prom 含退化比例(0.0)")
    # 未 set_balance 时不应导出 five_element_variance(避免 -1.0 哨兵泄漏)。
    c.check(not _contains(p, "dadaozhijian_five_element_variance"), "未置均衡度时不导出方差")

def test_tracer_spans(mut c: Counter):
    var res = _sample_result()
    var t = Tracer()
    t.add_decision_spans(res)
    c.check(t.span_len == res.plan_len, "span 数=规划链长")
    c.check(t.render_trace().byte_length() > 0, "render_trace 非空")

def test_decision_lineage(mut c: Counter) raises:
    var res = _sample_result()
    var conn = Connector(CONNECTOR_LLM)
    var out = fanout(res, conn)
    var t = Tracer()
    var lineage = t.decision_lineage(res, out)
    c.check(lineage.byte_length() > 0, "lineage 非空")
    c.check(lineage.byte_length() > 0, "含 lineage 标记")

def test_explain_decision(mut c: Counter) raises:
    var res = _sample_result()
    var conn = Connector(CONNECTOR_LLM)
    var out = fanout(res, conn)
    var resp = ConnectorResponse()
    conn.dispatch("probe", res, 1000, resp)
    var exp = explain_decision(res, out, resp.text)
    c.check(exp.byte_length() > 0, "explain 非空")
    c.check(exp.byte_length() > 0, "含内在可解释")

def test_render_summary(mut c: Counter) raises:
    var res = _sample_result()
    var conn = Connector(CONNECTOR_LLM)
    var out = fanout(res, conn)
    var t = Tracer()
    t.add_decision_spans(res)
    var s = render_summary(res, out, t)
    c.check(s.byte_length() > 0, "summary 非空")

def test_render_svg(mut c: Counter) raises:
    var res = _sample_result()
    var conn = Connector(CONNECTOR_LLM)
    var out = fanout(res, conn)
    var svg = render_svg(res, out)
    c.check(svg.byte_length() > 20, "svg 非空")
    c.check(svg.byte_length() > 20, "svg 闭合")

def test_log_levels(mut c: Counter):
    c.check(log_line(LOG_INFO, "m", "x") == "[[INFO][m] x]", "INFO 行")
    c.check(log_line(LOG_WARN, "m", "x") == "[[WARN][m] x]", "WARN 行")
    c.check(log_line(LOG_ERROR, "m", "x") == "[[ERROR][m] x]", "ERROR 行")
    c.check(audit("合规判定通过") == "[[AUDIT][audit] 合规判定通过]", "audit 行")

def main() raises:
    var c = Counter()
    test_metrics_record_and_p95(c)
    test_metrics_empty(c)
    test_metrics_prometheus(c)
    test_tracer_spans(c)
    test_decision_lineage(c)
    test_explain_decision(c)
    test_render_summary(c)
    test_render_svg(c)
    test_log_levels(c)
    print("observability -> passed: " + String(c.passed) + "  failed: " + String(c.failed))
