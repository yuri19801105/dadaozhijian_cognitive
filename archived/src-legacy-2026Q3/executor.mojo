# 十方执行器 - 将规划链转化为输出动作
# 八卦算子 → 具体文本输出（不直接改九宫, 输出可经 ws.hold 持久化; 见 ADR-0009 §4）
# 语言: Mojo 1.0.0b2 | 验证: TDD

from workspace import Workspace
from trigram import CHIEN, KUN, ZHEN, XUN, KAN, LI, GEN, DUI

def _exec_chien(ws: Workspace, input: String, idx: Int) -> String:
    return "[" + String(idx) + "] 创造: " + input

def _exec_kun(ws: Workspace, input: String, idx: Int) -> String:
    var cells = ws.available_cells()
    return "[" + String(idx) + "] 承载: 已占用 " + String(9 - cells) + " 格"

def _exec_zhen(ws: Workspace, input: String, idx: Int) -> String:
    return "[" + String(idx) + "] 启动: 处理 `" + input + "`"

def _exec_xun(ws: Workspace, input: String, idx: Int) -> String:
    return "[" + String(idx) + "] 渗透: 整合输入到九宫"

def _exec_kan(ws: Workspace, input: String, idx: Int) -> String:
    return "[" + String(idx) + "] 冒险: 尝试假设——长度 " + String(input.byte_length()) + " 字节"

def _exec_li(ws: Workspace, input: String, idx: Int) -> String:
    var parity = input.byte_length() % 2
    var classification = "奇数" if parity == 1 else "偶数"
    return "[" + String(idx) + "] 明辨: 输入判定为 " + classification

def _exec_gen(ws: Workspace, input: String, idx: Int) -> String:
    return "[" + String(idx) + "] 停止: 结束分支"

def _exec_dui(ws: Workspace, input: String, idx: Int) -> String:
    return "[" + String(idx) + "] 交流: " + input

def execute_trigram(t: Int, ws: Workspace, input: String, idx: Int) -> String:
    if t == CHIEN:
        return _exec_chien(ws, input, idx)
    elif t == KUN:
        return _exec_kun(ws, input, idx)
    elif t == ZHEN:
        return _exec_zhen(ws, input, idx)
    elif t == XUN:
        return _exec_xun(ws, input, idx)
    elif t == KAN:
        return _exec_kan(ws, input, idx)
    elif t == LI:
        return _exec_li(ws, input, idx)
    elif t == GEN:
        return _exec_gen(ws, input, idx)
    elif t == DUI:
        return _exec_dui(ws, input, idx)
    return "[" + String(idx) + "] 未知算子"

def action_label(t: Int) -> String:
    if t == CHIEN:
        return "创造"
    elif t == KUN:
        return "承载"
    elif t == ZHEN:
        return "启动"
    elif t == XUN:
        return "渗透"
    elif t == KAN:
        return "冒险"
    elif t == LI:
        return "明辨"
    elif t == GEN:
        return "停止"
    elif t == DUI:
        return "交流"
    return "未知"

def execute(chain: List[Int], ws: Workspace, raw_input: String) -> String:
    var output = String()
    for i in range(len(chain)):
        var t = chain[i]
        output += execute_trigram(t, ws, raw_input, i)
        if i < len(chain) - 1:
            output += "\n"
    return output^
