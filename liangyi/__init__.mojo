# === liangyi/__init__.mojo ===
# 两仪包聚合导出 —— 允许下游以 `from liangyi import Dual, Polarity, ...` 直接取用,
# 同时保留 `from liangyi.<file> import <sym>` 的细粒度导入(见 §4.2.2, 两种口径均可用)。

from .dual import Dual, YIN, YANG
from .polarity import Polarity
from .activation import YinYangGate, GatePair
