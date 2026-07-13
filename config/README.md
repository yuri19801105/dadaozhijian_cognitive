# `config/` — 外置化配置（schema 驱动 + 校验 + 最小 TOML 解析）【v1.5 已落地 ✅】

> 解锁 `docs/architecture-modular-plan.md` §6#4 / §8#4「配置外置」硬要求：运维改 `defaults.toml` 即可调整阈值/策略，**免重编译**。

## 一、设计约束（Mojo 1.0.0b2 已验证）
- **无 std.toml 解析器** → 以扁平 `key = value`（井号 `#` 注释）最小 grammar 解析（见 `config.mojo` 的 `_parse_kv`）。字符串值支持 `key = "..."` 双引号包裹（ASCII 安全去引号）。
- **`FieldSpec`（含 `String`）非 Movable** → 不能进 `List`/`Dict`；故 schema 以**索引函数**（`field_name`/`field_default`/`field_kind`/`field_min`/`field_max`/`field_bounded`）返回字面量，`String` 可按值返回，`Int`/`Float64` 为 Movable。
- **`Dict` 非 Movable** → `Config` 不可按值返回；`from_str`/`from_toml` 用 `mut` 参数（同 `TaijiState` 惯例）原地填充。

## 二、模块构成
| 文件 | 职责 |
|---|---|
| `schema.mojo` | 字段规格单一事实源：`field_count()` + 12 个索引访问器 + `default_config_string()` |
| `config.mojo` | `Config` 结构体（扁平 `Dict[String,String]` 存储）+ 类型化访问器（`get_int`/`get_float`/`get_str`）+ `validate()` 边界复查 + `to_toml()` round-trip + `from_str`/`from_toml`（mut 参数加载器） |
| `defaults.toml` | 默认配置（不进代码，可运维直改） |
| `tests/test_config.mojo` | TDD 套件（8 断言） |
| `__init__.mojo` | 聚合导出 |

### 配置字段（id: name / 类型 / 默认 / 边界）
```
0  max_depth            int    10      [1,200]
1  rule_count           int    5       [0,1000]
2  scheduler_policy_id  int    0       [-1,31]
3  intensity_floor      int    1       [1,9]
4  keep_rate            float  0.7     [0.1,1.0]
5  forget_rate          float  0.1     [0.0,0.9]
6  connector_timeout_ms int    2000    [50,60000]
7  connector_retry      int    2       [0,10]
8  llm_api_key          str    ""      (无界)
9  backfill_budget_ms   int    20      [1,1000]
10 backfill_min_samples int    4       [1,100]
11 health_fail_threshold int   5       [1,100]
```

## 三、API 速查
```mojo
from config import Config, from_str, from_toml

var c = Config()                 # 载入 schema 默认值（亦可 from default_config_string()）
from_str(c, "max_depth = 50\nkeep_rate = 0.5\n")   # 缺键保留默认；越界 raise
from_toml(c, "defaults.toml")    # 文件缺失/读取失败 → raise
c.validate()                     # 按 schema 边界复查当前值
_ = c.get_int("max_depth")       # 未知键 → raise
_ = c.get_str("llm_api_key")
var s = c.to_toml()              # 序列化回 TOML（round-trip）
```

## 四、实现状态（v1.5 · 零桩函数 TDD 全绿）
**8 断言全绿**（defaults / from_str 覆盖 / 注释忽略 / 越界校验 raise / round-trip / validate / 文件加载 / 缺文件 raise）。无生产代码改动时不影响既有 543 断言回归。详见 `docs/architecture-modular-plan.md` §4.16。
