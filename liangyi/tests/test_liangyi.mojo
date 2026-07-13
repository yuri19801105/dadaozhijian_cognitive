# === liangyi/tests/test_liangyi.mojo ===
# TDD: 先写失败测试(RED) -> 实现后全绿(GREEN)。零桩函数。
# 运行: .venv/bin/mojo run -I . -I core liangyi/tests/test_liangyi.mojo

from liangyi.dual import Dual, YIN, YANG
from liangyi.polarity import Polarity
from liangyi.activation import YinYangGate, GatePair


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol


# ---------- Dual 核心类型 ----------
def test_init_positive() raises:
    var d = Dual(3.0)
    if not approx(d.get_value(), 3.0, 1e-12): raise Error("init+ value")
    if d.get_phase() != YANG: raise Error("init+ phase should be YANG")
    if not approx(d.yin_part(), 0.0, 1e-12): raise Error("init+ yin==0")
    if not approx(d.yang_part(), 3.0, 1e-12): raise Error("init+ yang==value")


def test_init_negative() raises:
    var d = Dual(-3.0)
    if not approx(d.get_value(), -3.0, 1e-12): raise Error("init- value")
    if d.get_phase() != YIN: raise Error("init- phase should be YIN")
    if not approx(d.yin_part(), 3.0, 1e-12): raise Error("init- yin==|value|")
    if not approx(d.yang_part(), 0.0, 1e-12): raise Error("init- yang==0")


def test_init_zero() raises:
    var d = Dual(0.0)
    if not approx(d.get_value(), 0.0, 1e-12): raise Error("init0 value")
    if not approx(d.yin_part(), 0.0, 1e-12): raise Error("init0 yin")
    if not approx(d.yang_part(), 0.0, 1e-12): raise Error("init0 yang")
    if d.get_phase() != YANG: raise Error("init0 default phase YANG")


def test_from_parts_yang() raises:
    var d = Dual.from_parts(2.0, 5.0)
    if not approx(d.get_value(), 3.0, 1e-12): raise Error("from_parts yang value=3")
    if d.get_phase() != YANG: raise Error("from_parts yang phase")
    if not approx(d.yin_part(), 2.0, 1e-12): raise Error("from_parts yin==2")
    if not approx(d.yang_part(), 5.0, 1e-12): raise Error("from_parts yang==5")


def test_from_parts_yin() raises:
    var d = Dual.from_parts(5.0, 2.0)
    if not approx(d.get_value(), -3.0, 1e-12): raise Error("from_parts yin value=-3")
    if d.get_phase() != YIN: raise Error("from_parts yin phase")
    if not approx(d.yin_part(), 5.0, 1e-12): raise Error("from_parts yin==5")
    if not approx(d.yang_part(), 2.0, 1e-12): raise Error("from_parts yang==2")


def test_add() raises:
    var a = Dual(3.0)
    var b = Dual(2.0)
    var s = a.add(b)
    if not approx(s.get_value(), 5.0, 1e-12): raise Error("add 3+2=5")
    if not approx(s.yang_part(), 5.0, 1e-12): raise Error("add yang bucket")
    # 异号相加: 3 + (-2) = 1
    var c = Dual(-2.0)
    var s2 = a.add(c)
    if not approx(s2.get_value(), 1.0, 1e-12): raise Error("add 3+(-2)=1")
    if not approx(s2.yin_part(), 2.0, 1e-12): raise Error("add mixed yin=2")
    if not approx(s2.yang_part(), 3.0, 1e-12): raise Error("add mixed yang=3")


def test_sub() raises:
    var a = Dual(5.0)
    var b = Dual(2.0)
    var s = a.sub(b)
    if not approx(s.get_value(), 3.0, 1e-12): raise Error("sub 5-2=3")
    # 2 - 3 = -1
    var c = Dual(3.0)
    var s2 = b.sub(c)
    if not approx(s2.get_value(), -1.0, 1e-12): raise Error("sub 2-3=-1")


def test_scale() raises:
    var a = Dual(3.0)
    var s = a.scale(2.0)
    if not approx(s.get_value(), 6.0, 1e-12): raise Error("scale 3*2=6")
    if not approx(s.yang_part(), 6.0, 1e-12): raise Error("scale yang=6")
    # 负量缩放
    var n = Dual(-3.0)
    var s2 = n.scale(2.0)
    if not approx(s2.get_value(), -6.0, 1e-12): raise Error("scale -3*2=-6")
    if not approx(s2.yin_part(), 6.0, 1e-12): raise Error("scale yin=6")


def test_as_vector() raises:
    var d = Dual(3.0)
    var v = d.as_vector()
    if len(v) != 2: raise Error("vector len 2")
    if not approx(v[0], 0.0, 1e-12): raise Error("as_vector[0]=yin=0")
    if not approx(v[1], 3.0, 1e-12): raise Error("as_vector[1]=yang=3")


# ---------- Polarity 极性运算 ----------
def test_invert() raises:
    var d = Dual(3.0)
    var r = Polarity.invert(d)
    if not approx(r.get_value(), -3.0, 1e-12): raise Error("invert value -3")
    if r.get_phase() != YIN: raise Error("invert phase YIN")
    if not approx(r.yin_part(), 3.0, 1e-12): raise Error("invert yin=3")
    if not approx(r.yang_part(), 0.0, 1e-12): raise Error("invert yang=0")
    # 逆逆归原
    var back = Polarity.invert(r)
    if not approx(back.get_value(), 3.0, 1e-12): raise Error("invert twice -> 3")


