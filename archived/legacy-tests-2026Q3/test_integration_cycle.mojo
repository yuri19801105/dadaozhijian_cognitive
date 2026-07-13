# 全周期集成测试套件
# 15 tests — 验证流水线端到端行为(含六合→七星剪枝/排序真断言 + 认知→行动→回灌太极闭环)

from std.testing import assert_equal
from workspace import Workspace
from config import Config
from pipeline import run_cycle, CognitiveCycle, _compute_intensity, _detect_phase
from wu_xing import WOOD, FIRE, EARTH, METAL, WATER
from qixing import abstract_level
from trigram import CHIEN, KUN, ZHEN, XUN, KAN, LI, GEN, DUI

def test_compute_intensity_zero() raises:
    assert_equal(_compute_intensity(""), 0)

def test_compute_intensity_short() raises:
    assert_equal(_compute_intensity("hi"), 1)

def test_compute_intensity_mid() raises:
    assert_equal(_compute_intensity("a" * 50), 5)

def test_compute_intensity_max() raises:
    assert_equal(_compute_intensity("a" * 200), 9)

def test_detect_phase_empty() raises:
    assert_equal(_detect_phase(""), WATER)

def test_detect_phase_short() raises:
    assert_equal(_detect_phase("hello"), WOOD)

def test_detect_phase_medium() raises:
    assert_equal(_detect_phase("a" * 30), FIRE)

def test_detect_phase_long() raises:
    assert_equal(_detect_phase("a" * 60), EARTH)

def test_detect_phase_very_long() raises:
    assert_equal(_detect_phase("a" * 150), METAL)

def test_run_cycle_empty_text() raises:
    # 空文本 → 五行 WATER 相 → 候选链 [CHIEN, KAN] → 六合态势 → 七星按 abstract_level 降序
    var ws = Workspace()
    var cfg = Config()
    var result = run_cycle(ws, "", cfg)
    assert_equal(len(result), 2)
    assert_equal(result[0], CHIEN)   # abstract_level 5, 排最前
    assert_equal(result[1], KAN)     # abstract_level 3
    # 七星排序不变量: abstract_level 非增
    for i in range(len(result) - 1):
        assert_equal(abstract_level(result[i]) >= abstract_level(result[i + 1]), True)

def test_run_cycle_short_text() raises:
    # "hi" → WOOD 相 → 候选链 [ZHEN, XUN]
    var ws = Workspace()
    var cfg = Config()
    var result = run_cycle(ws, "hi", cfg)
    assert_equal(len(result), 2)
    # 七星剪枝不变量: 所有算子 abstract_level <= max_depth
    for i in range(len(result)):
        assert_equal(abstract_level(result[i]) <= cfg.max_depth, True)

def test_run_cycle_long_text() raises:
    # "a"*80 → EARTH 相 → 候选链 [KUN, GEN] → 七星降序 [KUN(5), GEN(1)]
    var ws = Workspace()
    var cfg = Config()
    var result = run_cycle(ws, "a" * 80, cfg)
    assert_equal(len(result), 2)
    assert_equal(result[0], KUN)     # abstract_level 5, 排最前
    assert_equal(result[1], GEN)     # abstract_level 1
    for i in range(len(result) - 1):
        assert_equal(abstract_level(result[i]) >= abstract_level(result[i + 1]), True)

def test_run_cycle_prunes_by_max_depth() raises:
    # 收紧 max_depth=1 → 七星剪枝丢弃高抽象算子: EARTH 候选链 [KUN(5), GEN(1)] 中 KUN 被剪, 仅 GEN 存活
    var ws = Workspace()
    var cfg = Config()
    cfg.max_depth = 1
    var result = run_cycle(ws, "a" * 80, cfg)
    assert_equal(len(result), 1)
    assert_equal(result[0], GEN)
    for i in range(len(result)):
        assert_equal(abstract_level(result[i]) <= 1, True)

