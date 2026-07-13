# === config/__init__.mojo ===
# 配置模块聚合导出。
from config.config import Config, from_str, from_toml
from config.schema import (
    field_count, field_name, field_default, field_kind,
    field_min, field_max, field_bounded, default_config_string,
)

# 加载 secrets.toml（git-crypt 加密，运行时覆盖 defaults.toml 中的敏感字段）
# 仅在文件存在时读取，缺失则静默跳过（CI/本地开发可无 secrets.toml）
def load_secrets(mut c: Config) raises:
    try:
        from_toml(c, "config/secrets.toml")
    except:
        pass
