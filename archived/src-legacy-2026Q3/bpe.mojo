# BPE (Byte Pair Encoding) tokenizer — 认知模型 "十方" 文本输入通道的符号化入口
# 语言: Mojo 1.0.0b2  |  验证: TDD (TestSuite + assert_equal)

def _utf8_decode(bytes: List[Int]) raises -> String:
    var result = String()
    var i = 0
    var n = len(bytes)
    while i < n:
        var b = bytes[i]
        var cp: Int
        if b < 0x80:
            cp = b
            i += 1
        elif b < 0xC0:
            cp = 0xFFFD
            i += 1
        elif b < 0xE0:
            if i + 1 >= n: i += 1; continue
            cp = ((b & 0x1F) << 6) | (bytes[i+1] & 0x3F)
            i += 2
        elif b < 0xF0:
            if i + 2 >= n: i += 1; continue
            cp = ((b & 0x0F) << 12) | ((bytes[i+1] & 0x3F) << 6) | (bytes[i+2] & 0x3F)
            i += 3
        else:
            if i + 3 >= n: i += 1; continue
            cp = ((b & 0x07) << 18) | ((bytes[i+1] & 0x3F) << 12) | ((bytes[i+2] & 0x3F) << 6) | (bytes[i+3] & 0x3F)
            i += 4
        result += chr(cp)
    return result^


struct Tokenizer:
    """Minimal byte-level BPE. Maps raw text -> integer token ids."""
    var vocab: Dict[Int, List[Int]]
    var merge_order: List[Tuple[Int, Int]]

    def __init__(out self):
        self.vocab = Dict[Int, List[Int]]()
        self.merge_order = List[Tuple[Int, Int]]()

    def _bytes(self, text: String) raises -> List[Int]:
        var n = text.byte_length()
        var p = text.unsafe_ptr()
        var res = List[Int]()
        for i in range(n):
            res.append(Int(p[i]))
        return res^

    def _merge_pass(self, ids: List[Int], a: Int, b: Int, new_id: Int) raises -> List[Int]:
        var out = List[Int]()
        var i = 0
        while i < len(ids):
            if i < len(ids) - 1 and ids[i] == a and ids[i + 1] == b:
                out.append(new_id)
                i += 2
            else:
                out.append(ids[i])
                i += 1
        return out^

    def train(mut self, text: String, vocab_size: Int) raises:
        # base byte vocab: id == byte value, for 0..255
        for i in range(256):
            var one = List[Int]()
            one.append(i)
            self.vocab[i] = one^

        var ids = self._bytes(text)
        var num_merges = vocab_size - 256
        for step in range(num_merges):
            # count adjacent pairs, track the most frequent in one pass
            var counts = Dict[Tuple[Int, Int], Int]()
            var best = Tuple(0, 0)
            var best_count = 0
            for i in range(len(ids) - 1):
                var key = Tuple(ids[i], ids[i + 1])
                var c = counts.get(key, 0) + 1
                counts[key] = c
                if c > best_count:
                    best_count = c
                    best = key
            if best_count == 0:
                break
            var new_id = 256 + step
            # extend vocab: merged bytes = bytes(a) ++ bytes(b)
            var merged = List[Int]()
            for x in self.vocab[best[0]]:
                merged.append(x)
            for x in self.vocab[best[1]]:
                merged.append(x)
            self.vocab[new_id] = merged^
            self.merge_order.append(best)
            ids = self._merge_pass(ids, best[0], best[1], new_id)

    def encode(self, text: String) raises -> List[Int]:
        var ids = self._bytes(text)
        for step in range(len(self.merge_order)):
            var pair = self.merge_order[step]
            var new_id = 256 + step
            ids = self._merge_pass(ids, pair[0], pair[1], new_id)
        return ids^

    def decode(self, ids: List[Int]) raises -> String:
        var out = List[Int]()
        for id in ids:
            for byte in self.vocab[id]:
                out.append(byte)
        return _utf8_decode(out)
