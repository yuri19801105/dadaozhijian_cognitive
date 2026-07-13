from qixing import plan
from workspace import Workspace

@extern("clock")
def clock() abi("C") -> Int:
    ...

def main() raises:
    var N = 1000000

    var vec = SIMD[DType.int64, 6](0, 2, 6, 8, 0, 0)
    var chain = List[Int]()
    chain.append(0)  # CHIEN
    chain.append(2)  # ZHEN
    chain.append(5)  # LI
    chain.append(7)  # DUI

    var t0 = clock()
    for _ in range(N):
        var result = plan(vec, chain)
        var _rlen = len(result)
    var t1 = clock()
    print("plan_4chain_1M_ns:", (t1 - t0) * 1000 / N)