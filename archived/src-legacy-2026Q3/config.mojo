# 配置 - 六合所引用的外部约束
# 语言: Mojo 1.0.0b2

struct Config(ImplicitlyCopyable):
    var max_depth: Int
    var rule_count: Int

    def __init__(out self):
        self.max_depth = 10
        self.rule_count = 5

    def __copy_init__(out self, other: Self):
        self.max_depth = other.max_depth
        self.rule_count = other.rule_count
