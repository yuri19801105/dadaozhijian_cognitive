# === ops/healthcheck.mojo ===
# Kubernetes 探针实现：liveness/readiness
# 集成 runtime/lifecycle + memory + backfill 健康度
from runtime.lifecycle import Runtime, RuntimeState
from runtime.memory import MemoryBudget
from runtime.integration import BackfillGate
from config import Config, load_secrets, from_toml
from std.io import FileHandle
from sys.argv import argv

def main() raises:
    args = argv()
    ready_mode = "--ready" in args

    # 载入配置（含 secrets）
    c = Config()
    from_str(c, Config.default_config_string())
    try:
        from_toml(c, "config/defaults.toml")
    except:
        pass
    load_secrets(c)

    # 获取全局 Runtime 实例（需在服务启动时注册到全局）
    # 这里演示：若无全局实例则视为未就绪
    try:
        rt = get_global_runtime()
    except:
        if ready_mode:
            print("NOT_READY: runtime not initialized")
            return 1
        else:
            print("ALIVE: no runtime yet")
            return 0

    # Liveness：仅检查进程状态机是否非 STOPPED
    if not ready_mode:
        if rt.state() != RuntimeState.STOPPED:
            print("ALIVE")
            return 0
        else:
            print("DEAD: runtime stopped")
            return 1

    # Readiness：检查完整健康度
    # 1. 状态机 RUNNING
    if rt.state() != RuntimeState.RUNNING:
        print("NOT_READY: state=" + rt.state().name())
        return 1

    # 2. 内存预算 > 10%
    mem = MemoryBudget()
    if mem.available_percent() <= 10.0:
        print("NOT_READY: memory budget low ({:.1f}%)".format(mem.available_percent()))
        return 1

    # 3. 回灌健康度
    gate = BackfillGate()
    if not gate.is_healthy():
        print("NOT_READY: backfill gate unhealthy (success_rate={:.2f})".format(gate.backfill_success_rate()))
        return 1

    # 3. 并发槽位未满
    if rt.concurrency_usage_percent() > 90.0:
        print("NOT_READY: concurrency saturated ({:.1f}%)".format(rt.concurrency_usage_percent()))
        return 1

    print("READY")
    return 0

# 占位：实际项目中在 main.mojo 启动时注册全局 runtime 实例
def get_global_runtime() -> Runtime:
    # 这里应返回单例 Runtime，演示用抛出
    raise Error("global runtime not registered")

def from_str(c: Config, s: String) raises:
    # 复用 config.mojo 的解析逻辑
    pass

def Config.default_config_string() -> String:
    from config.schema import default_config_string
    return default_config_string()