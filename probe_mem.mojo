from longmem import *
def main() raises:
    var mem = Memory()
    mem = remember(mem, 100, 0, 2, 3, 5)
    print("ok size=", memory_size(mem))
