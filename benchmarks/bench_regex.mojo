# RegexTokenizer 基准: Mojo vs Python(minbpe)
# 运行: .venv/bin/mojo -I src benchmarks/bench_regex.mojo
from regex import RegexTokenizer
from std.testing import assert_equal

@extern("clock")
def clock() abi("C") -> Int:
    ...

def main() raises:
    var text = String()
    var base = "the quick brown fox jumps over the lazy dog. The dog was lazy! 123 4567. hello-world foo_bar. "
    for _ in range(500):
        text += base
    print("text_size:", text.byte_length())

    var t = RegexTokenizer()
    var t0 = clock()
    t.train(text, 300)
    var t1 = clock()
    print("train_time_ms:", (t1 - t0) // 1000)

    var t2 = clock()
    var ids = t.encode_ordinary(text)
    var t3 = clock()
    print("encode_time_ms:", (t3 - t2) // 1000)
    print("encoded_ids:", len(ids))

    var t4 = clock()
    var decoded = t.decode(ids)
    var t5 = clock()
    print("decode_time_ms:", (t5 - t4) // 1000)
    print("decode_match:", decoded == text)

    var total = (t1 - t0) // 1000 + (t3 - t2) // 1000 + (t5 - t4) // 1000
    print("total_time_ms:", total)
