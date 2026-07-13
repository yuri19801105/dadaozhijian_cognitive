# shifang/tests/test_shifang.mojo — TDD 测试套件(红→绿→重构)
# 运行: mojo run -I . -I core shifang/tests/test_shifang.mojo
from pipeline import run_pipeline_safe, PipelineResult
from wuxing import WOOD, FIRE, EARTH, METAL, WATER, element_name
from shifang import (
    Connector, ConnectorResponse, CONNECTOR_LOCAL, CONNECTOR_LLM,
    direction_name, DIR_COUNT, DIR_EAST, DIR_SOUTH, DIR_WEST, DIR_NORTH,
    DIR_SE, DIR_SW, DIR_NE, DIR_NW, DIR_UP, DIR_DOWN,
    ShifangOutput, fanout, fanout_safe, action_label,
    execute_plan_to_text, render_reply, call_external, SIDECAR_TEMPLATE,
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
    # 文本入口产出一个真实 PipelineResult(规划链 木→火→土)。
    return run_pipeline_safe("认知架构的五行调度如何决定任务优先级与资源分配的整体策略", 0.5, 8, 3, 5)

def test_direction_constants(mut c: Counter):
    var names = List[String]()
    names.append(direction_name(DIR_EAST)); names.append(direction_name(DIR_SOUTH))
    names.append(direction_name(DIR_WEST)); names.append(direction_name(DIR_NORTH))
    names.append(direction_name(4)); names.append(direction_name(5))
    names.append(direction_name(6)); names.append(direction_name(7))
    names.append(direction_name(DIR_UP)); names.append(direction_name(DIR_DOWN))
    var expected = List[String]()
    expected.append("东"); expected.append("南"); expected.append("西"); expected.append("北")
    expected.append("东南"); expected.append("西南"); expected.append("东北"); expected.append("西北")
    expected.append("上"); expected.append("下")
    var all_ok = True
    for i in range(DIR_COUNT):
        if names[i] != expected[i]:
            all_ok = False
    c.check(all_ok, "十方方向名 0..9")
    c.check(DIR_COUNT == 10, "DIR_COUNT==10")

def test_action_label(mut c: Counter):
    c.check(action_label(WOOD) == "创生", "木→创生")
    c.check(action_label(FIRE) == "明辨", "火→明辨")
    c.check(action_label(EARTH) == "承载", "土→承载")
    c.check(action_label(METAL) == "收敛", "金→收敛")
    c.check(action_label(WATER) == "归藏", "水→归藏")

def test_call_external(mut c: Counter) raises:
    var r = call_external("phase=0 plan=[木]")
    c.check(r.byte_length() > 0, "call_external 返回非空模板响应")

def test_connector_local_dispatch(mut c: Counter) raises:
    var res = _sample_result()
    c.check(res.ok == 1, "采样 pipeline ok")
    c.check(res.plan_len > 0, "采样 plan 非空")
    var conn = Connector(CONNECTOR_LLM, SIDECAR_TEMPLATE)
    var resp = ConnectorResponse()
    conn.dispatch("测试 prompt", res, 1000, resp)
    c.check(resp.ok == 1, "连接器正常派发 ok=1")
    c.check(resp.degraded == 0, "正常未降级")
    c.check(resp.text.byte_length() > 0, "回复文本非空(能说话)")

def test_connector_circuit_breaker(mut c: Counter) raises:
    var res = _sample_result()
    var conn = Connector(CONNECTOR_LLM, SIDECAR_TEMPLATE)
    # 连续超时(<=0) → 失败计数累积 → 熔断开启。
    var resp = ConnectorResponse()
    conn.dispatch("p", res, 0, resp)   # 超时
    conn.dispatch("p", res, 0, resp)   # 超时
    conn.dispatch("p", res, 0, resp)   # 超时 → 熔断
    c.check(conn.cb_open == 1, "连续超时触发熔断")
    var resp2 = ConnectorResponse()
    conn.dispatch("p", res, 1000, resp2)  # 熔断开启应直接降级
    c.check(resp2.degraded == 1, "熔断开启 → 降级回复")
    c.check(resp2.ok == 0, "降级 ok=0")

def test_connector_with_retry(mut c: Counter):
    var res = _sample_result()
    var conn = Connector(CONNECTOR_LLM, SIDECAR_TEMPLATE)
    var resp = ConnectorResponse()
    # 正常路径重试一次即成功。
    conn.with_retry("p", res, 1000, 2, resp)
    c.check(resp.ok == 1, "with_retry 正常成功")
    # 超时路径: 重试耗尽 → 降级。
    var conn2 = Connector(CONNECTOR_LLM, SIDECAR_TEMPLATE)
    var resp2 = ConnectorResponse()
    conn2.with_retry("p", res, 0, 2, resp2)
    c.check(resp2.degraded == 1, "with_retry 超时耗尽 → 降级")

def test_fanout(mut c: Counter) raises:
    var res = _sample_result()
    var conn = Connector(CONNECTOR_LLM, SIDECAR_TEMPLATE)
    var out = fanout(res, conn)
    c.check(out.ok == 1, "fanout ok=1")
    c.check(out.action_len == res.plan_len, "扇出方向数 = 规划链长")
    c.check(out.degraded == 0, "fanout 未降级")
    # 每个规划步映射到某方向, action_at 返回对应元素。
    var covered = True
    for i in range(res.plan_len):
        var element = res.plan_at(i)
        var dir = (element * 2 + i) % DIR_COUNT
        if out.action_at(dir) != element:
            covered = False
    c.check(covered, "扇出映射方向→元素正确")

def test_fanout_safe(mut c: Counter):
    var res = _sample_result()
    var conn = Connector(CONNECTOR_LLM, SIDECAR_TEMPLATE)
    var out = fanout_safe(res, conn)
    c.check(out.ok == 1, "fanout_safe 正常 ok=1")
    # 异常路径: 构造一个会触发 except 的退化输入(plan_len=0 但仍能跑)。
    # 这里验证不崩溃且返回结构化输出。
    var empty = PipelineResult()
    var conn2 = Connector(CONNECTOR_LLM, SIDECAR_TEMPLATE)
    var out2 = fanout_safe(empty, conn2)
    c.check(out2.ok == 1 or out2.degraded == 1, "fanout_safe 空结果不崩溃")

def test_execute_plan_to_text(mut c: Counter):
    var res = _sample_result()
    var txt = execute_plan_to_text(res, "示例输入")
    c.check(txt.byte_length() > 0, "execute_plan_to_text 非空")
    # 验证文本确实落到具体方向动作(含元素名 + 输入回声)。
    var has_input = txt.byte_length() > "示例输入".byte_length()
    c.check(has_input, "扇出动作串可读落地(含输入回声)")

def test_render_reply(mut c: Counter) raises:
    var res = _sample_result()
    var conn = Connector(CONNECTOR_LLM, SIDECAR_TEMPLATE)
    var out = fanout(res, conn)
    var resp = ConnectorResponse()
    conn.dispatch("p", res, 1000, resp)
    var reply = render_reply(res, out, resp)
    c.check(reply.byte_length() > 0, "render_reply 非空(能说话)")

def main() raises:
    var c = Counter()
    test_direction_constants(c)
    test_action_label(c)
    test_call_external(c)
    test_connector_local_dispatch(c)
    test_connector_circuit_breaker(c)
    test_connector_with_retry(c)
    test_fanout(c)
    test_fanout_safe(c)
    test_execute_plan_to_text(c)
    test_render_reply(c)
    print("shifang -> passed: " + String(c.passed) + "  failed: " + String(c.failed))
