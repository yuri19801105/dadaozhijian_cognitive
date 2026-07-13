# RegexTokenizer — 十方(10)·文本入口扩展
# 类别预切分(GPT-4 split pattern) + 特殊 token
# 语言: Mojo 1.0.0b2 | 验证: TDD (对照 minbpe RegexTokenizer)

def _is_letter(cp: Int) -> Bool:
    if (cp >= 97 and cp <= 122) or (cp >= 65 and cp <= 90):
        return True
    return cp >= 0x80

def _is_number(cp: Int) -> Bool:
    return cp >= 48 and cp <= 57

def _is_ws(cp: Int) -> Bool:
    if cp == 32 or cp == 9 or cp == 10 or cp == 13 or cp == 12 or cp == 11:
        return True
    if cp == 0x85 or cp == 0xA0 or cp == 0x1680:
        return True
    if cp >= 0x2000 and cp <= 0x200A:
        return True
    if cp == 0x2028 or cp == 0x2029 or cp == 0x202F or cp == 0x205F or cp == 0x3000:
        return True
    return False

def _decode_codepoints(text: String) -> List[Int]:
    var n = text.byte_length()
    var p = text.unsafe_ptr()
    var cps = List[Int]()
    var i = 0
    while i < n:
        var b = Int(p[i])
        var cp: Int
        var adv: Int
        if b < 0x80:
            cp = b; adv = 1
        elif (b & 0xE0) == 0xC0:
            cp = ((b & 0x1F) << 6) | (Int(p[i + 1]) & 0x3F); adv = 2
        elif (b & 0xF0) == 0xE0:
            cp = ((b & 0x0F) << 12) | ((Int(p[i + 1]) & 0x3F) << 6) | (Int(p[i + 2]) & 0x3F); adv = 3
        else:
            cp = ((b & 0x07) << 18) | ((Int(p[i + 1]) & 0x3F) << 12) | ((Int(p[i + 2]) & 0x3F) << 6) | (Int(p[i + 3]) & 0x3F); adv = 4
        cps.append(cp)
        i += adv
    return cps^

def _utf8_bytes_of_cp(cp: Int) -> List[Int]:
    var out = List[Int]()
    if cp < 0x80:
        out.append(cp)
    elif cp < 0x800:
        out.append(0xC0 | (cp >> 6))
        out.append(0x80 | (cp & 0x3F))
    elif cp < 0x10000:
        out.append(0xE0 | (cp >> 12))
        out.append(0x80 | ((cp >> 6) & 0x3F))
        out.append(0x80 | (cp & 0x3F))
    else:
        out.append(0xF0 | (cp >> 18))
        out.append(0x80 | ((cp >> 12) & 0x3F))
        out.append(0x80 | ((cp >> 6) & 0x3F))
        out.append(0x80 | (cp & 0x3F))
    return out^

def _bytes_to_string(bytes_list: List[Int]) -> String:
    var n = len(bytes_list)
    var s = String()
    var i = 0
    while i < n:
        var b = bytes_list[i]
        var cp: Int
        var adv: Int
        if b < 0x80:
            cp = b; adv = 1
        elif (b & 0xE0) == 0xC0:
            cp = ((b & 0x1F) << 6) | (bytes_list[i + 1] & 0x3F); adv = 2
        elif (b & 0xF0) == 0xE0:
            cp = ((b & 0x0F) << 12) | ((bytes_list[i + 1] & 0x3F) << 6) | (bytes_list[i + 2] & 0x3F); adv = 3
        else:
            cp = ((b & 0x07) << 18) | ((bytes_list[i + 1] & 0x3F) << 12) | ((bytes_list[i + 2] & 0x3F) << 6) | (bytes_list[i + 3] & 0x3F); adv = 4
        s += chr(cp)
        i += adv
    return s^

def _up(cp: Int) -> Int:
    if cp >= 97 and cp <= 122:
        return cp - 32
    return cp

def _alt1(cp: List[Int], i: Int, n: Int) -> Int:
    if i >= n:
        return 0
    var c = _up(cp[i])
    if c == 83 or c == 68 or c == 77 or c == 84:
        return 1
    if i + 1 < n:
        var a = _up(cp[i])
        var b = _up(cp[i + 1])
        if (a == 76 and b == 76) or (a == 86 and b == 69) or (a == 82 and b == 69):
            return 2
    return 0

