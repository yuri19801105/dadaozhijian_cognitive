# shifang/executor.mojo — 把规划链落地为可读动作串(让架构"能说话")
# 迁自 src/executor.mojo 的 trigram→文本思路, 但本层消费元素链(PipelineResult.plan)。
# 运行: mojo run -I . -I core shifang/executor.mojo
from pipeline import PipelineResult
from .dispatch import ShifangOutput
from .protocol import ConnectorResponse, direction_name, DIR_COUNT
from wuxing import element_name, WOOD, FIRE, EARTH, METAL, WATER

def action_label(element: Int) -> String:
    # 元素 → 动作语义(由五行属性派生)。
    if element == WOOD: return "创生"
    if element == FIRE: return "明辨"
    if element == EARTH: return "承载"
    if element == METAL: return "收敛"
    if element == WATER: return "归藏"
    return "?"

def execute_plan_to_text(result: PipelineResult, input: String) -> String:
    # 把规划链转为"十方动作"可读串(返回 String, 可 Movable, 直接以值返回)。
    var out = String("[十方执行] 输入: " + input + "\n")
    for i in range(result.plan_len):
        var element = result.plan_at(i)
        var dir = (element * 2 + i) % DIR_COUNT
        out = out + "  " + direction_name(dir) + "方 → " + element_name(element) + "(" + action_label(element) + ")"
        if i < result.plan_len - 1:
            out = out + "\n"
    return out^

def render_reply(result: PipelineResult, output: ShifangOutput, resp: ConnectorResponse) -> String:
    # 合成最终"能说话"的回复: 连接器文本 + 扇出动作摘要。
    var s = String(resp.text)
    s = s + "\n[扇出] 十方已落地 " + String(output.action_len) + " 向"
    s = s + " (ok=" + String(output.ok) + " degraded=" + String(output.degraded) + ")"
    return s^
