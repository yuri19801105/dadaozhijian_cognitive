from trigram import CHIEN, apply_trigram, TrigramAction
from workspace import Workspace

def main() raises:
    var ws = Workspace()
    var a = apply_trigram(CHIEN, ws, 42)
    print("action_id:", a.action_id)
    print("value:", a.value)
    print("confidence:", a.confidence)
