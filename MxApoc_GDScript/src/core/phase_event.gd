class_name PhaseEvent
extends RefCounted

## 正式阶段切换事件。与可取消的技能 event 分离，专门供 UI、教程和测试观察。

const TurnContextScript = preload("res://src/core/turn_context.gd")

var player: Variant = null
var context: RefCounted = null
var old_phase: String = ""
var new_phase: String = ""
var sequence: int = 0
var reason: String = ""
var action_remaining: int = 0
var parent: Variant = null  # TurnEvent，统一事件树的正式回合父节点


func _init(
	phase_player: Variant,
	turn_context: RefCounted,
	previous_phase: String,
	next_phase: String,
	phase_sequence: int,
	phase_reason: String = "",
	turn_event: Variant = null
) -> void:
	player = phase_player
	context = turn_context
	old_phase = previous_phase
	new_phase = next_phase
	sequence = phase_sequence
	reason = phase_reason
	action_remaining = turn_context.remaining_actions if turn_context != null else 0
	parent = turn_event
