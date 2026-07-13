# === taiji/persistence.mojo ===
# 太极长期记忆持久化落盘（迁自规划 §4.1.2 完整方案）。
# 见 docs/architecture-modular-plan.md §4.1.2。
#
# 实现约束（Mojo 1.0.0b2，本构建已验证）：
#   - 无 std.file / 无 rename / 无 remove / 无 create_directory。
#   - 故以 FileHandle 文本落盘；路径策略由 {base_dir}/{model_name}_* 扁平化
#     （因无法创建子目录），model_name 作为文件名前缀实现实例隔离。
#   - 原子性以「单次整写 + CRC32 校验 + WAL 日志重放 + 内容锁」模拟（无 rename/remove）。
#   - TaijiState 含 Tensor（不可 Movable），故 load 以 mut 参数改写，不按值返回。

from std.io import FileHandle
from taiji.taiji_state import TaijiState, TAIJI_MAGIC, TAIJI_FORMAT_VERSION


# —— 编码/校验辅助 ——
def _bytes_of(s: String) -> List[Int]:
    var out = List[Int]()
    var p = s.unsafe_ptr()
    for i in range(s.byte_length()):
        out.append(Int(p[i]) & 0xFF)
    return out^


# 自实现 CRC32（IEEE 802.3, poly 0xEDB88320），无外部依赖
def _crc32(data: List[Int]) -> UInt32:
    var crc: UInt32 = 0xFFFFFFFF
    for i in range(len(data)):
        var b = UInt32(data[i] & 0xFF)
        crc = crc ^ b
        for _ in range(8):
            if (crc & 1) != 0:
                crc = (crc >> 1) ^ UInt32(0xEDB88320)
            else:
                crc = crc >> 1
    return crc ^ 0xFFFFFFFF


# 由魔数派生 4 字节 ASCII 魔数串（"TAIJ"）
def _magic_string() -> String:
    var m = TAIJI_MAGIC
    var s = String()
    s += chr((m >> 24) & 0xFF)
    s += chr((m >> 16) & 0xFF)
    s += chr((m >> 8) & 0xFF)
    s += chr(m & 0xFF)
    return s^


