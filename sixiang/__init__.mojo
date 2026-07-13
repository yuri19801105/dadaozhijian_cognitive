# === sixiang/__init__.mojo ===
# 四象包标记(四态/四象限: 老少阴阳)。子模块: quadrant(四象限类型) / phase(四相状态机)。
# 下游聚合导入: from sixiang import Quadrant, QuadrantClassifier, PhaseMachine, phase_name

from .quadrant import Quadrant, QuadrantClassifier, phase_name, OLD_YIN, YOUNG_YANG, OLD_YANG, YOUNG_YIN, QUADRANT_COUNT
from .phase import PhaseMachine
