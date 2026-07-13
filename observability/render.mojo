# observability/render.mojo — 可视化: 文本摘要 + 轻量 SVG(迁自 src/emoji.mojo 思路)
# 以 String 产出(可 Movable, 直接返回), 不持 List 字段。
# 运行: mojo run -I . -I core observability/render.mojo
from pipeline import PipelineResult
from shifang import ShifangOutput
from observability.tracing import Tracer
from wuxing import element_name

def render_summary(result: PipelineResult, output: ShifangOutput, trace: Tracer) -> String:
    var s = String("══ 大道至简 · 执行摘要 ══\n")
    s = s + "相位: " + String(result.phase) + "  强度: " + String(result.intensity)
    s = s + "  置信度: " + String(Int(result.confidence * 100.0)) + "%\n"
    s = s + "规划链: "
    for i in range(result.plan_len):
        if i > 0:
            s = s + " → "
        s = s + element_name(result.plan_at(i))
    s = s + "\n十方扇出: " + String(output.action_len) + " 向"
    s = s + " (ok=" + String(output.ok) + " degraded=" + String(output.degraded) + ")\n"
    s = s + "溯源 span 数: " + String(trace.span_len) + "\n"
    s = s + "════════════════════════"
    return s^

def render_svg(result: PipelineResult, output: ShifangOutput) -> String:
    # 轻量 SVG: 相位节点 + 规划链水平流 + 十方向点阵(命中方向点亮)。
    var svg = String("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"440\" height=\"170\">")
    svg = svg + "<rect width=\"440\" height=\"170\" fill=\"#0f172a\"/>"
    # 相位节点
    svg = svg + "<circle cx=\"40\" cy=\"80\" r=\"18\" fill=\"#38bdf8\"/>"
    svg = svg + "<text x=\"40\" y=\"85\" fill=\"#fff\" font-size=\"12\" text-anchor=\"middle\">P" + String(result.phase) + "</text>"
    # 规划链
    for i in range(result.plan_len):
        var cx = 110 + i * 70
        svg = svg + "<circle cx=\"" + String(cx) + "\" cy=\"80\" r=\"16\" fill=\"#f59e0b\"/>"
        svg = svg + "<text x=\"" + String(cx) + "\" y=\"84\" fill=\"#000\" font-size=\"11\" text-anchor=\"middle\">" + element_name(result.plan_at(i)) + "</text>"
        if i > 0:
            var px = 110 + (i - 1) * 70 + 16
            svg = svg + "<line x1=\"" + String(px) + "\" y1=\"80\" x2=\"" + String(cx - 16) + "\" y2=\"80\" stroke=\"#94a3b8\"/>"
    # 十方向点阵(2 行 × 5 列), 命中方向(前 action_len 个)点亮。
    for d in range(10):
        var row = d / 5
        var col = d % 5
        var cx = 250 + col * 36
        var cy = 140 + row * 22
        var color = "#334155"
        if d < output.action_len:
            color = "#22c55e"
        svg = svg + "<circle cx=\"" + String(cx) + "\" cy=\"" + String(cy) + "\" r=\"6\" fill=\"" + color + "\"/>"
    svg = svg + "</svg>"
    return svg^
