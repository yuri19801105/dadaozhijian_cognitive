# shifang/dispatch.mojo — 十方扇出：把 PipelineResult.plan 周遍到十个方向
# 消费: PipelineResult.plan(七星定序后的有序元素链 0..4 = 木火土金水)。
# 产出: ShifangOutput(十方向 action 码 + ok + degraded + latency)。
# 运行: mojo run -I . -I core shifang/dispatch.mojo
from pipeline import PipelineResult
from .protocol import (
    Connector, ConnectorResponse, DIR_COUNT,
    DIR_EAST, DIR_SOUTH, DIR_WEST, DIR_NORTH, DIR_SE, DIR_SW, DIR_NE, DIR_NW, DIR_UP, DIR_DOWN,
)
from wuxing import element_name, WOOD, FIRE, EARTH, METAL, WATER

struct ShifangOutput(Movable):
    # 固定标量槽: 每方向存"分配到的元素动作码"(未分配=-1)。
    var a0: Int; var a1: Int; var a2: Int; var a3: Int
    var a4: Int; var a5: Int; var a6: Int; var a7: Int
    var a8: Int; var a9: Int
    var action_len: Int
    var ok: Int
    var degraded: Int
    var latency_ms: Int
    def __init__(out self):
        self.a0 = -1; self.a1 = -1; self.a2 = -1; self.a3 = -1
        self.a4 = -1; self.a5 = -1; self.a6 = -1; self.a7 = -1
        self.a8 = -1; self.a9 = -1
        self.action_len = 0
        self.ok = 0; self.degraded = 0; self.latency_ms = 0
    def _set(mut self, dir: Int, element: Int):
        if dir == 0: self.a0 = element
        elif dir == 1: self.a1 = element
        elif dir == 2: self.a2 = element
        elif dir == 3: self.a3 = element
        elif dir == 4: self.a4 = element
        elif dir == 5: self.a5 = element
        elif dir == 6: self.a6 = element
        elif dir == 7: self.a7 = element
        elif dir == 8: self.a8 = element
        elif dir == 9: self.a9 = element
        else: return
        self.action_len = self.action_len + 1
    def action_at(self, dir: Int) -> Int:
        if dir == 0: return self.a0
        if dir == 1: return self.a1
        if dir == 2: return self.a2
        if dir == 3: return self.a3
        if dir == 4: return self.a4
        if dir == 5: return self.a5
        if dir == 6: return self.a6
        if dir == 7: return self.a7
        if dir == 8: return self.a8
        if dir == 9: return self.a9
        return -1

def _build_prompt(result: PipelineResult) -> String:
    # 以 result 构造自然语言 prompt(让架构"能说话")。
    var p = String("phase=")
    p = p + String(result.phase)
    p = p + " intensity=" + String(result.intensity)
    p = p + " confidence=" + String(Int(result.confidence * 100.0)) + "%"
    p = p + " policy=" + String(result.policy_id)
    p = p + " plan=["
    for i in range(result.plan_len):
        if i > 0:
            p = p + "→"
        p = p + element_name(result.plan_at(i))
    p = p + "]"
    return p^

def fanout(result: PipelineResult, mut connector: Connector) raises -> ShifangOutput:
    # 十方扇出: 规划链每步映射到十方向之一, 调用连接器生成回复。
    var out = ShifangOutput()
    var resp = ConnectorResponse()
    var prompt = _build_prompt(result)
    connector.dispatch(prompt, result, 1000, resp)
    out.latency_ms = resp.latency_ms
    out.ok = resp.ok
    out.degraded = resp.degraded
    # 规划链 → 十方向映射: direction = (element*2 + step) % 10
    for i in range(result.plan_len):
        var element = result.plan_at(i)
        var dir = (element * 2 + i) % DIR_COUNT
        out._set(dir, element)
    return out^

def fanout_safe(result: PipelineResult, mut connector: Connector) -> ShifangOutput:
    # 中性降级: 任何异常(含连接器派发 raises) → ok=0, degraded=1, 不崩溃。
    var out = ShifangOutput()
    try:
        out = fanout(result, connector)
    except:
        out.ok = 0
        out.degraded = 1
    return out^

def build_prompt(result: PipelineResult) -> String:
    # 以 result 构造自然语言 prompt(让架构"能说话")；公开供编排层(cycle)复用, 避免元组返回非 Movable。
    return _build_prompt(result)
