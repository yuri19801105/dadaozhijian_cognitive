# === io/tests/test_io.mojo ===
# TDD: io 模块（BPE 分词器 + 正则风格分词器）。
from io.bpe_tokenizer import Tokenizer, train_tokenizer
from io.regex_tokenizer import RegexTokenizer


def check(cond: Bool, msg: String) raises:
    if not cond:
        raise Error(msg)


def test_bpe_roundtrip() raises:
    var corpus = "ab ab ab cd cd hello world hello world ab cd ab cd "
    var t = Tokenizer()
    train_tokenizer(t, corpus, 300)
    var s = String("ab ab cd hello")
    var ids = t.encode(s)
    var back = t.decode(ids)
    check(back == s, "bpe roundtrip should reproduce original")
    check(len(ids) > 0, "bpe encode should produce ids")


def test_bpe_deterministic() raises:
    var corpus = "ab ab ab cd cd ab cd ab cd "
    var t1 = Tokenizer()
    train_tokenizer(t1, corpus, 280)
    var t2 = Tokenizer()
    train_tokenizer(t2, corpus, 280)
    var a = t1.encode("ab ab cd")
    var b = t2.encode("ab ab cd")
    check(len(a) == len(b), "bpe deterministic: same length")
    var same = True
    for i in range(len(a)):
        if a[i] != b[i]:
            same = False
    check(same, "bpe deterministic: same ids")


def test_regex_chinese() raises:
    var rt = RegexTokenizer()
    var toks = rt.encode("Hello 世界 123!")
    # 期望: Hello / 空格 / 世 / 界 / 空格 / 123 / !  (两处空格均保留)
    check(len(toks) == 7, "regex token count for 'Hello 世界 123!'")
    check(toks[0] == "Hello", "regex: word token")
    check(toks[1] == " ", "regex: whitespace token (preserved)")
    check(toks[2] == "世", "regex: cjk char 1")
    check(toks[3] == "界", "regex: cjk char 2")
    check(toks[4] == " ", "regex: whitespace token 2 (preserved)")
    check(toks[5] == "123", "regex: number token")
    check(toks[6] == "!", "regex: punctuation token")


def test_regex_roundtrip() raises:
    var rt = RegexTokenizer()
    var s = String("Hello 世界 123! foo_bar 9 ")
    var toks = rt.encode(s)
    var back = rt.decode(toks)
    check(back == s, "regex roundtrip should reproduce original")


def main() raises:
    var failed = 0
    print("=== io tests ===")
    try: test_bpe_roundtrip(); print("  passed: bpe_roundtrip")
    except e: failed += 1; print("  FAILED: bpe_roundtrip ->", e)
    try: test_bpe_deterministic(); print("  passed: bpe_deterministic")
    except e: failed += 1; print("  FAILED: bpe_deterministic ->", e)
    try: test_regex_chinese(); print("  passed: regex_chinese")
    except e: failed += 1; print("  FAILED: regex_chinese ->", e)
    try: test_regex_roundtrip(); print("  passed: regex_roundtrip")
    except e: failed += 1; print("  FAILED: regex_roundtrip ->", e)
    if failed > 0:
        print("io -> failed:", failed)
        raise Error("io tests failed")
    print("io -> passed: 4  failed: 0")
