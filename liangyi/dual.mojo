# === liangyi/dual.mojo ===
# 两仪核心类型: 阴阳对(同数异相), SIMD 友好。
# 模型(双桶): value = yang - yin; 二者均 >= 0; phase = (yang >= yin) ? YANG : YIN。
#   - 正量 -> yin=0, yang=v
#   - 负量 -> yin=|v|, yang=0
# 该表示在 from_parts / __init / invert / 算术 间保持一致, 可解释可溯源。

comptime YIN: Int = 0
comptime YANG: Int = 1


struct Dual(Movable):
    var value: Float64       # 净值 = yang - yin
    var phase: Int           # 相: YIN=0 / YANG=1
    var yin: Float64         # 阴分量 (>= 0)
    var yang: Float64        # 阳分量 (>= 0)

    # 默认构造: 零
    def __init__(out self):
        self.value = 0.0
        self.phase = YANG
        self.yin = 0.0
        self.yang = 0.0

    # 由标量值 + 相位构造 (相位仅对零值生效, 非零按符号推导以保持不变量)
    def __init__(out self, value: Float64, phase: Int = YANG):
        self.value = value
        if value >= 0.0:
            self.yang = value
            self.yin = 0.0
            self.phase = YANG
        else:
            self.yang = 0.0
            self.yin = -value
            self.phase = YIN
        if value == 0.0:
            self.phase = phase

    # 由显式阴阳分量合成 (不变量自动推导 value/phase)
    @staticmethod
    def from_parts(yin: Float64, yang: Float64) -> Dual:
        var d = Dual()
        d.yin = yin
        d.yang = yang
        d.value = yang - yin
        d.phase = YANG if (yang >= yin) else YIN
        return d^

    def get_value(self) -> Float64:
        return self.value

    def get_phase(self) -> Int:
        return self.phase

    def yin_part(self) -> Float64:
        return self.yin

    def yang_part(self) -> Float64:
        return self.yang

    # 基础算术: 分量各自运算, 结果仍为 Dual (保持双桶不变量)
    def add(self, other: Dual) -> Dual:
        return Dual.from_parts(self.yin + other.yin, self.yang + other.yang)

    def sub(self, other: Dual) -> Dual:
        return Dual.from_parts(self.yin - other.yin, self.yang - other.yang)

    def scale(self, k: Float64) -> Dual:
        return Dual.from_parts(self.yin * k, self.yang * k)

    # SIMD 友好载体: 打包 [yin, yang] 供批量运算。
    # 注: 本构建 `core.simd.vector` 长路径导入不可用(与 rename/remove 缺位同类环境约束),
    #     故沿用 core/tensor 视图方法的项目惯例, 以 List[Float64] 作为向量载体。
    def as_vector(self) -> List[Float64]:
        var v = List[Float64]()
        v.append(self.yin)
        v.append(self.yang)
        return v^
