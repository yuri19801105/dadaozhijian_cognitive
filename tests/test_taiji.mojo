# 太极 / 长期记忆 单元测试
# 验证回灌机制: create / recall / feedback / 跨轮累积 / 种子派生确定性
# 语言: Mojo 1.0.0b2 | 验证: TDD (手写 try/except 运行器)

from std.testing import assert_equal
from taiji import TaijiState

def test_create_empty() raises:
    var t = TaijiState(0)
    assert_equal(t.round, 0)
    assert_equal(len(t.decision_chains), 0)
    assert_equal(len(t.phases), 0)
    assert_equal(t.recall(), "")
    assert_equal(t.intent_hash, 0)

def test_create_with_intent() raises:
    # "解析用户意图" = 6 个中文字符 = 18 字节 UTF-8, 意图哈希 = 18
    var t = TaijiState(18)
    assert_equal(t.intent_hash, 18)
    assert_equal(t.recall(), "")

def test_feedback_accumulates() raises:
    var t = TaijiState(0)
    var d1 = List[Int]()
    d1.append(1)
    d1.append(2)
    t.feedback("out1", d1, 5, 3)
    assert_equal(t.round, 1)
    assert_equal(len(t.decision_chains), 1)
    assert_equal(len(t.decision_chains[0]), 2)
    assert_equal(len(t.phases), 1)
    assert_equal(t.phases[0], 5)
    assert_equal(len(t.intensities), 1)
    assert_equal(t.intensities[0], 3.0)
    var d2 = List[Int]()
    d2.append(3)
    d2.append(4)
    d2.append(5)
    t.feedback("out2", d2, 7, 9)
    assert_equal(t.round, 2)
    assert_equal(len(t.decision_chains), 2)
    assert_equal(len(t.decision_chains[1]), 3)
    assert_equal(len(t.phases), 2)
    assert_equal(t.phases[1], 7)

def test_recall_nonempty_after_feedback() raises:
    var t = TaijiState(0)
    var d = List[Int]()
    d.append(0)
    d.append(5)
    t.feedback("创造: hello", d, 5, 3)
    var r = t.recall()
    # recall 以 "[记忆 N 轮] " 开头, 含相位链与决策数
    assert_equal(r.find("[记忆"), 0)
    assert_equal(r.find("相位链=[5]") >= 0, True)
    assert_equal(r.find("决策链数=1") >= 0, True)

def test_seed_derivation_deterministic() raises:
    var a = TaijiState(0)
    var b = TaijiState(0)
    var da = List[Int](); da.append(1)
    var db = List[Int](); db.append(1)
    a.feedback("same", da, 5, 3)
    b.feedback("same", db, 5, 3)
    assert_equal(a.seed, b.seed)
    # 不同输出(字节长不同) → 不同种子
    var c = TaijiState(0)
    var dc = List[Int](); dc.append(1)
    c.feedback("differs", dc, 5, 3)
    assert_equal(a.seed == c.seed, False)

def test_last_decision() raises:
    var t = TaijiState(0)
    var d = List[Int]()
    d.append(1)
    d.append(2)
    d.append(3)
    t.feedback("o1", d, 5, 3)
    var ld = t.last_decision()
    assert_equal(len(ld), 3)
    assert_equal(ld[0], 1)
    assert_equal(ld[2], 3)

def main() raises:
    var passed = 0
    var failed = 0
    try: test_create_empty(); passed += 1
    except e: failed += 1; print("FAIL test_create_empty:", e)
    try: test_create_with_intent(); passed += 1
    except e: failed += 1; print("FAIL test_create_with_intent:", e)
    try: test_feedback_accumulates(); passed += 1
    except e: failed += 1; print("FAIL test_feedback_accumulates:", e)
    try: test_recall_nonempty_after_feedback(); passed += 1
    except e: failed += 1; print("FAIL test_recall_nonempty_after_feedback:", e)
    try: test_seed_derivation_deterministic(); passed += 1
    except e: failed += 1; print("FAIL test_seed_derivation_deterministic:", e)
    try: test_last_decision(); passed += 1
    except e: failed += 1; print("FAIL test_last_decision:", e)

    print("Taiji tests -> passed:", passed, " failed:", failed)
    if failed > 0:
        raise Error("taiji tests failed")
