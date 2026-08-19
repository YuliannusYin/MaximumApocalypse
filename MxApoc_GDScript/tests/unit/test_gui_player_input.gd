extends GutTest

## 测试 GUIPlayerInput 异步等待/响应机制。


func test_wait_action_returns_response() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var holder: Dictionary = {"value": null}
	_run_wait_action(input, holder)
	await get_tree().create_timer(0.02).timeout
	input.respond_action("end_turn")
	await get_tree().create_timer(0.02).timeout
	assert_eq(holder["value"], "end_turn", "wait_action 应返回 respond_action 的值")


func test_wait_action_returns_null_by_default() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var holder: Dictionary = {"value": "sentinel"}
	_run_wait_action(input, holder)
	await get_tree().create_timer(0.02).timeout
	input.respond_action(null)
	await get_tree().create_timer(0.02).timeout
	assert_null(holder["value"], "wait_action 应返回 null")


func test_choose_returns_selected_option() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var holder: Dictionary = {"value": null}
	_run_choose(input, holder, ["选项A", "选项B"], "请选择")
	await get_tree().create_timer(0.02).timeout
	input.respond_choose("选项B")
	await get_tree().create_timer(0.02).timeout
	assert_eq(holder["value"], "选项B", "choose 应返回选中项")


func test_choose_card_returns_array() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var holder: Dictionary = {"value": null}
	_run_choose_card(input, holder, 2, "hand")
	await get_tree().create_timer(0.02).timeout
	var cards: Array = [Card.new(), Card.new()]
	input.respond_choose_card(cards)
	await get_tree().create_timer(0.02).timeout
	assert_eq(holder["value"], cards, "choose_card 应返回卡牌数组")


func test_choose_card_returns_empty_on_non_array() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var holder: Dictionary = {"value": "sentinel"}
	_run_choose_card(input, holder, 1, "hand")
	await get_tree().create_timer(0.02).timeout
	input.respond_choose("not_an_array")
	await get_tree().create_timer(0.02).timeout
	assert_eq(holder["value"], [], "非数组响应应返回空数组")


func test_choose_target_returns_array() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var holder: Dictionary = {"value": null}
	_run_choose_target(input, holder, 1)
	await get_tree().create_timer(0.02).timeout
	var targets: Array = [Player.new()]
	input.respond_choose_target(targets)
	await get_tree().create_timer(0.02).timeout
	assert_eq(holder["value"], targets, "choose_target 应返回目标数组")


func test_choose_map_block_returns_block() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var holder: Dictionary = {"value": null}
	_run_choose_block(input, holder, [], "选择地块")
	await get_tree().create_timer(0.02).timeout
	var block: MapBlock = MapBlock.new()
	input.respond_choose_block(block)
	await get_tree().create_timer(0.02).timeout
	assert_eq(holder["value"], block, "choose_map_block 应返回选中的地块")


func test_confirm_returns_bool() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var holder: Dictionary = {"value": null}
	_run_confirm(input, holder, "确认？")
	await get_tree().create_timer(0.02).timeout
	input.respond_confirm(true)
	await get_tree().create_timer(0.02).timeout
	assert_true(holder["value"], "confirm 应返回 true")


func test_confirm_returns_false() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var holder: Dictionary = {"value": null}
	_run_confirm(input, holder, "确认？")
	await get_tree().create_timer(0.02).timeout
	input.respond_confirm(false)
	await get_tree().create_timer(0.02).timeout
	assert_false(holder["value"], "confirm 应返回 false")


func test_show_card_emits_signal() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var received: Array = []
	input.show_card_requested.connect(func(card, target): received.append([card, target]))
	var card: Card = Card.new()
	var target: Player = Player.new()
	input.show_card(card, target)
	assert_eq(received.size(), 1, "应发射 show_card_requested 信号")
	assert_eq(received[0][0], card, "信号应携带正确的卡牌")
	assert_eq(received[0][1], target, "信号应携带正确的目标")


func test_action_requested_signal_emitted() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var signal_received: Array = []
	input.action_requested.connect(func(_p): signal_received.append(true))
	_run_wait_action(input, {})
	await get_tree().create_timer(0.02).timeout
	assert_true(signal_received.size() > 0, "wait_action 应发射 action_requested 信号")
	input.respond_action(null)
	await get_tree().create_timer(0.01).timeout


