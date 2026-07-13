# === bagua/tests/test_bagua.mojo ===
# 八卦算子集 TDD 测试套件（红→绿→重构）。运行: mojo run -I . -I core bagua/tests/test_bagua.mojo
# 覆盖: 8 卦定义 / 爻线往返 / 符号映射与降级 / sancai 派生 / 8 算子变换与激活 / 重卦组合 / essence / 推理链。

from bagua.trigrams import (
    Trigram, QIAN, KUN, ZHEN, XUN, KAN, LI, GEN, DUI, TRIGRAM_COUNT, NEUTRAL_ID,
    trigram_name, trigram_code, trigram_by_id, trigram_by_code,
    trigram_from_lines, trigram_from_symbol, trigram_from_symbol_safe, trigram_from_sancai,
)
from bagua.operators import TrigramOperatorResult, apply, apply_by_id, apply_chain
from bagua.combine import Hexagram, combine

from liangyi.dual import Dual, YIN, YANG
from liangyi.polarity import Polarity
from math.activate import sigmoid
from sancai.layers import SanCai
from tensor.tensor import Tensor


def _approx(a: Float64, b: Float64, eps: Float64) -> Bool:
    var d = a - b
    if d < 0: d = -d
    return d <= eps


# ---------- 1. 8 卦 by_id / 名称 / code ----------
def test_trigram_by_id() raises:
    var expect_names = ["乾", "坤", "震", "巽", "坎", "离", "艮", "兑"]
    var expect_codes = [7, 0, 1, 6, 2, 5, 4, 3]
    for i in range(TRIGRAM_COUNT):
        var t = trigram_by_id(i)
        if t.id != i: raise Error("by_id id mismatch")
        if t.name() != expect_names[i]: raise Error("by_id name mismatch: " + String(i))
        if t.code() != expect_codes[i]: raise Error("by_id code mismatch")


# ---------- 2. by_id 越界 raises ----------
def test_trigram_by_id_oob() raises:
    var raised = False
    try:
        _ = trigram_by_id(8)
    except:
        raised = True
    if not raised: raise Error("by_id(8) should raise")


# ---------- 3. by_code 往返 ----------
def test_trigram_by_code() raises:
    for c in range(8):
        var t = trigram_by_code(c)
        if t.code() != c: raise Error("by_code roundtrip fail")
    var raised = False
    try:
        _ = trigram_by_code(8)
    except:
        raised = True
    if not raised: raise Error("by_code(8) should raise")


# ---------- 4. lines() 往返 (每条爻线相位正确) ----------
def test_trigram_lines_roundtrip() raises:
    for i in range(TRIGRAM_COUNT):
        var t = trigram_by_id(i)
        var ls = t.lines()
        if len(ls) != 3: raise Error("lines len != 3")
        var back = trigram_from_lines(ls)
        if back.id != i: raise Error("lines roundtrip id mismatch: " + String(i))


# ---------- 5. trigram_from_lines 错误路径 ----------
def test_trigram_from_lines_errors() raises:
    # 数量错
    var raised = False
    try:
        _ = trigram_from_lines(List[Dual]())
    except:
        raised = True
    if not raised: raise Error("empty lines should raise")
    # 非法相位
    raised = False
    try:
        var bad = List[Dual]()
        bad.append(Dual(0.0, YANG))
        bad.append(Dual(0.0, YANG))
        bad.append(Dual(1.0))  # phase 默认 YANG, 但 value!=0 -> 仍 YANG, 合法; 改用 NaN 相位不可得
        # 直接构造一个相位既非 YIN 也非 YANG 的 Dual 不可(phase 仅两态), 故改用数量错已覆盖; 这里放一个合法三线确保不误报
        _ = trigram_from_lines(bad)
    except:
        raised = True
    if raised: raise Error("valid 3 lines should NOT raise")


