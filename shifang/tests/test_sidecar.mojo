# === shifang/tests/test_sidecar.mojo ===
# TDD: 真实 LLM 侧车（需求 ①）— 模板/外部两种模式 + C-ABI 接入缝 + Connector 委托。
# 运行: mojo run -I . -I core shifang/tests/test_sidecar.mojo
from shifang import (
    LLMSidecar, SidecarRequest, SidecarResponse,
    SIDECAR_TEMPLATE, SIDECAR_EXTERNAL, shifang_llm_call,
    Connector, CONNECTOR_LLM, ConnectorResponse,
)
from pipeline import PipelineResult, run_pipeline_safe
from wuxing import WOOD, FIRE, EARTH

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
    var res = run_pipeline_safe("测试 prompt", 0.5, 8, 3, 5)
    return res^

def test_template_sidecar(mut c: Counter) raises:
    var sc = LLMSidecar()                 # 默认 = 模板模式
    c.check(sc.mode == SIDECAR_TEMPLATE, "默认模板模式")
    var resp = ConnectorResponse()
    sc.call("phase=2 plan=[木→火]", _sample_result(), resp)
    c.check(resp.ok == 1, "模板侧车 ok=1")
    c.check(resp.degraded == 0, "模板侧车 非降级")
    c.check(resp.text.find("[模型回复]") >= 0, "模板侧车含 [模型回复] 标记")
    c.check(resp.text.find("phase=2 plan=[木→火]") >= 0, "模板侧车回显 prompt")

def test_external_sidecar_default_seam(mut c: Counter) raises:
    # 外部模式经 shifang_llm_call 缝真实抵达 llm_sidecar.py 子进程（已端到端验证）。
    # 默认未设置 LLM_API_KEY → 侧车优雅降级返回确定性非空文本（仍证明桥接真实打通）。
    var sc = LLMSidecar(SIDECAR_EXTERNAL)
    c.check(sc.mode == SIDECAR_EXTERNAL, "外部模式")
    var resp = ConnectorResponse()
    sc.call("hello", _sample_result(), resp)
    c.check(resp.ok == 1, "外部侧车 ok=1（桥接成功）")
    c.check(resp.text.byte_length() > 0, "外部侧车返回非空真实文本")
    c.check(resp.text.find("[模型回复]") == -1, "外部侧车非模板回复（确走桥接）")
    c.check(resp.text.find("占位") == -1, "外部侧车已脱离旧占位实现")

def test_seam_function(mut c: Counter) raises:
    var s = shifang_llm_call("世界")
    c.check(s.byte_length() > 0, "shifang_llm_call 桥接返回非空")
    c.check(s.find("占位") == -1, "shifang_llm_call 已脱离旧占位实现")

def test_connector_delegates_template(mut c: Counter) raises:
    # Connector 默认持 ExternalLLMSidecar(真实 LLM 接入缝)；确定性单测显式传 SIDECAR_TEMPLATE。
    var conn = Connector(CONNECTOR_LLM, SIDECAR_TEMPLATE)
    c.check(conn.sidecar.mode == SIDECAR_TEMPLATE, "Connector 显式模板侧车")
    var res = _sample_result()
    var resp = ConnectorResponse()
    conn.dispatch("phase=2 plan=[木→火]", res, 1000, resp)
    c.check(resp.ok == 1, "Connector 派发 ok=1")
    c.check(resp.text.find("[模型回复]") >= 0, "Connector 经模板侧车回复")

def test_connector_delegates_external(mut c: Counter) raises:
    # 生产: 把 Connector.sidecar 换为 ExternalLLMSidecar → 走真实桥接(抵达 llm_sidecar.py)。
    var conn = Connector(CONNECTOR_LLM)
    conn.sidecar = LLMSidecar(SIDECAR_EXTERNAL)
    c.check(conn.sidecar.mode == SIDECAR_EXTERNAL, "Connector 换外部侧车")
    var res = _sample_result()
    var resp = ConnectorResponse()
    conn.dispatch("phase=2 plan=[木→火]", res, 1000, resp)
    c.check(resp.ok == 1, "Connector 外部派发 ok=1（桥接成功）")
    c.check(resp.text.byte_length() > 0, "Connector 外部派发返回非空文本")
    c.check(resp.text.find("[模型回复]") == -1, "Connector 经外部侧车桥接（非模板）")

def test_request_response_scalar(mut c: Counter):
    var req = SidecarRequest()
    c.check(req.mode == SIDECAR_TEMPLATE, "请求默认模板模式")
    c.check(req.timeout_ms == 2000, "请求默认超时 2000ms")
    var rsp = SidecarResponse()
    c.check(rsp.ok == 0 and rsp.degraded == 0, "响应初始清零")

def main() raises:
    var c = Counter()
    test_template_sidecar(c)
    test_external_sidecar_default_seam(c)
    test_seam_function(c)
    test_connector_delegates_template(c)
    test_connector_delegates_external(c)
    test_request_response_scalar(c)
    print("shifang sidecar -> passed: " + String(c.passed) + "  failed: " + String(c.failed))
