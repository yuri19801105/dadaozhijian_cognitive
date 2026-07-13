# === sancai/tests/test_sancai.mojo ===
# TDD: 先写失败测试(RED) -> 实现后全绿(GREEN)。零桩函数。
# 运行: .venv/bin/mojo run -I . -I core sancai/tests/test_sancai.mojo

from sancai.layers import SanCai, TIAN, DI, REN, LAYER_COUNT
from sancai.interface import LayerMessage, LayerBus
from liangyi.dual import Dual, YIN, YANG
from liangyi.polarity import Polarity
from liangyi.activation import YinYangGate, GatePair
from tensor.tensor import Tensor
from math.activate import sigmoid


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol


# ---------- SanCai 三层结构 (layers.mojo) ----------

def test_sc_neutral() raises:
    var sc = SanCai()
    if not approx(sc.tian.get_value(), 0.0, 1e-12): raise Error("neutral tian==0")
    if not approx(sc.di.get_value(), 0.0, 1e-12): raise Error("neutral di==0")
    if not approx(sc.ren.get_value(), 0.0, 1e-12): raise Error("neutral ren==0")
    var sh = sc.payload.shape()
    if len(sh) != 2 or sh[0] != 3 or sh[1] != 3: raise Error("neutral payload [3,3]")


def test_from_layer_vectors() raises:
    var tian = List[Float64](); tian.append(1.0); tian.append(2.0); tian.append(3.0)   # mean 2 -> yang 2
    var di = List[Float64](); di.append(0.0); di.append(0.0); di.append(0.0)            # mean 0
    var ren = List[Float64](); ren.append(-1.0); ren.append(-2.0); ren.append(-3.0)      # mean -2 -> yin 2
    var sc = SanCai()
    sc.from_layer_vectors(tian, di, ren)
    if not approx(sc.tian.get_value(), 2.0, 1e-12): raise Error("tian mean=2")
    if sc.tian.get_phase() != YANG: raise Error("tian phase YANG")
    if not approx(sc.di.get_value(), 0.0, 1e-12): raise Error("di mean=0")
    if not approx(sc.ren.get_value(), -2.0, 1e-12): raise Error("ren mean=-2")
    if sc.ren.get_phase() != YIN: raise Error("ren phase YIN")
    # payload: 行0 = [1,2,3]
    if not approx(sc.payload.at([0, 0]), 1.0, 1e-12): raise Error("payload[0,0]=1")
    if not approx(sc.payload.at([0, 2]), 3.0, 1e-12): raise Error("payload[0,2]=3")


def test_from_layer_vectors_empty_raises() raises:
    var a = List[Float64](); a.append(1.0)
    var b = List[Float64](); b.append(1.0)
    var empty = List[Float64]()
    var sc = SanCai()
    var raised = False
    try:
        sc.from_layer_vectors(empty, b, a)
    except:
        raised = True
    if not raised: raise Error("empty layer vector must raise")


def test_from_tensors() raises:
    # 三个 [3] 张量: 天=[2,2,2](mean2) 地=[0,0,0](0) 人=[-4,-4,-4](mean -4)
    var td = List[Float64](); td.append(2.0); td.append(2.0); td.append(2.0)
    var dd = List[Float64](); dd.append(0.0); dd.append(0.0); dd.append(0.0)
    var rd = List[Float64](); rd.append(-4.0); rd.append(-4.0); rd.append(-4.0)
    var tsh = List[Int](); tsh.append(3)
    var tian = Tensor(); tian.from_list(td, tsh)
    var di = Tensor(); di.from_list(dd, tsh)
    var ren = Tensor(); ren.from_list(rd, tsh)
    var sc = SanCai()
    sc.from_tensors(tian, di, ren)
    if not approx(sc.tian.get_value(), 2.0, 1e-12): raise Error("from_tensors tian=2")
    if not approx(sc.ren.get_value(), -4.0, 1e-12): raise Error("from_tensors ren=-4")


