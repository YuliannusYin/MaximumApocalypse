class_name TurnEvent
extends "res://src/core/game_event.gd"

## 正式回合的统一事件节点。
## PhaseEvent 作为其 children，挂接在 Player 的 begin_turn_context/_enter_turn_phase 流程中。
## 详见 .cursor/plan/plan.md 批次三。

var turn_number: int = 0


func _init(turn_owner: Variant = null, number: int = 0) -> void:
	super._init("turn", turn_owner, null)
	turn_number = number
