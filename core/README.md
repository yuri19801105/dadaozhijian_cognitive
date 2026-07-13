# core/ — 数基模块（Phase 1 公共地基）

> 万物皆数。本模块是后续所有哲学概念模块（五行/六合/七星/八卦/九宫/十方/太极…）的**公共数值地基**：统一标量、SIMD 向量原语、轻量张量、数值与激活函数。所有运算可解释、可测量、可独立测试。

## 目录结构

```
core/
├── number/           # 统一标量类型 + 精度枚举
│   ├── scalar.mojo     # Scalar=Float64, Scalar32=Float32; ZERO/ONE 常量; cast_scalar
│   ├── dtype.mojo      # PRECISION_* 精度常量 + to_dtype() 映射到 Mojo DType
│   └── __init__.mojo
├── simd/            # SIMD 向量原语（Mojo 内建 SIMD[DType.float64,N] 封装）
│   ├── vector.mojo     # Vector[size](Movable): 构造/读写/get/set/elementwise/dot/reduce/compare-mask/select/normalize/to_list
│   ├── shuffle.mojo    # gather/scatter/reverse/rotate/mask-any-all/count_true/first_true
│   └── __init__.mojo
├── tensor/          # 轻量 NDArray（本构建无 mojo.tensor, 自建）
│   ├── tensor.mojo     # Tensor: List[Float64] 数据 + List[Int] 形状/步长; 多维索引/加减/归约/行; 3x3(九宫)/6向(六合) 专用初始化
│   ├── view.mojo       # transpose_2d / slice_rows / slice_cols / broadcast_add（自由函数, 返回结果数据 List）
│   └── __init__.mojo
├── math/            # 数值与激活（本构建无 math 模块, 全自实现）
│   ├── ops.mojo        # sqrt/exp/sin/cos/log/pow/clamp/abs + sum/mean + 逐元素列表运算（数值稳定版）
│   ├── activate.mojo   # sigmoid / tanh / softmax_list（数值稳定）
│   └── __init__.mojo
├── tests/           # TDD 红-绿-重构 测试（共 78 个用例, 7 套件全绿）
│   ├── test_number.mojo / test_vector.mojo / test_shuffle.mojo
│   ├── test_tensor.mojo / test_view.mojo
│   ├── test_math_ops.mojo / test_math_activate.mojo
│   └── test_all.mojo    # 聚合器
├── benchmarks/      # 热路径基准
│   ├── bench_core.mojo
│   └── results_core.json
└── README.md
```

## 关键设计决策（Mojo 1.0.0b2 约束适配）

1. **无 `mojo.tensor`、无 `math` 模块** → 张量自建（数据存 `List[Float64]`），数值函数全自实现（牛顿法 sqrt、泰勒 exp/sin/cos、范围约简 log、稳定 softmax）。
2. **含 `List` 字段的结构不可按值移动** → `Tensor` 以本地 `var` + `mut self` 方法使用；张量间运算由调用方传入对方 `List` 分量（可移动）实现；视图/广播以**自由函数返回 `List[Float64]`** 载体，调用方按需建新 `Tensor`。
3. **`Vector[size](Movable)`** → 参数化 SIMD 封装，支持逐元素读写、按值返回、归约、`gt/lt` 掩码 + `m.select(a,b)` 混合，天然契合 SIMD。
4. **数值稳定**：`log` 限制正参数、`sqrt/pow` 限制负基；`softmax` 先减最大值防 exp 溢出；`exp` 用 `k*LN2` 范围约简避免大数爆炸。

## 运行

```bash
# 全量测试
mojo run -I core core/tests/test_all.mojo
# 单套件（如张量）
mojo run -I core core/tests/test_tensor.mojo
# 基准
mojo run -I core core/benchmarks/bench_core.mojo
```

## 验收（已实现）

| 子模块 | 用例数 | 覆盖 |
|---|---|---|
| number | 7 | 类型别名、常量、精度映射、cast |
| simd/vector | 13 | 构造/读写/elementwise/dot/reduce/argmax/mask-select/normalize/边界 |
| simd/shuffle | 10 | gather/scatter/reverse/rotate/mask-any-all/count/first/边界 |
| tensor | 12 | 形状/索引/加减/归约/行/3x3/6向/边界/形状不匹配 |
| tensor/view | 8 | 转置/切片/广播/越界/不兼容 |
| math/ops | 18 | sqrt/exp/sin/cos/log/pow/clamp/abs/sum/mean/逐元素/异常 |
| math/activate | 10 | sigmoid/tanh/softmax/归一化/稳定性/极值 |
| **合计** | **78** | **全绿, 0 warnings** |

基准（1M 次, ns/op）：向量加 6 / 张量加 9 / softmax(长8) 599 / exp 14。
