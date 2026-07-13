# === shifang/__init__.mojo ===
# 十方执行层：十向周遍扇出 + 真实模型/API 连接器（让架构"能说话"）。
# 下游聚合导入：from shifang import fanout, Connector, ShifangOutput, render_reply

from .protocol import (
    CONNECTOR_LOCAL, CONNECTOR_LLM,
    DIR_EAST, DIR_SOUTH, DIR_WEST, DIR_NORTH, DIR_SE, DIR_SW, DIR_NE, DIR_NW, DIR_UP, DIR_DOWN, DIR_COUNT,
    direction_name, Connector, ConnectorResponse, call_external,
)
from .sidecar import (
    LLMSidecar, SidecarRequest, SidecarResponse, SIDECAR_TEMPLATE, SIDECAR_EXTERNAL, shifang_llm_call,
)
from .dispatch import ShifangOutput, fanout, fanout_safe, build_prompt
from .executor import action_label, execute_plan_to_text, render_reply
