# scheduler/policy.mojo — 调度策略装配（可插拔）
# SchedulerPolicy 携带生克率(gen_rate/ke_rate, 预留给未来 propagate 驱动)与 policy_id。
# 默认策略 default_policy() 不会失败；dispatcher 在装配失败时回退 policy_id=-1(降级而非崩溃)。
# 运行: mojo run -I . -I core scheduler/policy.mojo
struct SchedulerPolicy(Movable):
    var gen_rate: Float64
    var ke_rate: Float64
    var policy_id: Int
    def __init__(out self):
        self.gen_rate = 0.1
        self.ke_rate = 0.1
        self.policy_id = 0

def default_policy() -> SchedulerPolicy:
    return SchedulerPolicy()
