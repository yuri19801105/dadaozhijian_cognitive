# runtime/memory.mojo — 内存预算: 预算字节 + 已用 + alloc/free + 利用率
# 扇出规模受预算约束: alloc 超预算 raises → 调用方降级为局部执行。
# 运行: mojo run -I . -I core runtime/memory.mojo
struct MemoryBudget(Movable):
    var budget: Int
    var used: Int
    def __init__(out self, budget: Int):
        self.budget = budget
        self.used = 0
    def alloc(mut self, size: Int) raises:
        # 超预算 → raises(调用方决定降级)。
        if self.used + size > self.budget:
            raise Error("MemoryBudget: 超预算分配 " + String(size) + " 字节")
        self.used = self.used + size
    def free(mut self, size: Int):
        self.used = self.used - size
        if self.used < 0:
            self.used = 0
    def available(self) -> Int:
        return self.budget - self.used
    def utilization(self) -> Float64:
        # 0.0..1.0。budget<=0 视为满(防除零)。
        if self.budget <= 0:
            return 1.0
        return Float64(self.used) / Float64(self.budget)
