# 太极 - 元认知 / 全局状态根 + 长期记忆
# 十方输出 → 回灌太极 → 下一轮派生, 形成真实闭环
# 语言: Mojo 1.0.0b2 | 验证: TDD
#
# 关系约束(见 CONTEXT.md):
#   太极为根, 一切派生自太极, 最终回灌太极(闭环)。
#   太极(M1 之根) 与 九宫(M3 工作记忆) 分层:
#     - 九宫承载单轮中间态(3x3 草稿纸 + 注意力), 不参与跨轮;
#     - 太极承载跨轮累积态(全局状态根), 不参与单轮注意力计算。
#   二者不重复造轮子, 太极是九宫之上的「全局状态根」。
#
# 实现约束(Mojo 1.0.0b2):
#   - 本构建不支持 class, 且含 String / List[String] 字段的 struct 不可 Movable;
#     故太极状态仅以 Int / List[Int] 存储, 历史输出经哈希派生为种子(不落盘原文)。
#   - 跨轮可变状态由 CognitiveCycle(见 pipeline.mojo) 以 mut self 方法持有, 避免 inout 参数。

struct TaijiState:
    var decisions_flat: List[Int]     # 历史七星决策链(按轮展平存储)
    var decision_lens: List[Int]      # 每轮决策链长度
    var phases: List[Int]             # 每轮五行相位
    var intensities: List[Int]        # 每轮强度
    var out_lengths: List[Int]        # 每轮十方输出字节长
    var round: Int                    # 已回灌轮数
    var seed: Int                     # 由历史派生的全局状态根种子
    var intent_hash: Int              # 意图哈希(派生自意图长度)

    def __init__(out self, intent_hash: Int = 0):
        self.decisions_flat = List[Int]()
        self.decision_lens = List[Int]()
        self.phases = List[Int]()
        self.intensities = List[Int]()
        self.out_lengths = List[Int]()
        self.round = 0
        self.seed = 0
        self.intent_hash = intent_hash

    def recall(self) -> String:
        # 回灌读取: 返回累积记忆上下文, 供下一轮派生(注入输入文本)
        # 首次(无历史)返回 "" —— 等价于无记忆, 退化成单轮流水线
        if self.round == 0:
            return ""
        var s = "[记忆 " + String(self.round) + " 轮] 意图根=" + String(self.intent_hash) + " 相位链=["
        for i in range(len(self.phases)):
            if i > 0:
                s += ","
            s += String(self.phases[i])
        s += "] 决策数=" + String(len(self.decision_lens)) + " 根种子=" + String(self.seed)
        return s^

    def feedback(mut self, output: String, decision: List[Int], phase: Int, intensity: Int):
        # 十方输出 → 回灌太极: 写入长期记忆, 并派生全局状态根种子
        for i in range(len(decision)):
            self.decisions_flat.append(decision[i])
        self.decision_lens.append(len(decision))
        self.phases.append(phase)
        self.intensities.append(intensity)
        self.out_lengths.append(output.byte_length())
        self.round += 1
        # 种子 = (旧种子 * 31 + 相位*7 + 强度*3 + 输出长) mod 1e6+3 —— 确定性派生, 反映认知轨迹
        self.seed = (self.seed * 31 + phase * 7 + intensity * 3 + output.byte_length()) % 1000003

    def last_decision(self) -> List[Int]:
        # 返回最近一轮七星决策链的副本(避免外移内部状态)
        var out = List[Int]()
        if self.round == 0:
            return out^
        var start = 0
        for k in range(self.round - 1):
            start += self.decision_lens[k]
        var n = self.decision_lens[self.round - 1]
        for i in range(n):
            out.append(self.decisions_flat[start + i])
        return out^

def _intent_hash(s: String) -> Int:
    # 意图哈希: 派生自意图长度(本构建不支持 String 字节直接索引, 长度即可区分意图规模)
    return s.byte_length()
