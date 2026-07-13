# === bagua/__init__.mojo ===
# 八卦包聚合导出：下游以 `from bagua import ...` 或 `from bagua.<file> import <sym>` 取用。
# 子模块：trigrams(8 卦定义/派生) / operators(算子) / combine(重卦)。

from .trigrams import (
    Trigram, QIAN, KUN, ZHEN, XUN, KAN, LI, GEN, DUI, TRIGRAM_COUNT, NEUTRAL_ID,
    trigram_name, trigram_code, trigram_by_id, trigram_by_code,
    trigram_from_lines, trigram_from_symbol, trigram_from_symbol_safe, trigram_from_sancai,
)
from .operators import TrigramOperatorResult, apply, apply_by_id, apply_chain
from .combine import Hexagram, combine
