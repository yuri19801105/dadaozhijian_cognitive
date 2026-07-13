from liuhe import context_vector
from workspace import Workspace
from config import Config

@extern("clock")
def clock() abi("C") -> Int:
    ...

def main() raises:
    var ws = Workspace()
    var cfg = Config()
    var N = 1000000

    var t0 = clock()
    for _ in range(N):
        _ = context_vector(ws, 3, "hello world", cfg)
    var t1 = clock()
    print("context_vector_1M_ns:", (t1 - t0) * 1000 / N)
