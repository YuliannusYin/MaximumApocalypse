class_name IPlayerInput
extends RefCounted

## 玩家输入接口（抽象基类模拟）。
## GDScript 无 interface 关键字，用抽象基类 + push_error 强制子类 override。
## 阶段 1 用 CliPlayerInput；阶段 2+ 用 GUIPlayerInput/AIPlayerInput。
## 设计文档：docs/design-gaps.md §2.2


## 行动阶段等待玩家选择行动。返回 null 表示结束行动。
func wait_action(player: Variant) -> Variant:
	_push_override_error("wait_action")
	return null


## 从列表中选择一项，返回选中项（非索引）。
func choose(options: Array, prompt: String = "") -> Variant:
	_push_override_error("choose")
	return null


## 从手牌/装备区选 n 张牌。filter: Callable(card) -> bool，null 表示不过滤。
func choose_card(n: int, position: String = "hand", filter: Variant = null) -> Array:
	_push_override_error("choose_card")
	return []


## 选 n 个目标玩家。filter: Callable(player) -> bool。
func choose_target(n: int, filter: Variant = null) -> Array:
	_push_override_error("choose_target")
	return []


## 选一个地块。
func choose_map_block(blocks: Array, prompt: String = "") -> Variant:
	_push_override_error("choose_map_block")
	return null


## 确认对话框，返回 true/false。
func confirm(message: String) -> bool:
	_push_override_error("confirm")
	return false


## 向目标展示一张牌。
func show_card(card: Card, target: Variant) -> void:
	_push_override_error("show_card")


func _push_override_error(method_name: String) -> void:
	push_error("IPlayerInput.%s must be overridden by subclass" % method_name)
