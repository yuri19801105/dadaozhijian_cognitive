from trigram import *
from workspace import Workspace

@extern("clock")
def clock() abi("C") -> Int:
    ...

def main() raises:
    var ws = Workspace()

    var N = 1000000
    var t0 = clock()
    for _ in range(N):
        _ = apply_chien(ws, 42)
        _ = apply_kun(ws, 10)
        _ = apply_zhen(ws, 7)
        _ = apply_xun(ws, 3)
        _ = apply_kan(ws, 99)
        _ = apply_li(ws, 15)
        _ = apply_gen(ws, 1)
        _ = apply_dui(ws, 8)
    var t1 = clock()
    print("8x1M_trigrams_ms:", (t1 - t0) // 1000)

    var t2 = clock()
    for _ in range(N):
        _ = apply_trigram(CHIEN, ws, 42)
        _ = apply_trigram(KUN, ws, 10)
        _ = apply_trigram(ZHEN, ws, 7)
        _ = apply_trigram(XUN, ws, 3)
        _ = apply_trigram(KAN, ws, 99)
        _ = apply_trigram(LI, ws, 15)
        _ = apply_trigram(GEN, ws, 1)
        _ = apply_trigram(DUI, ws, 8)
    var t3 = clock()
    print("dispatch_8x1M_ms:", (t3 - t2) // 1000)

    var chain = List[Int]()
    chain.append(CHIEN)
    chain.append(LI)
    chain.append(DUI)
    var t4 = clock()
    for _ in range(N):
        _ = apply_chain(ws, chain, 10)
    var t5 = clock()
    print("chain_3x1M_ms:", (t5 - t4) // 1000)
