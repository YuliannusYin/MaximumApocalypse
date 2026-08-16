class_name GUIPlayerInput
extends IPlayerInput

## GUI 玩家输入实现。
## 通过信号与 GameScene2D 通信，使用 await 等待玩家操作。
## 每个方法发射请求信号，等待 respond_* 方法响应后返回。

# === 请求信号（GameScene2D 订阅） ===

signal action_requested(player: Variant)
signal choose_requested(options: Array, prompt: String)
signal choose_card_requested(n: int, param: Variant, filter: Variant)
signal choose_target_requested(n: int, skill: Variant)
signal choose_block_requested(blocks: Array, prompt: String)
signal choose_block_inline_requested(valid_blocks: Array, prompt: String, count: int)
signal confirm_requested(message: String)
signal show_card_requested(card: Card, target: Variant)
signal set_prompt_requested(text: String)
signal redraw_decision_requested()

# === 响应状态 ===

var _response: Variant = null
var _response_received: bool = false


# === 通用等待机制 ===

func _wait_for_response() -> Variant:
	_response_received = false
	while not _response_received:
		await Engine.get_main_loop().process_frame
	return _response


func _set_response(value: Variant) -> void:
	_response = value
	_response_received = true


# === IPlayerInput 实现 ===

func wait_action(player: Variant) -> Variant:
	action_requested.emit(player)
	return await _wait_for_response()


func choose(options: Array, prompt: String = "") -> Variant:
	choose_requested.emit(options, prompt)
	return await _wait_for_response()


func choose_card(n: int, param: Variant = "hand", filter: Variant = null) -> Array:
	choose_card_requested.emit(n, param, filter)
	var result: Variant = await _wait_for_response()
	if result is Array:
		return result
	return []


func choose_target(n: int, skill: Variant = null) -> Array:
	choose_target_requested.emit(n, skill)
	var result: Variant = await _wait_for_response()
	if result == null:
		return []
	if result is Array:
		return result
	return []


func choose_map_block(blocks: Array, prompt: String = "") -> Variant:
	choose_block_requested.emit(blocks, prompt)
	return await _wait_for_response()


func choose_block_inline(valid_blocks: Array, prompt: String, count: int) -> Array:
	choose_block_inline_requested.emit(valid_blocks, prompt, count)
	var result: Variant = await _wait_for_response()
	if result is Array:
		return result
	return []


func confirm(message: String) -> bool:
	confirm_requested.emit(message)
	var result: Variant = await _wait_for_response()
	return bool(result)


func show_card(card: Card, target: Variant) -> void:
	show_card_requested.emit(card, target)


## 设置 prompt 区文本（fire-and-forget，不等待响应）。
func set_prompt(text: String) -> void:
	set_prompt_requested.emit(text)


## 等待玩家重调决策。发射信号请求 UI 显示重调界面，await 响应后返回。
func wait_redraw_decision(player: Variant) -> bool:
	redraw_decision_requested.emit()
	var result: Variant = await _wait_for_response()
	return bool(result)


# === 响应方法（GameScene2D 调用） ===

func respond_action(choice: Variant) -> void:
	_set_response(choice)


func respond_choose(choice: Variant) -> void:
	_set_response(choice)


func respond_choose_card(cards: Array) -> void:
	_set_response(cards)


func respond_choose_target(targets: Array) -> void:
	_set_response(targets)


func respond_choose_block(blocks: Variant) -> void:
	_set_response(blocks)


func respond_confirm(result: bool) -> void:
	_set_response(result)


func respond_redraw_decision(result: bool) -> void:
	_set_response(result)