# ---------- 6. 符号映射 (中文/英文/自然物) ----------
def test_trigram_from_symbol() raises:
    if trigram_from_symbol("乾").id != QIAN: raise Error("乾->QIAN")
    if trigram_from_symbol("qian").id != QIAN: raise Error("qian->QIAN")
    if trigram_from_symbol("天").id != QIAN: raise Error("天->QIAN")
    if trigram_from_symbol("坤").id != KUN: raise Error("坤->KUN")
    if trigram_from_symbol("地").id != KUN: raise Error("地->KUN")
    if trigram_from_symbol("震").id != ZHEN: raise Error("震->ZHEN")
    if trigram_from_symbol("雷").id != ZHEN: raise Error("雷->ZHEN")
    if trigram_from_symbol("巽").id != XUN: raise Error("巽->XUN")
    if trigram_from_symbol("风").id != XUN: raise Error("风->XUN")
    if trigram_from_symbol("坎").id != KAN: raise Error("坎->KAN")
    if trigram_from_symbol("水").id != KAN: raise Error("水->KAN")
    if trigram_from_symbol("离").id != LI: raise Error("离->LI")
    if trigram_from_symbol("火").id != LI: raise Error("火->LI")
    if trigram_from_symbol("艮").id != GEN: raise Error("艮->GEN")
    if trigram_from_symbol("山").id != GEN: raise Error("山->GEN")
    if trigram_from_symbol("兑").id != DUI: raise Error("兑->DUI")
    if trigram_from_symbol("泽").id != DUI: raise Error("泽->DUI")


# ---------- 7. 未知符号 raises ----------
def test_trigram_from_symbol_unknown() raises:
    var raised = False
    try:
        _ = trigram_from_symbol("不存在")
    except:
        raised = True
    if not raised: raise Error("unknown symbol should raise")


# ---------- 8. 未知符号降级 (不静默丢弃) ----------
def test_trigram_from_symbol_safe() raises:
    var t = trigram_from_symbol_safe("不存在之符号")
    if t.id != NEUTRAL_ID: raise Error("safe unknown should degrade to NEUTRAL_ID")
    # 已知符号正常
    if trigram_from_symbol_safe("乾").id != QIAN: raise Error("safe known should map")


# ---------- 9. sancai 派生卦象 ----------
def test_trigram_from_sancai() raises:
    # 全阳 -> 乾
    var sc_all_yang = SanCai()
    var p1 = Tensor(); p1.init([3,3])
    sc_all_yang.compose_layers(Dual(3.0), Dual(3.0), Dual(3.0), p1)
    if trigram_from_sancai(sc_all_yang).id != QIAN: raise Error("all-yang -> QIAN")
    # 全阴 -> 坤
    var sc_all_yin = SanCai()
    var p2 = Tensor(); p2.init([3,3])
    sc_all_yin.compose_layers(Dual(-3.0), Dual(-3.0), Dual(-3.0), p2)
    if trigram_from_sancai(sc_all_yin).id != KUN: raise Error("all-yin -> KUN")
    # 天阳/地阴/人阳 -> 顶阳中阴底阳 = 离(5)
    var sc_mix = SanCai()
    var p3 = Tensor(); p3.init([3,3])
    sc_mix.compose_layers(Dual(2.0), Dual(-2.0), Dual(2.0), p3)
    if trigram_from_sancai(sc_mix).id != LI: raise Error("tian-yang/di-yin/ren-yang -> LI")


# ---------- 10. sancai 含 NaN -> raises ----------
def test_trigram_from_sancai_nan() raises:
    var sc = SanCai()
    var p = Tensor(); p.init([3,3])
    var nan_d = Dual.from_parts(Float64(0.0) / Float64(0.0), 0.0)  # 0/0 = NaN
    sc.compose_layers(nan_d, Dual(1.0), Dual(1.0), p)
    var raised = False
    try:
        _ = trigram_from_sancai(sc)
    except:
        raised = True
    if not raised: raise Error("NaN layer should raise")


# ---------- 11. essence: 乾=纯阳(value 1), 坤=纯阴(value -1) ----------
def test_trigram_essence() raises:
    if not _approx(trigram_by_id(QIAN).essence().get_value(), 1.0, 1e-9): raise Error("QIAN essence value 1")
    if not _approx(trigram_by_id(KUN).essence().get_value(), -1.0, 1e-9): raise Error("KUN essence value -1")
    # 震 essence = -0.5 (见设计)
    if not _approx(trigram_by_id(ZHEN).essence().get_value(), -0.5, 1e-9): raise Error("ZHEN essence -0.5")


