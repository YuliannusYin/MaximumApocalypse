class_name TurnContext
extends RefCounted

## 正式回合的阶段与行动点上下文。
## 有限跨玩家操作由 OperationRuntime 单独承载，并在 Player 的 effective API 中优先。

var owner: Variant = null
var turn_number: int = 0
var phase: String = "idle"
var action_limit: int = 0
var remaining_actions: int = 0
var active: bool = true
var ended: bool = false


func _init(owner_player: Variant = null, number: int = 0, action_count: int = 0) -> void:
	owner = owner_player
	turn_number = number
	action_limit = maxi(action_count, 0)
	remaining_actions = action_limit


func enter_phase(new_phase: String) -> String:
	var old_phase: String = phase
	phase = new_phase
	return old_phase


func consume_action(amount: int) -> int:
	var actual: int = mini(maxi(amount, 0), remaining_actions)
	remaining_actions -= actual
	return actual


func add_action(amount: int) -> void:
	remaining_actions = maxi(remaining_actions + amount, 0)


func set_action_count(amount: int) -> void:
	remaining_actions = maxi(amount, 0)


func finish() -> void:
	active = false
	ended = true
