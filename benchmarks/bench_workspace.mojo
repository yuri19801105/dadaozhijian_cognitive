# 九宫 - 工作记忆基准测试 (M3)
# 运行: .venv/bin/mojo -I src benchmarks/bench_workspace.mojo
from workspace import Workspace

@extern("clock")
def clock() abi("C") -> Int:
    ...

def main() raises:
    # 测试 hold + update 的低延时性（典型推理流程）
    var ws = Workspace()
    var start = clock()
    for i in range(10000):
        _ = ws.hold(i)
        ws.update_attention(i % 9)
    var mid = clock()
    print("10000 iterations (hold+attention) -> ", (mid - start) // 1000, "ms")

    # 测试注意力检索
    ws = Workspace()
    start = clock()
    for i in range(10000):
        _ = ws.hold(i)
        ws.update_attention(i % 9)
        _ = ws.attention_retrieve()
    var end = clock()
    print("10000 iterations (hold+attention+retrieve) -> ", (end - start) // 1000, "ms")
    print("done")
