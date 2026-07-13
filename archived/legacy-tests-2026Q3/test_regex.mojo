# RegexTokenizer 测试套件 (对照 minbpe RegexTokenizer)
# 运行: .venv/bin/mojo -I src tests/test_regex.mojo

from std.testing import assert_equal
from regex import RegexTokenizer

# 与 minbpe 参考一致的训练语料
def _corpus() -> String:
    return "the quick brown fox jumps over the lazy dog. The dog was lazy! 123 4567. hello-world foo_bar."

def test_encode_the_quick() raises:
    var tok = RegexTokenizer()
    tok.train(_corpus(), 256 + 20)
    assert_equal(tok.encode_ordinary("the quick brown fox"),
                 [257, 271, 275, 110, 259, 120])

def test_encode_the_dog_lazy() raises:
    var tok = RegexTokenizer()
    tok.train(_corpus(), 256 + 20)
    assert_equal(tok.encode_ordinary("The dog was lazy!"),
                 [84, 256, 266, 32, 119, 97, 115, 263, 33])

def test_encode_hello_world_bar() raises:
    var tok = RegexTokenizer()
    tok.train(_corpus(), 256 + 20)
    assert_equal(tok.encode_ordinary("hello-world foo_bar."),
                 [256, 108, 108, 111, 45, 119, 111, 114, 108, 100, 259, 111, 95, 98, 97, 114, 46])

def test_encode_numbers() raises:
    var tok = RegexTokenizer()
    tok.train(_corpus(), 256 + 20)
    assert_equal(tok.encode_ordinary("123 4567 89"),
                 [49, 50, 51, 32, 52, 53, 54, 55, 32, 56, 57])

def test_encode_whitespace() raises:
    var tok = RegexTokenizer()
    tok.train(_corpus(), 256 + 20)
    assert_equal(tok.encode_ordinary("  spaces   and\ttabs\nnewline"),
                 [32, 32, 115, 112, 97, 99, 101, 115, 32, 32, 32, 97, 110, 100, 9, 116, 97, 98, 115, 10, 110, 101, 119, 108, 105, 110, 101])

def test_roundtrip_ascii() raises:
    var tok = RegexTokenizer()
    tok.train(_corpus(), 256 + 20)
    var samples = ["the quick brown fox", "The dog was lazy!", "hello-world foo_bar.", "123 4567 89"]
    for s in samples:
        var ids = tok.encode_ordinary(s)
        assert_equal(tok.decode(ids), s)

def test_special_tokens() raises:
    var tok = RegexTokenizer()
    tok.train(_corpus(), 256 + 20)
    var sp = Dict[String, Int]()
    sp["<S>"] = 1000
    sp["</S>"] = 1001
    tok.register_special_tokens(sp)
    var allowed = List[String]()
    allowed.append("<S>")
    allowed.append("</S>")
    assert_equal(tok.encode("hello <S> world </S> foo", allowed),
                 [256, 108, 108, 111, 32, 1000, 32, 119, 111, 114, 108, 100, 32, 1001, 259, 111])
    var ids = tok.encode("hello <S> world </S> foo", allowed)
    assert_equal(tok.decode(ids), "hello <S> world </S> foo")

def test_special_ignored_when_not_allowed() raises:
    var tok = RegexTokenizer()
    tok.train(_corpus(), 256 + 20)
    var sp = Dict[String, Int]()
    sp["<S>"] = 1000
    tok.register_special_tokens(sp)
    var none_allowed = List[String]()
    var ids = tok.encode("hello <S> world", none_allowed)
    assert_equal(ids, tok.encode_ordinary("hello <S> world"))

def test_roundtrip_cjk() raises:
    var tok = RegexTokenizer()
    tok.train(_corpus(), 256 + 20)
    var s = "认知 模型 太极"
    var ids = tok.encode_ordinary(s)
    assert_equal(tok.decode(ids), s)

def main() raises:
    var passed = 0
    var failed = 0
    try: test_encode_the_quick(); passed += 1
    except e: failed += 1; print("FAIL test_encode_the_quick:", e)
    try: test_encode_the_dog_lazy(); passed += 1
    except e: failed += 1; print("FAIL test_encode_the_dog_lazy:", e)
    try: test_encode_hello_world_bar(); passed += 1
    except e: failed += 1; print("FAIL test_encode_hello_world_bar:", e)
    try: test_encode_numbers(); passed += 1
    except e: failed += 1; print("FAIL test_encode_numbers:", e)
    try: test_encode_whitespace(); passed += 1
    except e: failed += 1; print("FAIL test_encode_whitespace:", e)
    try: test_roundtrip_ascii(); passed += 1
    except e: failed += 1; print("FAIL test_roundtrip_ascii:", e)
    try: test_special_tokens(); passed += 1
    except e: failed += 1; print("FAIL test_special_tokens:", e)
    try: test_special_ignored_when_not_allowed(); passed += 1
    except e: failed += 1; print("FAIL test_special_ignored_when_not_allowed:", e)
    try: test_roundtrip_cjk(); passed += 1
    except e: failed += 1; print("FAIL test_roundtrip_cjk:", e)

    print("Regex tests -> passed:", passed, " failed:", failed)
    if failed > 0:
        raise Error("Regex tests failed")
