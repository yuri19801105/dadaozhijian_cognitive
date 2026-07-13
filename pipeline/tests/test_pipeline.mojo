# pipeline/tests/test_pipeline.mojo — pipeline 端到端编排测试套件
# 运行: mojo run -I . -I core pipeline/tests/test_pipeline.mojo
from pipeline import (
    run_pipeline, run_pipeline_from_energies, run_pipeline_chains, run_pipeline_safe,
    PipelineResult, StageGraph, stage_name, stage_depends_on,
    STAGE_PARSE, STAGE_SCHEDULE, STAGE_SUPPLY, STAGE_ORDER, STAGE_DISPATCH, STAGE_COUNT,
)
from wuxing import WOOD, FIRE, EARTH, METAL, WATER

struct Counter(Movable):
    var passed: Int
    var failed: Int
    def __init__(out self):
        self.passed = 0
        self.failed = 0
    def check(mut self, cond: Bool, name: String):
        if cond:
            self.passed += 1
        else:
            self.failed += 1
            print("  FAIL:", name)

def _rep(n: Int) -> String:
    var s = String("")
    for _i in range(n):
        s = s + "x"
    return s^

def _energies(a: Float64, b: Float64, c: Float64, d: Float64, e: Float64) -> List[Float64]:
    var l = List[Float64]()
    l.append(a); l.append(b); l.append(c); l.append(d); l.append(e)
    return l^

def _contains(l: List[Int], v: Int) -> Bool:
    for i in range(len(l)):
        if l[i] == v:
            return True
    return False

# ---------------- stages ----------------
def test_stage_constants(mut c: Counter):
    # 有序校验替代常量折叠 (STAGE_PARSE==0 and ...) 以避免编译告警
    var expect = List[Int]()
    expect.append(STAGE_PARSE); expect.append(STAGE_SCHEDULE)
    expect.append(STAGE_SUPPLY); expect.append(STAGE_ORDER)
    expect.append(STAGE_DISPATCH); expect.append(STAGE_COUNT)
    var want = List[Int]()
    want.append(0); want.append(1); want.append(2); want.append(3); want.append(4); want.append(5)
    var ok = True
    for i in range(6):
        if expect[i] != want[i]:
            ok = False
    c.check(ok, "stage ids 0..5")

def test_stage_name(mut c: Counter):
    c.check(stage_name(STAGE_PARSE) == "parse", "name parse")
    c.check(stage_name(STAGE_SCHEDULE) == "schedule", "name schedule")
    c.check(stage_name(STAGE_SUPPLY) == "supply", "name supply")
    c.check(stage_name(STAGE_ORDER) == "order", "name order")
    c.check(stage_name(STAGE_DISPATCH) == "dispatch", "name dispatch")

def test_stage_name_unknown(mut c: Counter):
    c.check(stage_name(99) == "unknown", "name unknown")

def test_stage_depends_on(mut c: Counter):
    c.check(stage_depends_on(STAGE_PARSE) == -1, "parse no dep")
    c.check(stage_depends_on(STAGE_SCHEDULE) == STAGE_PARSE, "schedule<-parse")
    c.check(stage_depends_on(STAGE_SUPPLY) == STAGE_SCHEDULE, "supply<-schedule")
    c.check(stage_depends_on(STAGE_ORDER) == STAGE_SUPPLY, "order<-supply")
    c.check(stage_depends_on(STAGE_DISPATCH) == STAGE_ORDER, "dispatch<-order")
    c.check(stage_depends_on(99) == -2, "invalid dep -2")

def test_stage_graph_can_run(mut c: Counter):
    var g = StageGraph()
    c.check(g.can_run(STAGE_PARSE) == 1, "parse runnable initially")
    c.check(g.can_run(STAGE_SCHEDULE) == 0, "schedule blocked before parse")
    c.check(g.can_run(STAGE_DISPATCH) == 0, "dispatch blocked")
    g.mark_done(STAGE_PARSE)
    c.check(g.can_run(STAGE_SCHEDULE) == 1, "schedule runnable after parse")
    c.check(g.can_run(STAGE_SUPPLY) == 0, "supply still blocked")
    c.check(g.can_run(-1) == 0, "invalid stage not runnable")
    c.check(g.can_run(99) == 0, "out-of-range not runnable")