# ---------- 12. 8 算子: 输入 Dual(2.0) 的变换与激活 ----------
def test_operators_positive() raises:
    var x = Dual(2.0)
    var r = apply(trigram_by_id(QIAN), x)
    if r.trigram != QIAN: raise Error("QIAN trigram field")
    if r.code != 7: raise Error("QIAN code field")
    if not _approx(r.transformed.get_value(), 4.0, 1e-9): raise Error("QIAN scale2 -> 4")
    # 激活门
    if not _approx(r.activation.yin, sigmoid(0.0 - x.yin_part()), 1e-6): raise Error("QIAN yin gate")
    if not _approx(r.activation.yang, sigmoid(x.yang_part() - 0.0), 1e-6): raise Error("QIAN yang gate")

    if not _approx(apply(trigram_by_id(KUN), x).transformed.get_value(), 1.0, 1e-9): raise Error("KUN scale0.5 -> 1")
    if not _approx(apply(trigram_by_id(ZHEN), x).transformed.get_value(), 3.0, 1e-9): raise Error("ZHEN +1 yang -> 3")
    if not _approx(apply(trigram_by_id(XUN), x).transformed.get_value(), 0.0, 1e-9): raise Error("XUN reconcile -> 0")
    if not _approx(apply(trigram_by_id(KAN), x).transformed.get_value(), 3.0, 1e-9): raise Error("KAN tilt -> 3")
    if not _approx(apply(trigram_by_id(LI), x).transformed.get_value(), 4.0, 1e-9): raise Error("LI sharpen -> 4")
    if not _approx(apply(trigram_by_id(GEN), x).transformed.get_value(), 0.0, 1e-9): raise Error("GEN stop -> 0")
    if not _approx(apply(trigram_by_id(DUI), x).transformed.get_value(), 0.0, 1e-9): raise Error("DUI exchange -> 0")


# ---------- 13. 8 算子: 输入 Dual(-2.0) 的变换 ----------
def test_operators_negative() raises:
    var x = Dual(-2.0)
    if not _approx(apply(trigram_by_id(QIAN), x).transformed.get_value(), -4.0, 1e-9): raise Error("QIAN neg -4")
    if not _approx(apply(trigram_by_id(KUN), x).transformed.get_value(), -1.0, 1e-9): raise Error("KUN neg -1")
    if not _approx(apply(trigram_by_id(ZHEN), x).transformed.get_value(), -1.0, 1e-9): raise Error("ZHEN neg -1")
    if not _approx(apply(trigram_by_id(XUN), x).transformed.get_value(), 0.0, 1e-9): raise Error("XUN neg 0")
    if not _approx(apply(trigram_by_id(KAN), x).transformed.get_value(), -1.0, 1e-9): raise Error("KAN neg -1")
    if not _approx(apply(trigram_by_id(LI), x).transformed.get_value(), -4.0, 1e-9): raise Error("LI neg -4")
    if not _approx(apply(trigram_by_id(GEN), x).transformed.get_value(), 0.0, 1e-9): raise Error("GEN neg 0")
    if not _approx(apply(trigram_by_id(DUI), x).transformed.get_value(), 0.0, 1e-9): raise Error("DUI neg 0")


# ---------- 14. apply_by_id 与越界 raises ----------
def test_apply_by_id() raises:
    var r = apply_by_id(QIAN, Dual(2.0))
    if r.trigram != QIAN: raise Error("apply_by_id QIAN")
    var raised = False
    try:
        _ = apply_by_id(99, Dual(1.0))
    except:
        raised = True
    if not raised: raise Error("apply_by_id(99) should raise")


# ---------- 15. 平衡输入 Dual(0) 的激活 ----------
def test_operator_balanced() raises:
    var x = Dual(0.0)
    var r = apply(trigram_by_id(LI), x)
    if not _approx(r.activation.yin, 0.5, 1e-6): raise Error("balanced yin gate 0.5")
    if not _approx(r.activation.yang, 0.5, 1e-6): raise Error("balanced yang gate 0.5")


