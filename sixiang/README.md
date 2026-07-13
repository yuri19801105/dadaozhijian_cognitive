# `sixiang/` — 四象（四态 / 四象限）【v0.6 已落地 ✅】

> **实现状态（2026-07-11，零桩函数 TDD 全绿）**：`sixiang/quadrant.mojo` ✅（`Quadrant` 单象限载体 + `QuadrantClassifier` 判别/幅度/典型构造/降级）+ `sixiang/phase.mojo` ✅（`PhaseMachine` 四相流转状态机，调用 `Polarity.classify/invert/compose` 与 `YinYangGate.dual_gate`）。详见 `docs/architecture-modular-plan.md` §4.4 / §4.4.1。

**职责**：四态（老少阴阳）或时空四象限，用于调度窗口 / 相位象限的离散化。由两仪 `Dual` 派生，是 liangyi 在算子层的第二个落地消费者。

```
sixiang/
├── quadrant.mojo          # 四象限类型与索引(Quadrant / QuadrantClassifier)
├── phase.mojo             # 四相状态机(老少阴阳流转)
├── tests/  benchmarks/
└── README.md
```

**依赖**：`core`、`liangyi`。

## 经典映射（对 liangyi 的调用契约）
- 老阴 `OLD_YIN`(0)：纯阴 → `Dual(yin=m, yang=0)`
- 少阳 `YOUNG_YANG`(1)：阳生 → `yang > yin`（阳占优）
- 老阳 `OLD_YANG`(2)：纯阳 → `Dual(yang=m, yin=0)`
- 少阴 `YOUNG_YIN`(3)：阴生 → `yin > yang`（阴占优）

流转顺序（老少阴阳循环）：**老阴 → 少阳 → 老阳 → 少阴 → 老阴**。

## I/O 规范
- 输入：一个 `Dual`（当前阴阳态）。
- 输出：`Quadrant { index: Int(0..3), symbol: Dual }`；名称由 `Quadrant.name()` / `phase_name(index)` 派生（因 Mojo 1.0.0b2 中 `String` 字段使 struct 不可 Movable，名称不落字段）。
- 确定性：纯函数派生，无随机。

## 错误处理
- `raises`：`NaN`、`平衡态(阴==阳)`、`Polarity.classify` 非收敛 → 抛 `Error`。
- 降级：`from_dual` 对未知/非法输入映射中性象限（太极近似）并保留原符号，不静默丢弃。

## 验证
`tests/test_sixiang.mojo` 覆盖判别/幅度/典型构造往返/相位名/降级/四步循环/`dual_gate` 门控，全绿。
