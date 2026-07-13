# shifang/protocol.mojo — 外部模型/API 连接器协议（真实接入缝 + 熔断/重试/降级）
# 让架构"能说话"的关键：以 PipelineResult 构造 prompt, 经连接器生成可读回复。
# call_external 经 shifang_llm_call 缝真实抵达 llm_sidecar.py（Mojo→python3 子进程桥接，已端到端验证）；
#   默认 Connector 持 ExternalLLMSidecar(真实 LLM 接入缝)，未设置 LLM_API_KEY 时侧车优雅降级；
#   离线/确定性单测显式传 SIDECAR_TEMPLATE。
# 运行: mojo run -I . -I core shifang/protocol.mojo
from pipeline import PipelineResult
from wuxing import element_name, WOOD, FIRE, EARTH, METAL, WATER
from .sidecar import LLMSidecar, SIDECAR_TEMPLATE, SIDECAR_EXTERNAL, shifang_llm_call

comptime CONNECTOR_LOCAL: Int = 0
comptime CONNECTOR_LLM: Int = 1

# 十方方向常量(东/南/西/北/东南/西南/东北/西北/上/下)
comptime DIR_EAST: Int = 0
comptime DIR_SOUTH: Int = 1
comptime DIR_WEST: Int = 2
comptime DIR_NORTH: Int = 3
comptime DIR_SE: Int = 4
comptime DIR_SW: Int = 5
comptime DIR_NE: Int = 6
comptime DIR_NW: Int = 7
comptime DIR_UP: Int = 8
comptime DIR_DOWN: Int = 9
comptime DIR_COUNT: Int = 10

def direction_name(id: Int) -> String:
    if id == DIR_EAST: return "东"
    if id == DIR_SOUTH: return "南"
    if id == DIR_WEST: return "西"
    if id == DIR_NORTH: return "北"
    if id == DIR_SE: return "东南"
    if id == DIR_SW: return "西南"
    if id == DIR_NE: return "东北"
    if id == DIR_NW: return "西北"
    if id == DIR_UP: return "上"
    if id == DIR_DOWN: return "下"
    return "?"

struct ConnectorResponse:
    # 含 String 字段 → 非 Movable; 一律以 mut resp 传出, 不以值返回。
    var text: String
    var ok: Int
    var degraded: Int
    var latency_ms: Int
    var attempt: Int
    def __init__(out self):
        self.text = String()
        self.ok = 0
        self.degraded = 0
        self.latency_ms = 0
        self.attempt = 0

struct Connector(Movable):
    # 连接器状态机: 熔断(cb_open) + 失败计数(fail_count) + 侧车(真实 LLM 接入缝)。
    var kind: Int
    var fail_count: Int
    var cb_open: Int
    var last_latency: Int
    var trip_threshold: Int
    var sidecar: LLMSidecar       # 默认 ExternalLLMSidecar(真实 LLM 接入缝); 离线/单测显式传 SIDECAR_TEMPLATE
    def __init__(out self, kind: Int):
        # 默认接入真实 LLM 侧车（需求 ①）：未设置 LLM_API_KEY 时侧车优雅降级，ok=1。
        self.kind = kind
        self.fail_count = 0
        self.cb_open = 0
        self.last_latency = 0
        self.trip_threshold = 3
        self.sidecar = LLMSidecar(SIDECAR_EXTERNAL)
    def __init__(out self, kind: Int, mode: Int):
        self.kind = kind
        self.fail_count = 0
        self.cb_open = 0
        self.last_latency = 0
        self.trip_threshold = 3
        self.sidecar = LLMSidecar(mode)
    def _record_success(mut self):
        self.fail_count = 0
        self.cb_open = 0
    def _record_failure(mut self):
        self.fail_count = self.fail_count + 1
        if self.fail_count >= self.trip_threshold:
            self.cb_open = 1
    def dispatch(mut self, prompt: String, result: PipelineResult,
                 timeout_ms: Int, mut resp: ConnectorResponse) raises:
        # 熔断开启 → 直接降级回复(防雪崩), 不调用外部。
        if self.cb_open == 1:
            resp.text = "[降级] 连接器熔断开启, 返回缓存占位回复。"
            resp.ok = 0
            resp.degraded = 1
            resp.latency_ms = 0
            resp.attempt = 0
            return
        # 超时建模: 若 timeout_ms <= 0 视为超时 → 降级。
        if timeout_ms <= 0:
            self._record_failure()
            resp.text = "[降级] 连接器超时。"
            resp.ok = 0
            resp.degraded = 1
            resp.latency_ms = 0
            resp.attempt = 1
            return
        # 经侧车生成回复（需求 ①：call_external 经 LLMSidecar 侧车缝真实抵达 LLM）。
        # 默认 ExternalLLMSidecar 经 shifang_llm_call 真实桥接 llm_sidecar.py 子进程；
        #   未设置 LLM_API_KEY 时侧车返回确定性降级串（ok=1, degraded=0），上层可正常消费。
        #   离线/确定性单测可将 Connector 构造为 SIDECAR_TEMPLATE。
        self.sidecar.call(prompt, result, resp)
        self.last_latency = resp.latency_ms
        if resp.ok == 1:
            self._record_success()
    def with_retry(mut self, prompt: String, result: PipelineResult,
                   timeout_ms: Int, max_retries: Int, mut resp: ConnectorResponse):
        # 非 raises: 重试耗尽 → 降级回复(不崩溃)。
        var attempt = 0
        while attempt <= max_retries:
            try:
                self.dispatch(prompt, result, timeout_ms, resp)
                if resp.ok == 1:
                    return
            except:
                self._record_failure()
            attempt = attempt + 1
        # 重试耗尽 → 降级
        resp.text = "[降级] 连接器重试耗尽, 返回安全占位回复。"
        resp.ok = 0
        resp.degraded = 1
        resp.latency_ms = 0
        resp.attempt = attempt

def call_external(prompt: String) raises -> String:
    # 真实 API 接入缝（唯一外部依赖点）：经 shifang_llm_call 真实桥接 llm_sidecar.py 子进程。
    # 默认（未设置 LLM_API_KEY）侧车优雅降级返回确定性文本；设置后即为真实 LLM 回复。
    # 旧的 mock/占位模板已移除 —— 统一由 LLMSidecar 侧车缝(见 sidecar.mojo)承接。
    return shifang_llm_call(prompt)