def test_compose_layers() raises:
    # 构造 payload [3,3]
    var pd = List[Float64]()
    for i in range(9):
        pd.append(Float64(i))
    var psh = List[Int](); psh.append(3); psh.append(3)
    var payload = Tensor(); payload.from_list(pd, psh)
    var sc = SanCai()
    sc.compose_layers(Dual(1.0), Dual(2.0), Dual(-1.0), payload)
    if not approx(sc.tian.get_value(), 1.0, 1e-12): raise Error("compose tian=1")
    if not approx(sc.di.get_value(), 2.0, 1e-12): raise Error("compose di=2")
    if not approx(sc.ren.get_value(), -1.0, 1e-12): raise Error("compose ren=-1")
    if sc.ren.get_phase() != YIN: raise Error("compose ren YIN")
    if not approx(sc.payload.at([2, 0]), 6.0, 1e-12): raise Error("payload copied row2[0]=6")


def test_validate_ok() raises:
    var sc = SanCai()
    sc.validate()   # 中性态不应抛


def test_validate_nan_raises() raises:
    var inf = 1.0 / 0.0
    var nan = inf - inf
    var sc = SanCai()
    sc.tian = Dual(nan)
    var raised = False
    try:
        sc.validate()
    except:
        raised = True
    if not raised: raise Error("validate must raise on NaN")


def test_validate_shape_raises() raises:
    var sc = SanCai()
    var d = List[Float64](); d.append(1.0)
    var sh = List[Int](); sh.append(1)
    sc.payload.from_list(d, sh)   # 形状 [1] -> 首维 != 3
    var raised = False
    try:
        sc.validate()
    except:
        raised = True
    if not raised: raise Error("validate must raise on bad payload shape")


def test_layer_access() raises:
    var sc = SanCai()
    sc.tian = Dual(5.0)
    sc.di = Dual(-3.0)
    sc.ren = Dual(2.0)
    if not approx(sc.layer(TIAN).get_value(), 5.0, 1e-12): raise Error("layer(0)=tian")
    if not approx(sc.layer(DI).get_value(), -3.0, 1e-12): raise Error("layer(1)=di")
    if not approx(sc.layer(REN).get_value(), 2.0, 1e-12): raise Error("layer(2)=ren")
    var raised = False
    try:
        _ = sc.layer(3)
    except:
        raised = True
    if not raised: raise Error("layer(3) out of range must raise")


def test_dominant_phase() raises:
    # 天=5(YANG) 地=0 人=-3 -> 天绝对值最大 -> YANG
    var a = SanCai()
    a.tian = Dual(5.0); a.di = Dual(0.0); a.ren = Dual(-3.0)
    if a.dominant_phase() != YANG: raise Error("dominant=YANG (tian)")
    # 天=1 地=-4(YIN) 人=2 -> 地绝对值最大 -> YIN
    var b = SanCai()
    b.tian = Dual(1.0); b.di = Dual(-4.0); b.ren = Dual(2.0)
    if b.dominant_phase() != YIN: raise Error("dominant=YIN (di)")


# ---------- 层间消息契约 (interface.mojo) ----------

def test_transmit_tian_to_di() raises:
    # compose(Dual(2),Dual(0),0.5) = Dual(1); gate = balance_gate(Dual(1),0) = sigmoid(1)
    var msg = LayerBus.pass_tian_to_di(Dual(2.0), Dual(0.0), 0.5, 0.0)
    if msg.source != TIAN: raise Error("source=TIAN")
    if msg.target != DI: raise Error("target=DI")
    if not approx(msg.content.get_value(), 1.0, 1e-12): raise Error("content value=1")
    if not approx(msg.gate, sigmoid(1.0), 1e-6): raise Error("gate=sigmoid(1)")
    if not LayerBus.is_passed(msg): raise Error("gate>=0.5 -> passed")


