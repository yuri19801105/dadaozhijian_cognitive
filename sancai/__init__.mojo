# === sancai/__init__.mojo ===
# 三才包标记(天地人分层接口)。子模块: layers(三层结构) / interface(层间消息契约)。
# 下游聚合导入: from sancai import SanCai, LayerMessage, LayerBus

from .layers import SanCai, TIAN, DI, REN, LAYER_COUNT
from .interface import LayerMessage, LayerBus
