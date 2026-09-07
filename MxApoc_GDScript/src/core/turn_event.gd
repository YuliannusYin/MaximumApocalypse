class_name TurnEvent
extends "res://src/core/game_event.gd"

## 正式回合的统一事件节点。由 EventScheduler.run_event 贯穿整个 start_turn / 第零轮。
## PhaseEvent 作为其 children 跨度运行。

var turn_number: int = 0


func _init(turn_owner: Variant = null, number: int = 0) -> void:
	super._init("turn", turn_owner, null)
	turn_number = number
