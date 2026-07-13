# === taiji/taiji_state.mojo ===
# 太极全局状态根（迁自 src/taiji.mojo，升级为张量化能量态）。
# 见规划 §4.1.1（v0.4 接口骨架）。
#
# 实现约束（Mojo 1.0.0b2，本构建已验证）：
#   - 无 bitcast / 无 std.file；Float64 经 String(Float64) 文本序列化可精确往返。
#   - Tensor 含 List 字段 -> 不可 Movable；故 TaijiState 亦不可按值返回，
#     持久化 Persistence.load 以 inout 参数改写（见 persistence.mojo）。
#   - to_payload/from_payload 以 List[Int]（UTF-8 字节载体）承载，honors §4.1.1 签名；
#     因本构建无 bytes->String 解码器，from_payload 经 chr() 逐字节还原（已验证可用）。

from tensor.tensor import Tensor
from math.activate import softmax_list


comptime TAIJI_MAGIC = 0x5441494A            # "TAIJ", 落盘魔数
comptime TAIJI_FORMAT_VERSION = 2            # 格式版本, 迁移依据（v2 起含 last_lineage 跨进程串联键）


# —— 序列化辅助（模块级函数，供 taiji_state 与 persistence 复用）——
def _join_ints(xs: List[Int]) -> String:
    var s = String()
    for i in range(len(xs)):
        if i > 0:
            s += ","
        s += String(xs[i])
    return s^


def _join_floats(xs: List[Float64]) -> String:
    var s = String()
    for i in range(len(xs)):
        if i > 0:
            s += ","
        s += String(xs[i])
    return s^


def _parse_int_csv(s: String, n: Int) raises -> List[Int]:
    var out = List[Int]()
    if n <= 0:
        return out^
    if len(s) == 0:
        raise Error("TaijiState.deserialize: expected ints but empty")
    var parts = s.split(",")
    if len(parts) != n:
        raise Error("TaijiState.deserialize: int count mismatch")
    for i in range(n):
        out.append(Int(parts[i]))
    return out^


def _parse_int_csv_all(s: String) raises -> List[Int]:
    var out = List[Int]()
    if len(s) == 0:
        return out^
    var parts = s.split(",")
    for i in range(len(parts)):
        var t = parts[i]
        if len(t) > 0:
            out.append(Int(t))
    return out^


def _parse_float_csv(s: String, n: Int) raises -> List[Float64]:
    var out = List[Float64]()
    if n <= 0:
        return out^
    if len(s) == 0:
        raise Error("TaijiState.deserialize: expected floats but empty")
    var parts = s.split(",")
    if len(parts) != n:
        raise Error("TaijiState.deserialize: float count mismatch")
    for i in range(n):
        out.append(Float64(parts[i]))
    return out^


def _bytes_of(s: String) -> List[Int]:
    var out = List[Int]()
    var p = s.unsafe_ptr()
    for i in range(s.byte_length()):
        out.append(Int(p[i]) & 0xFF)
    return out^


