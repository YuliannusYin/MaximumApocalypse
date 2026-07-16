class_name GUIPlayerInput
extends IPlayerInput

## GUI 玩家输入实现。
## 通过信号与 GameScene2D 通信，使用 await 等待玩家操作。
## 每个方法发射请求信号，等待 respond_* 方法响应后返回。

# === 请求信号（GameScene2D 订阅） ===

signal action_requested(player: Variant)
signal choose_requested(options: Array, prompt: String)
signal choose_card_requested(n: int, position: String)
signal choose_target_requested(n: int)
signal choose_block_requested(blocks: Array, prompt: String)
signal confirm_requested(message: String)
signal show_card_requested(card: Card, target: Variant)

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


func choose_card(n: int, position: String = "hand", filter: Variant = null) -> Array:
	choose_card_requested.emit(n, position)
	var result: Variant = await _wait_for_response()
	if result is Array:
		return result
	return []


func choose_target(n: int, filter: Variant = null) -> Array:
	choose_target_requested.emit(n)
	var result: Variant = await _wait_for_response()
	if result is Array:
		return result
	return []


func choose_map_block(blocks: Array, prompt: String = "") -> Variant:
	choose_block_requested.emit(blocks, prompt)
	return await _wait_for_response()


func confirm(message: String) -> bool:
	confirm_requested.emit(message)
	var result: Variant = await _wait_for_response()
	return bool(result)


func show_card(card: Card, target: Variant) -> void:
	show_card_requested.emit(card, target)


# === 响应方法（GameScene2D 调用） ===

func respond_action(choice: Variant) -> void:
	_set_response(choice)


func respond_choose(choice: Variant) -> void:
	_set_response(choice)


func respond_choose_card(cards: Array) -> void:
	_set_response(cards)


func respond_choose_target(targets: Array) -> void:
	_set_response(targets)


func respond_choose_block(block: Variant) -> void:
	_set_response(block)


func respond_confirm(result: bool) -> void:
	_set_response(result)
