# observability/logging.mojo — 结构化日志 + 审计(合规判定同样留痕, 可独立审查)
# 运行: mojo run -I . -I core observability/logging.mojo
comptime LOG_INFO: Int = 0
comptime LOG_WARN: Int = 1
comptime LOG_ERROR: Int = 2
comptime LOG_AUDIT: Int = 3

def _level_name(level: Int) -> String:
    if level == LOG_INFO: return "INFO"
    if level == LOG_WARN: return "WARN"
    if level == LOG_ERROR: return "ERROR"
    if level == LOG_AUDIT: return "AUDIT"
    return "?"

def log_line(level: Int, module: String, msg: String) -> String:
    # 结构化: [[LEVEL][module] msg]
    var s = String("[[")
    s = s + _level_name(level) + "]["
    s = s + module + "] " + msg + "]"
    return s^

def audit(event: String) -> String:
    # 审计事件强制 AUDIT 级别留痕(合规判定同样纳入, 可独立审查验证)。
    return log_line(LOG_AUDIT, "audit", event)
