class_name GUIPlayerInput
extends IPlayerInput

## GUI 玩家输入实现。
## 通过信号与 GameScene2D 通信，使用 await 等待玩家操作。
## 所有玩家输入请求经请求队列串行处理：空闲时立即派发（emit 请求信号），
## 忙碌（已有活动请求未结算）时入队等待；活动请求结算恢复后自动派发
## 下一个排队请求。这样外层结算 await 期间发生的插入结算（内层请求）
## 不会被吞掉，各请求只消费自己的响应，不会错位。
## respond_* 方法写入当前活动请求的响应；已响应的请求忽略重复响应（防双击）。

# === 请求信号（GameScene2D 订阅） ===

signal action_requested(player: Variant)
signal choose_requested(options: Array, prompt: String)
signal choose_card_requested(n: int, param: Variant, filter: Variant, prompt: String, min_n: int)
signal choose_target_requested(n: int, skill: Variant, prompt: String, min_n: int)
signal choose_block_requested(blocks: Array, prompt: String)
signal choose_block_inline_requested(valid_blocks: Array, prompt: String, count: int)
signal confirm_requested(message: String)
signal show_card_requested(card: Card, target: Variant)
signal set_prompt_requested(text: String)
signal redraw_decision_requested()
signal judge_confirm_requested(prompt: String, allow_cancel: bool)
signal dice_animation_requested(d1: int, d2: int, label: String, outcome: String)
signal monster_draw_animation_requested(player: Variant, card: Variant)
signal scavenge_draw_animation_requested(player: Variant, card: Variant)
signal card_destroy_animation_requested(card: Card)
signal monster_skill_trigger_animation_requested(monster: Variant)
signal monster_attack_animation_requested(monster: Variant, targets: Array)

# === 请求队列（插入结算机制核心） ===
# 所有玩家输入请求串行处理：空闲时立即派发，忙碌时入队等待；
# 活动请求结算恢复后自动派发下一个排队请求，外层结算不会被内层插入结算吞掉。
var _request_queue: Array = []  # 等待派发的请求对象列表
var _active_request: Dictionary = {}  # 当前活动请求（空字典 = 无活动请求）
var _request_counter: int = 0  # 请求 id 自增计数器


# === 队列核心 ===

## 创建请求并入队；若无活动请求则立即派发给 UI。
func _enqueue_request(emit_fn: Callable) -> Dictionary:
	_request_counter += 1
	var req: Dictionary = {
		"id": _request_counter,
		"emit_fn": emit_fn,
		"response": null,
		"received": false,
	}
	_request_queue.append(req)
	_dispatch_next_if_idle()
	return req


## 空闲时弹出队首请求并向 UI 派发（emit 请求信号）。
func _dispatch_next_if_idle() -> void:
	if _active_request.is_empty() and not _request_queue.is_empty():
		_active_request = _request_queue.pop_front()
		var fn: Callable = _active_request["emit_fn"]
		fn.call()


## 等待指定请求自身的响应；恢复后释放活动槽并派发下一个排队请求。
func _wait_for_request(req: Dictionary) -> Variant:
	while not req["received"]:
		await Engine.get_main_loop().process_frame
	if _active_request.get("id") == req.get("id"):
		_active_request = {}
		_dispatch_next_if_idle()
	return req["response"]


## 写入当前活动请求的响应；已响应的请求忽略重复响应（防双击）。
func _respond_active(value: Variant) -> void:
	if _active_request.is_empty():
		return
	if _active_request["received"]:
		return
	_active_request["response"] = value
	_active_request["received"] = true


## 安全 bool 转换：被污染的非 bool 响应（Array/Dictionary 等）一律按 false 结算，
## 避免 bool() 构造异常导致脚本中止、联机断连。
func _to_bool(value: Variant) -> bool:
	return value if value is bool else false


# === IPlayerInput 实现 ===

func wait_action(player: Variant) -> Variant:
	var req: Dictionary = _enqueue_request(func() -> void:
		action_requested.emit(player))
	return await _wait_for_request(req)


func choose(options: Array, prompt: String = "") -> Variant:
	var req: Dictionary = _enqueue_request(func() -> void:
		choose_requested.emit(options, prompt))
	return await _wait_for_request(req)


func choose_card(n: int, param: Variant = "hand", filter: Variant = null, prompt: String = "", min_n: int = -1) -> Array:
	var req: Dictionary = _enqueue_request(func() -> void:
		choose_card_requested.emit(n, param, filter, prompt, min_n))
	var result: Variant = await _wait_for_request(req)
	if result is Array:
		return result
	return []


func choose_target(n: int, skill: Variant = null, prompt: String = "", min_n: int = -1) -> Array:
	var req: Dictionary = _enqueue_request(func() -> void:
		choose_target_requested.emit(n, skill, prompt, min_n))
	var result: Variant = await _wait_for_request(req)
	if result is Array:
		return result
	return []


func choose_map_block(blocks: Array, prompt: String = "") -> Variant:
	var req: Dictionary = _enqueue_request(func() -> void:
		choose_block_requested.emit(blocks, prompt))
	return await _wait_for_request(req)


