# liuhe/directions.mojo — 六向空间维度（六合之空间义）
# 六合 = 上下四方，三组阴阳对待（东西／南北／上下）；为调度脑提供空间坐标系，
# 并把五行元素映射到六向（五行配六合），供 qixing 容量折扣与 scheduler 编排使用。
# 运行: mojo run -I . -I core liuhe/directions.mojo
from wuxing.elements import WOOD, FIRE, EARTH, METAL, WATER, ELEMENT_COUNT

comptime EAST: Int = 0
comptime WEST: Int = 1
comptime SOUTH: Int = 2
comptime NORTH: Int = 3
comptime UP: Int = 4
comptime DOWN: Int = 5
comptime DIRECTION_COUNT: Int = 6

def direction_name(id: Int) -> String:
    if id == EAST: return "东"
    if id == WEST: return "西"
    if id == SOUTH: return "南"
    if id == NORTH: return "北"
    if id == UP: return "上"
    if id == DOWN: return "下"
    return "?"

def opposite(id: Int) -> Int:
    if id == EAST: return WEST
    if id == WEST: return EAST
    if id == SOUTH: return NORTH
    if id == NORTH: return SOUTH
    if id == UP: return DOWN
    if id == DOWN: return UP
    return -1

def axis_of(id: Int) -> Int:
    # 0=横(东西) 1=纵(南北) 2=竖(上下)；越界返回 -1
    if id == EAST or id == WEST: return 0
    if id == SOUTH or id == NORTH: return 1
    if id == UP or id == DOWN: return 2
    return -1

def element_direction(id: Int) -> Int:
    # 五行配六合(空间义): 木东 火南 金西 水北 土上(中, 寄于上)；越界返回 -1
    if id == WOOD: return EAST
    if id == FIRE: return SOUTH
    if id == METAL: return WEST
    if id == WATER: return NORTH
    if id == EARTH: return UP
    return -1
