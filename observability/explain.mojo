# observability/explain.mojo — 标准化可解释接口: 内在(符号中间表示)+事后(决策链/探针)
# 运行: mojo run -I . -I core observability/explain.mojo
from pipeline import PipelineResult
from shifang import ShifangOutput
from wuxing import element_name, WOOD, FIRE, EARTH, METAL, WATER

def explain_decision(result: PipelineResult, output: ShifangOutput, resp_text: String) -> String:
    # 内在可解释: 相位/强度/主导元素(符号中间表示)。
    var s = String("【内在·符号表示】phase=" + String(result.phase))
    s = s + " intensity=" + String(result.intensity)
    s = s + " confidence=" + String(Int(result.confidence * 100.0)) + "%"
    s = s + " policy=" + String(result.policy_id)
    # 事后可解释: 决策链(规划链) + 十方扇出 + 连接器回复探针。
    s = s + "\n【事后·决策链】"
    for i in range(result.plan_len):
        if i > 0:
            s = s + " → "
        s = s + element_name(result.plan_at(i))
    s = s + "\n【事后·扇出】十方 " + String(output.action_len) + " 向 (ok=" + String(output.ok)
    s = s + " degraded=" + String(output.degraded) + ")"
    s = s + "\n【事后·探针】" + resp_text
    return s^