# === 请求队列机制测试 ===

func test_single_request_dispatched_immediately() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var emitted: Array = []
	input.confirm_requested.connect(func(_message): emitted.append(true))
	_run_confirm(input, {}, "立即派发")
	assert_eq(emitted.size(), 1, "空闲时请求应立即派发（同步发出 confirm_requested）")
	input.respond_confirm(true)
	await get_tree().create_timer(0.02).timeout


func test_queued_request_dispatched_after_active_resolved() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var confirm_emitted: Array = []
	var choose_card_emitted: Array = []
	input.confirm_requested.connect(func(_message): confirm_emitted.append(true))
	input.choose_card_requested.connect(func(_n, _param, _filter, _prompt, _min_n): choose_card_emitted.append(true))

	var holder_a: Dictionary = {"value": null}
	var holder_b: Dictionary = {"value": null}
	# A（confirm）派发为活动请求；B（choose_card）应入队而非立即派发
	_run_confirm(input, holder_a, "外层结算")
	_run_choose_card(input, holder_b, 1, "hand")

	assert_eq(confirm_emitted.size(), 1, "A（confirm）应立即派发")
	assert_eq(choose_card_emitted.size(), 0, "A 未结算时 B（choose_card）不应派发")

	# 响应 A → A 恢复并释放活动槽 → B 自动派发
	input.respond_confirm(true)
	await get_tree().create_timer(0.05).timeout

	assert_eq(holder_a["value"], true, "A 应返回 true")
	assert_eq(choose_card_emitted.size(), 1, "A 结算后 B 应自动派发")

	# 清理：响应 B，使其正常返回
	input.respond_choose_card([])
	await get_tree().create_timer(0.05).timeout
	assert_eq(holder_b["value"], [], "B 应正常返回")


func test_response_not_misrouted_to_queued_request() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var holder_a: Dictionary = {"value": null}
	var holder_b: Dictionary = {"value": null}

	_run_confirm(input, holder_a, "外层结算")
	_run_choose_card(input, holder_b, 1, "hand")

	# 响应 A：A 返回 true；B 仍等待，不应错收 A 的响应
	input.respond_confirm(true)
	await get_tree().create_timer(0.05).timeout

	assert_eq(holder_a["value"], true, "A 应返回自己的响应 true")
	assert_null(holder_b["value"], "B 不应错收 A 的响应（仍在等待）")

	# 随后响应 B：B 正常返回自己的数组
	var cards: Array = [Card.new()]
	input.respond_choose_card(cards)
	await get_tree().create_timer(0.05).timeout
	assert_eq(holder_b["value"], cards, "B 应返回自己的响应数组")


func test_duplicate_response_ignored() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var holder: Dictionary = {"value": null}
	_run_confirm(input, holder, "确认？")

	input.respond_confirm(true)
	input.respond_confirm(false)
	await get_tree().create_timer(0.05).timeout

	assert_true(holder["value"], "重复响应应被忽略，confirm 只返回第一次的 true")


func test_single_request_flow_compatible() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var holder: Dictionary = {"value": null}
	_run_wait_action(input, holder)
	await get_tree().create_timer(0.02).timeout
	input.respond_action("attack")
	await get_tree().create_timer(0.02).timeout
	assert_eq(holder["value"], "attack", "单请求流程 wait_action → respond_action 应正常返回")


# === 协程辅助方法 ===

func _run_wait_action(input: GUIPlayerInput, holder: Dictionary) -> void:
	holder["value"] = await input.wait_action(null)


func _run_choose(input: GUIPlayerInput, holder: Dictionary, options: Array, prompt: String) -> void:
	holder["value"] = await input.choose(options, prompt)


func _run_choose_card(input: GUIPlayerInput, holder: Dictionary, n: int, position: String) -> void:
	holder["value"] = await input.choose_card(n, position)


func _run_choose_target(input: GUIPlayerInput, holder: Dictionary, n: int) -> void:
	holder["value"] = await input.choose_target(n)


func _run_choose_block(input: GUIPlayerInput, holder: Dictionary, blocks: Array, prompt: String) -> void:
	holder["value"] = await input.choose_map_block(blocks, prompt)


func _run_confirm(input: GUIPlayerInput, holder: Dictionary, message: String) -> void:
	holder["value"] = await input.confirm(message)
