# ops/metrics_exporter.mojo — 真实 Metrics → Prometheus 文本导出(node_exporter textfile 兼容)
#
# 设计依据(GitHub/全网调研最优解): Mojo 1.0.0b2 无原生 HTTP 服务, 故不暴露常驻
#   /metrics HTTP 端点, 而是把 observability.metrics.Metrics 的快照按 Prometheus 文本
#   exposition 格式写入 .prom 文件, 由 node_exporter 的 textfile collector 定时抓取 ——
#   **无需容器、无需常驻 HTTP 服务**。这正是「不可能所有都容器化」原则下的落地:
#   把可观测性解耦成「二进制写文件 + 采集器读」。
#
# 真实落地: 直接复用 observability.Metrics.to_prometheus(), 不再使用参数化骨架。
#   运行服务在指标变化后调用 metrics.to_prometheus() 并写入 node_exporter textfile
#   目录(默认 /var/lib/node_exporter/); 本工具作为独立 CLI / CronJob 演示同一路径
#   —— 从聚合计数回填一个 Metrics 实例, 再导出 .prom。
#
# 用法:
#   mojo run -I . -I core ops/metrics_exporter.mojo <output.prom> [throughput] [ok] [degraded] [sample_latency_ms]
# 例:
#   mojo run -I . -I core ops/metrics_exporter.mojo /var/lib/node_exporter/dadaozhijian.prom 42 40 2 12

from std.io import FileHandle
from std.sys import argv
from observability import Metrics


def _atoi(s: String) -> Int:
    var v = 0
    var p = s.unsafe_ptr()
    for i in range(s.byte_length()):
        var c = Int(p[i]) & 0xFF
        if c >= 48 and c <= 57:
            v = v * 10 + (c - 48)
    return v


def main() raises:
    var args = argv()
    if len(args) < 2:
        print("usage: metrics_exporter.mojo <output.prom> [throughput] [ok] [degraded] [sample_latency_ms]")
        return
    var path = args[1]
    var throughput = 0
    var ok = 0
    var degraded = 0
    var sample_lat = 10
    if len(args) > 2:
        throughput = _atoi(args[2])
    if len(args) > 3:
        ok = _atoi(args[3])
    if len(args) > 4:
        degraded = _atoi(args[4])
    if len(args) > 5:
        sample_lat = _atoi(args[5])

    # 真实落地: 直接复用 observability.Metrics 的快照能力, 而非参数化骨架。
    var m = Metrics()
    m.seed(throughput, ok, degraded)
    m.seed_latency(sample_lat)

    var prom = m.to_prometheus()
    var f = FileHandle(path, "w")
    _ = f.write(prom)
    f.close()
    print("wrote metrics to ", path)
