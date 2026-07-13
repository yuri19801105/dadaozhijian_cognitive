from bpe import Tokenizer
from std.testing import assert_equal

@extern("clock")
def clock() abi("C") -> Int:
    ...

def main() raises:
    var text = String()
    var base = "天地玄黄 宇宙洪荒 日月盈昃 辰宿列张 寒来暑往 秋收冬藏 "
    for _ in range(1000):
        text += base
    print("text_size:", text.byte_length())

    var t = Tokenizer()
    var t0 = clock()
    t.train(text, 300)
    var t1 = clock()
    var train_clocks = (t1 - t0) // 1000
    print("train_time_ms:", train_clocks)

    var t2 = clock()
    var ids = t.encode(text)
    var t3 = clock()
    var encode_clocks = (t3 - t2) // 1000
    print("encode_time_ms:", encode_clocks)
    print("encoded_ids:", len(ids))

    var t4 = clock()
    var decoded = t.decode(ids)
    var t5 = clock()
    var decode_clocks = (t5 - t4) // 1000
    print("decode_time_ms:", decode_clocks)
    print("decode_match:", decoded == text)

    var total = train_clocks + encode_clocks + decode_clocks
    print("total_time_ms:", total)