def test_run_full_cycle_end_to_end() raises:
    # 认知→行动→回灌闭环首轮: 太极为空, recall()="" 注入无记忆, 输出与无记忆单轮完全一致
    # 与 test_run_cycle_empty_text 的链断言(精确 [CHIEN, KAN])绑定, 确保 规划→执行 链路真闭环
    var cfg = Config()
    var c = CognitiveCycle("")
    var out = c.run("", cfg)
    var expected = "[0] 创造: \n[1] 冒险: 尝试假设——长度 0 字节"
    assert_equal(out, expected)
    # 单轮后太极已回灌 1 次, recall 非空
    assert_equal(c.state.round, 1)
    assert_equal(c.state.recall().find("[记忆"), 0)

def test_run_full_cycle_continuity() raises:
    # 跨轮连续性: 十方输出回灌太极后, 下一轮 recall() 注入使输入带上记忆上下文, 输出不同于首轮
    var cfg = Config()
    var c = CognitiveCycle("任务")
    var r1 = c.run("abc", cfg)
    # 首轮无记忆前缀(回灌发生在 run 末尾, 首轮输入 recall="")
    assert_equal(r1.find("[记忆"), -1)
    assert_equal(c.state.round, 1)
    var r2 = c.run("abc", cfg)
    # 次轮 recall() 注入记忆上下文 → 输入改变 → 输出与首轮不同, 且太极已累积 2 轮
    assert_equal(r2 == r1, False)
    assert_equal(c.state.round, 2)
    # 决策链按轮累积(每轮 2 算子 → 累计 4 个展平元素, 2 条链)
    assert_equal(len(c.state.decision_lens), 2)
    assert_equal(len(c.state.last_decision()), 2)


def main() raises:
    var passed = 0
    var failed = 0
    try: test_compute_intensity_zero(); passed += 1
    except e: failed += 1; print("FAIL test_compute_intensity_zero:", e)
    try: test_compute_intensity_short(); passed += 1
    except e: failed += 1; print("FAIL test_compute_intensity_short:", e)
    try: test_compute_intensity_mid(); passed += 1
    except e: failed += 1; print("FAIL test_compute_intensity_mid:", e)
    try: test_compute_intensity_max(); passed += 1
    except e: failed += 1; print("FAIL test_compute_intensity_max:", e)
    try: test_detect_phase_empty(); passed += 1
    except e: failed += 1; print("FAIL test_detect_phase_empty:", e)
    try: test_detect_phase_short(); passed += 1
    except e: failed += 1; print("FAIL test_detect_phase_short:", e)
    try: test_detect_phase_medium(); passed += 1
    except e: failed += 1; print("FAIL test_detect_phase_medium:", e)
    try: test_detect_phase_long(); passed += 1
    except e: failed += 1; print("FAIL test_detect_phase_long:", e)
    try: test_detect_phase_very_long(); passed += 1
    except e: failed += 1; print("FAIL test_detect_phase_very_long:", e)
    try: test_run_cycle_empty_text(); passed += 1
    except e: failed += 1; print("FAIL test_run_cycle_empty_text:", e)
    try: test_run_cycle_short_text(); passed += 1
    except e: failed += 1; print("FAIL test_run_cycle_short_text:", e)
    try: test_run_cycle_long_text(); passed += 1
    except e: failed += 1; print("FAIL test_run_cycle_long_text:", e)
    try: test_run_cycle_prunes_by_max_depth(); passed += 1
    except e: failed += 1; print("FAIL test_run_cycle_prunes_by_max_depth:", e)
    try: test_run_full_cycle_end_to_end(); passed += 1
    except e: failed += 1; print("FAIL test_run_full_cycle_end_to_end:", e)
    try: test_run_full_cycle_continuity(); passed += 1
    except e: failed += 1; print("FAIL test_run_full_cycle_continuity:", e)

    print("Integration tests -> passed:", passed, " failed:", failed)
    if failed > 0:
        raise Error("Integration tests failed")
