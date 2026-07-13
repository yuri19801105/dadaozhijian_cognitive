# sancai · 三才（天地人分层接口）

三才是认知的一次纵向切片：**天(输入/上下文) · 地(状态/根基) · 人(行为/主体)** 三层，各以 `Dual` 表阴阳属性，是 `liangyi`（阴阳原语）在算子层的首个派生消费者。

## 职责

- 把一次认知拆为三层，提供层间接口契约与门控放行。
- 三层语义（阴阳同数异相，见 `liangyi`）：
  - **天 Tian**：输入/上下文的 **显隐**（yang=显 / yin=隐）。
  - **地 Di**：状态/根基的 **动静**（yang=动 / yin=静）。
  - **人 Ren**：行为主体的 **有无**（yang=有 / yin=無）。

## 目录结构

```
sancai/
├── layers.mojo            # SanCai 三层结构(Dual×3 + payload Tensor) + 构造/校验/取层/主导相
├── interface.mojo         # LayerMessage 层间消息 + LayerBus 传递/门控/调和
├── __init__.mojo          # 聚合导出: from sancai import SanCai, LayerMessage, LayerBus
├── tests/test_sancai.mojo # 14 用例(RED→GREEN, 零桩函数)
├── benchmarks/bench_sancai.mojo
└── README.md
```

## 接口（详见规划 §4.3.1）

- `SanCai`：`__init__`(中性) / `from_layer_vectors(List×3)` / `from_tensors(Tensor×3)` / `compose_layers(Dual×3 + payload)` / `validate()` / `layer(idx)` / `dominant_phase()`。
  - `payload: Tensor`（shape `[3,3]`）：每层一行，映射 `jiugong` 三行（`r=0 天 / r=1 地 / r=2 人`）。
- `LayerMessage(Movable)`：层间消息载体（`source / target / content:Dual / gate:Float64`）。
- `LayerBus`：`transmit` / `pass_tian_to_di` / `pass_di_to_ren`（调用 `Polarity.compose` + `YinYangGate.balance_gate`）/ `is_passed(gate>=0.5)` / `harmonize(sc)`（地由天·人调和，同步 payload 中间行）。

## 依赖与调用契约

- 仅依赖 `core`（`tensor` / `math`）与 `liangyi`（阴阳原语）——不重新实现阴阳表示。
- 导入根：`core/` 无 `__init__.mojo`，故以 `-I core` + `from tensor.tensor` / `from math.ops` 短路径导入；项目包以 `-I .` + `from sancai` 导入。

## 运行测试

```bash
.venv/bin/mojo run -I . -I core sancai/tests/test_sancai.mojo
```

## 实现要点（Mojo 1.0.0b2）

- `Dual` 参数 = 不可隐式复制的借入：字段落值用 `Dual.from_parts(d.yin_part(), d.yang_part())` 重构（同源不变）或移动自有局部（`^`）。
- `Tensor` 非 Movable：不可按值返回；字段初始化 `self.payload = Tensor(); self.payload.init([3,3])`；外部张量经 `to_list()/shape()` 以 `List` 透传 `from_list`。
