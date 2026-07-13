# pipeline/orchestrator.mojo — 阶段图驱动端到端编排（重构 MVP 线性 run_cycle）
# 阶段: 解析 → 五行调度 → 六合供给 → 七星定序 → 总派发。
# 由 StageGraph.run_order() 循环 + can_run 门控执行; 任一阶段失败(raises)即停摆, 记 failed_stage。
# 运行: mojo run -I . -I core pipeline/orchestrator.mojo
from wuxing import (
    schedule, schedule_from_phase, dominant_element, mean_energy, ScheduleDecision,
    WOOD, FIRE, EARTH, METAL, WATER,
)
from liuhe import build_supply, SupplyVector
from qixing import build_sequence, DecisionSequence
from scheduler import DispatchPlan, default_policy
from .stages import (
    STAGE_PARSE, STAGE_SCHEDULE, STAGE_SUPPLY, STAGE_ORDER, STAGE_DISPATCH,
    StageGraph,
)

struct PipelineResult(Movable):
    # 全链路产物载体; 固定标量槽保 Movable 可按值返回。
    var phase: Int
    var intensity: Int
    var candidate_len: Int
    var c0: Int; var c1: Int; var c2: Int; var c3: Int
    var c4: Int; var c5: Int; var c6: Int; var c7: Int
    var plan_len: Int
    var p0: Int; var p1: Int; var p2: Int; var p3: Int
    var p4: Int; var p5: Int; var p6: Int; var p7: Int
    var confidence: Float64
    var policy_id: Int
    var ok: Int
    var failed_stage: Int
    def __init__(out self):
        self.phase = 0; self.intensity = 0; self.candidate_len = 0
        self.c0 = -1; self.c1 = -1; self.c2 = -1; self.c3 = -1
        self.c4 = -1; self.c5 = -1; self.c6 = -1; self.c7 = -1
        self.plan_len = 0
        self.p0 = -1; self.p1 = -1; self.p2 = -1; self.p3 = -1
        self.p4 = -1; self.p5 = -1; self.p6 = -1; self.p7 = -1
        self.confidence = 0.0; self.policy_id = 0
        self.ok = 0; self.failed_stage = -1
    def append_candidate(mut self, e: Int):
        if self.candidate_len == 0: self.c0 = e
        elif self.candidate_len == 1: self.c1 = e
        elif self.candidate_len == 2: self.c2 = e
        elif self.candidate_len == 3: self.c3 = e
        elif self.candidate_len == 4: self.c4 = e
        elif self.candidate_len == 5: self.c5 = e
        elif self.candidate_len == 6: self.c6 = e
        elif self.candidate_len == 7: self.c7 = e
        else: return
        self.candidate_len += 1
    def candidate_at(self, i: Int) -> Int:
        if i == 0: return self.c0
        if i == 1: return self.c1
        if i == 2: return self.c2
        if i == 3: return self.c3
        if i == 4: return self.c4
        if i == 5: return self.c5
        if i == 6: return self.c6
        if i == 7: return self.c7
        return -1
    def append_plan(mut self, e: Int):
        if self.plan_len == 0: self.p0 = e
        elif self.plan_len == 1: self.p1 = e
        elif self.plan_len == 2: self.p2 = e
        elif self.plan_len == 3: self.p3 = e
        elif self.plan_len == 4: self.p4 = e
        elif self.plan_len == 5: self.p5 = e
        elif self.plan_len == 6: self.p6 = e
        elif self.plan_len == 7: self.p7 = e
        else: return
        self.plan_len += 1
    def plan_at(self, i: Int) -> Int:
        if i == 0: return self.p0
        if i == 1: return self.p1
        if i == 2: return self.p2
        if i == 3: return self.p3
        if i == 4: return self.p4
        if i == 5: return self.p5
        if i == 6: return self.p6
        if i == 7: return self.p7
        return -1

def _compute_intensity(text: String) -> Int:
    # 字节长 / 10 截断 1..9; 空输入下限 1(防止 schedule_from_phase 全零 raise)。
    var length = text.byte_length()
    if length == 0:
        return 1
    var raw = length / 10
    if raw < 1: return 1
    if raw > 9: return 9
    return raw

def _detect_phase(text: String) -> Int:
    # 空输入 → 水(收藏/归静, 中性偏静); 短→木 / 中→火 / 长→土 / 极长→金。
    var length = text.byte_length()
    if length == 0:
        return WATER
    elif length < 10: return WOOD
    elif length < 50: return FIRE
    elif length < 100: return EARTH
    else: return METAL

