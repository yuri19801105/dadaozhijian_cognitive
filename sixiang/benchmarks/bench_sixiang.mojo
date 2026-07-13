# === sixiang/benchmarks/bench_sixiang.mojo ===
# 四象基准: classify+canonical 派生、PhaseMachine.advance 流转。
# 计时用 C clock() 微秒(*1000 -> ns/op, 对齐 sancai/core 基准惯例)。
# 关键: 输入随循环索引变化(防常量折叠 DCE); advance 每轮重新播种(避免 1M 次耗散收敛到平衡态触发严格 classify 抛错)。
# 运行: .venv/bin/mojo run -I . -I core sixiang/benchmarks/bench_sixiang.mojo

from sixiang.quadrant import QuadrantClassifier, OLD_YIN, YOUNG_YANG, OLD_YANG, YOUNG_YIN, QUADRANT_COUNT
from sixiang.phase import PhaseMachine
from liangyi.dual import Dual

@extern("clock")
def clock() abi("C") -> Int:
    ...


def main() raises:
    var N = 1000000
    var sink = 0.0

    # 基准 1: from_dual + classify + canonical 全路径(输入经 sink 反馈成递推, 打破闭式求和/常量折叠)
    var t0 = clock()
    var d = Dual(0.5)
    for i in range(N):
        var q = QuadrantClassifier.from_dual(d)
        sink = sink + q.symbol.get_value()
        var fb = sink % 97.0
        d = Dual(fb * 0.013 + 0.5)
    var t1 = clock()
    print("sixiang.classify+canonical_ns_per_op:", (t1 - t0) * 1000 / N)

    # 基准 2: PhaseMachine.advance(四步流转, 每轮重新播种防收敛)
    var t2 = clock()
    for i in range(N):
        var pm = PhaseMachine(Dual(Float64(i) * 0.0001 + 0.5))
        pm.advance()
        sink = sink + pm.current.get_value()
    var t3 = clock()
    print("sixiang.advance_ns_per_op:", (t3 - t2) * 1000 / N)

    print("sink:", sink)
