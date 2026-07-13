# 静语 (Emoji) 可视化 - M8-core (CLI 可跑 + 可单测)
# 纯观测层: 把推理链渲染为 emoji / 文本化图形, 不改变系统功能行为。
# 范围裁剪见 ADR-0011: 推迟鼠标悬停/节点点击/拖拽/实时动画等 GUI 交互特性。
# 语言: Mojo 1.0.0b2 | 验证: TDD
#
# 约束(Mojo 1.0.0b2, 已由 ADR-0005 / ADR-0010 记录):
#   - 不支持 class; inout 参数不解析 → 更新用 struct 的 mut self 方法。
#   - List[T: Movable]: 容器内元素 T 必须 Movable。而「含 List 字段的 struct 不可 Movable」
#     (与 String 规则同源)。二者叠加 ⇒ 一个 List 不能容纳「自身含 List 的 struct」。
#   - 因此本模块采用**扁平并行数组**存储(同 TaijiState): 节点/连线的各字段分别存于
#     List[Int] / List[Int](权重以百分比整数表示), EmojiGraph 仅持有这些数组。
#   - 因 EmojiGraph 含 List 字段不可 Movable, 既不可按值返回也不可按值传参:
#       · 构造用 mut self 方法 build(chains) (等价 architecture 的 create_emoji_graph(chains),
#         同 M9 CognitiveCycle 的 mut self 模式);
#       · 渲染用 self 方法 render() / render_svg() (等价 architecture 的 render_graph(graph));
#       · 更新用 mut self 方法 update_node_emotion / update_node_weight
#         (等价 architecture 的 inout 自由函数, 本构建 inout 不解析故用 mut self)。

# ---- 情绪类型 (对齐 architecture.md, 用 comptime Int 常量, 同 wu_xing.mojo 风格) ----
comptime NEUTRAL: Int = 0
comptime EXCITED: Int = 1
comptime ANXIOUS: Int = 2
comptime JOY: Int = 3
comptime SAD: Int = 4
comptime SURPRISED: Int = 5

# ---- 布局类型 ----
comptime LAYOUT_LINEAR: Int = 0
comptime LAYOUT_TREE: Int = 1
comptime LAYOUT_CIRCLE: Int = 2
comptime LAYOUT_HEATMAP: Int = 3

