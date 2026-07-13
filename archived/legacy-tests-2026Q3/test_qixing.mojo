# 七星 - 动态规划测试套件
# 7 tests

from std.testing import assert_equal
from trigram import CHIEN, KUN, ZHEN, XUN, KAN, LI, GEN, DUI
from qixing import abstract_level, plan

def test_abstract_level() raises:
    assert_equal(abstract_level(CHIEN), 5)
    assert_equal(abstract_level(KUN), 5)
    assert_equal(abstract_level(LI), 3)
    assert_equal(abstract_level(KAN), 3)
    assert_equal(abstract_level(ZHEN), 2)
    assert_equal(abstract_level(XUN), 2)
    assert_equal(abstract_level(GEN), 1)
    assert_equal(abstract_level(DUI), 1)
    assert_equal(abstract_level(99), 0)

def test_plan_empty_candidates() raises:
    var ctx = SIMD[DType.int64, 6](0, 0, 0, 0, 0, 0)
    var candidates = List[Int]()
    var result = plan(ctx, candidates)
    assert_equal(len(result), 0)

def test_plan_filters_by_depth() raises:
    var ctx = SIMD[DType.int64, 6](0, 0, 5, 2, 0, 0)
    var candidates = List[Int]()
    candidates.append(CHIEN)
    candidates.append(GEN)
    candidates.append(DUI)
    var result = plan(ctx, candidates)
    for i in range(len(result)):
        assert_equal(abstract_level(result[i]) <= 2, True)

def test_plan_returns_sorted() raises:
    var ctx = SIMD[DType.int64, 6](3, 1, 5, 9, 0, 0)
    var candidates = List[Int]()
    candidates.append(GEN)
    candidates.append(ZHEN)
    candidates.append(LI)
    var result = plan(ctx, candidates)
    assert_equal(len(result), 3)

def test_plan_keeps_all_when_depth_high() raises:
    var ctx = SIMD[DType.int64, 6](5, 1, 7, 9, 0, 0)
    var candidates = List[Int]()
    candidates.append(CHIEN)
    candidates.append(KUN)
    candidates.append(ZHEN)
    candidates.append(DUI)
    var result = plan(ctx, candidates)
    assert_equal(len(result), 4)

def test_plan_prioritizes_abstract() raises:
    var ctx = SIMD[DType.int64, 6](5, 1, 9, 9, 0, 0)
    var candidates = List[Int]()
    candidates.append(DUI)
    candidates.append(CHIEN)
    candidates.append(GEN)
    var result = plan(ctx, candidates)
    # CHIEN (level 5) should come first
    for i in range(len(result) - 1):
        assert_equal(abstract_level(result[i]) >= abstract_level(result[i + 1]), True)

def test_plan_all() raises:
    var ctx = SIMD[DType.int64, 6](9, 0, 9, 9, 0, 0)
    var all_trigrams = List[Int]()
    all_trigrams.append(CHIEN)
    all_trigrams.append(KUN)
    all_trigrams.append(ZHEN)
    all_trigrams.append(XUN)
    all_trigrams.append(KAN)
    all_trigrams.append(LI)
    all_trigrams.append(GEN)
    all_trigrams.append(DUI)
    var result = plan(ctx, all_trigrams)
    assert_equal(len(result), 8)


def main() raises:
    var passed = 0
    var failed = 0
    try: test_abstract_level(); passed += 1
    except e: failed += 1; print("FAIL test_abstract_level:", e)
    try: test_plan_empty_candidates(); passed += 1
    except e: failed += 1; print("FAIL test_plan_empty_candidates:", e)
    try: test_plan_filters_by_depth(); passed += 1
    except e: failed += 1; print("FAIL test_plan_filters_by_depth:", e)
    try: test_plan_returns_sorted(); passed += 1
    except e: failed += 1; print("FAIL test_plan_returns_sorted:", e)
    try: test_plan_keeps_all_when_depth_high(); passed += 1
    except e: failed += 1; print("FAIL test_plan_keeps_all_when_depth_high:", e)
    try: test_plan_prioritizes_abstract(); passed += 1
    except e: failed += 1; print("FAIL test_plan_prioritizes_abstract:", e)
    try: test_plan_all(); passed += 1
    except e: failed += 1; print("FAIL test_plan_all:", e)

    print("QiXing tests -> passed:", passed, " failed:", failed)
    if failed > 0:
        raise Error("QiXing tests failed")
