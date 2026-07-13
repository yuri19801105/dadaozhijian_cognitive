# === sixiang/tests/test_sixiang.mojo ===
# 四象 TDD 验收: 判别 / 幅度 / 典型构造往返 / 相位名 / 降级 / 四步循环 / dual_gate 门控。
# 运行: .venv/bin/mojo run -I . -I core sixiang/tests/test_sixiang.mojo

from sixiang.quadrant import Quadrant, QuadrantClassifier, phase_name, OLD_YIN, YOUNG_YANG, OLD_YANG, YOUNG_YIN, QUADRANT_COUNT
from sixiang.phase import PhaseMachine
from liangyi.dual import Dual
from liangyi.activation import YinYangGate


def approx(a: Float64, b: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < 1e-9


def main() raises:
    var passed = 0
    var failed = 0

    # 1. classify 四象判别
    if QuadrantClassifier.classify(Dual(3.0)) == OLD_YANG:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL classify 老阳")
    if QuadrantClassifier.classify(Dual(-3.0)) == OLD_YIN:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL classify 老阴")
    if QuadrantClassifier.classify(QuadrantClassifier.canonical(YOUNG_YANG, 1.0)) == YOUNG_YANG:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL classify 少阳")
    if QuadrantClassifier.classify(QuadrantClassifier.canonical(YOUNG_YIN, 1.0)) == YOUNG_YIN:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL classify 少阴")

    # 2. magnitude(阴+阳 守恒量)
    if approx(QuadrantClassifier.magnitude(Dual(3.0)), 3.0):
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL magnitude 老阳")
    if approx(QuadrantClassifier.magnitude(Dual.from_parts(0.4, 0.6)), 1.0):
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL magnitude 少阳形")

    # 3. canonical 往返: 纯阳/少阳/少阴 形状正确
    var c_yang = QuadrantClassifier.canonical(OLD_YANG, 3.0)
    if approx(c_yang.get_value(), 3.0) and approx(c_yang.yin_part(), 0.0):
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL canonical 老阳")
    var c_young_yang = QuadrantClassifier.canonical(YOUNG_YANG, 1.0)
    if c_young_yang.yang_part() > c_young_yang.yin_part():
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL canonical 少阳 yang>yin")
    var c_young_yin = QuadrantClassifier.canonical(YOUNG_YIN, 1.0)
    if c_young_yin.yin_part() > c_young_yin.yang_part():
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL canonical 少阴 yin>yang")

    # 4. phase_name
    if phase_name(OLD_YIN) == "老阴":
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL phase_name 老阴")
    if phase_name(YOUNG_YANG) == "少阳":
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL phase_name 少阳")
    if phase_name(OLD_YANG) == "老阳":
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL phase_name 老阳")
    if phase_name(YOUNG_YIN) == "少阴":
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL phase_name 少阴")

    # 5. Quadrant.from_dual(输出契约: index / symbol / name)
    var q1 = QuadrantClassifier.from_dual(Dual(2.0))
    if q1.index == OLD_YANG and approx(q1.symbol.get_value(), 2.0) and q1.name() == "老阳":
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL from_dual 老阳")
    if QuadrantClassifier.from_dual(Dual(-2.0)).index == OLD_YIN:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL from_dual 老阴")
    if QuadrantClassifier.from_dual(QuadrantClassifier.canonical(YOUNG_YANG, 1.0)).index == YOUNG_YANG:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL from_dual 少阳")

    # 6. PhaseMachine 四步循环: 老阴 -> 少阳 -> 老阳 -> 少阴 -> 老阴
    var pm = PhaseMachine(Dual(-3.0))
    if pm.current_index() == OLD_YIN:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL pm 初始老阴")
    pm.advance()
    if pm.current_index() == YOUNG_YANG:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL pm 老阴->少阳")
    pm.advance()
    if pm.current_index() == OLD_YANG:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL pm 少阳->老阳")
    pm.advance()
    if pm.current_index() == YOUNG_YIN:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL pm 老阳->少阴")
    pm.advance()
    if pm.current_index() == OLD_YIN:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL pm 少阴->老阴")
    if pm.rounds == 4:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL pm rounds==4")
    if pm.current_quadrant().name() == "老阴":
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL pm 末态名")

    # 7. next_dual 静态流转
    var nd = PhaseMachine.next_dual(Dual(-3.0))
    if QuadrantClassifier.classify(nd) == YOUNG_YANG:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL next_dual 老阴->少阳")

    # 8. 错误处理: NaN / 平衡态 严格抛错; from_dual 降级不抛
    var nan_val = 0.0 / 0.0
    var raised_nan = False
    try:
        _ = QuadrantClassifier.classify(Dual(nan_val))
    except:
        raised_nan = True
    if raised_nan:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL classify NaN 应抛错")
    var qn = QuadrantClassifier.from_dual(Dual(nan_val))
    if qn.index == OLD_YIN:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL from_dual NaN 降级")

    var balanced = Dual.from_parts(1.0, 1.0)
    var raised_bal = False
    try:
        _ = QuadrantClassifier.classify(balanced)
    except:
        raised_bal = True
    if raised_bal:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL classify 平衡应抛错")
    if QuadrantClassifier.from_dual(balanced).index == OLD_YIN:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL from_dual 平衡降级")

    # 9. dual_gate 门控(contract): 纯阳 yang 门 > yin 门
    var g = YinYangGate.dual_gate(Dual(3.0), 0.0)
    if g.yang > g.yin:
        passed = passed + 1
    else:
        failed = failed + 1
        print("FAIL dual_gate 纯阳 yang>yin")

    print("sixiang -> passed:", passed, " failed:", failed)
    if failed > 0:
        raise Error("sixiang tests failed")
