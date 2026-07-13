# === bagua/combine.mojo ===
# 重卦组合：八卦两两相重成六十四卦（8×8）。下卦(初/二/三爻) + 上卦(四/五/上爻)。
# 调用契约（见 §4.8.0）：卦之组合用 Polarity.compose（均权 0.5）求重卦之"精"。
# 编码：code = lower.code + upper.code * 8 （0..63）。

from liangyi.dual import Dual
from liangyi.polarity import Polarity
from .trigrams import Trigram, trigram_name


# 重卦载体（Movable：存 id 与 essence(Dual)，不存 Trigram 结构以保 Movable）
struct Hexagram(Movable):
    var lower: Int         # 下卦 id
    var upper: Int         # 上卦 id
    var code: Int          # 0..63
    var essence: Dual      # 重卦之精（两卦 essence 均权合成）

    def __init__(out self, lower: Int, upper: Int, code: Int, essence: Dual):
        self.lower = lower
        self.upper = upper
        self.code = code
        self.essence = Dual.from_parts(essence.yin_part(), essence.yang_part())

    # 上下卦名拼接，如 "乾坤"
    def name(self) -> String:
        return trigram_name(self.lower) + trigram_name(self.upper)


# 组合两卦为重卦
def combine(lower: Trigram, upper: Trigram) -> Hexagram:
    var code = lower.code() + upper.code() * 8
    var ess = Polarity.compose(lower.essence(), upper.essence(), 0.5)
    return Hexagram(lower.id, upper.id, code, ess)
