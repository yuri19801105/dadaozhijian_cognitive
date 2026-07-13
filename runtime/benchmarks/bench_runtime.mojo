# runtime/benchmarks/bench_runtime.mojo — 生命周期/内存/并发 基准
# @extern("clock") 取时; sink 反馈 + 连续变化种子防 DCE。
# 运行: mojo run -I . -I core runtime/benchmarks/bench_runtime.mojo
from runtime import RuntimeState, MemoryBudget, TaskSlot, TimeoutGuard, BackfillGate

@extern("clock")
def clock() abi("C") -> Int:
    ...

def main() raises:
    var N: Int = 200_000
    var sink_i: Int = 0
    var sink_f: Float64 = 0.0
    var seed: Int = 1          # 跨迭代反馈, 防止优化器把循环折叠为闭式(否则 clock 差分为 0)

    # --- lifecycle 状态转换 + 健康判定 (每轮 50 次, seed/i/k 反馈) ---
    var t0 = clock()
    for _ in range(N):
        var s = 0
        for _ in range(50):
            var rt = RuntimeState()
            rt.start()
            rt.tick()
            if (seed + s) % 7 == 0:
                rt.record_error()
            s = s + rt.is_healthy()
            rt.pause()
            rt.resume()
            rt.stop()
            seed = seed * 31 + s + 1
        sink_i = sink_i + s
    var t1 = clock()
    var ns_lifecycle = (t1 - t0) * 1000 / (N * 50)

    # --- memory alloc/free 循环 (每轮 50 次, seed 反馈) ---
    var t2 = clock()
    for i in range(N):
        var s = 0
        for k in range(50):
            var mb = MemoryBudget(1024 + (seed % 256))
            mb.alloc((seed + i + k) % 256)
            s = s + mb.available()
            mb.free((seed + i + k) % 256)
            seed = seed * 31 + s + 1
        sink_i = sink_i + s
    var t3 = clock()
    var ns_mem = (t3 - t2) * 1000 / (N * 50)

    # --- task slot acquire/release + timeout tick (每轮 50 次, seed 反馈) ---
    var t4 = clock()
    for i in range(N):
        var s = 0
        for k in range(50):
            var slot = TaskSlot(4)
            _ = slot.acquire()
            _ = slot.acquire()
            slot.release()
            var g = TimeoutGuard(5)
            g.tick((seed + i + k) % 6)
            s = s + g.expired()
            seed = seed * 31 + s + 1
        sink_i = sink_i + s
    var t5 = clock()
    var ns_conc = (t5 - t4) * 1000 / (N * 50)

    # --- backfill 健康度记录 + 超时门控判定 (每轮 50 次, seed 反馈) ---
    var t6 = clock()
    for i in range(N):
        var s = 0
        for k in range(50):
            var rt = RuntimeState()
            rt.start()
            rt.record_backfill((1 if ((seed + i + k) % 3 != 0) else 0), (seed + k) % 40)
            var gate = BackfillGate(20)
            s = s + gate.allow(rt, (seed + k) % 60)
            seed = seed * 31 + s + 1
        sink_i = sink_i + s
    var t7 = clock()
    var ns_backfill = (t7 - t6) * 1000 / (N * 50)

    print("runtime lifecycle : " + String(ns_lifecycle) + " ns/op")
    print("runtime memory    : " + String(ns_mem) + " ns/op")
    print("runtime concurrency: " + String(ns_conc) + " ns/op")
    print("runtime backfill  : " + String(ns_backfill) + " ns/op")
    print("sink " + String(sink_i) + " " + String(sink_f))