# ---------- 16. combine 重卦 (64) ----------
def test_combine() raises:
    var qk = combine(trigram_by_id(QIAN), trigram_by_id(KUN))
    if qk.lower != QIAN: raise Error("combine lower QIAN")
    if qk.upper != KUN: raise Error("combine upper KUN")
    if qk.code != 7: raise Error("combine code 7 (lower7+upper0*8)")
    if qk.name() != "乾坤": raise Error("combine name 乾坤")
    # essence = compose(乾essence(0,1), 坤essence(1,0), 0.5) -> (0.5,0.5) value 0
    if not _approx(qk.essence.get_value(), 0.0, 1e-9): raise Error("combine essence 0")

    var kq = combine(trigram_by_id(KUN), trigram_by_id(QIAN))
    if kq.code != 56: raise Error("combine code 56 (lower0+upper7*8)")


# ---------- 17. 推理链 apply_chain ----------
def test_apply_chain() raises:
    var chain = List[Trigram]()
    chain.append(trigram_by_id(QIAN))
    chain.append(trigram_by_id(GEN))
    chain.append(trigram_by_id(DUI))
    var results = apply_chain(chain, Dual(4.0))
    if len(results) != 3: raise Error("chain len 3")
    if results[0].trigram != QIAN: raise Error("chain[0] QIAN")
    if results[1].trigram != GEN: raise Error("chain[1] GEN")
    if results[2].trigram != DUI: raise Error("chain[2] DUI")
    # 第一步 QIAN scale2 -> 8
    if not _approx(results[0].transformed.get_value(), 8.0, 1e-9): raise Error("chain QIAN -> 8")


# ---------- 测试运行器 ----------
def main():
    var passed = 0
    var failed = 0
    var suite = List[String]()
    suite.append("trigram_by_id")
    suite.append("trigram_by_id_oob")
    suite.append("trigram_by_code")
    suite.append("trigram_lines_roundtrip")
    suite.append("trigram_from_lines_errors")
    suite.append("trigram_from_symbol")
    suite.append("trigram_from_symbol_unknown")
    suite.append("trigram_from_symbol_safe")
    suite.append("trigram_from_sancai")
    suite.append("trigram_from_sancai_nan")
    suite.append("trigram_essence")
    suite.append("operators_positive")
    suite.append("operators_negative")
    suite.append("apply_by_id")
    suite.append("operator_balanced")
    suite.append("combine")
    suite.append("apply_chain")

    for i in range(len(suite)):
        try:
            if suite[i] == "trigram_by_id": test_trigram_by_id()
            elif suite[i] == "trigram_by_id_oob": test_trigram_by_id_oob()
            elif suite[i] == "trigram_by_code": test_trigram_by_code()
            elif suite[i] == "trigram_lines_roundtrip": test_trigram_lines_roundtrip()
            elif suite[i] == "trigram_from_lines_errors": test_trigram_from_lines_errors()
            elif suite[i] == "trigram_from_symbol": test_trigram_from_symbol()
            elif suite[i] == "trigram_from_symbol_unknown": test_trigram_from_symbol_unknown()
            elif suite[i] == "trigram_from_symbol_safe": test_trigram_from_symbol_safe()
            elif suite[i] == "trigram_from_sancai": test_trigram_from_sancai()
            elif suite[i] == "trigram_from_sancai_nan": test_trigram_from_sancai_nan()
            elif suite[i] == "trigram_essence": test_trigram_essence()
            elif suite[i] == "operators_positive": test_operators_positive()
            elif suite[i] == "operators_negative": test_operators_negative()
            elif suite[i] == "apply_by_id": test_apply_by_id()
            elif suite[i] == "operator_balanced": test_operator_balanced()
            elif suite[i] == "combine": test_combine()
            elif suite[i] == "apply_chain": test_apply_chain()
            passed += 1
        except e:
            failed += 1
            print("FAILED: " + suite[i] + " -> " + String(e))

    print("bagua -> passed: " + String(passed) + "  failed: " + String(failed))
