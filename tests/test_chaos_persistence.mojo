# === tests/test_chaos_persistence.mojo ===
# 混沌测试简化版：验证 save_snapshot + save_journal + load() 恢复轮数不丢
from taiji.persistence import Persistence
from taiji.taiji_state import TaijiState
from std.io import FileHandle

def test_persistence_recovery() raises:
    p = Persistence("/tmp", "chaos1")

    # 创建一个 state 并连续 feedback 10 次构建 10 轮
    s = TaijiState(7)
    for i in range(10):
        var d = List[Int]()
        d.append(i)
        d.append(i + 1)
        s.feedback("round-" + String(i), d, i % 5, 0.5)
        # 前 9 轮写 journal
        if i < 9:
            p.save_journal(s)
        # 第 10 轮写 snapshot
        else:
            p.save_snapshot(s)

    # 重新加载验证（模拟进程重启后恢复）
    s2 = TaijiState()
    p.load(s2)
    if s2.round < 10:
        raise Error("persistence recovery lost rounds: expected >=10, got " + String(s2.round))
    print("✅ persistence recovery test passed: recovered round=" + String(s2.round))


def main() raises:
    test_persistence_recovery()