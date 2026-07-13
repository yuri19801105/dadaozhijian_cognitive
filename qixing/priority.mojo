# qixing/priority.mojo — 优先级赋值（七星·定序枢机之一）
# 优先级源自 wuxing 归一权重(策略层)，经 liuhe 六向容量折扣(资源约束层)：
#   priority(step) = weight(step) * capacity_factor(supply, step)
# 抽象度 abstract_level 用于同优先级锚定（迁自 MVP 语义，适配五行元素 id）。
# 运行: mojo run -I . -I core qixing/priority.mojo
from math.ops import clamp
from wuxing.scheduler_core import ScheduleDecision
from wuxing.elements import WOOD, FIRE, EARTH, METAL, WATER
from liuhe import SupplyVector, element_direction, NORTH

def abstract_level(step: Int) -> Int:
    # 步骤抽象度: 土居中承化最高, 火金次之, 水木基础, 越界 0
    if step == EARTH: return 5
    if step == FIRE: return 3
    if step == METAL: return 3
    if step == WATER: return 2
    if step == WOOD: return 2
    return 0

def capacity_factor(supply: SupplyVector, step: Int) raises -> Float64:
    # 该步对应方向容量 / 最大深度配额, 截断 [0,1]; 越界元素 → 0(无容量)
    var dir = element_direction(step)
    if dir < 0:
        return 0.0
    var cap = supply.get(dir)
    var quota = supply.get(NORTH)
    if quota <= 0.0:
        return 0.0
    return clamp(cap / quota, 0.0, 1.0)

def priority_of(step: Int, decision: ScheduleDecision, supply: SupplyVector) raises -> Float64:
    var w = decision.weight(step)
    var cf = capacity_factor(supply, step)
    return w * cf

def priority_list(decision: ScheduleDecision, supply: SupplyVector) raises -> List[Float64]:
    var l = List[Float64]()
    for i in range(5):
        l.append(priority_of(i, decision, supply))
    return l^
