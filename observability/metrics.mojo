# observability/metrics.mojo — 运行时指标(延迟/吞吐/五行均衡度/鲁棒性退化%)
# 固定窗口采样(避免 List 嵌套 → Movable 可按值返回/传参)。
# 运行: mojo run -I . -I core observability/metrics.mojo
from wuxing import variance, is_balanced


def _ftoa(v: Float64) -> String:
    # Prometheus 浮点文本(固定 3 位小数, 符号安全); 用于 gauge 值导出。
    if v < 0.0:
        return "-" + _ftoa(-v)
    var scaled = Int(v * 1000.0)
    var int_part = scaled // 1000
    var frac = scaled - int_part * 1000
    var s = String(int_part) + "."
    if frac < 100:
        s = s + "0"
    if frac < 10:
        s = s + "0"
    s = s + String(frac)
    return s^


struct Metrics(Movable):
    # 延迟窗口(8 样本循环覆盖) + 计数 + 吞吐 + 五行均衡度缓存。
    var lat0: Int; var lat1: Int; var lat2: Int; var lat3: Int
    var lat4: Int; var lat5: Int; var lat6: Int; var lat7: Int
    var lat_len: Int
    var ok_count: Int
    var degraded_count: Int
    var throughput: Int
    var last_balance_var: Float64    # 最近一次五行方差(均衡度代理)
    def __init__(out self):
        self.lat0 = 0; self.lat1 = 0; self.lat2 = 0; self.lat3 = 0
        self.lat4 = 0; self.lat5 = 0; self.lat6 = 0; self.lat7 = 0
        self.lat_len = 0
        self.ok_count = 0
        self.degraded_count = 0
        self.throughput = 0
        self.last_balance_var = -1.0
    def _set_lat(mut self, idx: Int, v: Int):
        if idx == 0: self.lat0 = v
        elif idx == 1: self.lat1 = v
        elif idx == 2: self.lat2 = v
        elif idx == 3: self.lat3 = v
        elif idx == 4: self.lat4 = v
        elif idx == 5: self.lat5 = v
        elif idx == 6: self.lat6 = v
        elif idx == 7: self.lat7 = v
    def _lat_at(self, idx: Int) -> Int:
        if idx == 0: return self.lat0
        if idx == 1: return self.lat1
        if idx == 2: return self.lat2
        if idx == 3: return self.lat3
        if idx == 4: return self.lat4
        if idx == 5: return self.lat5
        if idx == 6: return self.lat6
        if idx == 7: return self.lat7
        return 0
    def record(mut self, latency_ms: Int, ok: Int, degraded: Int):
        # 循环写入窗口(容量 8)。
        var idx = self.lat_len % 8
        self._set_lat(idx, latency_ms)
        if self.lat_len < 8:
            self.lat_len = self.lat_len + 1
        if ok == 1:
            self.ok_count = self.ok_count + 1
        if degraded == 1:
            self.degraded_count = self.degraded_count + 1
        self.throughput = self.throughput + 1
    def _sorted_latencies(self) -> List[Int]:
        # 选择排序(升序), 返回新 List(不修改窗口)。
        var arr = List[Int]()
        for i in range(self.lat_len):
            arr.append(self._lat_at(i))
        for i in range(len(arr)):
            var min_idx = i
            for j in range(i + 1, len(arr)):
                if arr[j] < arr[min_idx]:
                    min_idx = j
            var tmp = arr[i]
            arr[i] = arr[min_idx]
            arr[min_idx] = tmp
        return arr^
    def p95(self) -> Int:
        if self.lat_len == 0:
            return 0
        var s = self._sorted_latencies()
        # 95th 百分位索引(向上取整), 样本少时近似取高位。
        var idx = (self.lat_len * 95) / 100
        if idx >= self.lat_len:
            idx = self.lat_len - 1
        return s[idx]
    def p50(self) -> Int:
        if self.lat_len == 0:
            return 0
        var s = self._sorted_latencies()
        var idx = self.lat_len / 2
        return s[idx]
    def robustness_degradation(self) -> Float64:
        # 退化% = degraded / (ok + degraded); 无样本=0。
        var total = self.ok_count + self.degraded_count
        if total == 0:
            return 0.0
        return Float64(self.degraded_count) / Float64(total)
    def set_balance(self, energies: List[Float64]):
        # 以五行方差作均衡度代理(越低越均衡)。
        self.last_balance_var = variance(energies)
    def snapshot(self) -> String:
        var s = String("[metrics] p50=")
        s = s + String(self.p50()) + "ms p95=" + String(self.p95()) + "ms"
        s = s + " throughput=" + String(self.throughput)
        s = s + " ok=" + String(self.ok_count) + " degraded=" + String(self.degraded_count)
        s = s + " robustness_degradation=" + String(Int(self.robustness_degradation() * 100.0)) + "%"
        if self.last_balance_var >= 0.0:
            s = s + " five_element_var=" + String(Int(self.last_balance_var * 1000.0)) + "m"
        return s^
    def seed(mut self, throughput: Int, ok: Int, degraded: Int):
        # 由外部聚合源(ledger / 跨进程计数)回填计数器, 便于从既有运行态重建快照。
        self.throughput = throughput
        self.ok_count = ok
        self.degraded_count = degraded
    def seed_latency(mut self, ms: Int):
        # 把一个代表性延迟样本压入窗口(不增减吞吐/ok/degraded 计数), 使 p50/p95 有意义。
        var idx = self.lat_len % 8
        self._set_lat(idx, ms)
        if self.lat_len < 8:
            self.lat_len = self.lat_len + 1
    def to_prometheus(self) -> String:
        # 把指标快照序列化为 Prometheus 文本 exposition 格式(供 node_exporter
        #   textfile collector 抓取); Mojo 1.0.0b2 无原生 HTTP, 故走「写文件」路径。
        var s = String()
        # --- counters ---
        s = s + "# HELP dadaozhijian_request_total 累计请求数(吞吐)\n"
        s = s + "# TYPE dadaozhijian_request_total counter\n"
        s = s + "dadaozhijian_request_total " + String(self.throughput) + "\n"
        s = s + "# HELP dadaozhijian_ok_total 成功(未降级)请求累计\n"
        s = s + "# TYPE dadaozhijian_ok_total counter\n"
        s = s + "dadaozhijian_ok_total " + String(self.ok_count) + "\n"
        s = s + "# HELP dadaozhijian_degraded_total 鲁棒性降级请求累计\n"
        s = s + "# TYPE dadaozhijian_degraded_total counter\n"
        s = s + "dadaozhijian_degraded_total " + String(self.degraded_count) + "\n"
        # --- gauges ---
        s = s + "# HELP dadaozhijian_latency_p50_ms p50 判定延迟(ms)\n"
        s = s + "# TYPE dadaozhijian_latency_p50_ms gauge\n"
        s = s + "dadaozhijian_latency_p50_ms " + String(self.p50()) + "\n"
        s = s + "# HELP dadaozhijian_latency_p95_ms p95 判定延迟(ms)\n"
        s = s + "# TYPE dadaozhijian_latency_p95_ms gauge\n"
        s = s + "dadaozhijian_latency_p95_ms " + String(self.p95()) + "\n"
        s = s + "# HELP dadaozhijian_robustness_degradation_ratio 鲁棒性退化比例(0..1)\n"
        s = s + "# TYPE dadaozhijian_robustness_degradation_ratio gauge\n"
        s = s + "dadaozhijian_robustness_degradation_ratio " + _ftoa(self.robustness_degradation()) + "\n"
        if self.last_balance_var >= 0.0:
            s = s + "# HELP dadaozhijian_five_element_variance 五行均衡方差(越低越均衡)\n"
            s = s + "# TYPE dadaozhijian_five_element_variance gauge\n"
            s = s + "dadaozhijian_five_element_variance " + _ftoa(self.last_balance_var) + "\n"
        return s^
