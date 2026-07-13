from wu_xing import *
from workspace import Workspace

@extern("clock")
def clock() abi("C") -> Int:
    ...

def main() raises:
    var ws = Workspace()
    var N = 1000000

    var t0 = clock()
    for _ in range(N):
        var sig = PhaseSignal()
        sig.phase = WOOD
        sig.intensity = 5
        _ = schedule(ws, sig)
    var t1 = clock()
    print("wood_schedule_1M_ms:", (t1 - t0) // 1000)

    var t2 = clock()
    for _ in range(N):
        var sig = PhaseSignal()
        sig.phase = FIRE
        sig.intensity = 7
        _ = schedule(ws, sig)
    var t3 = clock()
    print("fire_schedule_1M_ms:", (t3 - t2) // 1000)

    var t4 = clock()
    for _ in range(N):
        _ = generate_next(WOOD)
        _ = restrain_target(WOOD)
    var t5 = clock()
    print("shengke_1M_ms:", (t5 - t4) // 1000)

    var t6 = clock()
    for _ in range(N):
        var oc = OverloadCounter()
        _ = oc.track(ZHEN)
        _ = oc.track(ZHEN)
        _ = oc.track(ZHEN)
        _ = oc.track(ZHEN)
    var t7 = clock()
    print("overload_4x1M_ms:", (t7 - t6) // 1000)
