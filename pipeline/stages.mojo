# pipeline/stages.mojo — 阶段定义与依赖图（阶段图 DAG）
# 阶段: 解析 → 五行调度 → 六合供给 → 七星定序 → 总派发。
# 依赖关系为线性紧邻链(dep = stage-1); StageGraph 承载"已完成"标记,
# 供编排器按依赖门控(can_run) + 断点重放。运行: mojo run -I . -I core pipeline/stages.mojo

comptime STAGE_PARSE: Int = 0
comptime STAGE_SCHEDULE: Int = 1
comptime STAGE_SUPPLY: Int = 2
comptime STAGE_ORDER: Int = 3
comptime STAGE_DISPATCH: Int = 4
comptime STAGE_COUNT: Int = 5

def stage_name(id: Int) -> String:
    if id == STAGE_PARSE: return "parse"
    if id == STAGE_SCHEDULE: return "schedule"
    if id == STAGE_SUPPLY: return "supply"
    if id == STAGE_ORDER: return "order"
    if id == STAGE_DISPATCH: return "dispatch"
    return "unknown"

def stage_depends_on(id: Int) -> Int:
    # 返回必须先完成的阶段 id; -1 = 无前置; <-1 = 非法阶段。
    if id == STAGE_PARSE: return -1
    if id == STAGE_SCHEDULE: return STAGE_PARSE
    if id == STAGE_SUPPLY: return STAGE_SCHEDULE
    if id == STAGE_ORDER: return STAGE_SUPPLY
    if id == STAGE_DISPATCH: return STAGE_ORDER
    return -2

struct StageGraph(Movable):
    # 五阶段完成标记(0/1), 固定标量槽保 Movable 可按值返回。
    var f0: Int; var f1: Int; var f2: Int; var f3: Int; var f4: Int
    def __init__(out self):
        self.f0 = 0; self.f1 = 0; self.f2 = 0; self.f3 = 0; self.f4 = 0
    def _flag(self, stage: Int) -> Int:
        if stage == 0: return self.f0
        if stage == 1: return self.f1
        if stage == 2: return self.f2
        if stage == 3: return self.f3
        if stage == 4: return self.f4
        return 0
    def _set_flag(mut self, stage: Int, v: Int):
        if stage == 0: self.f0 = v
        elif stage == 1: self.f1 = v
        elif stage == 2: self.f2 = v
        elif stage == 3: self.f3 = v
        elif stage == 4: self.f4 = v
    def is_done(self, stage: Int) -> Int:
        if stage < 0 or stage >= STAGE_COUNT: return 0
        return self._flag(stage)
    def mark_done(mut self, stage: Int):
        if stage < 0 or stage >= STAGE_COUNT: return
        self._set_flag(stage, 1)
    def can_run(self, stage: Int) -> Int:
        # 依赖门控: 无前置(PARSE) 或 前置已完成 → 可运行; 非法阶段 → 不可。
        if stage < 0 or stage >= STAGE_COUNT: return 0
        var dep = stage_depends_on(stage)
        if dep == -1: return 1
        if dep < 0: return 0
        return self.is_done(dep)
    def all_done(self) -> Int:
        for s in range(STAGE_COUNT):
            if self.is_done(s) == 0: return 0
        return 1
    def validate(self) -> Int:
        # 依赖须合法且形成线性紧邻链(dep == stage-1, 仅 PARSE 无前置)。
        for s in range(STAGE_COUNT):
            var dep = stage_depends_on(s)
            if dep == -1:
                if s != STAGE_PARSE: return 0
            else:
                if dep < 0 or dep >= STAGE_COUNT: return 0
                if dep != s - 1: return 0
        return 1
    def run_order(self) -> List[Int]:
        # 线性链 → id 序即拓扑序。
        var l = List[Int]()
        for s in range(STAGE_COUNT):
            l.append(s)
        return l^
