# ADR-0013: 原子写降级为 Advisory Lock

## 状态
Accepted (2026-07-13)

## 背景
`taiji/persistence.mojo` 需要实现 POSIX 原子写：临时文件写满 → `fsync` → `rename` 原子覆盖。Mojo 1.0.0b2 标准库无 `std.file.rename`/`fsync`，无法完成真正的原子写。

## 决策
采用“读-判-写”文件令牌模拟互斥锁（advisory lock）：
- `_acquire_lock()` 读取 `.lock` 文件，内容为 `1` 视为已持有 → 返回 `0`（拒绝）；否则写入 `1` 返回 `1`（获取成功）
- `_release_lock()` 写入 `0`
- 仅为单进程/协作式多进程软护栏，**非原子、非强一致**

## 后果
- 并发写入极小概率竞争，但生产环境单实例部署可规避
- 后续 Mojo 版本提供 `rename`/`fcntl` 时可无缝升级
- 测试 `taiji/tests/test_persistence.mojo::test_lock_advisory` 验证读-判-写互斥

## 备选
- 使用外部锁服务：引入额外依赖，过度设计
- 不加锁：并发写损坏概率不可接受