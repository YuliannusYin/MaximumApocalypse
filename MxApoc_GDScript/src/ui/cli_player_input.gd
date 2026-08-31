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
var _judge_confirm_queue: Array = []


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


func queue_judge_confirm(result: bool) -> void:
	_judge_confirm_queue.append(result)


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


func wait_judge_confirm(player: Variant, prompt: String, allow_cancel: bool) -> bool:
	if _judge_confirm_queue.size() > 0:
		return _judge_confirm_queue.pop_front()
	return true  # 默认确定（与 GUI 5 秒超时默认确定语义一致）


func play_dice_animation(d1: int, d2: int, label: String, outcome: String) -> void:
	# 命令行模式无动画，仅打印骰子结果并立即返回，不阻塞流程
	print("[骰子] " + label + ": " + str(d1) + " + " + str(d2) + " = " + str(d1 + d2) + (" " + outcome if outcome != "" else ""))


func play_monster_draw_animation(_player: Variant, card: Variant) -> void:
	# 命令行模式无动画，仅打印抓取的怪物牌并立即返回，不阻塞流程
	print("[抓怪] " + card.card_name)


func play_scavenge_draw_animation(_player: Variant, card: Variant) -> void:
	# 命令行模式无动画，仅打印抓取的拾荒牌并立即返回，不阻塞流程
	print("[抓牌] " + card.card_name)


func play_card_destroy_animation(_card: Card) -> void:
	# 命令行与 headless 测试环境不播放动画，立即完成销毁流程。
	pass


func play_monster_skill_trigger_animation(_monster: Variant) -> void:
	# 命令行模式不播动画，立即完成技能触发流程，不阻塞流程。
	pass


func play_monster_attack_animation(_monster: Variant, _targets: Array) -> void:
	# 命令行模式不播动画，立即完成怪物攻击流程，不阻塞流程。
	pass
