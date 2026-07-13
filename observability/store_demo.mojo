# === observability/store_demo.mojo ===
# 跨进程持久化串联演示：以真实回灌衔接桥(taiji.reinjection)驱动
#   begin_lineage -> reinject_safe(lineage_id) 链路，再把 ledger 序列化为
#   JSON-Lines 输出到 stdout，由 store_reader.py 从 stdin 消费校验。
#
# 运行：
#   mojo run -I . -I core observability/store_demo.mojo | python3 observability/store_reader.py

from pipeline import PipelineResult
from shifang import ShifangOutput
from observability.tracing import Tracer, TraceSpan
from observability.metrics import Metrics
from taiji.reinjection import ReinjectionBridge
from wuxing import WOOD, FIRE, EARTH, METAL, WATER


def _mklist(a: Int, b: Int, c: Int) -> List[Int]:
    var l = List[Int]()
    l.append(a); l.append(b); l.append(c)
    return l^


def _result(phase: Int, conf: Float64, plan: List[Int]) -> PipelineResult:
    var r = PipelineResult()
    r.phase = phase
    r.confidence = conf
    r.policy_id = 3
    for i in range(len(plan)):
        r.append_plan(plan[i])
    return r^


def _output(ok: Int, degraded: Int, actions: List[Int]) -> ShifangOutput:
    var o = ShifangOutput()
    for i in range(len(actions)):
        o._set(i, actions[i])
    o.ok = ok
    o.degraded = degraded
    return o^


def _tracer(elems: List[Int]) -> Tracer:
    var t = Tracer()
    for i in range(len(elems)):
        var sp = TraceSpan()
        sp.trace_id = i
        sp.stage = i
        sp.element = elems[i]
        sp.decision = elems[i]
        sp.confidence_milli = 850
        sp.policy_id = 3
        t.add_span(sp)
    return t^


def _metrics(ok: Int, degraded: Int) -> Metrics:
    var m = Metrics()
    m.record(20, ok, degraded)
    return m^


def main() raises:
    # 一轮回灌：成功链路
    var b = ReinjectionBridge(7, 1.0, 1e9)
    var plan1 = _mklist(WOOD, FIRE, EARTH)
    var lid1 = b.begin_lineage(_tracer(plan1), _result(2, 0.9, plan1))
    _ = b.reinject_safe(_result(2, 0.9, plan1), _output(1, 0, plan1),
                        _tracer(plan1), _metrics(1, 0), "用户：推演春耕", lid1)

    # 一轮回灌：被校验拒绝（非法相位），仍记入 ledger 的 backfill(status=0) 与 trace 串联
    var plan2 = _mklist(METAL, WATER, WOOD)
    var lid2 = b.begin_lineage(_tracer(plan2), _result(9, 0.6, plan2))
    _ = b.reinject_safe(_result(9, 0.6, plan2), _output(1, 0, plan2),
                        _tracer(plan2), _metrics(1, 0), "用户：问秋收", lid2)

    # 一轮回灌：扇出降级，强度折半，status=1 但 degraded=1
    var plan3 = _mklist(WATER, WOOD, FIRE)
    var lid3 = b.begin_lineage(_tracer(plan3), _result(1, 0.7, plan3))
    _ = b.reinject_safe(_result(1, 0.7, plan3), _output(1, 1, plan3),
                        _tracer(plan3), _metrics(0, 1), "用户：问冬藏", lid3)

    print("[store_demo] 共", b.ledger.size(), "条 ledger 记录，导出的 JSON-Lines：")
    b.ledger.emit()
