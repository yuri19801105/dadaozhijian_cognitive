# === config/config.mojo ===
# 外置化配置加载器（迁自 src/config.mojo，升级为 schema 驱动 + 校验 + 最小 TOML 解析）。
# 见 docs/architecture-modular-plan.md §4.16 / §6#4 / §8#4。
from std.io import FileHandle
from config.schema import (
    field_count, field_name, field_default, field_kind,
    field_min, field_max, field_bounded,
)


struct Config:
    # 以 schema 驱动的扁平键值存储；类型化访问器供下游调用。
    # 注：Dict 非 Movable → Config 不可按值返回，故 from_str/from_toml 用 mut 参数（同 TaijiState 惯例）。
    var values: Dict[String, String]

    def __init__(out self):
        self.values = Dict[String, String]()
        var n = field_count()
        for i in range(n):
            self.values[field_name(i)] = field_default(i)

    # —— 类型化访问器 ——
    def get_int(self, name: String) raises -> Int:
        if name not in self.values:
            raise Error("config: unknown key " + name)
        return Int(self.values[name])

    def get_float(self, name: String) raises -> Float64:
        if name not in self.values:
            raise Error("config: unknown key " + name)
        return Float64(self.values[name])

    def get_str(self, name: String) raises -> String:
        if name not in self.values:
            raise Error("config: unknown key " + name)
        return self.values[name]

    # —— 校验：对当前值按 schema 边界复查（防御程序化误改）——
    def validate(self) raises:
        var n = field_count()
        for i in range(n):
            if field_bounded(i) == 0:
                continue
            var name = field_name(i)
            var v: Float64
            var kind = field_kind(i)
            if kind == 0:
                v = Float64(Int(self.values[name]))
            elif kind == 1:
                v = Float64(self.values[name])
            else:
                continue
            if v < field_min(i) or v > field_max(i):
                raise Error("config validate: " + name + " out of range [" +
                            String(field_min(i)) + "," + String(field_max(i)) + "]")

    # —— 序列化回 TOML（round-trip）——
    def to_toml(self) raises -> String:
        var s = String()
        var n = field_count()
        for i in range(n):
            var name = field_name(i)
            var val = self.values[name]
            if field_kind(i) == 2:
                s += name + " = \"" + val + "\"\n"
            else:
                s += name + " = " + val + "\n"
        return s^


# —— 最小 TOML 解析：扁平 "key = value" + 井号注释 ——
# 注：本构建 String.strip() 返回 StringSlice、String.split 返回 List[StringSlice]，
#     故 _substr/_strip 统一以 String 承载，split 结果经 String(...) 转回 String。
def _substr(s: String, start: Int, end: Int) -> String:
    var out = String()
    var n = s.byte_length()
    var e = end
    if e > n:
        e = n
    var i = start
    if i < 0:
        i = 0
    if i > e:
        i = e
    var p = s.unsafe_ptr()
    while i < e:
        out += chr(Int(p[i]) & 0xFF)
        i += 1
    return out^


def _strip(s: String) -> String:
    var p = s.unsafe_ptr()
    var n = s.byte_length()
    var start = 0
    while start < n:
        var b = Int(p[start]) & 0xFF
        if b == 32 or b == 9 or b == 13 or b == 10:   # 空格/Tab/CR/LF
            start += 1
        else:
            break
    var end = n
    while end > start:
        var b = Int(p[end - 1]) & 0xFF
        if b == 32 or b == 9 or b == 13 or b == 10:
            end -= 1
        else:
            break
    return _substr(s, start, end)


def _parse_kv(s: String) -> Dict[String, String]:
    var map = Dict[String, String]()
    var lines = s.split("\n")
    for i in range(len(lines)):
        var raw = String(lines[i])               # StringSlice -> String
        var line = _strip(raw)
        if line.byte_length() == 0:
            continue
        var hash = line.find("#")
        if hash >= 0:
            line = _strip(_substr(line, 0, hash))
            if line.byte_length() == 0:
                continue
        var eq = line.find("=")
        if eq < 0:
            continue
        var key = _strip(_substr(line, 0, eq))
        var val = _strip(_substr(line, eq + 1, line.byte_length()))
        if key.byte_length() == 0:
            continue
        # 去字符串引号（ASCII 安全：按字节比对双引号 0x22）
        if val.byte_length() >= 2:
            var bp = val.unsafe_ptr()
            if Int(bp[0]) == 34 and Int(bp[val.byte_length() - 1]) == 34:
                val = _substr(val, 1, val.byte_length() - 1)
        map[key] = val
    return map^


# 从 TOML 文本加载（mut 参数；Dict 非 Movable → 不可按值返回，同 TaijiState 惯例）：
#   schema 校验类型与边界，缺键保留 __init__ 已载入的默认值。
def from_str(mut c: Config, s: String) raises:
    var map = _parse_kv(s)
    var n = field_count()
    for i in range(n):
        var name = field_name(i)
        if name in map:
            var raw = map[name]
            # 类型 + 边界校验（非法值直接 raise）
            var kind = field_kind(i)
            if kind == 0:
                var v = Int(raw)
                if field_bounded(i) == 1 and (Float64(v) < field_min(i) or Float64(v) > field_max(i)):
                    raise Error("config: " + name + " = " + raw + " out of range")
            elif kind == 1:
                var v = Float64(raw)
                if field_bounded(i) == 1 and (v < field_min(i) or v > field_max(i)):
                    raise Error("config: " + name + " = " + raw + " out of range")
            c.values[name] = raw
        # 否则保留 __init__ 已载入的 schema 默认值


# 从文件加载（缺失/读取失败 → raise）。
def from_toml(mut c: Config, path: String) raises:
    try:
        var f = FileHandle(path, "r")
        var content = f.read()
        f.close()
        from_str(c, content)
    except:
        raise Error("config: cannot read file: " + path)
