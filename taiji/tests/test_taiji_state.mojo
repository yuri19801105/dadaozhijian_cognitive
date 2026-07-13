# === taiji/tests/test_taiji_state.mojo ===
# TDD (RED -> GREEN): 测试 taiji/taiji_state（太极全局状态根 · 张量化能量态）。
# 先定义契约与断言，再于 taiji_state.mojo 落地真实实现。
from taiji.taiji_state import TaijiState
from tensor.tensor import Tensor
from math.activate import softmax_list


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol


def ints_equal(a: List[Int], b: List[Int]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def floats_equal(a: List[Float64], b: List[Float64], tol: Float64) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if not approx(a[i], b[i], tol):
            return False
    return True


def test_init_default() raises:
    var s = TaijiState()
    if s.round != 0: raise Error("round should be 0")
    if s.seed != 0: raise Error("seed should be 0")
    if s.intent_hash != 0: raise Error("intent_hash should be 0")
    if s.energy.rank() != 1 or s.energy.size() != 9:
        raise Error("energy should be shape [9]")
    if len(s.decision_chains) != 0: raise Error("no chains yet")
    if len(s.phases) != 0: raise Error("no phases yet")


def test_init_intent_hash() raises:
    var s = TaijiState(42)
    if s.intent_hash != 42: raise Error("intent_hash mismatch")


def test_recall_empty() raises:
    var s = TaijiState(7)
    if s.recall() != "": raise Error("recall on round 0 must be empty string")


def test_feedback_basic() raises:
    var s = TaijiState(3)
    var dec = List[Int]()
    dec.append(1); dec.append(2); dec.append(3)
    s.feedback("output text", dec, 2, 0.5)
    if s.round != 1: raise Error("round should be 1 after feedback")
    var last = s.last_decision()
    if not ints_equal(last, dec): raise Error("last_decision mismatch")
    if len(s.phases) != 1 or s.phases[0] != 2: raise Error("phase not recorded")
    if len(s.intensities) != 1 or not approx(s.intensities[0], 0.5, 1e-12):
        raise Error("intensity not recorded")
    if s.recall().find("1 轮") < 0: raise Error("recall should mention 1 round")
    if s.recall().find("意图根=3") < 0: raise Error("recall should mention intent root")


def test_feedback_multiple() raises:
    var s = TaijiState(1)
    for r in range(3):
        var dec = List[Int]()
        dec.append(r); dec.append(r * 10)
        s.feedback("o" + String(r), dec, r % 5, Float64(r) * 0.1)
    if s.round != 3: raise Error("round should be 3")
    if len(s.decision_chains) != 3: raise Error("should have 3 chains")
    if len(s.phases) != 3 or len(s.intensities) != 3 or len(s.out_lengths) != 3:
        raise Error("parallel lists length mismatch")
    # last decision is the 3rd chain
    var last = s.last_decision()
    var expected = List[Int]()
    expected.append(2); expected.append(20)
    if not ints_equal(last, expected): raise Error("last decision wrong")
    # energy accumulated at phase indices (idx = phase % 9)
    var ed = s.energy.to_list()
    if not approx(ed[0], 0.0, 1e-12): raise Error("energy[0] accumulates phase0 intensity(0.0)")
    if not approx(ed[2], 0.2, 1e-12): raise Error("energy[2] accumulates phase2 intensity(0.2)")


def test_energy_distribution() raises:
    var s = TaijiState(0)
    var dec = List[Int]()
    dec.append(1)
    s.feedback("x", dec, 0, 1.0)
    s.feedback("y", dec, 1, 1.0)
    var dist = s.energy_distribution()
    if len(dist) != 9: raise Error("distribution len")
    var sum = 0.0
    for i in range(9):
        sum += dist[i]
    if not approx(sum, 1.0, 1e-9): raise Error("softmax should sum to 1")


def test_serialize_payload_roundtrip() raises:
    # 构造含多轮的丰富状态
    var s = TaijiState(99)
    for r in range(4):
        var dec = List[Int]()
        dec.append(r); dec.append(r + 1); dec.append(r + 2)
        s.feedback("round" + String(r), dec, (r * 2) % 5, Float64(r) * 0.25 + 0.1)
    # 经 List[Int] 字节载体 round-trip
    var payload = s.to_payload()
    if len(payload) == 0: raise Error("payload should be non-empty")
    var s2 = TaijiState()
    s2.from_payload(payload)
    if s2.round != s.round: raise Error("round mismatch after payload roundtrip")
    if s2.seed != s.seed: raise Error("seed mismatch after payload roundtrip")
    if s2.intent_hash != s.intent_hash: raise Error("intent_hash mismatch")
    if not ints_equal(s2.last_decision(), s.last_decision()):
        raise Error("last_decision mismatch after payload roundtrip")
    if not floats_equal(s2.energy.to_list(), s.energy.to_list(), 1e-12):
        raise Error("energy mismatch after payload roundtrip")
    if not ints_equal(s2.phases, s.phases): raise Error("phases mismatch")
    if not floats_equal(s2.intensities, s.intensities, 1e-12):
        raise Error("intensities mismatch")


def test_serialize_string_roundtrip() raises:
    var s = TaijiState(5)
    for r in range(2):
        var dec = List[Int]()
        dec.append(7); dec.append(8)
        s.feedback("zz", dec, 3, -0.5)
    var str = s.serialize()
    var s3 = TaijiState()
    s3.deserialize(str)
    if s3.round != s.round or s3.seed != s.seed:
        raise Error("string roundtrip failed")
    if not floats_equal(s3.intensities, s.intensities, 1e-12):
        raise Error("intensities string roundtrip failed")
    # 序列化自包含：不依赖外部
    if str.find("|") < 0: raise Error("serialize should be pipe-delimited")


def test_seed_deterministic() raises:
    # 相同反馈序列 -> 相同 seed（确定性派生）
    var a = TaijiState(1)
    var b = TaijiState(1)
    var dec = List[Int]()
    dec.append(4); dec.append(5)
    a.feedback("same", dec, 2, 0.7)
    b.feedback("same", dec, 2, 0.7)
    if a.seed != b.seed: raise Error("seed must be deterministic")
    # 不同相位 -> 不同 seed
    var c = TaijiState(1)
    c.feedback("same", dec, 3, 0.7)
    if c.seed == a.seed: raise Error("different phase should change seed")


def main() raises:
    var failed = 0
    print("=== taiji/taiji_state tests ===")
    try: test_init_default(); print("  passed: init_default")
    except e: failed += 1; print("  FAILED: init_default ->", e)
    try: test_init_intent_hash(); print("  passed: init_intent_hash")
    except e: failed += 1; print("  FAILED: init_intent_hash ->", e)
    try: test_recall_empty(); print("  passed: recall_empty")
    except e: failed += 1; print("  FAILED: recall_empty ->", e)
    try: test_feedback_basic(); print("  passed: feedback_basic")
    except e: failed += 1; print("  FAILED: feedback_basic ->", e)
    try: test_feedback_multiple(); print("  passed: feedback_multiple")
    except e: failed += 1; print("  FAILED: feedback_multiple ->", e)
    try: test_energy_distribution(); print("  passed: energy_distribution")
    except e: failed += 1; print("  FAILED: energy_distribution ->", e)
    try: test_serialize_payload_roundtrip(); print("  passed: serialize_payload_roundtrip")
    except e: failed += 1; print("  FAILED: serialize_payload_roundtrip ->", e)
    try: test_serialize_string_roundtrip(); print("  passed: serialize_string_roundtrip")
    except e: failed += 1; print("  FAILED: serialize_string_roundtrip ->", e)
    try: test_seed_deterministic(); print("  passed: seed_deterministic")
    except e: failed += 1; print("  FAILED: seed_deterministic ->", e)
    if failed > 0:
        print("taiji_state -> passed: 0  failed:", failed)
        raise Error("taiji_state tests failed")
    print("taiji_state -> passed: 10  failed: 0")
