# 七星 - 动态规划与任务调度
# 基于六合态势 + 五行候选 → 排序后的执行链
# 语言: Mojo 1.0.0b2 | 验证: TDD

from workspace import Workspace
from trigram import CHIEN, KUN, ZHEN, XUN, KAN, LI, GEN, DUI

def abstract_level(t: Int) -> Int:
    if t == CHIEN or t == KUN:
        return 5
    elif t == LI or t == KAN:
        return 3
    elif t == ZHEN or t == XUN:
        return 2
    elif t == GEN or t == DUI:
        return 1
    return 0

def plan(context: SIMD[DType.int64, 6], candidates: List[Int]) -> List[Int]:
    # extrae Int values from SIMD
    var _east = Int(context[0])
    var west = Int(context[1])
    var south = Int(context[2])
    var north = Int(context[3])

    # 1. 剪枝: filter by north (max_depth)
    var pruned = List[Int]()
    for i in range(len(candidates)):
        var t = candidates[i]
        if abstract_level(t) <= north:
            pruned.append(t)

    if len(pruned) == 0:
        return pruned^

    # 2. 评分 + 排序 (bubble sort by score desc)
    var n = len(pruned)
    var sorted = List[Int]()
    for i in range(n):
        sorted.append(pruned[i])

    for _ in range(n):
        var swapped = False
        for j in range(n - 1):
            var a = sorted[j]
            var b = sorted[j + 1]
            var sa = south - west + abstract_level(a)
            var sb = south - west + abstract_level(b)
            if sb > sa:
                sorted[j] = b
                sorted[j + 1] = a
                swapped = True
        if not swapped:
            break

    # 3. 锚定: abstract ops first (if same score, reorder by abstraction)
    for _ in range(n):
        var swapped = False
        for j in range(n - 1):
            var a = sorted[j]
            var b = sorted[j + 1]
            var sa = south - west + abstract_level(a)
            var sb = south - west + abstract_level(b)
            if sa == sb and abstract_level(b) > abstract_level(a):
                sorted[j] = b
                sorted[j + 1] = a
                swapped = True
        if not swapped:
            break

    return sorted^
