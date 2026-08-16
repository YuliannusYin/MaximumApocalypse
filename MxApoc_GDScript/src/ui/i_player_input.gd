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


## 选 n 张牌。filter: Callable(card) -> bool，null 表示不过滤。
## param 为 String 时：按 position（如 "hand"/"equipment"/"discard"）查询玩家区域卡牌。
## param 为 Array 时：直接作为候选卡牌列表，绕过 position 查询。
func choose_card(n: int, param: Variant = "hand", filter: Variant = null) -> Array:
	_push_override_error("choose_card")
	return []


## 选择目标。n 为选择数量（-1 表示全部），skill 为当前技能（含 target_type/filter_target 等）。
func choose_target(n: int, skill: Variant) -> Array:
	_push_override_error("choose_target")
	return []


## 选一个地块。
func choose_map_block(blocks: Array, prompt: String = "") -> Variant:
	_push_override_error("choose_map_block")
	return null


## 内联选取地块（使用地图内联高亮，非弹窗）。返回选中的地块数组（取消返回空数组）。
func choose_block_inline(valid_blocks: Array, prompt: String, count: int) -> Array:
	_push_override_error("choose_block_inline")
	return []


## 确认对话框，返回 true/false。
func confirm(message: String) -> bool:
	_push_override_error("confirm")
	return false


## 向目标展示一张牌。
func show_card(card: Card, target: Variant) -> void:
	_push_override_error("show_card")


## 设置 prompt 区文本（单向通知，不等待响应）。
func set_prompt(text: String) -> void:
	_push_override_error("set_prompt")


## 等待玩家重调决策。返回 true 表示确定重调，false 表示取消。
func wait_redraw_decision(player: Variant) -> bool:
	_push_override_error("wait_redraw_decision")
	return false


func _push_override_error(method_name: String) -> void:
	push_error("IPlayerInput.%s must be overridden by subclass" % method_name)
