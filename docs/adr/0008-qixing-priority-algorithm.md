# ADR-0008: 七星优先级算法决策

## 状态

已采纳

## 背景

七星(QiXing)作为认知模型第 7 层的动态规划模块,需要基于六合(M6)的 6 维态势向量 + 候选算子列表,输出排序后的执行链。ADR-0004 规定六合→七星的供给关系,本 ADR 记录七星规划算法的具体决策。

## 决策

### 1. 三阶段流水线

`plan(context, candidates) → sorted_chain`

```
candidates → 剪枝 → 评分排序 → 锚定 → 输出
```

### 2. 阶段详情

| 阶段 | 函数 | 输入 | 输出 | 逻辑 |
|------|------|------|------|------|
| 剪枝 | `_prune` | candidates + `north`(max_depth) | filtered | `abstract_level(t) ≤ max_depth` |
| 排序 | bubble sort by `_score` | pruned list + `south`/`west` | 降序列表 | `score = south - west + abstract_level(t)` |
| 锚定 | bubble tiebreaker | 排序后列表 + 等同分项 | 重排后列表 | 同分时 `abstract_level` 高的先执行 |

### 3. 优先级评分函数

```text
score(context, trigram) = south(焦点强度) - west(已消耗) + abstract_level(trigram)
```

分值越高越先执行。`south - west` 表达"当前焦点越强、已消耗越少 → 优先级越高"的动态平衡。

### 4. abstract_level 映射

| 算子 | 层级 | 理由 |
|------|------|------|
| 乾/坤 | 5 | 创造/承载——最抽象 |
| 离/坎 | 3 | 明辨/冒险——中间层 |
| 震/巽 | 2 | 启动/渗透——接近执行 |
| 艮/兑 | 1 | 停止/交流——最具体 |

### 5. 输出类型

`List[Int]` — trigram id 的有序序列,长度 ≤ 输入候选长度

## 不变量

- 输出长度 ≤ 输入长度
- 不含 `abstract_level > max_depth` 的算子
- 排序单调(非增 score)

## 影响

- 七星完成后,M6→M7 的供给关系(ADR-0004)首次完整实现
- 下接十方(M10)的执行层可消费 `planned_chain` 直接驱动
- 无新增源文件依赖

## 性能基准

| 场景 | 1M 次耗时 | 单次 |
|------|----------|------|
| plan(4 候选,全流水线) | ~270ms | **~270ns** |

> 勘误(2026-07-10): 原记 280ns 系早期估值,实测稳定区间 259–279ns(中位 ~270ns),已校准。证据落盘 `benchmarks/results_qixing.json`。

远低于 1µs 目标,规划不是瓶颈。