func choose_block_inline(valid_blocks: Array, prompt: String, count: int) -> Array:
	var req: Dictionary = _enqueue_request(func() -> void:
		choose_block_inline_requested.emit(valid_blocks, prompt, count))
	var result: Variant = await _wait_for_request(req)
	if result is Array:
		return result
	return []


func confirm(message: String) -> bool:
	var req: Dictionary = _enqueue_request(func() -> void:
		confirm_requested.emit(message))
	var result: Variant = await _wait_for_request(req)
	return _to_bool(result)


func show_card(card: Card, target: Variant) -> void:
	show_card_requested.emit(card, target)


## 设置 prompt 区文本（fire-and-forget，不等待响应）。
func set_prompt(text: String) -> void:
	set_prompt_requested.emit(text)


## 等待玩家重调决策。发射信号请求 UI 显示重调界面，await 响应后返回。
func wait_redraw_decision(player: Variant) -> bool:
	var req: Dictionary = _enqueue_request(func() -> void:
		redraw_decision_requested.emit())
	var result: Variant = await _wait_for_request(req)
	return _to_bool(result)


## 检定确认门。发射信号请求 UI 显示确认门，await 响应后返回（true=执行 / false=放弃）。
func wait_judge_confirm(player: Variant, prompt: String, allow_cancel: bool) -> bool:
	var req: Dictionary = _enqueue_request(func() -> void:
		judge_confirm_requested.emit(prompt, allow_cancel))
	var result: Variant = await _wait_for_request(req)
	return _to_bool(result)


## 播放两颗骰子投掷动画并等待结束。动画播完后由 UI 调用 respond_dice_animation 结算，期间阻塞后续请求派发。
func play_dice_animation(d1: int, d2: int, label: String, outcome: String) -> void:
	var req: Dictionary = _enqueue_request(func() -> void:
		dice_animation_requested.emit(d1, d2, label, outcome))
	await _wait_for_request(req)


## 播放抓取怪物牌动画并等待结束。动画播完后由 UI 调用 respond_monster_draw_animation 结算，期间阻塞后续请求派发。
func play_monster_draw_animation(player: Variant, card: Variant) -> void:
	var req: Dictionary = _enqueue_request(func() -> void:
		monster_draw_animation_requested.emit(player, card))
	await _wait_for_request(req)


## 播放抓取拾荒牌"抓取时"技能触发动画并等待结束。动画播完后由 UI 调用 respond_scavenge_draw_animation 结算，期间阻塞后续请求派发。
func play_scavenge_draw_animation(player: Variant, card: Variant) -> void:
	var req: Dictionary = _enqueue_request(func() -> void:
		scavenge_draw_animation_requested.emit(player, card))
	await _wait_for_request(req)


## 播放卡牌移出游戏动画并等待结束。动画由 UI 完成后回执，期间阻塞后续请求派发。
func play_card_destroy_animation(card: Card) -> void:
	var req: Dictionary = _enqueue_request(func() -> void:
		card_destroy_animation_requested.emit(card))
	await _wait_for_request(req)


## 播放触发怪物技能动画并等待结束。动画播完后由 UI 调用 respond_monster_skill_trigger_animation 结算，期间阻塞后续请求派发。
func play_monster_skill_trigger_animation(monster: Variant) -> void:
	var req: Dictionary = _enqueue_request(func() -> void:
		monster_skill_trigger_animation_requested.emit(monster))
	await _wait_for_request(req)


## 播放怪物攻击动画并等待结束。动画播完后由 UI 调用 respond_monster_attack_animation 结算，期间阻塞后续请求派发。
func play_monster_attack_animation(monster: Variant, targets: Array) -> void:
	var req: Dictionary = _enqueue_request(func() -> void:
		monster_attack_animation_requested.emit(monster, targets))
	await _wait_for_request(req)


# === 响应方法（GameScene2D 调用，写入当前活动请求） ===

func respond_action(choice: Variant) -> void:
	_respond_active(choice)


func respond_choose(choice: Variant) -> void:
	_respond_active(choice)


func respond_choose_card(cards: Array) -> void:
	_respond_active(cards)


func respond_choose_target(targets: Array) -> void:
	_respond_active(targets)


func respond_choose_block(blocks: Variant) -> void:
	_respond_active(blocks)


func respond_confirm(result: bool) -> void:
	_respond_active(result)


func respond_redraw_decision(result: bool) -> void:
	_respond_active(result)


func respond_judge_confirm(result: bool) -> void:
	_respond_active(result)


func respond_dice_animation() -> void:
	_respond_active(null)


func respond_monster_draw_animation() -> void:
	_respond_active(null)


func respond_scavenge_draw_animation() -> void:
	_respond_active(null)


func respond_card_destroy_animation() -> void:
	_respond_active(null)


func respond_monster_skill_trigger_animation() -> void:
	_respond_active(null)


func respond_monster_attack_animation() -> void:
	_respond_active(null)
