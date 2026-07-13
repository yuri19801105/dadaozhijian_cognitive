# 认知流水线 - 统一入口
#   run_cycle       : 只读规划器 —— 读取九宫+文本 → 输出七星规划链, 不修改九宫
#   CognitiveCycle  : 认知→行动→回灌太极 闭环持有者(mut self 方法, 跨轮可变状态)
# 语言: Mojo 1.0.0b2 | 验证: E2E
#
# 设计注: 本构建不支持 class / inout 参数, 且含 String 字段的 struct 不可 Movable。
# 故跨轮闭环状态由 CognitiveCycle 以「Workspace + TaijiState 字段 + mut self run」
# 承载, 状态变更发生在 mut self 方法内, 无需跨函数 inout 传递。

from workspace import Workspace
from config import Config
from wu_xing import WOOD, FIRE, EARTH, METAL, WATER, PhaseSignal, schedule
from liuhe import context_vector
from qixing import plan
from executor import execute
from taiji import TaijiState, _intent_hash

def _compute_intensity(text: String) -> Int:
    var length = text.byte_length()
    if length == 0:
        return 0
    var raw = length / 10
    if raw < 1:
        return 1
    if raw > 9:
        return 9
    return raw

def _detect_phase(text: String) -> Int:
    var length = text.byte_length()
    if length == 0:
        return WATER
    elif length < 10:
        return WOOD
    elif length < 50:
        return FIRE
    elif length < 100:
        return EARTH
    else:
        return METAL

def _parse_text(text: String) -> PhaseSignal:
    var sig = PhaseSignal()
    sig.phase = _detect_phase(text)
    sig.intensity = _compute_intensity(text)
    sig.data_tag = text.byte_length()
    return sig

def run_cycle(ws: Workspace, text: String, cfg: Config) -> List[Int]:
    # 1. 解析文本 → 阶段信号
    var sig = _parse_text(text)

    # 2. 五行调度 → 候选链
    var decision = schedule(ws, sig)
    var chain = decision.chain_to_list()

    if len(chain) == 0:
        return chain^

    # 3. 六合态势
    var vec = context_vector(ws, 1, text, cfg)

    # 4. 七星规划 → 排序后执行链
    var planned = plan(vec, chain)

    return planned^

def run_cycle_chains(ws: Workspace, text: String, cfg: Config) -> List[List[Int]]:
    # M8(静语可视化)接入点: 返回中间链集合 [候选链(五行调度), 规划链(七星排序)]
    # 不改变 run_cycle 的既有行为, 仅供可视化观测使用。
    var sig = _parse_text(text)
    var decision = schedule(ws, sig)
    var chain = decision.chain_to_list()
    var out = List[List[Int]]()
    if len(chain) == 0:
        return out^
    out.append(chain.copy())              # 中间候选链(复制进 out, chain 仍可用)
    var vec = context_vector(ws, 1, text, cfg)
    var planned = plan(vec, chain)
    out.append(planned^)                  # 排序后规划链(移入 out)
    return out^

struct CognitiveCycle:
    # 认知→行动→回灌太极 闭环持有者
    #   ws    : 单轮工作记忆(九宫), 每轮重建语义由 schedule 读取
    #   state : 跨轮全局状态根(太极), 累积记忆 + 派生种子
    var ws: Workspace
    var state: TaijiState

    def __init__(out self, intent: String = ""):
        self.ws = Workspace()
        self.state = TaijiState(_intent_hash(intent))

    def run(mut self, text: String, cfg: Config) -> String:
        # 0. 读取太极记忆, 注入本轮输入 (首次 recall()="" 等价于无记忆, 退化成单轮流水线)
        var ctx = self.state.recall()
        var effective = ctx + text
        # 1-4. 规划(同 run_cycle, 只读九宫)
        var planned = run_cycle(self.ws, effective, cfg)
        if len(planned) == 0:
            return ""
        # 5. 十合执行 → 文本输出 (用副本, 保留 planned 供回灌)
        var exec_chain = List[Int]()
        for i in range(len(planned)):
            exec_chain.append(planned[i])
        var output = execute(exec_chain^, self.ws, effective)
        # 6. 回灌太极: 十方输出 + 七星决策写入长期记忆, 派生全局状态根种子(见 ADR-0010)
        self.state.feedback(output, planned, _detect_phase(effective), _compute_intensity(effective))
        return output^
