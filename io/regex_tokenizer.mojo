# === io/regex_tokenizer.mojo ===
# 轻量「正则风格」分词器 — 从零实现（src/regex.mojo 在本项目不存在，见审计 §4.15 不实声明修正）。
# 规则（确定性扫描，无外部正则引擎）：
#   - ASCII 字母(a-z A-Z) / 数字(0-9) 连续段 → 各自合并成一个 token（单词 / 数字）；
#   - CJK 统一表意文字 (U+4E00–U+9FFF) 等宽字符 → 逐字成 token；
#   - 空白(空格/Tab/CR/LF) → 跳过；
#   - 其余（标点等）→ 逐字符成 token。
# 见 docs/architecture-modular-plan.md §4.15。

def _codepoints(text: String) -> List[Int]:
    var res = List[Int]()
    var i = 0
    var n = text.byte_length()
    var p = text.unsafe_ptr()
    while i < n:
        var b = Int(p[i]) & 0xFF
        var cp: Int
        if b < 0x80:
            cp = b
            i += 1
        elif b < 0xC0:
            cp = 0xFFFD
            i += 1
        elif b < 0xE0:
            if i + 1 >= n:
                i += 1
                continue
            cp = ((b & 0x1F) << 6) | (Int(p[i + 1]) & 0x3F)
            i += 2
        elif b < 0xF0:
            if i + 2 >= n:
                i += 1
                continue
            cp = ((b & 0x0F) << 12) | ((Int(p[i + 1]) & 0x3F) << 6) | (Int(p[i + 2]) & 0x3F)
            i += 3
        else:
            if i + 3 >= n:
                i += 1
                continue
            cp = ((b & 0x07) << 18) | ((Int(p[i + 1]) & 0x3F) << 12) | ((Int(p[i + 2]) & 0x3F) << 6) | (Int(p[i + 3]) & 0x3F)
            i += 4
        res.append(cp)
    return res^


struct RegexTokenizer:
    def __init__(out self):
        pass

    # 文本 → token 列表（确定性扫描，非 raises）。
    def encode(self, text: String) -> List[String]:
        var out = List[String]()
        var cps = _codepoints(text)
        var n = len(cps)
        var buf = String()
        for i in range(n):
            var cp = cps[i]
            var is_alpha = (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122)
            var is_digit = (cp >= 48 and cp <= 57)
            if is_alpha or is_digit:
                buf += chr(cp)
            else:
                if buf.byte_length() > 0:
                    out.append(buf^)
                    buf = String()
                # 空白 / CJK / 标点：逐字成 token（保证 decode 精确还原，含空白）
                out.append(chr(cp))
        if buf.byte_length() > 0:
            out.append(buf^)
        return out^

    # token 列表 → 原文（确定性拼接）。
    def decode(self, toks: List[String]) -> String:
        var s = String()
        for t in toks:
            s += t
        return s^