def _alt2_other(cp: Int) -> Bool:
    # [^\r\n\p{L}\p{N}] : 排除 \r \n 字母 数字, 但允许空格等空白(与 GPT-4 模式一致)
    if cp == 13 or cp == 10:
        return False
    if _is_letter(cp) or _is_number(cp):
        return False
    return True

def _alt2(cp: List[Int], i: Int, n: Int) -> Int:
    var k = i
    if k < n:
        var c = cp[k]
        if _alt2_other(c):
            k += 1
    if k >= n or not _is_letter(cp[k]):
        return 0
    var j = k
    while j < n and _is_letter(cp[j]):
        j += 1
    return j - i

def _alt3(cp: List[Int], i: Int, n: Int) -> Int:
    if i >= n or not _is_number(cp[i]):
        return 0
    var j = i
    while j < n and _is_number(cp[j]):
        j += 1
    var cnt = j - i
    if cnt > 3:
        cnt = 3
    return cnt

def _alt4(cp: List[Int], i: Int, n: Int) -> Int:
    var k = i
    if k < n and cp[k] == 32:
        k += 1
    if k >= n or _is_ws(cp[k]) or _is_letter(cp[k]) or _is_number(cp[k]):
        return 0
    var j = k
    while j < n and not _is_ws(cp[j]) and not _is_letter(cp[j]) and not _is_number(cp[j]):
        j += 1
    var m = j
    while m < n and (cp[m] == 13 or cp[m] == 10):
        m += 1
    return m - i

def _alt5(cp: List[Int], i: Int, n: Int) -> Int:
    if i >= n or not _is_ws(cp[i]):
        return 0
    var j = i
    while j < n and _is_ws(cp[j]):
        j += 1
    if j > i and (cp[j - 1] == 13 or cp[j - 1] == 10):
        return j - i
    return 0

def _alt6(cp: List[Int], i: Int, n: Int) -> Int:
    if i >= n or not _is_ws(cp[i]):
        return 0
    var j = i
    while j < n and _is_ws(cp[j]):
        j += 1
    if j == n:
        return j - i
    return 0

def _alt7(cp: List[Int], i: Int, n: Int) -> Int:
    if i >= n or not _is_ws(cp[i]):
        return 0
    var j = i
    while j < n and _is_ws(cp[j]):
        j += 1
    return j - i

def _best_match(cp: List[Int], i: Int, n: Int) -> Int:
    var best = 0
    var a1 = _alt1(cp, i, n)
    if a1 > best: best = a1
    var a2 = _alt2(cp, i, n)
    if a2 > best: best = a2
    var a3 = _alt3(cp, i, n)
    if a3 > best: best = a3
    var a4 = _alt4(cp, i, n)
    if a4 > best: best = a4
    var a5 = _alt5(cp, i, n)
    if a5 > best: best = a5
    var a6 = _alt6(cp, i, n)
    if a6 > best: best = a6
    var a7 = _alt7(cp, i, n)
    if a7 > best: best = a7
    return best

def _pretokenize(text: String) -> List[List[Int]]:
    var cp = _decode_codepoints(text)
    var n = len(cp)
    var pieces = List[List[Int]]()
    var i = 0
    while i < n:
        var l = _best_match(cp, i, n)
        if l == 0:
            l = 1
        var piece = List[Int]()
        for k in range(i, i + l):
            var bts = _utf8_bytes_of_cp(cp[k])
            for b in bts:
                piece.append(b)
        pieces.append(piece^)
        i += l
    return pieces^

def _merge(ids: List[Int], pair: Tuple[Int, Int], idx: Int) -> List[Int]:
    var result = List[Int]()
    var i = 0
    while i < len(ids):
        if ids[i] == pair[0] and i < len(ids) - 1 and ids[i + 1] == pair[1]:
            result.append(idx)
            i += 2
        else:
            result.append(ids[i])
            i += 1
    return result^