def _intensity_from_energies(energies: List[Float64]) -> Int:
    # 由能量均值派生代表性强度(截断 1..9)。
    var m = mean_energy(energies)
    var it = Int(m * 10.0)
    if it < 1: return 1
    if it > 9: return 9
    return it

def run_pipeline(text: String, focus: Float64, max_depth: Int,
                 chain_depth: Int, ground: Int) raises -> PipelineResult:
    # 文本入口: 阶段图驱动端到端编排。
    var g = StageGraph()
    var res = PipelineResult()
    var decision = ScheduleDecision()           # 占位, SCHEDULE 阶段被覆盖
    var supply = SupplyVector()
    var seq = DecisionSequence()
    var plan = DispatchPlan()

    for stage in g.run_order():
        if g.can_run(stage) == 0:
            res.ok = 0
            res.failed_stage = stage
            return res^
        if stage == STAGE_PARSE:
            res.phase = _detect_phase(text)
            res.intensity = _compute_intensity(text)
        elif stage == STAGE_SCHEDULE:
            decision = schedule_from_phase(res.phase, Float64(res.intensity))
            var cand = decision.chain_list()
            for i in range(len(cand)):
                res.append_candidate(cand[i])
        elif stage == STAGE_SUPPLY:
            var energies = decision.weights_list()
            supply = build_supply(energies, focus, max_depth, chain_depth, ground)
        elif stage == STAGE_ORDER:
            seq = build_sequence(decision, supply)
        elif stage == STAGE_DISPATCH:
            for i in range(seq.s_len):
                plan.append(seq.step_at(i))
            plan.confidence = decision.confidence
            plan.policy_id = default_policy().policy_id
            for i in range(plan.s_len):
                res.append_plan(plan.step_at(i))
            res.confidence = plan.confidence
            res.policy_id = plan.policy_id
        g.mark_done(stage)

    res.ok = 1
    res.failed_stage = -1
    return res^

def run_pipeline_from_energies(energies: List[Float64], focus: Float64,
                               max_depth: Int, chain_depth: Int,
                               ground: Int) raises -> PipelineResult:
    # 能量入口: 主导元素派生相位, 直接 wuxing.schedule(避免 quadrant/element 映射错位)。
    var g = StageGraph()
    var res = PipelineResult()
    var decision = ScheduleDecision()
    var supply = SupplyVector()
    var seq = DecisionSequence()
    var plan = DispatchPlan()

    for stage in g.run_order():
        if g.can_run(stage) == 0:
            res.ok = 0
            res.failed_stage = stage
            return res^
        if stage == STAGE_PARSE:
            res.phase = dominant_element(energies)
            res.intensity = _intensity_from_energies(energies)
        elif stage == STAGE_SCHEDULE:
            decision = schedule(energies)
            var cand = decision.chain_list()
            for i in range(len(cand)):
                res.append_candidate(cand[i])
        elif stage == STAGE_SUPPLY:
            var e2 = decision.weights_list()
            supply = build_supply(e2, focus, max_depth, chain_depth, ground)
        elif stage == STAGE_ORDER:
            seq = build_sequence(decision, supply)
        elif stage == STAGE_DISPATCH:
            for i in range(seq.s_len):
                plan.append(seq.step_at(i))
            plan.confidence = decision.confidence
            plan.policy_id = default_policy().policy_id
            for i in range(plan.s_len):
                res.append_plan(plan.step_at(i))
            res.confidence = plan.confidence
            res.policy_id = plan.policy_id
        g.mark_done(stage)

    res.ok = 1
    res.failed_stage = -1
    return res^

def run_pipeline_chains(text: String, focus: Float64, max_depth: Int,
                        chain_depth: Int, ground: Int) raises -> List[List[Int]]:
    # 可视化(M8 接入点): 返回 [候选链(五行调度), 规划链(七星定序)]。
    var res = run_pipeline(text, focus, max_depth, chain_depth, ground)
    if res.ok == 0:
        return List[List[Int]]()
    var out = List[List[Int]]()
    var cand = List[Int]()
    for i in range(res.candidate_len):
        cand.append(res.candidate_at(i))
    out.append(cand^)
    var pl = List[Int]()
    for i in range(res.plan_len):
        pl.append(res.plan_at(i))
    out.append(pl^)
    return out^

def run_pipeline_safe(text: String, focus: Float64, max_depth: Int,
                      chain_depth: Int, ground: Int) -> PipelineResult:
    # 中性降级: 任何异常 → ok=0, 相位回落水, 强度下限 1, 不崩溃。
    try:
        return run_pipeline(text, focus, max_depth, chain_depth, ground)
    except:
        var r = PipelineResult()
        r.ok = 0
        r.failed_stage = STAGE_SCHEDULE
        r.phase = WATER
        r.intensity = 1
        return r^