struct EmojiGraph:
    # 扁平并行数组存储 (避免 List 嵌套, 保证可按 mut self 原地构建/更新)
    var count: Int                                   # 节点数
    var node_trigram: List[Int]                      # 各节点 trigram id (0..7)
    var node_position: List[Int]                     # 各节点时间轴位置
    var node_emotion: List[Int]                      # 各节点情绪 (EmotionType)
    var node_weight: List[Int]                       # 各节点权重 (0-100 百分比)
    var conn_count: Int                              # 连线数
    var conn_from: List[Int]                         # 连线起点节点 id
    var conn_to: List[Int]                           # 连线终点节点 id
    var conn_strength: List[Int]                     # 连线强度 (0-100 百分比)
    var conn_color: List[Int]                        # 连线颜色 (EmotionType)
    var layout_type: Int                             # LayoutType

    def __init__(out self):
        self.count = 0
        self.node_trigram = List[Int]()
        self.node_position = List[Int]()
        self.node_emotion = List[Int]()
        self.node_weight = List[Int]()
        self.conn_count = 0
        self.conn_from = List[Int]()
        self.conn_to = List[Int]()
        self.conn_strength = List[Int]()
        self.conn_color = List[Int]()
        self.layout_type = LAYOUT_LINEAR

    # --- 构建 (mut self, 因 EmojiGraph 含 List 字段不可 Movable, 不能按值返回) ---
    def build(mut self, chains: List[List[Int]]):
        # 依据推理链(每条为 trigram id 序列)填充图形, 自动分配节点 id 与时间位置。
        # 采用扁平并行数组存储 (见 EmojiGraph 注释)。
        var id_counter = 0
        for c in range(len(chains)):
            var clen = len(chains[c])
            var start_id = id_counter
            for i in range(clen):
                self.node_trigram.append(chains[c][i])
                self.node_position.append(id_counter)
                self.node_emotion.append(NEUTRAL)
                self.node_weight.append(50)
                self.count += 1
                id_counter += 1
            # 链内相邻节点连边
            for i in range(1, clen):
                self.conn_from.append(start_id + i - 1)
                self.conn_to.append(start_id + i)
                self.conn_strength.append(50)
                self.conn_color.append(NEUTRAL)
                self.conn_count += 1

    # --- mut self 方法 (inout 的替代, 原地更新) ---
    def update_node_emotion(mut self, node_id: Int, new_emotion: Int):
        if node_id < 0 or node_id >= self.count:
            return
        self.node_emotion[node_id] = new_emotion
        # 同步更新从该节点出发的连线颜色
        for j in range(self.conn_count):
            if self.conn_from[j] == node_id:
                self.conn_color[j] = new_emotion

    def update_node_weight(mut self, node_id: Int, new_weight: Float64):
        if node_id < 0 or node_id >= self.count:
            return
        self.node_weight[node_id] = Int(new_weight * 100.0)

    # --- 渲染出口 (self 方法, 不按值传参, 见 ADR-0011) ---
    def render(self) -> String:
        # 生成 emoji / 文本化 行式可视化 (CLI 友好, 确定性)
        var s = "EmojiGraph{nodes="
        s += String(self.count)
        s += ",connections="
        s += String(self.conn_count)
        s += ",layout="
        s += _layout_name(self.layout_type)
        s += "}\n"
        for i in range(self.count):
            s += "["
            s += String(i)
            s += "] "
            s += _trigram_emoji(self.node_trigram[i])
            s += _trigram_name(self.node_trigram[i])
            s += " pos="
            s += String(self.node_position[i])
            s += " emo="
            s += _emotion_emoji(self.node_emotion[i])
            s += _emotion_name(self.node_emotion[i])
            s += " w="
            s += String(self.node_weight[i])
            s += "%\n"
        for j in range(self.conn_count):
            s += "  conn "
            s += String(self.conn_from[j])
            s += "->"
            s += String(self.conn_to[j])
            s += " strength="
            s += String(self.conn_strength[j])
            s += "% color="
            s += _emotion_name(self.conn_color[j])
            s += "\n"
        return s^

    def render_svg(self) -> String:
        # 生成 SVG 字符串 (坐标用 Int 派生, 不依赖 Float→String, 保持确定性)
        var w = 40 + (self.count * 60)
        var svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\""
        svg += String(w)
        svg += "\" height=\"80\">\n"
        for j in range(self.conn_count):
            var x1 = 30 + self.conn_from[j] * 60
            var x2 = 30 + self.conn_to[j] * 60
            svg += "  <line x1=\""
            svg += String(x1)
            svg += "\" y1=\"40\" x2=\""
            svg += String(x2)
            svg += "\" y2=\"40\" stroke=\"gray\" stroke-width=\"2\"/>\n"
        for i in range(self.count):
            var x = 30 + self.node_position[i] * 60
            svg += "  <g transform=\"translate("
            svg += String(x)
            svg += ",40)\"><rect x=\"-18\" y=\"-14\" width=\"36\" height=\"28\" rx=\"4\" fill=\"white\" stroke=\"black\"/>"
            svg += "<text x=\"0\" y=\"5\" text-anchor=\"middle\" font-size=\"14\">"
            svg += _trigram_emoji(self.node_trigram[i])
            svg += "</text></g>\n"
        svg += "</svg>\n"
        return svg^

# ---- 名称 / emoji 映射 (确定性, 纯 Int → String) ----

def _emotion_name(e: Int) -> String:
    if e == NEUTRAL: return "NEUTRAL"
    elif e == EXCITED: return "EXCITED"
    elif e == ANXIOUS: return "ANXIOUS"
    elif e == JOY: return "JOY"
    elif e == SAD: return "SAD"
    elif e == SURPRISED: return "SURPRISED"
    else: return "UNKNOWN"

def _emotion_emoji(e: Int) -> String:
    if e == NEUTRAL: return "😐"
    elif e == EXCITED: return "🤩"
    elif e == ANXIOUS: return "😰"
    elif e == JOY: return "😄"
    elif e == SAD: return "😢"
    elif e == SURPRISED: return "😲"
    else: return "?"

def _trigram_name(t: Int) -> String:
    if t == 0: return "CHIEN"
    elif t == 1: return "KUN"
    elif t == 2: return "ZHEN"
    elif t == 3: return "XUN"
    elif t == 4: return "KAN"
    elif t == 5: return "LI"
    elif t == 6: return "GEN"
    elif t == 7: return "DUI"
    else: return "?"

def _trigram_emoji(t: Int) -> String:
    # 八卦 Unicode 符号
    if t == 0: return "☰"
    elif t == 1: return "☷"
    elif t == 2: return "☳"
    elif t == 3: return "☴"
    elif t == 4: return "☵"
    elif t == 5: return "☲"
    elif t == 6: return "☶"
    elif t == 7: return "☱"
    else: return "?"

def _layout_name(t: Int) -> String:
    if t == LAYOUT_LINEAR: return "LINEAR"
    elif t == LAYOUT_TREE: return "TREE"
    elif t == LAYOUT_CIRCLE: return "CIRCLE"
    elif t == LAYOUT_HEATMAP: return "HEATMAP"
    else: return "UNKNOWN"