def test_stage_graph_validate_and_all_done(mut c: Counter):
    var g = StageGraph()
    c.check(g.validate() == 1, "fresh graph valid")
    c.check(g.all_done() == 0, "not all done initially")
    g.mark_done(STAGE_PARSE)
    g.mark_done(STAGE_SCHEDULE)
    g.mark_done(STAGE_SUPPLY)
    g.mark_done(STAGE_ORDER)
    g.mark_done(STAGE_DISPATCH)
    c.check(g.all_done() == 1, "all done after marking")

def test_stage_graph_run_order(mut c: Counter):
    var g = StageGraph()
    var order = g.run_order()
    c.check(len(order) == STAGE_COUNT, "run_order length")
    var ok = True
    for i in range(len(order)):
        if order[i] != i:
            ok = False
    c.check(ok, "run_order topological 0..4")

def test_stage_graph_mark_done(mut c: Counter):
    var g = StageGraph()
    g.mark_done(STAGE_ORDER)
    c.check(g.is_done(STAGE_ORDER) == 1, "order marked done")
    c.check(g.is_done(STAGE_SUPPLY) == 0, "supply still pending")

# ---------------- orchestrator: parse stage (via run_pipeline) ----------------
def test_run_pipeline_parse_phase(mut c: Counter) raises:
    var r1 = run_pipeline("", 0.5, 8, 4, 20)
    c.check(r1.phase == WATER, "empty -> water")
    var r2 = run_pipeline("hi", 0.5, 8, 4, 20)
    c.check(r2.phase == WOOD, "len2 -> wood")
    var r3 = run_pipeline(_rep(11), 0.5, 8, 4, 20)
    c.check(r3.phase == FIRE, "len11 -> fire")
    var r4 = run_pipeline(_rep(60), 0.5, 8, 4, 20)
    c.check(r4.phase == EARTH, "len60 -> earth")
    var r5 = run_pipeline(_rep(120), 0.5, 8, 4, 20)
    c.check(r5.phase == METAL, "len120 -> metal")

def test_run_pipeline_parse_intensity(mut c: Counter) raises:
    c.check(run_pipeline("", 0.5, 8, 4, 20).intensity == 1, "empty intensity=1")
    c.check(run_pipeline(_rep(10), 0.5, 8, 4, 20).intensity == 1, "len10 intensity=1")
    c.check(run_pipeline(_rep(50), 0.5, 8, 4, 20).intensity == 5, "len50 intensity=5")
    c.check(run_pipeline(_rep(95), 0.5, 8, 4, 20).intensity == 9, "len95 intensity=9 (clamp)")

def test_run_pipeline_basic(mut c: Counter) raises:
    var r = run_pipeline("hello world", 0.5, 8, 4, 20)
    c.check(r.ok == 1, "ok=1")
    c.check(r.failed_stage == -1, "no failure")
    c.check(r.plan_len > 0, "plan non-empty")
    c.check(r.confidence > 0.0, "confidence>0")
    c.check(r.policy_id == 0, "default policy id=0")
    c.check(r.candidate_len == 3, "candidate chain len=3")

def test_run_pipeline_empty(mut c: Counter) raises:
    var r = run_pipeline("", 0.5, 8, 4, 20)
    c.check(r.ok == 1, "empty text still ok (degraded intensity)")
    c.check(r.plan_len > 0, "empty text yields plan")

def test_run_pipeline_chains(mut c: Counter) raises:
    var chains = run_pipeline_chains("hello world", 0.5, 8, 4, 20)
    c.check(len(chains) == 2, "two intermediate chains")
    c.check(len(chains[0]) == 3, "candidate chain len=3")
    c.check(len(chains[1]) == 3, "planned chain len=3")
    # 规划链是候选链的同元素重排(优先级排序)
    for i in range(len(chains[0])):
        c.check(_contains(chains[1], chains[0][i]), "planned contains candidate[i]")

def test_run_pipeline_from_energies(mut c: Counter) raises:
    var e = _energies(5.0, 1.0, 1.0, 1.0, 1.0)   # 木主导
    var r = run_pipeline_from_energies(e, 0.5, 8, 4, 20)
    c.check(r.ok == 1, "from_energies ok=1")
    c.check(r.phase == WOOD, "dominant wood")
    c.check(r.plan_len == 3, "plan len=3")
    c.check(r.confidence > 0.0, "confidence>0")

