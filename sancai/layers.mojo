# === sancai/layers.mojo ===
# 三才核心结构: 天(输入/上下文)·地(状态/根基)·人(行为/主体) 三层, 各以 Dual 表阴阳属性。
# 模型:
#   天 Tian  : 输入/上下文的显隐 (yang=显, yin=隐)
#   地 Di    : 状态/根基的动静 (yang=动, yin=静)
#   人 Ren   : 行为主体的有无 (yang=有, yin=無)
# 每层由一条向量(或张量)的均值派生为 Dual; payload = [3, 3] 张量(每层一行, 映射 jiugong 3 行)。
# SanCai 含 Tensor(payload) → 非 Movable, 一律以 mut self 就地构造/改写, 不按值返回。

from liangyi.dual import Dual, YIN, YANG
from liangyi.polarity import Polarity
from liangyi.activation import YinYangGate
from tensor.tensor import Tensor
from math.ops import mean_list, abs_f64

comptime TIAN: Int = 0
comptime DI: Int = 1
comptime REN: Int = 2
comptime LAYER_COUNT: Int = 3


# NaN 检测(本构建无 math.isnan, 用 v != v 判定)
def _is_nan(v: Float64) -> Bool:
    return v != v


struct SanCai:
    var tian: Dual
    var di: Dual
    var ren: Dual
    var payload: Tensor

    # 中性构造: 三层 Dual(0) + payload 3x3 全零
    def __init__(out self) raises:
        self.tian = Dual(0.0)
        self.di = Dual(0.0)
        self.ren = Dual(0.0)
        self.payload = Tensor()
        self.payload.init([3, 3])

    # 由三层向量(各 List[Float64]) 派生: 每层激活 = mean(vec) -> Dual; payload = [3,3](每层取前 3, 不足补 0)
    def from_layer_vectors(mut self, tian: List[Float64], di: List[Float64], ren: List[Float64]) raises:
        if len(tian) == 0 or len(di) == 0 or len(ren) == 0:
            raise Error("sancai: each layer vector must be non-empty")
        self.tian = Dual(mean_list(tian))
        self.di = Dual(mean_list(di))
        self.ren = Dual(mean_list(ren))
        var data = List[Float64]()
        for i in range(3):
            if i < len(tian): data.append(tian[i])
            else: data.append(0.0)
        for i in range(3):
            if i < len(di): data.append(di[i])
            else: data.append(0.0)
        for i in range(3):
            if i < len(ren): data.append(ren[i])
            else: data.append(0.0)
        var sh = List[Int]()
        sh.append(3)
        sh.append(3)
        self.payload.from_list(data, sh)

    # 由三层张量派生(逐张量 to_list 后同 from_layer_vectors)
    def from_tensors(mut self, tian: Tensor, di: Tensor, ren: Tensor) raises:
        self.from_layer_vectors(tian.to_list(), di.to_list(), ren.to_list())

    # 由显式 Dual + 给定 payload 组装(拷贝 payload 进 self.payload)
    # 注: Dual 参数在本构建为不可隐式复制的借入, 字段赋值须以 from_parts 重构(同源不变)
    def compose_layers(mut self, tian: Dual, di: Dual, ren: Dual, payload: Tensor) raises:
        self.tian = Dual.from_parts(tian.yin_part(), tian.yang_part())
        self.di = Dual.from_parts(di.yin_part(), di.yang_part())
        self.ren = Dual.from_parts(ren.yin_part(), ren.yang_part())
        self.payload.from_list(payload.to_list(), payload.shape())

    # 校验: 三层无 NaN, payload 首维 == 3
    def validate(self) raises:
        if _is_nan(self.tian.yin_part()) or _is_nan(self.tian.yang_part()):
            raise Error("sancai: tian Dual contains NaN")
        if _is_nan(self.di.yin_part()) or _is_nan(self.di.yang_part()):
            raise Error("sancai: di Dual contains NaN")
        if _is_nan(self.ren.yin_part()) or _is_nan(self.ren.yang_part()):
            raise Error("sancai: ren Dual contains NaN")
        var sh = self.payload.shape()
        if len(sh) == 0 or sh[0] != LAYER_COUNT:
            raise Error("sancai: payload first dim must be 3")

    # 取某层 Dual (idx: 0=天 / 1=地 / 2=人)
    def layer(self, idx: Int) raises -> Dual:
        if idx < 0 or idx >= LAYER_COUNT:
            raise Error("sancai: layer index out of range [0,2]")
        if idx == TIAN: return Dual.from_parts(self.tian.yin_part(), self.tian.yang_part())
        if idx == DI: return Dual.from_parts(self.di.yin_part(), self.di.yang_part())
        return Dual.from_parts(self.ren.yin_part(), self.ren.yang_part())

    # 主导层(绝对值最大的层)的相位, 用于Recall 偏置
    def dominant_phase(self) -> Int:
        var vt = abs_f64(self.tian.get_value())
        var vd = abs_f64(self.di.get_value())
        var vr = abs_f64(self.ren.get_value())
        if vd >= vt and vd >= vr:
            return self.di.get_phase()
        if vr >= vt and vr >= vd:
            return self.ren.get_phase()
        return self.tian.get_phase()
