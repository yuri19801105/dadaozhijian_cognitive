# `shifang/` — 十方（执行扇出 + 外部连接器）【v1.4 已落地 ✅】

> 十方 = 东/南/西/北/东南/西南/东北/西北/上/下 十个方向，是空间的最完备划分。
> 本模块把 `pipeline.PipelineResult.plan`（七星定序后的元素链）**周遍扇出到十方**，并经**真实模型/API 连接器**生成可读回复——架构首次"能说话"。

## 一、职责与边界
- **消费**：`pipeline.PipelineResult`（phase / intensity / plan / confidence / policy_id / ok）。
- **产出**：`ShifangOutput`（十方向 action 码 + ok + degraded + latency）；`ConnectorResponse`（连接器文本回复）。
- **故障隔离**：连接器 `raises` 透传 + 熔断（连续失败达阈值→`cb_open`）+ 重试（`with_retry`）+ 中性降级（`fanout_safe` 异常→`ok=0/degraded=1` 不崩溃）；不影响 `taiji` 状态根。

## 二、双后端选择器（已落地，非占位）
Mojo 1.0.0b2 **无内置 HTTP 客户端/子进程 API**，无法在 Mojo 内直接调远程 LLM。连接器以
`call_external(prompt) raises -> String` 为**唯一真实接入缝**，并已通过 **Mojo→python3 子进程桥接**真正抵达 `llm_sidecar.py`：
1. `shifang_llm_call(prompt)`（`sidecar.mojo`）以 `setenv("LLM_PROMPT")` 传 prompt → `system("python3 shifang/llm_sidecar.py > 响应文件")` 拉起侧车 → `fopen("r")/fread` 读回（UTF-8 解码）；
2. `llm_sidecar.py` 重构为**双后端选择器**：在 `qwen3-4b-mlx`(默认, `qwen3.5:4b-mlx`) / `phi-4-mini`(`phi4-mini:3.8b`) / `qwen3-4b`(可选轻量 fallback) 之间**按 `shifang/sidecar_config.json` 动态切换**，全部本地运行。支持**双接口**：`interface:"ollama"` 走原生 `/api/chat`、`interface:"openai"` 走 `/v1/chat/completions`（vLLM·llama.cpp 兼容）；
3. 选择器能力：**配置驱动切换** + **自动健康检查**（按接口探测 `/api/tags` 或 `/models`，结果缓存到 `shifang/ledger/.health_cache.json` 跨子进程有效）+ **故障转移**（`failover_order` 依次尝试，全失败则确定性降级）+ **全量 ledger 记录**（每条含 `call_id`、后端/模型/时延/token，写 `shifang/ledger/sidecar_calls.jsonl`，供两阶段蒸馏使用，输出可溯源）；
4. 兼容旧云 API：设置 `LLM_BASE_URL`/`LLM_MODEL`/`LLM_API_KEY` 环境变量即覆盖为单后端（最高优先级）；不设则走本地配置，零云依赖；
5. 早期"C shim 覆盖 Mojo 符号"方案因 macOS 链接器不支持多定义覆盖而废弃，改为纯 Mojo 桥接（无链接器 hack，`mojo run` 全面可用，已端到端验证）。
> ⚠️ **已知要点（Ollama + 思考模型）**：`qwen3.5:4b-mlx` 是**思考模型**，Ollama 的 OpenAI `/v1` 接口**不响应 `think:false`**（content 恒空、文本全进 `reasoning`），故该后端须用 `interface:"ollama"` 原生 `/api/chat` + `think:false` 方能关思考、直接出中文。生成调用超时（`call_timeout_sec`，默认 120s）与健康探测超时（`health_check.timeout_sec`，默认 5s）**已分离**——首次加载 4GB 模型需数十秒，切勿复用探测超时。
> 两种侧车模式：`LLMSidecar(SIDECAR_TEMPLATE)` 确定性模板（默认、离线可测）；`LLMSidecar(SIDECAR_EXTERNAL)` 经真实桥接。生产把 `Connector.sidecar` 换为外部模式即可——**Mojo 框架其余代码无需改动**，选择器对外契约（prompt→stdout）保持不变。
> 两阶段混合蒸馏计划见 `docs/two-stage-distillation-plan.md`（阶段 A：Qwen3-3B 本地默认+全量日志；阶段 B：自蒸馏唯一专属后端，下线外部大模型）。

