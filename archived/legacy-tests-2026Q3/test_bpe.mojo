# BPE Tokenizer 测试套件
# 7 tests

from std.testing import assert_equal
from bpe import Tokenizer

def test_bpe_tokenizer_create() raises:
    var tok = Tokenizer()
    assert_equal(len(tok.vocab), 0)

def test_bpe_train_small() raises:
    var tok = Tokenizer()
    tok.train("aaab", 258)
    assert_equal(len(tok.vocab), 258)

def test_bpe_train_identity() raises:
    var tok = Tokenizer()
    tok.train("abc", 256)
    assert_equal(len(tok.vocab), 256)

def test_bpe_encode_decode() raises:
    var tok = Tokenizer()
    tok.train("hello world", 260)
    var ids = tok.encode("hello")
    var decoded = tok.decode(ids)
    assert_equal(decoded, "hello")

def test_bpe_multiple_merges() raises:
    var tok = Tokenizer()
    tok.train("aaaa bbbb cccc", 260)
    var ids = tok.encode("aaaa bbbb")
    assert_equal(len(ids) > 0, True)

def test_bpe_roundtrip_empty() raises:
    var tok = Tokenizer()
    tok.train("test", 258)
    var ids = tok.encode("test")
    var decoded = tok.decode(ids)
    assert_equal(decoded, "test")

def test_train_basic() raises:
    # 维基 BPE 经典例, 与 minbpe BasicTokenizer 输出一致
    var tok = Tokenizer()
    tok.train("aaabdaaabac", 256 + 3)
    # 期望合并序列: aa→256, (256,97)→257, (257,98)→258
    assert_equal(tok.encode("aaabdaaabac"), [258, 100, 258, 97, 99])

def main() raises:
    var passed = 0
    var failed = 0

    try:
        test_bpe_tokenizer_create(); passed += 1
    except e:
        failed += 1; print("FAIL test_bpe_tokenizer_create:", e)

    try:
        test_bpe_train_small(); passed += 1
    except e:
        failed += 1; print("FAIL test_bpe_train_small:", e)

    try:
        test_bpe_train_identity(); passed += 1
    except e:
        failed += 1; print("FAIL test_bpe_train_identity:", e)

    try:
        test_bpe_encode_decode(); passed += 1
    except e:
        failed += 1; print("FAIL test_bpe_encode_decode:", e)

    try:
        test_bpe_multiple_merges(); passed += 1
    except e:
        failed += 1; print("FAIL test_bpe_multiple_merges:", e)

    try:
        test_bpe_roundtrip_empty(); passed += 1
    except e:
        failed += 1; print("FAIL test_bpe_roundtrip_empty:", e)

    try:
        test_train_basic(); passed += 1
    except e:
        failed += 1; print("FAIL test_train_basic:", e)

    print("BPE tests -> passed:", passed, " failed:", failed)
    if failed > 0:
        raise Error("BPE tests failed")
