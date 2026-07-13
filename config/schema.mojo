# === config/schema.mojo ===
# 配置字段规格与默认值（配置外置化的单一事实源，见 §4.16 / §6#4 / §8#4）。
#
# 设计约束（Mojo 1.0.0b2 已验证）：
#   - 无 std.toml 解析器 → 扁平 "key = value"（井号注释）最小 grammar 解析（见 config.mojo）。
#   - FieldSpec(String 字段) 非 Movable → 不能进 List/Dict；故以索引函数返回字面量，
#     String 可按值返回（to_toml()->String 已验证编译通过），数值元数据为 Int/Float64（Movable）。
#   - 字段顺序即 to_toml 输出顺序，与 defaults.toml 一致。
#
# 字段表（id: name / kind / default / min / max / bounded）
#   0  max_depth            int    10     1     200   1
#   1  rule_count           int    5      0     1000  1
#   2  scheduler_policy_id  int    0     -1     31    1
#   3  intensity_floor      int    1      1     9     1
#   4  keep_rate            float  0.7    0.1   1.0   1
#   5  forget_rate          float  0.1    0.0   0.9   1
#   6  connector_timeout_ms int    2000   50    60000 1
#   7  connector_retry      int    2      0     10    1
#   8  llm_api_key          str    ""     0     0     0
#   9  backfill_budget_ms   int    20     1     1000  1
#   10 backfill_min_samples int    4      1     100   1
#   11 health_fail_threshold int   5      1     100   1

def field_count() -> Int:
    return 12


def field_name(id: Int) -> String:
    if id == 0: return "max_depth"
    elif id == 1: return "rule_count"
    elif id == 2: return "scheduler_policy_id"
    elif id == 3: return "intensity_floor"
    elif id == 4: return "keep_rate"
    elif id == 5: return "forget_rate"
    elif id == 6: return "connector_timeout_ms"
    elif id == 7: return "connector_retry"
    elif id == 8: return "llm_api_key"
    elif id == 9: return "backfill_budget_ms"
    elif id == 10: return "backfill_min_samples"
    elif id == 11: return "health_fail_threshold"
    return ""


def field_default(id: Int) -> String:
    if id == 0: return "10"
    elif id == 1: return "5"
    elif id == 2: return "0"
    elif id == 3: return "1"
    elif id == 4: return "0.7"
    elif id == 5: return "0.1"
    elif id == 6: return "2000"
    elif id == 7: return "2"
    elif id == 8: return ""
    elif id == 9: return "20"
    elif id == 10: return "4"
    elif id == 11: return "5"
    return ""


def field_kind(id: Int) -> Int:   # 0=Int, 1=Float64, 2=String
    if id == 4 or id == 5:
        return 1
    elif id == 8:
        return 2
    return 0


def field_min(id: Int) -> Float64:
    if id == 0: return 1.0
    elif id == 1: return 0.0
    elif id == 2: return -1.0
    elif id == 3: return 1.0
    elif id == 4: return 0.1
    elif id == 5: return 0.0
    elif id == 6: return 50.0
    elif id == 7: return 0.0
    elif id == 9: return 1.0
    elif id == 10: return 1.0
    elif id == 11: return 1.0
    return 0.0


def field_max(id: Int) -> Float64:
    if id == 0: return 200.0
    elif id == 1: return 1000.0
    elif id == 2: return 31.0
    elif id == 3: return 9.0
    elif id == 4: return 1.0
    elif id == 5: return 0.9
    elif id == 6: return 60000.0
    elif id == 7: return 10.0
    elif id == 9: return 1000.0
    elif id == 10: return 100.0
    elif id == 11: return 100.0
    return 0.0


def field_bounded(id: Int) -> Int:   # 1=启用数值边界校验, 0=不限制
    if id == 8:
        return 0
    return 1


# 默认配置文本（与 defaults.toml 内容一致；作为文件缺失/缺键时的回退）。
def default_config_string() -> String:
    var s = String()
    s += "# 大道至简 · 全局默认配置（外置化, 不进代码）\n"
    s += "max_depth = 10\n"
    s += "rule_count = 5\n"
    s += "scheduler_policy_id = 0\n"
    s += "intensity_floor = 1\n"
    s += "keep_rate = 0.7\n"
    s += "forget_rate = 0.1\n"
    s += "connector_timeout_ms = 2000\n"
    s += "connector_retry = 2\n"
    s += "llm_api_key = \"\"\n"
    s += "backfill_budget_ms = 20\n"
    s += "backfill_min_samples = 4\n"
    s += "health_fail_threshold = 5\n"
    return s^