def test_run_pipeline_candidate_plan_membership(mut c: Counter) raises:
    var r = run_pipeline("hello world", 0.5, 8, 4, 20)
    var cand = List[Int]()
    for i in range(r.candidate_len):
        cand.append(r.candidate_at(i))
    var plan = List[Int]()
    for i in range(r.plan_len):
        plan.append(r.plan_at(i))
    c.check(r.plan_len == r.candidate_len, "plan len == candidate len")
    for i in range(len(cand)):
        c.check(_contains(plan, cand[i]), "plan contains candidate element")

# ---------------- safe path (no raises) ----------------
def test_run_pipeline_safe_success(mut c: Counter):
    var r = run_pipeline_safe("hello world", 0.5, 8, 4, 20)
    c.check(r.ok == 1, "safe ok=1")
    c.check(r.plan_len > 0, "safe plan non-empty")

def test_run_pipeline_safe_degrade(mut c: Counter):
    # max_depth<=0 → build_supply raises → safe 兜底中性降级
    var r = run_pipeline_safe("hello world", 0.5, 0, 4, 20)
    c.check(r.ok == 0, "safe degrade ok=0")
    c.check(r.failed_stage == STAGE_SCHEDULE, "degrade marker stage")
    c.check(r.plan_len == 0, "no plan on degrade")
    c.check(r.phase == WATER, "degrade phase->water")

def test_run_pipeline_safe_no_raise(mut c: Counter):
    # 整体函数签名非 raises, 必须不向外抛
    var r = run_pipeline_safe("x", 0.5, 0, 4, 20)
    c.check(r.ok == 0, "no-raise path returns degraded result")

# ---------------- PipelineResult carrier ----------------
def test_pipeline_result_append_candidate(mut c: Counter):
    var r = PipelineResult()
    r.append_candidate(3)
    r.append_candidate(1)
    r.append_candidate(4)
    c.check(r.candidate_len == 3, "candidate len 3")
    c.check(r.candidate_at(0) == 3, "cand[0]=3")
    c.check(r.candidate_at(1) == 1, "cand[1]=1")
    c.check(r.candidate_at(2) == 4, "cand[2]=4")

def test_pipeline_result_append_plan(mut c: Counter):
    var r = PipelineResult()
    r.append_plan(2)
    r.append_plan(0)
    c.check(r.plan_len == 2, "plan len 2")
    c.check(r.plan_at(0) == 2, "plan[0]=2")
    c.check(r.plan_at(1) == 0, "plan[1]=0")

def test_pipeline_result_candidate_at_oob(mut c: Counter):
    var r = PipelineResult()
    r.append_candidate(7)
    c.check(r.candidate_at(0) == 7, "valid idx")
    c.check(r.candidate_at(5) == -1, "oob -> -1")
    c.check(r.candidate_at(-1) == -1, "neg idx -> -1")

def test_pipeline_result_plan_at_oob(mut c: Counter):
    var r = PipelineResult()
    r.append_plan(9)
    c.check(r.plan_at(0) == 9, "valid idx")
    c.check(r.plan_at(3) == -1, "oob -> -1")

def test_run_pipeline_policy_default(mut c: Counter) raises:
    var r = run_pipeline(_rep(30), 0.5, 8, 4, 20)
    c.check(r.policy_id == 0, "default policy id")

def main() raises:
    var c = Counter()
    test_stage_constants(c)
    test_stage_name(c)
    test_stage_name_unknown(c)
    test_stage_depends_on(c)
    test_stage_graph_can_run(c)
    test_stage_graph_validate_and_all_done(c)
    test_stage_graph_run_order(c)
    test_stage_graph_mark_done(c)
    test_run_pipeline_parse_phase(c)
    test_run_pipeline_parse_intensity(c)
    test_run_pipeline_basic(c)
    test_run_pipeline_empty(c)
    test_run_pipeline_chains(c)
    test_run_pipeline_from_energies(c)
    test_run_pipeline_candidate_plan_membership(c)
    test_run_pipeline_safe_success(c)
    test_run_pipeline_safe_degrade(c)
    test_run_pipeline_safe_no_raise(c)
    test_pipeline_result_append_candidate(c)
    test_pipeline_result_append_plan(c)
    test_pipeline_result_candidate_at_oob(c)
    test_pipeline_result_plan_at_oob(c)
    test_run_pipeline_policy_default(c)
    print("pipeline -> passed:", c.passed, " failed:", c.failed)
    if c.failed > 0:
        raise Error("pipeline tests failed")
