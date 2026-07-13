# === taiji/tests/test_persistence.mojo ===
# TDD (RED -> GREEN): 测试 taiji/persistence（CRC32 校验 + WAL 落盘 + 崩溃恢复 + 校验失败回滚）。
# 本构建无 std.file/rename/remove，故以 FileHandle 文本落盘 + 内容锁 + 自实现 CRC32 落地。
from taiji.taiji_state import TaijiState, TAIJI_FORMAT_VERSION
from taiji.persistence import Persistence
from std.io import FileHandle


def ints_equal(a: List[Int], b: List[Int]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def approx(a: Float64, b: Float64, tol: Float64) -> Bool:
    var d = a - b
    if d < 0.0:
        d = -d
    return d < tol


def read_file(path: String) -> String:
    try:
        var f = FileHandle(path, "r")
        var c = f.read()
        f.close()
        return c
    except:
        return ""


# 截断 journal 文件（Mojo 本构建无 remove, 以 "w" 空写替代），避免历史残留的
# 旧格式 journal 记录污染 WAL 重放（见 §4.1.2 格式演进）。
def truncate_journal(p: Persistence):
    try:
        var f = FileHandle(p.journal_path(), "w")
        f.write("")
        f.close()
    except:
        pass


# 注意: TaijiState 含 Tensor(不可 Movable), 不能按值返回, 故以 mut 就地构造
def build_state(mut s: TaijiState, n: Int) raises:
    for r in range(n):
        var dec = List[Int]()
        dec.append(r); dec.append(r * 3); dec.append(r + 7)
        s.feedback("out" + String(r), dec, (r * 2) % 5, Float64(r) * 0.3 + 0.1)


def bytes_of(s: String) -> List[Int]:
    var out = List[Int]()
    var p = s.unsafe_ptr()
    for i in range(s.byte_length()):
        out.append(Int(p[i]) & 0xFF)
    return out^


def test_roundtrip_v1_16field_snapshot() raises:
    # 真·16 字段 v1 快照 round-trip 端到端落盘测试（加固 §4.1.2 B/C 修复）：
    #   构造 16 字段(无 last_lineage)的 v1 快照真实落盘 -> load 读回 -> last_lineage 兜底 0
    #   -> 重新 save 升级为 v2(17 字段) -> 再 load 验证字段不丢、能量守恒。
    var p = Persistence("/tmp", "rt16")
    truncate_journal(p)
    var s = TaijiState(9)
    build_state(s, 3)
    # 1) 构造真·v1 16 字段载荷（去掉末段 last_lineage）
    var s17 = s.serialize()
    var parts = s17.split("|")
    if len(parts) != 17: raise Error("serialize should be 17 fields, got " + String(len(parts)))
    var payload16 = String(parts[0])
    for i in range(1, 16):
        payload16 = payload16 + "|" + String(parts[i])
    # 2) 载荷 CRC（与 persistence._parse_snapshot 校验口径一致）
    var crc = p.checksum(bytes_of(payload16))
    # 3) 真实落盘为 v1 版本头快照文件（魔数 TAIJ / 版本 1 / 16 字段载荷 / CRC）
    var content = "TAIJ\n1\n" + payload16 + "\nCRC:" + String(crc) + "\n"
    var f = FileHandle(p.snapshot_path(), "w")
    f.write(content)
    f.close()
    # 4) load 读回：deserialize 兼容 16 字段, last_lineage 兜底 0
    var loaded = TaijiState()
    p.load(loaded)
    if loaded.round != 3: raise Error("v1 16-field load should preserve round 3, got " + String(loaded.round))
    if loaded.last_lineage != 0: raise Error("v1 16-field load should default last_lineage=0")
    if not ints_equal(loaded.last_decision(), s.last_decision()):
        raise Error("v1 16-field load should preserve last decision chain")
    # 5) 重新 save(升级为 v2 / 17 字段) -> 再 load 验证 round-trip 不丢字段、能量守恒
    p.save_snapshot(loaded)
    var r2 = TaijiState()
    p.load(r2)
    if r2.round != 3: raise Error("round-trip reload should preserve round 3, got " + String(r2.round))
    if r2.last_lineage != 0: raise Error("round-trip should keep last_lineage=0 (upgraded from v1)")
    if not approx(r2.energy.at_flat(0), s.energy.at_flat(0), 1e-12):
        raise Error("round-trip energy should be conserved")


def test_normal_snapshot_load() raises:
    var p = Persistence("/tmp", "norm1")
    var s = TaijiState(11)
    build_state(s, 3)
    p.save_snapshot(s)
    var loaded = TaijiState()
    p.load(loaded)
    if loaded.round != 3: raise Error("loaded round should be 3, got " + String(loaded.round))
    if loaded.seed != s.seed: raise Error("loaded seed mismatch")
    if loaded.intent_hash != 11: raise Error("loaded intent_hash mismatch")
    if not ints_equal(loaded.last_decision(), s.last_decision()):
        raise Error("loaded last_decision mismatch")
    if not approx(loaded.energy.at_flat(0), s.energy.at_flat(0), 1e-12):
        raise Error("loaded energy mismatch")


def test_journal_replay_over_snapshot() raises:
    var p = Persistence("/tmp", "jrnl1")
    truncate_journal(p)
    var a = TaijiState(1)
    build_state(a, 2)      # round 2
    p.save_snapshot(a)
    var b = TaijiState(1)
    build_state(b, 3)      # round 3 (deterministic from same inputs)
    p.save_journal(b)
    var loaded = TaijiState()
    p.load(loaded)
    # snapshot(2) + journal(3) -> 重放至最新一致态 round 3
    if loaded.round != 3: raise Error("journal replay should reach round 3, got " + String(loaded.round))
    if loaded.seed != b.seed: raise Error("replayed seed mismatch")


def test_checksum_failure_rollback() raises:
    var p = Persistence("/tmp", "roll1")
    truncate_journal(p)
    var sa = TaijiState(1)
    build_state(sa, 2)     # round 2 snapshot
    p.save_snapshot(sa)
    var sb = TaijiState(1)
    build_state(sb, 3)     # round 3 journal
    p.save_journal(sb)
    # 破坏快照：结构合法但 CRC 故意写错 -> 校验失败
    var payload = sa.serialize()
    var corrupt = "TAIJ\n" + String(TAIJI_FORMAT_VERSION) + "\n" + payload + "\nCRC:0\n"
    var f = FileHandle(p.snapshot_path(), "w")
    f.write(corrupt)
    f.close()
    var loaded = TaijiState()
    p.load(loaded)
    # 快照损坏 -> 回滚到 journal 中最后一致点（round 3），绝不加载损坏数据
    if loaded.round != 3: raise Error("rollback should recover round 3 from journal, got " + String(loaded.round))
    if loaded.seed != sb.seed: raise Error("rollback seed mismatch (loaded corrupt data?)")


def test_crash_recovery_truncates_bad_journal() raises:
    var p = Persistence("/tmp", "crash1")
    truncate_journal(p)
    var sa = TaijiState(2)
    build_state(sa, 2)     # round 2 snapshot
    p.save_snapshot(sa)
    var sb = TaijiState(2)
    build_state(sb, 3)     # round 3 valid journal
    p.save_journal(sb)
    # 模拟崩溃：追加一条半写（CRC 错误）的 journal 记录
    var jpath = p.journal_path()
    var bad = "intent_hash|3|seed|1|9|0|0|0||0|0||0|0||0|0||0|0||CRC:0\n"
    var af = FileHandle(jpath, "a")
    af.write(bad)
    af.close()
    var loaded = TaijiState()
    p.load(loaded)
    # 重放：round3 有效 -> best=3；坏记录 CRC 失败 -> 截断停止。恢复至 round 3
    if loaded.round != 3: raise Error("crash recovery should stop at round 3, got " + String(loaded.round))
    if loaded.seed != sb.seed: raise Error("crash recovery seed mismatch")


def test_load_empty_is_fresh() raises:
    var p = Persistence("/tmp", "empty1")
    var loaded = TaijiState()
    p.load(loaded)
    if loaded.round != 0: raise Error("no files -> fresh state round 0")
    if loaded.seed != 0: raise Error("no files -> seed 0")


def test_sidecar_written() raises:
    var p = Persistence("/tmp", "side1")
    var s = TaijiState(5)
    build_state(s, 2)
    p.save_snapshot(s)
    var sc = read_file(p.sidecar_path())
    if len(sc) == 0: raise Error("sidecar should be written")
    if sc.find("round") < 0: raise Error("sidecar should contain round field")


def test_checksum_function() raises:
    # CRC32 对同一输入确定性；不同输入大概率不同
    var p = Persistence("/tmp", "chk1")
    var d1 = List[Int]()
    d1.append(72); d1.append(101); d1.append(108); d1.append(108); d1.append(111)
    var d2 = List[Int]()
    d2.append(72); d2.append(101); d2.append(108); d2.append(108); d2.append(111)
    var d3 = List[Int]()
    d3.append(72); d3.append(101); d3.append(108); d3.append(108); d3.append(112)
    if p.checksum(d1) != p.checksum(d2): raise Error("same data -> same crc")
    if p.checksum(d1) == p.checksum(d3): raise Error("different data -> different crc (unlikely collision)")


def test_lock_advisory() raises:
    # §4.1.2 C：写锁为最佳努力互斥；未释放不可二次获取, 释放后可再获取。
    var p = Persistence("/tmp", "lock1")
    truncate_journal(p)
    var a = p._acquire_lock()
    if a != 1: raise Error("first acquire should succeed (1)")
    var b = p._acquire_lock()           # 未释放, 视为冲突
    if b != 0: raise Error("re-acquire without release should conflict (0)")
    p._release_lock()
    var c = p._acquire_lock()           # 释放后可再获取
    if c != 1: raise Error("acquire after release should succeed (1)")
    p._release_lock()


def test_migrate_v1_to_v2() raises:
    # 版本迁移（§4.1.2）：旧版本(v1)快照经 migrate 升级为当前版本(v2)并重新落盘。
    var p = Persistence("/tmp", "mig1")
    truncate_journal(p)
    var s = TaijiState(7)
    build_state(s, 3)
    p.save_snapshot(s)                 # 当前版本 v2 落盘
    # 1) 已是最新版本 -> migrate 返回 0（无需迁移）
    if p.migrate(s) != 0: raise Error("already-latest migrate should return 0")
    # 2) 模拟旧版本: 把快照头版本号改写为 1（载荷不变, CRC 仍对载荷有效）
    var snap = read_file(p.snapshot_path())
    var raw = snap.split("\n")
    var lines = List[String]()
    for i in range(len(raw)):
        lines.append(String(raw[i]))
    if len(lines) < 4: raise Error("snapshot header unexpected")
    lines[1] = "1"                     # 降级版本头 -> 旧格式
    var downgraded = lines[0]
    for i in range(1, len(lines)):
        downgraded = downgraded + "\n" + lines[i]
    var f = FileHandle(p.snapshot_path(), "w")
    f.write(downgraded)
    f.close()
    # 载入旧版本（deserialize 兼容 16/17 字段, last_lineage 兜底 0）
    var loaded = TaijiState()
    p.load(loaded)
    if loaded.round != 3: raise Error("v1 load should preserve round 3, got " + String(loaded.round))
    # 2b) 真·16 字段 v1 载荷(无 last_lineage)经 deserialize 直接载入, last_lineage 兜底 0
    var s17 = s.serialize()                       # 17 字段
    var f17 = s17.split("|")
    var parts17 = List[String]()
    for i in range(len(f17)):
        parts17.append(String(f17[i]))
    if len(parts17) != 17: raise Error("serialize should be 17 fields")
    var payload16 = parts17[0]                    # 去掉末段(last_lineage) -> 16 字段
    for i in range(1, len(parts17) - 1):
        payload16 = payload16 + "|" + parts17[i]
    var loaded16 = TaijiState()
    loaded16.deserialize(payload16)               # 直接反序列化 16 字段
    if loaded16.round != 3: raise Error("16-field deserialize should preserve round 3")
    if loaded16.last_lineage != 0: raise Error("16-field deserialize should default last_lineage=0")
    # 3) migrate 升级旧版本 -> 返回 1 并重新落盘为当前版本
    if p.migrate(loaded) != 1: raise Error("outdated migrate should return 1")
    var reloaded = TaijiState()
    p.load(reloaded)
    if reloaded.round != 3: raise Error("migrated reload should preserve round 3")
    # 版本头已升级为当前版本
    var snap2 = read_file(p.snapshot_path())
    var lines2 = snap2.split("\n")
    if lines2[1] != String(TAIJI_FORMAT_VERSION): raise Error("version header should be upgraded")


def main() raises:
    var failed = 0
    print("=== taiji/persistence tests ===")
    try: test_normal_snapshot_load(); print("  passed: normal_snapshot_load")
    except e: failed += 1; print("  FAILED: normal_snapshot_load ->", e)
    try: test_journal_replay_over_snapshot(); print("  passed: journal_replay_over_snapshot")
    except e: failed += 1; print("  FAILED: journal_replay_over_snapshot ->", e)
    try: test_checksum_failure_rollback(); print("  passed: checksum_failure_rollback")
    except e: failed += 1; print("  FAILED: checksum_failure_rollback ->", e)
    try: test_crash_recovery_truncates_bad_journal(); print("  passed: crash_recovery")
    except e: failed += 1; print("  FAILED: crash_recovery ->", e)
    try: test_load_empty_is_fresh(); print("  passed: load_empty_is_fresh")
    except e: failed += 1; print("  FAILED: load_empty_is_fresh ->", e)
    try: test_sidecar_written(); print("  passed: sidecar_written")
    except e: failed += 1; print("  FAILED: sidecar_written ->", e)
    try: test_checksum_function(); print("  passed: checksum_function")
    except e: failed += 1; print("  FAILED: checksum_function ->", e)
    try: test_roundtrip_v1_16field_snapshot(); print("  passed: roundtrip_v1_16field_snapshot")
    except e: failed += 1; print("  FAILED: roundtrip_v1_16field_snapshot ->", e)
    try: test_migrate_v1_to_v2(); print("  passed: migrate_v1_to_v2")
    except e: failed += 1; print("  FAILED: migrate_v1_to_v2 ->", e)
    try: test_lock_advisory(); print("  passed: lock_advisory")
    except e: failed += 1; print("  FAILED: lock_advisory ->", e)
    if failed > 0:
        print("persistence -> passed: 0  failed:", failed)
        raise Error("persistence tests failed")
    print("persistence -> passed: 10  failed: 0")
