# === io/benchmarks/bench_io.mojo ===
# io 模块基准：BPE 训练+编码、正则风格分词。
# 时钟约定（无 time 模块）：@extern("clock") → 微秒×1000 = ns。
from io.bpe_tokenizer import Tokenizer, train_tokenizer
from io.regex_tokenizer import RegexTokenizer

@extern("clock")
def clock() abi("C") -> Int:
    ...


def bench_bpe() raises:
    var corpus = "大道至简 知行合一 阴阳调和 五行生克 八卦演易 九宫洛书 "
    var t = Tokenizer()
    train_tokenizer(t, corpus, 320)
    var sample = String("阴阳调和 五行生克")
    var iters = 2000
    var c0 = clock()
    for _ in range(iters):
        var ids = t.encode(sample)
        var _ = t.decode(ids)
    var c1 = clock()
    var ns_per = (c1 - c0) * 1000 // iters
    print("  bpe encode+decode:", ns_per, "ns/op (", iters, " iters )")


def bench_regex() raises:
    var rt = RegexTokenizer()
    var sample = String("Hello 世界 123! 大道至简 知行合一 foo_bar")
    var iters = 20000
    var c0 = clock()
    for _ in range(iters):
        var toks = rt.encode(sample)
        var _ = rt.decode(toks)
    var c1 = clock()
    var ns_per = (c1 - c0) * 1000 // iters
    print("  regex encode+decode:", ns_per, "ns/op (", iters, " iters )")


def main() raises:
    print("=== io benchmarks ===")
    bench_bpe()
    bench_regex()
