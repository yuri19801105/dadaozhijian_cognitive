# 静语 M8 - CLI 落盘工具
#
# 把输入文本经认知流水线(五行调度候选链 + 七星规划链)送入 EmojiGraph,
# 渲染为确定性文本(.txt)与 SVG(.svg) 并落盘, 供调试 / 演示查看。
#
# 用法:
#   mojo run -I src tools/dump_emoji.mojo "<文本>" [输出基名]
#   输出基名缺省为 emoji_graph -> emoji_graph.txt + emoji_graph.svg
#
# 依赖 Mojo 1.0.0b2 API:
#   - from std.sys import argv        -> argv(): VariadicList[String]
#   - from std.io import FileHandle   -> FileHandle(path, mode).write(String).close()

from std.sys import argv
from std.io import FileHandle
from workspace import Workspace
from config import Config
from pipeline import run_cycle_chains
from emoji import EmojiGraph

def main() raises:
    # --- 解析命令行参数 ---
    var args = argv()
    var text = "天气太热了，开空调吧。"          # 缺省演示文本
    if len(args) > 1:
        text = args[1]
    var base = "emoji_graph"                       # 缺省输出基名
    if len(args) > 2:
        base = args[2]

    # --- 跑认知流水线, 取中间推理链供可视化 ---
    var ws = Workspace()
    var cfg = Config()
    var chains = run_cycle_chains(ws, text, cfg)   # [候选链(五行), 规划链(七星)]

    # --- 构建图形并渲染 ---
    var g = EmojiGraph()
    g.build(chains)
    var txt = g.render()
    var svg = g.render_svg()

    # --- 落盘 ---
    var txt_path = base + ".txt"
    var svg_path = base + ".svg"
    var ft = FileHandle(txt_path, "w")
    ft.write(txt)
    ft.close()
    var fs = FileHandle(svg_path, "w")
    fs.write(svg)
    fs.close()

    # --- 终端摘要 ---
    print("input    : ", text)
    print("chains   : ", len(chains), " (候选/规划)")
    print("nodes    : ", g.count, "  connections: ", g.conn_count)
    print("txt  -> ", txt_path)
    print("svg  -> ", svg_path)
