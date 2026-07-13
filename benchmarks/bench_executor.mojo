from executor import execute
from workspace import Workspace
from trigram import CHIEN, KUN, ZHEN, XUN, KAN, LI, GEN, DUI

@extern("clock")
def clock() abi("C") -> Int:
    ...

def main() raises:
    var ws = Workspace()
    var N = 1000000

    var chain = List[Int]()
    chain.append(ZHEN)
    chain.append(LI)
    chain.append(DUI)

    var t0 = clock()
    for _ in range(N):
        _ = execute(chain, ws, "hello world")
    var t1 = clock()
    print("execute_3chain_1M_ns:", (t1 - t0) * 1000 / N)