struct Persistence:
    var base_dir: String
    var model_name: String
    var format_version: Int

    def __init__(out self, base_dir: String, model_name: String):
        self.base_dir = base_dir
        self.model_name = model_name
        self.format_version = TAIJI_FORMAT_VERSION

    # —— 路径策略（扁平化, 见文件头约束说明）——
    def snapshot_path(self) -> String:
        if len(self.model_name) == 0:
            return self.base_dir + "/taiji_state.bin"
        return self.base_dir + "/" + self.model_name + "_taiji_state.bin"

    def journal_path(self) -> String:
        if len(self.model_name) == 0:
            return self.base_dir + "/taiji_journal.bin"
        return self.base_dir + "/" + self.model_name + "_taiji_journal.bin"

    def sidecar_path(self) -> String:
        if len(self.model_name) == 0:
            return self.base_dir + "/taiji_state.json"
        return self.base_dir + "/" + self.model_name + "_taiji_state.json"

    def lock_path(self) -> String:
        if len(self.model_name) == 0:
            return self.base_dir + "/.lock"
        return self.base_dir + "/" + self.model_name + ".lock"

    # —— 一致性: 自实现 CRC32 ——
    def checksum(self, data: List[Int]) -> UInt32:
        return _crc32(data)

    # —— 版本迁移（§4.1.2 接口骨架）——
    # 把内存态升级并重新落盘为当前版本格式（含版本头）。返回 1 表示执行了迁移落盘, 0 表示已是最新。
    # 兼容旧版本(16 字段, 无 last_lineage)的载入态: deserialize 已自动以 0 兜底 last_lineage,
    #   此处仅确保版本头与当前格式一致并重新落盘。
    def migrate(mut self, mut state: TaijiState) raises -> Int:
        var snap = self._read_if_exists(self.snapshot_path())
        var existing_version = 0
        if len(snap) > 0:
            var payload = String()
            var ok = False
            self._parse_snapshot(snap, payload, existing_version, ok)
        if existing_version >= TAIJI_FORMAT_VERSION:
            return 0   # 已是最新版本, 无需迁移
        self.format_version = TAIJI_FORMAT_VERSION
        self.save_snapshot(state)
        return 1

    # —— 写: 全量快照（整写 + 版本头 + sidecar）——
    def save_snapshot(mut self, mut state: TaijiState) raises:
        self._acquire_lock()
        var path = self.snapshot_path()
        var payload = state.serialize()
        var crc = self.checksum(_bytes_of(payload))
        # 头部: 魔数 / 格式版本 / 载荷 / CRC（版本头支持 migrate 迁移, 见 §4.1.2）
        var content = _magic_string() + "\n" + String(TAIJI_FORMAT_VERSION) + "\n" \
                      + payload + "\nCRC:" + String(crc) + "\n"
        var f = FileHandle(path, "w")
        f.write(content)
        f.close()
        self._write_sidecar(state)
        self._release_lock()

    # —— 写: 增量日志（WAL, 追加）——
    def save_journal(mut self, mut state: TaijiState) raises:
        self._acquire_lock()
        var path = self.journal_path()
        var payload = state.serialize()
        var crc = self.checksum(_bytes_of(payload))
        var line = payload + "|CRC:" + String(crc) + "\n"
        var f = FileHandle(path, "a")
        f.write(line)
        f.close()
        self._release_lock()

    # —— 读: 快照 + journal 重放 -> 一致态（写入 inout state）——
    def load(mut self, mut state: TaijiState) raises:
        # 1. 快照（若 CRC 通过则作为基态）
        var snap = self._read_if_exists(self.snapshot_path())
        if len(snap) > 0:
            var payload = String()
            var version = 0
            var ok = False
            self._parse_snapshot(snap, payload, version, ok)
            if ok:
                state.deserialize(payload)   # deserialize 兼容 16/17 字段(旧版本无 last_lineage)
        # 2. WAL 重放（仅在 CRC 有效的记录上推进, 遇首条损坏即截断）
        var jc = self._read_if_exists(self.journal_path())
        if len(jc) > 0:
            var raw_lines = jc.split("\n")
            var lines = List[String]()
            for i in range(len(raw_lines)):
                lines.append(String(raw_lines[i]))
            var base_round = state.round
            for i in range(len(lines)):
                var line = lines[i]
                if len(line) == 0:
                    continue
                var parts = line.split("|CRC:")
                if len(parts) != 2:
                    break
                var payload = String(parts[0])
                var crc_expected = UInt32(Int(parts[1]))
                var actual = self.checksum(_bytes_of(payload))
                if actual != crc_expected:
                    break
                var cand = TaijiState()
                cand.deserialize(payload)
                if cand.round > base_round:
                    state.deserialize(payload)
                    base_round = cand.round

    # 解析快照: 魔数 + 版本头 + CRC 校验; 通过则 payload 输出有效序列化串
    def _parse_snapshot(self, content: String, mut payload: String, mut version: Int, mut ok: Bool) raises:
        var raw_lines = content.split("\n")
        var lines = List[String]()
        for i in range(len(raw_lines)):
            lines.append(String(raw_lines[i]))
        if len(lines) < 4:
            payload = ""; version = 0; ok = False; return
        if lines[0] != _magic_string():
            payload = ""; version = 0; ok = False; return
        version = Int(lines[1])   # 格式版本（迁移依据）
        var p = lines[2]
        var crc_line = lines[3]
        var cparts = crc_line.split(":")
        if len(cparts) != 2:
            payload = ""; version = 0; ok = False; return
        var expected = UInt32(Int(cparts[1]))
        var actual = self.checksum(_bytes_of(p))
        if actual != expected:
            payload = ""; version = 0; ok = False; return
        payload = p
        ok = True

    # 人类可读 sidecar（observability/tracing 溯源）
    def _write_sidecar(self, mut state: TaijiState):
        var path = self.sidecar_path()
        var s = "{"
        s += "\"round\":" + String(state.round) + ","
        s += "\"seed\":" + String(state.seed) + ","
        s += "\"intent_hash\":" + String(state.intent_hash) + ","
        s += "\"n_chains\":" + String(len(state.decision_chains)) + ","
        s += "\"last_lineage\":" + String(state.last_lineage)
        s += "}"
        try:
            var f = FileHandle(path, "w")
            f.write(s)
            f.close()
        except:
            pass

    # 内容锁（本构建无 rename/remove/fcntl 原子语义, 以"读-判-写"最佳努力 advisory 锁模拟）。
    #   先读锁文件: 若已被持有("1")视为冲突返回 0; 否则写入持有令牌 "1" 并返回 1。
    #   注：单进程顺序执行可正确互斥；多进程下非原子测试-设置，仅作防并发写者的软护栏
    #   （与 §4.1.2 一致性保障 1 的 POSIX rename 原子语义目标一致, 受 Mojo 1.0.0b2 约束降级实现）。
    def _acquire_lock(self) -> Int:
        try:
            var cur = self._read_if_exists(self.lock_path())
            if len(cur) > 0 and cur.find("1") >= 0:
                return 0
            var f = FileHandle(self.lock_path(), "w")
            f.write("1")
            f.close()
            return 1
        except:
            return 0

    def _release_lock(self):
        try:
            var f = FileHandle(self.lock_path(), "w")
            f.write("0")
            f.close()
        except:
            pass

    # 读取文件; 不存在/读取失败 -> 返回空串（不做静默崩溃）
    def _read_if_exists(self, path: String) -> String:
        try:
            var f = FileHandle(path, "r")
            var c = f.read()
            f.close()
            return c
        except:
            return ""