## 三、接口骨架（函数签名 · 参数类型 · 返回值）
```mojo
# shifang/protocol.mojo
comptime CONNECTOR_LOCAL=0; CONNECTOR_LLM=1
comptime DIR_EAST=0..DIR_DOWN=9; DIR_COUNT=10
def direction_name(id) -> String
struct ConnectorResponse:                 # 含 String → 非 Movable, 以 mut resp 传出
    var text: String; var ok: Int; var degraded: Int; var latency_ms: Int; var attempt: Int
    def __init__(out self)
struct Connector(Movable):                # 熔断/重试状态机 + 侧车缝
    var kind: Int; var fail_count: Int; var cb_open: Int; var last_latency: Int; var trip_threshold: Int
    var sidecar: LLMSidecar              # 默认 TemplateSidecar; 可换 ExternalLLMSidecar
    def __init__(out self, kind: Int)
    def dispatch(mut self, prompt, result, timeout_ms, resp) raises   # mut resp 传参
    def with_retry(mut self, prompt, result, timeout_ms, max_retries, resp)
def call_external(prompt) raises -> String        # ★ 真实 API 接入缝(经 shifang_llm_call 桥接)

# shifang/sidecar.mojo
comptime SIDECAR_TEMPLATE=0; SIDECAR_EXTERNAL=1
struct LLMSidecar(Movable):               # 纯标量 → 可 Movable(随 Connector 持有)
    var mode: Int; var timeout_ms: Int; var simulate_latency: Int
    def call(self, prompt, result, resp) raises    # 模板 or 外部真实侧车
def shifang_llm_call(prompt) -> String    # Mojo→python3 子进程桥接(见 llm_sidecar.py)

# shifang/dispatch.mojo
struct ShifangOutput(Movable):            # 固定标量槽 a0..a9 + action_len + ok + degraded + latency_ms
    def action_at(self, dir) -> Int
def fanout(result, mut connector) raises -> ShifangOutput
def fanout_safe(result, mut connector) -> ShifangOutput

# shifang/executor.mojo
def action_label(element) -> String
def execute_plan_to_text(result, input) -> String
def render_reply(result, output, resp) -> String
```

## 四、调用示例（含真实外部侧车）
```mojo
from pipeline import run_pipeline_safe
from shifang import Connector, CONNECTOR_LLM, fanout, render_reply, ConnectorResponse, LLMSidecar, SIDECAR_EXTERNAL

var res = run_pipeline_safe("如何让调度策略自适应负载波动？", 0.5, 8, 3, 5)
var conn = Connector(CONNECTOR_LLM)
var out = fanout(res, conn)
var resp = ConnectorResponse()
conn.dispatch("prompt", res, 1000, resp)
print(render_reply(res, out, resp))    # 默认 TemplateSidecar: 架构"说话"(确定性)

# 生产: 换外部真实侧车 → 经 shifang_llm_call 桥接抵达 llm_sidecar.py(设 LLM_API_KEY 即真实 LLM)
conn.sidecar = LLMSidecar(SIDECAR_EXTERNAL)
conn.dispatch("phase=2 plan=[木→火] 请解释调度依据", res, 2000, resp)
print(resp.text)                        # 真实 LLM 文本 or 优雅降级串
```

## 五、实现状态（v1.4 · 零桩函数 TDD 全绿）
`protocol.mojo`（Connector/Response/熔断/重试/call_external 接入缝）+ `dispatch.mojo`（fanout/ShifangOutput/十方映射）+ `executor.mojo`（execute_plan_to_text/render_reply/action_label）+ `sidecar.mojo`（LLMSidecar 双模式 + shifang_llm_call 子进程桥接）+ `llm_sidecar.py`（真实侧车执行体）。
**shifang 套件 27 用例全绿**；`test_sidecar.mojo` 22 断言绿（含真实桥接到达验证）。基准 fanout≈1746 / dispatch-only≈1158 ns/op；外部桥接≈381 µs/call（python3 子进程开销主导，真实 LLM 网络另计）。
跨进程持久化(②)见 `observability/store.mojo`；runtime 回灌健康/超时门控(③)见 `runtime/lifecycle.mojo`（BackfillGate / is_healthy 纳入回灌成功率）。详见 `docs/phase5-execution-design.md` 与 `docs/architecture-modular-plan.md` §4.10。
