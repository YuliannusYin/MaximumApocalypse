class_name CliPlayerInput
extends IPlayerInput

## 命令行玩家输入实现。
## 阶段 1 测试用：默认返回第一项 / true / null，避免阻塞测试。
## 真正的 stdin 交互留待阶段 2 GUI 接入。
## 测试可通过 queue_* 方法注入预定应答序列。

# 预定应答队列（测试用）
var _action_queue: Array = []
var _choose_queue: Array = []
var _choose_card_queue: Array = []
var _choose_target_queue: Array = []
var _choose_block_queue: Array = []
var _confirm_queue: Array = []
var _redraw_decision_queue: Array = []


func queue_action(result: Variant) -> void:
	_action_queue.append(result)


func queue_choose(result: Variant) -> void:
	_choose_queue.append(result)


func queue_choose_card(result: Array) -> void:
	_choose_card_queue.append(result)


func queue_choose_target(result: Array) -> void:
	_choose_target_queue.append(result)


func queue_choose_block(result: Variant) -> void:
	_choose_block_queue.append(result)


func queue_confirm(result: bool) -> void:
	_confirm_queue.append(result)


func queue_redraw_decision(result: bool) -> void:
	_redraw_decision_queue.append(result)


func wait_action(player: Variant) -> Variant:
	if _action_queue.size() > 0:
		return _action_queue.pop_front()
	return null  # 默认结束行动


func choose(options: Array, prompt: String = "") -> Variant:
	if _choose_queue.size() > 0:
		return _choose_queue.pop_front()
	if options.size() > 0:
		return options[0]  # 默认第一项
	return null


func choose_card(n: int, param: Variant = "hand", filter: Variant = null, prompt: String = "", min_n: int = -1) -> Array:
	if _choose_card_queue.size() > 0:
		return _choose_card_queue.pop_front()
	return []  # 默认不选


func choose_target(n: int, skill: Variant = null, prompt: String = "", min_n: int = -1) -> Array:
	if _choose_target_queue.size() > 0:
		return _choose_target_queue.pop_front()
	return []


func choose_map_block(blocks: Array, prompt: String = "") -> Variant:
	if _choose_block_queue.size() > 0:
		return _choose_block_queue.pop_front()
	if blocks.size() > 0:
		return blocks[0]
	return null


func choose_block_inline(valid_blocks: Array, prompt: String, count: int) -> Array:
	if _choose_block_queue.size() > 0:
		var queued: Variant = _choose_block_queue.pop_front()
		if queued is Array:
			return queued
		if queued != null:
			return [queued]
		return []
	if valid_blocks.is_empty():
		return []
	var n: int = maxi(count, 1)
	if n > valid_blocks.size():
		n = valid_blocks.size()
	return valid_blocks.slice(0, n)


func confirm(message: String) -> bool:
	if _confirm_queue.size() > 0:
		return _confirm_queue.pop_front()
	return true  # 默认确认


func show_card(card: Card, target: Variant) -> void:
	pass  # 命令行模式静默


func set_prompt(text: String) -> void:
	print("[Prompt] " + text)


func wait_redraw_decision(player: Variant) -> bool:
	if _redraw_decision_queue.size() > 0:
		return _redraw_decision_queue.pop_front()
	return false  # 默认不重调
