# 太极 / 长期记忆 基准
# 测量每轮回灌开销: feedback()(写, O(1) append) 与 recall()(读, O(round) 重建上下文)
# 计时: C clock() 微秒, *1000 -> ns/op
#
# 注意: recall() 随历史轮数线性增长(重建上下文串), 故在固定历史 R=1024 下测读开销,
#       避免 N 次调用叠加成 O(N^2)。写开销 feedback() 为每轮 O(1), 直接测 1M 次。

from taiji import TaijiState

@extern("clock")
def clock() abi("C") -> Int:
    ...

def main() raises:
    var N = 1000000
    var decision = List[Int]()
    decision.append(0)
    decision.append(1)
    var output = "output"   # byte_length = 6

    # --- 写开销 feedback() : 每轮 O(1) append ---
    var tf = TaijiState(0)
    var t0 = clock()
    for _ in range(N):
        tf.feedback(output, decision, 5, 3)
    var t1 = clock()
    print("taiji_feedback_1M_ns:", (t1 - t0) * 1000 / N)

    # --- 读开销 recall() : 固定历史 R 下每轮 O(R) ---
    var R = 1024
    var tr = TaijiState(0)
    for _ in range(R):
        tr.feedback(output, decision, 5, 3)
    var t2 = clock()
    for _ in range(N):
        _ = tr.recall()
    var t3 = clock()
    print("taiji_recall_R", R, "_1M_ns:", (t3 - t2) * 1000 / N)