def test_compose() raises:
    var a = Dual(10.0)
    var b = Dual(0.0)
    var r1 = Polarity.compose(a, b, 1.0)
    if not approx(r1.get_value(), 10.0, 1e-12): raise Error("compose ratio=1 -> a")
    var r0 = Polarity.compose(a, b, 0.0)
    if not approx(r0.get_value(), 0.0, 1e-12): raise Error("compose ratio=0 -> b")
    var r5 = Polarity.compose(a, b, 0.5)
    if not approx(r5.get_value(), 5.0, 1e-12): raise Error("compose ratio=0.5 -> 5")


def test_classify() raises:
    if Polarity.classify(Dual(3.0)) != 1: raise Error("classify + -> 1")
    if Polarity.classify(Dual(-3.0)) != -1: raise Error("classify - -> -1")
    if Polarity.classify(Dual(0.0)) != 0: raise Error("classify 0 -> 0")


def test_reconcile() raises:
    var a = Dual(4.0)
    var b = Dual(2.0)
    var r = Polarity.reconcile(a, b)
    if not approx(r.get_value(), 3.0, 1e-12): raise Error("reconcile avg value=3")


# ---------- YinYangGate 阴阳激活门 ----------
def test_yin_gate() raises:
    # 阴门抑制: 阴分量越高, 门越低
    var d = Dual(3.0)            # yin=0 -> gate = sigmoid(0) = 0.5
    if not approx(YinYangGate.yin_gate(d), 0.5, 1e-9): raise Error("yin_gate(+3,0)=0.5")
    var n = Dual(-3.0)           # yin=3 -> gate = sigmoid(-3) ~ 0.047
    if not approx(YinYangGate.yin_gate(n), 0.047425873, 1e-6): raise Error("yin_gate(-3,0)~0.047")
    # bias 抬高 -> 门变大(抑制减弱)
    if not approx(YinYangGate.yin_gate(d, 1.0), 0.731058578, 1e-6): raise Error("yin_gate(+3,1)~0.731")


def test_yang_gate() raises:
    var d = Dual(3.0)            # yang=3 -> gate = sigmoid(3) ~ 0.952
    if not approx(YinYangGate.yang_gate(d), 0.952574127, 1e-6): raise Error("yang_gate(+3,0)~0.952")
    var n = Dual(-3.0)           # yang=0 -> gate = sigmoid(0) = 0.5
    if not approx(YinYangGate.yang_gate(n), 0.5, 1e-9): raise Error("yang_gate(-3,0)=0.5")
    if not approx(YinYangGate.yang_gate(d, 1.0), 0.88079708, 1e-6): raise Error("yang_gate(+3,1)~0.881")


def test_dual_gate() raises:
    var d = Dual(3.0)
    var g = YinYangGate.dual_gate(d)
    if not approx(g.yin, 0.5, 1e-9): raise Error("dual_gate.yin=0.5")
    if not approx(g.yang, 0.952574127, 1e-6): raise Error("dual_gate.yang~0.952")


def test_balance_gate() raises:
    var z = Dual(0.0)            # 平衡 -> ratio 0 -> sigmoid(-threshold)=0.5
    if not approx(YinYangGate.balance_gate(z), 0.5, 1e-9): raise Error("balance 0 = 0.5")
    var d = Dual(3.0)            # yang=3,yin=0 -> ratio=1 -> sigmoid(1)~0.731
    if not approx(YinYangGate.balance_gate(d), 0.731058578, 1e-6): raise Error("balance(+3)~0.731")
    var n = Dual(-3.0)           # ratio=-1 -> sigmoid(-1)~0.269
    if not approx(YinYangGate.balance_gate(n), 0.268941421, 1e-6): raise Error("balance(-3)~0.269")


def main() raises:
    var passed = 0
    var failed = 0
    var cases = List[String]()
    cases.append("test_init_positive")
    cases.append("test_init_negative")
    cases.append("test_init_zero")
    cases.append("test_from_parts_yang")
    cases.append("test_from_parts_yin")
    cases.append("test_add")
    cases.append("test_sub")
    cases.append("test_scale")
    cases.append("test_as_vector")
    cases.append("test_invert")
    cases.append("test_compose")
    cases.append("test_classify")
    cases.append("test_reconcile")
    cases.append("test_yin_gate")
    cases.append("test_yang_gate")
    cases.append("test_dual_gate")
    cases.append("test_balance_gate")

    for i in range(len(cases)):
        try:
            if cases[i] == "test_init_positive": test_init_positive()
            elif cases[i] == "test_init_negative": test_init_negative()
            elif cases[i] == "test_init_zero": test_init_zero()
            elif cases[i] == "test_from_parts_yang": test_from_parts_yang()
            elif cases[i] == "test_from_parts_yin": test_from_parts_yin()
            elif cases[i] == "test_add": test_add()
            elif cases[i] == "test_sub": test_sub()
            elif cases[i] == "test_scale": test_scale()
            elif cases[i] == "test_as_vector": test_as_vector()
            elif cases[i] == "test_invert": test_invert()
            elif cases[i] == "test_compose": test_compose()
            elif cases[i] == "test_classify": test_classify()
            elif cases[i] == "test_reconcile": test_reconcile()
            elif cases[i] == "test_yin_gate": test_yin_gate()
            elif cases[i] == "test_yang_gate": test_yang_gate()
            elif cases[i] == "test_dual_gate": test_dual_gate()
            elif cases[i] == "test_balance_gate": test_balance_gate()
            passed = passed + 1
        except e:
            failed = failed + 1
            print("[FAILED] ", cases[i], ": ", e)

    print("liangyi -> passed: ", passed, " failed: ", failed)
    if failed > 0:
        raise Error("liangyi tests failed")
