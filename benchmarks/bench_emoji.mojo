# 静语 M8-core 基准
# 测量: build() 构建开销 + render() / render_svg() 渲染开销
# 计时: C clock() 微秒 *1000 -> ns/op
#
# 注意: 避免 O(N^2)——render / render_svg 不写状态, 构建一次后渲染 N 次, 单独测纯渲染开销。
#       build 每次需新建 EmojiGraph + 填充并行数组; 因本构建不支持 borrowed 参数,
#       入参 chains 按值移动, 故每次循环内重新构造 chains (等价调用方持有可变链的场景)。

from emoji import EmojiGraph

@extern("clock")
def clock() abi("C") -> Int:
    ...

def _make_chains() -> List[List[Int]]:
    var chains = List[List[Int]]()
    var c1 = List[Int]()
    c1.append(0); c1.append(5); c1.append(7)
    var c2 = List[Int]()
    c2.append(1); c2.append(2); c2.append(3)
    chains.append(c1^)
    chains.append(c2^)
    return chains^

def main() raises:
    var N = 500000

    # --- build 开销: 每次新建 EmojiGraph + build (2 链, 6 节点) ---
    var t0 = clock()
    for _ in range(N):
        var g = EmojiGraph()
        var ch = _make_chains()
        g.build(ch)
    var t1 = clock()
    print("emoji_build_", N, "_ns:", (t1 - t0) * 1000 / N)

    # --- render 开销: 构建一次, 渲染 N 次 (纯文本行式输出) ---
    var g = EmojiGraph()
    var ch = _make_chains()
    g.build(ch)
    var t2 = clock()
    for _ in range(N):
        _ = g.render()
    var t3 = clock()
    print("emoji_render_", N, "_ns:", (t3 - t2) * 1000 / N)

    # --- render_svg 开销: 构建一次, 渲染 N 次 (纯 SVG 字符串) ---
    var t4 = clock()
    for _ in range(N):
        _ = g.render_svg()
    var t5 = clock()
    print("emoji_render_svg_", N, "_ns:", (t5 - t4) * 1000 / N)
