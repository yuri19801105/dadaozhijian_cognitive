# 八卦 - 八种推理算子库
# 编码认知模型的基本推理模式
# 语言: Mojo 1.0.0b2 | 验证: TDD

from workspace import Workspace

comptime CHIEN: Int = 0
comptime KUN: Int = 1
comptime ZHEN: Int = 2
comptime XUN: Int = 3
comptime KAN: Int = 4
comptime LI: Int = 5
comptime GEN: Int = 6
comptime DUI: Int = 7

struct TrigramAction(ImplicitlyCopyable):
    var action_id: Int
    var trigram: Int
    var value: Int
    var confidence: Int

    def __init__(out self):
        self.action_id = 0
        self.trigram = 0
        self.value = 0
        self.confidence = 5

    def __copy_init__(out self, other: Self):
        self.action_id = other.action_id
        self.trigram = other.trigram
        self.value = other.value
        self.confidence = other.confidence

# ----- 各算子实现 -----

def apply_chien(ws: Workspace, param: Int) -> TrigramAction:
    var a = TrigramAction()
    a.trigram = CHIEN
    a.action_id = param
    a.value = param
    a.confidence = 7
    return a

def apply_kun(ws: Workspace, param: Int) -> TrigramAction:
    var max_val = 0
    for i in range(3):
        for j in range(3):
            if ws.grid[i][j] > max_val:
                max_val = ws.grid[i][j]
    var a = TrigramAction()
    a.trigram = KUN
    a.action_id = ws.grid[0][0]
    a.value = max_val
    a.confidence = 6
    return a

def apply_zhen(ws: Workspace, param: Int) -> TrigramAction:
    var a = TrigramAction()
    a.trigram = ZHEN
    a.action_id = param + 1000
    a.value = param
    a.confidence = 8
    return a

def apply_xun(ws: Workspace, param: Int) -> TrigramAction:
    var total = 0
    var count = 0
    for i in range(3):
        for j in range(3):
            if ws.grid[i][j] >= 0:
                total += ws.grid[i][j]
                count += 1
    var avg = total / count if count > 0 else 0
    var a = TrigramAction()
    a.trigram = XUN
    a.action_id = avg
    a.value = avg
    a.confidence = 4
    return a

def apply_kan(ws: Workspace, param: Int) -> TrigramAction:
    var a = TrigramAction()
    a.trigram = KAN
    a.action_id = param + 2000
    a.value = param
    a.confidence = 3
    return a

def apply_li(ws: Workspace, param: Int) -> TrigramAction:
    var cat: Int
    if param == 2:
        cat = 2
    elif param < 2:
        cat = 0
    elif param % 2 == 0:
        cat = 0
    else:
        var is_prime = True
        for d in range(3, param):
            if param % d == 0:
                is_prime = False
                break
        cat = 2 if is_prime else 1
    var a = TrigramAction()
    a.trigram = LI
    a.action_id = cat
    a.value = param
    a.confidence = 9
    return a

def apply_gen(ws: Workspace, param: Int) -> TrigramAction:
    var a = TrigramAction()
    a.trigram = GEN
    a.action_id = -param
    a.value = param
    a.confidence = 9
    return a

def apply_dui(ws: Workspace, param: Int) -> TrigramAction:
    var a = TrigramAction()
    a.trigram = DUI
    a.action_id = param
    a.value = param
    a.confidence = 5
    return a

# ----- 调度函数 -----

def apply_trigram(type: Int, ws: Workspace, param: Int) -> TrigramAction:
    if type == CHIEN:
        return apply_chien(ws, param)
    elif type == KUN:
        return apply_kun(ws, param)
    elif type == ZHEN:
        return apply_zhen(ws, param)
    elif type == XUN:
        return apply_xun(ws, param)
    elif type == KAN:
        return apply_kan(ws, param)
    elif type == LI:
        return apply_li(ws, param)
    elif type == GEN:
        return apply_gen(ws, param)
    elif type == DUI:
        return apply_dui(ws, param)
    else:
        var a = TrigramAction()
        a.trigram = -1
        return a

# ----- 高阶函数：完整推理链 -----

def apply_chain(ws: Workspace, chain: List[Int], param: Int) -> TrigramAction:
    var last = TrigramAction()
    for i in range(len(chain)):
        last = apply_trigram(chain[i], ws, param if i == 0 else last.value)
    return last
