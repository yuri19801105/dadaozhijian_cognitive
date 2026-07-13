# === config/tests/test_config.mojo ===
# TDD: config 模块（schema 驱动加载 + 校验 + 最小 TOML 解析 + round-trip）。
# 注：Dict 非 Movable → Config 不可按值返回，from_str/from_toml 用 out 参数（见 config.mojo）。
from config import Config, from_str, from_toml
from std.io import FileHandle


def check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error(msg)


def test_defaults() raises:
    var c = Config()
    check(c.get_int("max_depth") == 10, "default max_depth should be 10")
    check(c.get_int("rule_count") == 5, "default rule_count should be 5")
    check(c.get_float("keep_rate") == 0.7, "default keep_rate should be 0.7")
    check(c.get_int("health_fail_threshold") == 5, "default health threshold")
    check(c.get_str("llm_api_key") == "", "default api key empty")


def test_from_str_override() raises:
    var toml = "max_depth = 50\nkeep_rate = 0.5\nllm_api_key = \"sk-test\"\n"
    var c = Config()
    from_str(c, toml)
    check(c.get_int("max_depth") == 50, "override max_depth")
    check(c.get_float("keep_rate") == 0.5, "override keep_rate")
    check(c.get_str("llm_api_key") == "sk-test", "override api key")
    check(c.get_int("rule_count") == 5, "missing key falls back to default")


def test_comments_ignored() raises:
    var toml = "# comment\nmax_depth = 20 # inline comment\n"
    var c = Config()
    from_str(c, toml)
    check(c.get_int("max_depth") == 20, "comment-stripped value")


def test_validation_out_of_range() raises:
    var toml = "max_depth = 999\n"
    var ok = False
    try:
        var c = Config()
        from_str(c, toml)
    except:
        ok = True
    check(ok, "out-of-range max_depth should raise")


def test_toml_roundtrip() raises:
    var c = Config()
    c.values["max_depth"] = "33"
    var s = c.to_toml()
    var c2 = Config()
    from_str(c2, s)
    check(c2.get_int("max_depth") == 33, "roundtrip max_depth")
    check(c2.get_int("rule_count") == 5, "roundtrip rule_count default")


def test_validate() raises:
    var c = Config()
    c.values["keep_rate"] = "5.0"
    var ok = False
    try:
        c.validate()
    except:
        ok = True
    check(ok, "validate should catch out-of-range keep_rate")


def test_from_toml_file() raises:
    var path = "/tmp/dadaozhijian_cfg_test.toml"
    var f = FileHandle(path, "w")
    f.write("connector_timeout_ms = 5000\nconnector_retry = 3\n")
    f.close()
    var c = Config()
    from_toml(c, path)
    check(c.get_int("connector_timeout_ms") == 5000, "file override timeout")
    check(c.get_int("connector_retry") == 3, "file override retry")
    check(c.get_int("max_depth") == 10, "file missing -> default")


def test_from_toml_missing_file() raises:
    var ok = False
    try:
        var c = Config()
        from_toml(c, "/tmp/does_not_exist_xyz.toml")
    except:
        ok = True
    check(ok, "missing file should raise")


def main() raises:
    var failed = 0
    print("=== config tests ===")
    try: test_defaults(); print("  passed: defaults")
    except e: failed += 1; print("  FAILED: defaults ->", e)
    try: test_from_str_override(); print("  passed: from_str_override")
    except e: failed += 1; print("  FAILED: from_str_override ->", e)
    try: test_comments_ignored(); print("  passed: comments_ignored")
    except e: failed += 1; print("  FAILED: comments_ignored ->", e)
    try: test_validation_out_of_range(); print("  passed: validation_out_of_range")
    except e: failed += 1; print("  FAILED: validation_out_of_range ->", e)
    try: test_toml_roundtrip(); print("  passed: toml_roundtrip")
    except e: failed += 1; print("  FAILED: toml_roundtrip ->", e)
    try: test_validate(); print("  passed: validate")
    except e: failed += 1; print("  FAILED: validate ->", e)
    try: test_from_toml_file(); print("  passed: from_toml_file")
    except e: failed += 1; print("  FAILED: from_toml_file ->", e)
    try: test_from_toml_missing_file(); print("  passed: from_toml_missing_file")
    except e: failed += 1; print("  FAILED: from_toml_missing_file ->", e)
    if failed > 0:
        print("config -> failed:", failed)
        raise Error("config tests failed")
    print("config -> passed: 8  failed: 0")
