# 静语 (Emoji) 可视化 单元测试
# 验证 M8-core: 构建 / 情绪更新 / 权重更新 / 连线颜色同步 / 渲染确定性
# 语言: Mojo 1.0.0b2 | 验证: TDD (手写 try/except 运行器)
# 注: 本构建下 EmojiGraph 含 List 字段不可 Movable, 故构造用 build() 方法、渲染用 render() 方法
#     (不按值返回/传参), 详见 docs/adr/0011-emoji-scope.md。

from std.testing import assert_equal
from emoji import (
    EmojiGraph, NEUTRAL, EXCITED, JOY, SURPRISED,
    LAYOUT_LINEAR, LAYOUT_TREE,
)

def _two_chains() -> List[List[Int]]:
    # 链1: CHIEN(0) LI(5) DUI(7); 链2: KUN(1) ZHEN(2) XUN(3)
    var c1 = List[Int]()
    c1.append(0); c1.append(5); c1.append(7)
    var c2 = List[Int]()
    c2.append(1); c2.append(2); c2.append(3)
    var chains = List[List[Int]]()
    chains.append(c1^)
    chains.append(c2^)
    return chains^

def test_build_node_and_conn_counts() raises:
    var g = EmojiGraph()
    g.build(_two_chains())
    # 3 + 3 = 6 节点; 链内相邻 (3-1)+(3-1) = 4 连线
    assert_equal(g.count, 6)
    assert_equal(g.conn_count, 4)

def test_build_positions_and_default_emotion() raises:
    var g = EmojiGraph()
    g.build(_two_chains())
    # 位置全局顺序 0..5
    for i in range(6):
        assert_equal(g.node_position[i], i)
        assert_equal(g.node_emotion[i], NEUTRAL)
        assert_equal(g.node_weight[i], 50)   # 默认权重 50%

def test_build_trigram_mapping() raises:
    var g = EmojiGraph()
    g.build(_two_chains())
    # 链1 节点: CHIEN, LI, DUI
    assert_equal(g.node_trigram[0], 0)
    assert_equal(g.node_trigram[1], 5)
    assert_equal(g.node_trigram[2], 7)
    # 链2 节点: KUN, ZHEN, XUN
    assert_equal(g.node_trigram[3], 1)
    assert_equal(g.node_trigram[4], 2)
    assert_equal(g.node_trigram[5], 3)

def test_update_node_emotion() raises:
    var g = EmojiGraph()
    g.build(_two_chains())
    g.update_node_emotion(0, EXCITED)
    g.update_node_emotion(1, JOY)
    assert_equal(g.node_emotion[0], EXCITED)
    assert_equal(g.node_emotion[1], JOY)
    # 同步: 从节点 0 出发的连线颜色 = EXCITED
    assert_equal(g.conn_from[0], 0)
    assert_equal(g.conn_color[0], EXCITED)

def test_update_node_emotion_bounds_safe() raises:
    var g = EmojiGraph()
    g.build(_two_chains())
    # 越界 id 不应崩溃或改变状态
    g.update_node_emotion(-1, EXCITED)
    g.update_node_emotion(99, EXCITED)
    assert_equal(g.node_emotion[0], NEUTRAL)

def test_update_node_weight() raises:
    var g = EmojiGraph()
    g.build(_two_chains())
    g.update_node_weight(0, 0.8)    # 0.8 -> 80%
    assert_equal(g.node_weight[0], 80)
    g.update_node_weight(2, 0.0)    # 0.0 -> 0%
    assert_equal(g.node_weight[2], 0)

def test_render_deterministic() raises:
    var g = EmojiGraph()
    g.build(_two_chains())
    var r = g.render()
    # 头部 (ASCII, 确定性)
    assert_equal(r.find("EmojiGraph{nodes=6,connections=4,layout=LINEAR}") >= 0, True)
    # 节点行含 trigram 名称 + 默认情绪/权重 (ASCII 子串, 避开 emoji 字面匹配)
    assert_equal(r.find("CHIEN pos=0") >= 0, True)
    assert_equal(r.find("DUI pos=2") >= 0, True)
    assert_equal(r.find("XUN pos=5") >= 0, True)
    assert_equal(r.find("NEUTRAL w=50%") >= 0, True)
    # 连线行
    assert_equal(r.find("conn 0->1 strength=50% color=NEUTRAL") >= 0, True)
    assert_equal(r.find("conn 3->4 strength=50% color=NEUTRAL") >= 0, True)
    # 确定性: 两次渲染完全一致
    assert_equal(g.render(), r)

def test_render_after_update_reflects_state() raises:
    var g = EmojiGraph()
    g.build(_two_chains())
    g.update_node_emotion(0, EXCITED)
    g.update_node_weight(0, 0.8)
    var r = g.render()
    assert_equal(r.find("CHIEN pos=0") >= 0, True)
    assert_equal(r.find("EXCITED") >= 0, True)
    assert_equal(r.find("w=80%") >= 0, True)
    # 连线颜色已同步为 EXCITED
    assert_equal(r.find("conn 0->1 strength=50% color=EXCITED") >= 0, True)

def test_render_svg_deterministic() raises:
    var g = EmojiGraph()
    g.build(_two_chains())
    var svg = g.render_svg()
    assert_equal(svg.find("<svg") >= 0, True)
    assert_equal(svg.find("</svg>") >= 0, True)
    # 6 个节点 (rect) + 4 条连线 (line)
    assert_equal(svg.find("rect") >= 0, True)
    assert_equal(svg.find("line") >= 0, True)
    # 确定性
    assert_equal(g.render_svg(), svg)

def test_layout_type_default() raises:
    var g = EmojiGraph()
    g.build(_two_chains())
    assert_equal(g.layout_type, LAYOUT_LINEAR)
    var g2 = EmojiGraph()
    g2.layout_type = LAYOUT_TREE
    assert_equal(g2.layout_type, LAYOUT_TREE)

def main() raises:
    var passed = 0
    var failed = 0
    try: test_build_node_and_conn_counts(); passed += 1
    except e: failed += 1; print("FAIL test_build_node_and_conn_counts:", e)
    try: test_build_positions_and_default_emotion(); passed += 1
    except e: failed += 1; print("FAIL test_build_positions_and_default_emotion:", e)
    try: test_build_trigram_mapping(); passed += 1
    except e: failed += 1; print("FAIL test_build_trigram_mapping:", e)
    try: test_update_node_emotion(); passed += 1
    except e: failed += 1; print("FAIL test_update_node_emotion:", e)
    try: test_update_node_emotion_bounds_safe(); passed += 1
    except e: failed += 1; print("FAIL test_update_node_emotion_bounds_safe:", e)
    try: test_update_node_weight(); passed += 1
    except e: failed += 1; print("FAIL test_update_node_weight:", e)
    try: test_render_deterministic(); passed += 1
    except e: failed += 1; print("FAIL test_render_deterministic:", e)
    try: test_render_after_update_reflects_state(); passed += 1
    except e: failed += 1; print("FAIL test_render_after_update_reflects_state:", e)
    try: test_render_svg_deterministic(); passed += 1
    except e: failed += 1; print("FAIL test_render_svg_deterministic:", e)
    try: test_layout_type_default(); passed += 1
    except e: failed += 1; print("FAIL test_layout_type_default:", e)
    print("Emoji tests -> passed:", passed, " failed:", failed)
    if failed > 0:
        raise Error("Emoji tests failed")
