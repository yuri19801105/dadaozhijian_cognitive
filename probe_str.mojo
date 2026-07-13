def main() raises:
    var s = String("测试abc")
    for byte in s.bytes():
        print("byte:", byte)
    print("len:", s.byte_length())