struct TaijiState:
    # —— 跨轮累积态（全局状态根）——
    var decision_chains: List[List[Int]]   # 每轮七星决策链（按轮存储）
    var phases: List[Int]                   # 每轮五行相位 (0..4)
    var intensities: List[Float64]          # 每轮强度（能量）
    var out_lengths: List[Int]              # 每轮十方输出字节长
    var energy: Tensor                      # 全局能量张量（长期记忆态, 默认 [9] 映射九宫）
    var round: Int                          # 已回灌轮数
    var seed: Int                           # 由历史派生的全局状态根种子（确定性）
    var intent_hash: Int                    # 意图哈希
    var last_lineage: Int                   # 最近一次回灌关联的 observability 溯源 lineage_id（跨进程持久化串联）

    def __init__(out self, intent_hash: Int = 0) raises:
        self.decision_chains = List[List[Int]]()
        self.phases = List[Int]()
        self.intensities = List[Float64]()
        self.out_lengths = List[Int]()
        self.energy = Tensor()
        self.energy.init([9])
        self.round = 0
        self.seed = 0
        self.intent_hash = intent_hash
        self.last_lineage = 0

    # 回灌读取: 返回累积记忆上下文, 供下一轮派生（首轮返回 ""）
    def recall(self) -> String:
        if self.round == 0:
            return ""
        var s = "[记忆 " + String(self.round) + " 轮] 意图根=" + String(self.intent_hash)
        s += " 相位链=["
        for i in range(len(self.phases)):
            if i > 0:
                s += ","
            s += String(self.phases[i])
        s += "] 决策链数=" + String(len(self.decision_chains))
        s += " 根种子=" + String(self.seed)
        return s^

    # 十方输出 → 回灌太极: 写入长期记忆 + 派生 seed + 叠加能量
    def feedback(mut self, output: String, decision: List[Int], phase: Int, intensity: Float64) raises:
        var chain = List[Int]()
        for i in range(len(decision)):
            chain.append(decision[i])
        self.decision_chains.append(chain^)
        self.phases.append(phase)
        self.intensities.append(intensity)
        self.out_lengths.append(output.byte_length())
        self.round += 1
        # 种子 = (旧种子*31 + 相位*7 + 强度*1000 + 输出长) mod 1e6+3 —— 确定性派生, 反映认知轨迹
        var i_part = Int(intensity * 1000.0)
        var v = self.seed * 31 + phase * 7 + i_part + output.byte_length()
        v = v % 1000003
        if v < 0:
            v = v + 1000003
        self.seed = v
        # 能量累积: 相位映射到 9 宫格之一
        var idx = phase % 9
        if idx < 0:
            idx = idx + 9
        self.energy.set_flat(idx, self.energy.at_flat(idx) + intensity)

    # 最近一轮决策链副本（避免外移内部状态）
    def last_decision(self) -> List[Int]:
        var out = List[Int]()
        if self.round == 0:
            return out^
        var last = self.decision_chains[self.round - 1].copy()
        for i in range(len(last)):
            out.append(last[i])
        return out^

    # 能量分布（softmax over energy）, 用于 recall 偏置
    def energy_distribution(self) -> List[Float64]:
        return softmax_list(self.energy.to_list())

    # —— 序列化（精确文本编解码, 兼容 persistence）——
    def serialize(self) -> String:
        var s = String()
        s += String(self.intent_hash)
        s += "|"; s += String(self.round)
        s += "|"; s += String(self.seed)
        var eshape = self.energy.shape()
        s += "|"; s += String(len(eshape))
        s += "|"; s += _join_ints(eshape)
        var edata = self.energy.to_list()
        s += "|"; s += String(len(edata))
        s += "|"; s += _join_floats(edata)
        # 决策链: 链数 | 展平 | 链长
        s += "|"; s += String(len(self.decision_chains))
        s += "|"
        var first_flat = True
        for k in range(len(self.decision_chains)):
            for j in range(len(self.decision_chains[k])):
                if not first_flat:
                    s += ","
                first_flat = False
                s += String(self.decision_chains[k][j])
        s += "|"
        for k in range(len(self.decision_chains)):
            if k > 0:
                s += ","
            s += String(len(self.decision_chains[k]))
        # 相位 / 强度 / 输出长
        s += "|"; s += String(len(self.phases)); s += "|"; s += _join_ints(self.phases)
        s += "|"; s += String(len(self.intensities)); s += "|"; s += _join_floats(self.intensities)
        s += "|"; s += String(len(self.out_lengths)); s += "|"; s += _join_ints(self.out_lengths)
        s += "|"; s += String(self.last_lineage)
        return s^

    def deserialize(mut self, s: String) raises:
        var raw_parts = s.split("|")
        var parts = List[String]()
        for i in range(len(raw_parts)):
            parts.append(String(raw_parts[i]))
        # 向后兼容：v1 旧格式仅 16 字段(无 last_lineage)，以 0 兜底补到 17，
        #   使 migrate 能从真·16 字段 v1 快照载入并升级（见 §4.1.2 版本迁移）。
        if len(parts) == 16:
            parts.append(String(0))
        elif len(parts) != 17:
            raise Error("TaijiState.deserialize: expected 16 or 17 fields, got " + String(len(parts)))
        self.intent_hash = Int(parts[0])
        self.round = Int(parts[1])
        self.seed = Int(parts[2])
        var nshape = Int(parts[3])
        var shape = _parse_int_csv(parts[4], nshape)
        var n_energy = Int(parts[5])
        var edata = _parse_float_csv(parts[6], n_energy)
        self.energy = Tensor()
        self.energy.from_list(edata, shape)
        var n_chains = Int(parts[7])
        var chains_flat_all = _parse_int_csv_all(parts[8])
        var chain_lens = _parse_int_csv(parts[9], n_chains)
        self.decision_chains = List[List[Int]]()
        var idx = 0
        for k in range(n_chains):
            var ln = chain_lens[k]
            var chain = List[Int]()
            for j in range(ln):
                chain.append(chains_flat_all[idx])
                idx += 1
            self.decision_chains.append(chain^)
        self.phases = _parse_int_csv(parts[11], Int(parts[10]))
        self.intensities = _parse_float_csv(parts[13], Int(parts[12]))
        self.out_lengths = _parse_int_csv(parts[15], Int(parts[14]))
        self.last_lineage = Int(parts[16])

    # 序列化辅助: 导出/导入为扁平字节载体（供 persistence 落盘 + CRC）
    def to_payload(self) -> List[Int]:
        return _bytes_of(self.serialize())

    def from_payload(mut self, payload: List[Int]) raises:
        var s = String()
        for i in range(len(payload)):
            s += chr(payload[i] & 0xFF)
        self.deserialize(s)

    # 原地巩固（供 Consolidation 委派; 因 mut 参数字段整体赋值受限, 此处以 mut self 实现）
    # 保留最近 keep_rate 比例的轨迹, 衰减存活轨迹强度(EWC 思路)
    def consolidate_in_place(mut self, keep_rate: Float64, forget_rate: Float64) raises:
        var n = self.round
        if n <= 3:
            return  # 轨迹过少, 不巩固
        var keep = Int(Float64(n) * keep_rate)
        if keep < 1:
            keep = 1
        if keep >= n:
            keep = n - 1  # 至少淘汰一条, 体现压缩
        if keep < 1:
            keep = 1
        var start = n - keep  # 保留最近 keep 条（recency bias）
        var kc = List[List[Int]]()
        var kp = List[Int]()
        var ki = List[Float64]()
        var ko = List[Int]()
        var decay = 1.0 - forget_rate
        for i in range(start, n):
            var chain = self.decision_chains[i].copy()
            kc.append(chain^)
            kp.append(self.phases[i])
            ki.append(self.intensities[i] * decay)
            ko.append(self.out_lengths[i])
        self.decision_chains = kc^
        self.phases = kp^
        self.intensities = ki^
        self.out_lengths = ko^
        self.round = keep