struct RegexTokenizer:
    var merges: Dict[Tuple[Int, Int], Int]
    var vocab: Dict[Int, List[Int]]
    var pattern: String
    var special_tokens: Dict[String, Int]
    var inverse_special_tokens: Dict[Int, String]

    def __init__(out self, pattern: String = "DEFAULT"):
        self.merges = Dict[Tuple[Int, Int], Int]()
        self.vocab = Dict[Int, List[Int]]()
        for i in range(256):
            var one = List[Int]()
            one.append(i)
            self.vocab[i] = one^
        if pattern == "DEFAULT":
            self.pattern = "GPT4_SPLIT_PATTERN"
        else:
            self.pattern = pattern.copy()
        self.special_tokens = Dict[String, Int]()
        self.inverse_special_tokens = Dict[Int, String]()

    def register_special_tokens(mut self, special_tokens: Dict[String, Int]) raises:
        self.inverse_special_tokens = Dict[Int, String]()
        var keys = List[String]()
        for k in special_tokens:
            keys.append(k.copy())
        for k in keys:
            var v = special_tokens[k]
            self.inverse_special_tokens[v] = k
        self.special_tokens = special_tokens.copy()

    def train(mut self, text: String, vocab_size: Int) raises:
        assert vocab_size >= 256
        var num_merges = vocab_size - 256
        var pieces = _pretokenize(text)
        for step in range(num_merges):
            var counts = Dict[Tuple[Int, Int], Int]()
            var first_seen = Dict[Tuple[Int, Int], Int]()
            var seen_counter = 0
            var best_pair = Tuple(0, 0)
            var best_count = 0
            var best_first = -1
            for plist in pieces:
                for ii in range(len(plist) - 1):
                    var pr = Tuple(plist[ii], plist[ii + 1])
                    if pr not in counts:
                        counts[pr] = 0
                        first_seen[pr] = seen_counter
                        seen_counter += 1
                    counts[pr] = counts[pr] + 1
                    var c = counts[pr]
                    if c > best_count or (c == best_count and first_seen[pr] < best_first):
                        best_count = c
                        best_pair = pr
                        best_first = first_seen[pr]
            if best_count == 0:
                break
            var idx = 256 + step
            self.merges[best_pair] = idx
            var merged = List[Int]()
            for b in self.vocab[best_pair[0]]:
                merged.append(b)
            for b in self.vocab[best_pair[1]]:
                merged.append(b)
            self.vocab[idx] = merged^
            for k in range(len(pieces)):
                pieces[k] = _merge(pieces[k].copy(), best_pair, idx)

    def _encode_chunk(mut self, ids: List[Int]) -> List[Int]:
        var text_ids = ids.copy()
        while len(text_ids) >= 2:
            var best_pair = Tuple(0, 0)
            var best_idx = -1
            for i in range(len(text_ids) - 1):
                var pr = Tuple(text_ids[i], text_ids[i + 1])
                var idx = self.merges.get(pr, -1)
                if idx != -1 and (best_idx == -1 or idx < best_idx):
                    best_pair = pr
                    best_idx = idx
            if best_idx == -1:
                break
            text_ids = _merge(text_ids, best_pair, best_idx)
        return text_ids^

    def encode_ordinary(mut self, text: String) -> List[Int]:
        var pieces = _pretokenize(text)
        var result = List[Int]()
        for k in range(len(pieces)):
            var chunk = self._encode_chunk(pieces[k].copy())
            for id in chunk:
                result.append(id)
        return result^

    def _split_special(mut self, text: String, allowed: List[String]) -> List[String]:
        var n = text.byte_length()
        var parts = List[String]()
        var buf = String()
        var i = 0
        while i < n:
            var matched = False
            for sp in allowed:
                if sp in self.special_tokens and text[byte=i:].startswith(sp):
                    if buf.byte_length() > 0:
                        parts.append(buf)
                        buf = String()
                    parts.append(sp.copy())
                    i += sp.byte_length()
                    matched = True
                    break
            if not matched:
                buf += text[byte=i : i + 1]
                i += 1
        if buf.byte_length() > 0:
            parts.append(buf)
        return parts^

    def encode(mut self, text: String, allowed: List[String]) raises -> List[Int]:
        var has_special = False
        for sp in allowed:
            if sp in self.special_tokens:
                has_special = True
        if not has_special:
            return self.encode_ordinary(text)
        var parts = self._split_special(text, allowed)
        var ids = List[Int]()
        for part in parts:
            if part in self.special_tokens:
                ids.append(self.special_tokens[part])
            else:
                var e = self.encode_ordinary(part)
                for x in e:
                    ids.append(x)
        return ids^

    def decode(mut self, ids: List[Int]) raises -> String:
        var result_bytes = List[Int]()
        for id in ids:
            if id in self.vocab:
                for b in self.vocab[id]:
                    result_bytes.append(b)
            elif id in self.inverse_special_tokens:
                var st = self.inverse_special_tokens[id]
                var pn = st.byte_length()
                var pp = st.unsafe_ptr()
                for k in range(pn):
                    result_bytes.append(Int(pp[k]))
            else:
                result_bytes.append(id)
        if len(result_bytes) == 0:
            return ""
        return _bytes_to_string(result_bytes)
