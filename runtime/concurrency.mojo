# runtime/concurrency.mojo — 并发/超时模型(确定性, 非 OS 线程)
# TaskSlot: 固定容量并发槽池(确定性限并发, 非阻塞热路径模型)。
# TimeoutGuard: 以 deadline/elapsed 建模非阻塞超时, with_timeout 失败返回降级标记(不阻塞状态根)。
# 运行: mojo run -I . -I core runtime/concurrency.mojo
struct TaskSlot(Movable):
    var capacity: Int
    var in_flight: Int
    def __init__(out self, capacity: Int):
        self.capacity = capacity
        self.in_flight = 0
    def acquire(mut self) -> Int:
        # 成功取槽=1, 满=0(非阻塞, 立即返回)。
        if self.in_flight >= self.capacity:
            return 0
        self.in_flight = self.in_flight + 1
        return 1
    def release(mut self):
        if self.in_flight > 0:
            self.in_flight = self.in_flight - 1
    def can_accept(self) -> Int:
        if self.in_flight < self.capacity:
            return 1
        return 0

struct TimeoutGuard(Movable):
    var deadline: Int
    var elapsed: Int
    def __init__(out self, deadline: Int):
        self.deadline = deadline
        self.elapsed = 0
    def tick(mut self, dt: Int):
        self.elapsed = self.elapsed + dt
    def expired(self) -> Int:
        if self.elapsed >= self.deadline:
            return 1
        return 0
    def with_timeout(mut self, dt: Int) -> Int:
        # 推进 dt; 在期内=1, 超时=0(降级标记, 不阻塞状态根)。
        self.tick(dt)
        if self.expired() == 1:
            return 0
        return 1