def test_transmit_di_to_ren() raises:
    # compose(Dual(0),Dual(-2),0.5) = Dual(-1); gate = balance_gate(Dual(-1),0) = sigmoid(-1)
    var msg = LayerBus.pass_di_to_ren(Dual(0.0), Dual(-2.0), 0.5, 0.0)
    if msg.source != DI: raise Error("source=DI")
    if msg.target != REN: raise Error("target=REN")
    if not approx(msg.content.get_value(), -1.0, 1e-12): raise Error("content value=-1")
    if not approx(msg.gate, sigmoid(-1.0), 1e-6): raise Error("gate=sigmoid(-1)")
    if LayerBus.is_passed(msg): raise Error("gate<0.5 -> not passed")


def test_is_passed_threshold() raises:
    var hi = LayerMessage(0, 1, Dual(0.0), 0.6)
    var lo = LayerMessage(0, 1, Dual(0.0), 0.4)
    if not LayerBus.is_passed(hi): raise Error("0.6 passed")
    if LayerBus.is_passed(lo): raise Error("0.4 not passed")


def test_harmonize() raises:
    # 天=4 地=-10(极端) 人=2 -> 调和后 地=reconcile(4,2)=3
    var sc = SanCai()
    sc.tian = Dual(4.0); sc.di = Dual(-10.0); sc.ren = Dual(2.0)
    LayerBus.harmonize(sc)
    if not approx(sc.di.get_value(), 3.0, 1e-12): raise Error("harmonize di=3")
    # payload 中间行同步: [yin, (yin+yang)/2, yang] = [0, 1.5, 3]
    if not approx(sc.payload.at([DI, 0]), 0.0, 1e-12): raise Error("harmonize payload yin=0")
    if not approx(sc.payload.at([DI, 1]), 1.5, 1e-12): raise Error("harmonize payload mid=1.5")
    if not approx(sc.payload.at([DI, 2]), 3.0, 1e-12): raise Error("harmonize payload yang=3")


def main() raises:
    var passed = 0
    var failed = 0
    var cases = List[String]()
    cases.append("test_sc_neutral")
    cases.append("test_from_layer_vectors")
    cases.append("test_from_layer_vectors_empty_raises")
    cases.append("test_from_tensors")
    cases.append("test_compose_layers")
    cases.append("test_validate_ok")
    cases.append("test_validate_nan_raises")
    cases.append("test_validate_shape_raises")
    cases.append("test_layer_access")
    cases.append("test_dominant_phase")
    cases.append("test_transmit_tian_to_di")
    cases.append("test_transmit_di_to_ren")
    cases.append("test_is_passed_threshold")
    cases.append("test_harmonize")

    for i in range(len(cases)):
        try:
            if cases[i] == "test_sc_neutral": test_sc_neutral()
            elif cases[i] == "test_from_layer_vectors": test_from_layer_vectors()
            elif cases[i] == "test_from_layer_vectors_empty_raises": test_from_layer_vectors_empty_raises()
            elif cases[i] == "test_from_tensors": test_from_tensors()
            elif cases[i] == "test_compose_layers": test_compose_layers()
            elif cases[i] == "test_validate_ok": test_validate_ok()
            elif cases[i] == "test_validate_nan_raises": test_validate_nan_raises()
            elif cases[i] == "test_validate_shape_raises": test_validate_shape_raises()
            elif cases[i] == "test_layer_access": test_layer_access()
            elif cases[i] == "test_dominant_phase": test_dominant_phase()
            elif cases[i] == "test_transmit_tian_to_di": test_transmit_tian_to_di()
            elif cases[i] == "test_transmit_di_to_ren": test_transmit_di_to_ren()
            elif cases[i] == "test_is_passed_threshold": test_is_passed_threshold()
            elif cases[i] == "test_harmonize": test_harmonize()
            passed = passed + 1
        except e:
            failed = failed + 1
            print("[FAILED] ", cases[i], ": ", e)

    print("sancai -> passed: ", passed, " failed: ", failed)
    if failed > 0:
        raise Error("sancai tests failed")
