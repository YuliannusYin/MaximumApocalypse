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


func test_action_requested_signal_emitted() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var signal_received: Array = []
	input.action_requested.connect(func(_p): signal_received.append(true))
	_run_wait_action(input, {})
	await get_tree().create_timer(0.02).timeout
	assert_true(signal_received.size() > 0, "wait_action 应发射 action_requested 信号")
	input.respond_action(null)
	await get_tree().create_timer(0.01).timeout


# === 请求栈机制测试 ===

func test_single_request_dispatched_immediately() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var emitted: Array = []
	input.confirm_requested.connect(func(_message): emitted.append(true))
	_run_confirm(input, {}, "立即派发")
	assert_eq(emitted.size(), 1, "空闲时请求应立即派发（同步发出 confirm_requested）")
	input.respond_confirm(true)
	await get_tree().create_timer(0.02).timeout


func test_nested_request_preempts_wait_action_and_restores_it() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var action_emitted: Array = []
	var choose_card_emitted: Array = []
	input.action_requested.connect(func(_p): action_emitted.append(true))
	input.choose_card_requested.connect(func(_n, _param, _filter, _prompt, _min_n): choose_card_emitted.append(true))

	var action_holder: Dictionary = {"value": "sentinel"}
	var card_holder: Dictionary = {"value": null}
	_run_wait_action(input, action_holder)
	_run_choose_card(input, card_holder, 1, "hand")

	assert_eq(action_emitted.size(), 1, "wait_action 应先派发")
	assert_eq(choose_card_emitted.size(), 1, "choose_card 应抢占 wait_action 并立即派发")

	input.respond_choose_card([])
	await get_tree().create_timer(0.05).timeout
	assert_eq(card_holder["value"], [], "后进的 choose_card 应先返回")
	assert_eq(action_holder["value"], "sentinel", "wait_action 在选牌结算前不应结束")
	assert_eq(action_emitted.size(), 2, "选牌结束后应重新派发 wait_action")

	input.respond_action("move")
	await get_tree().create_timer(0.05).timeout
	assert_eq(action_holder["value"], "move", "wait_action 恢复后应返回真实行动")


func test_wait_action_does_not_preempt_choose_card() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var action_emitted: Array = []
	var choose_card_emitted: Array = []
	input.action_requested.connect(func(_p): action_emitted.append(true))
	input.choose_card_requested.connect(func(_n, _param, _filter, _prompt, _min_n): choose_card_emitted.append(true))

	var card_holder: Dictionary = {"value": null}
	var action_holder: Dictionary = {"value": "sentinel"}
	_run_choose_card(input, card_holder, 3, "hand")
	_run_wait_action(input, action_holder)

	assert_eq(choose_card_emitted.size(), 1, "choose_card 应保持活动")
	assert_eq(action_emitted.size(), 0, "wait_action 不应抢走未完成的选牌窗口")

	var cards: Array = [Card.new(), Card.new(), Card.new()]
	input.respond_choose_card(cards)
	await get_tree().create_timer(0.05).timeout
	assert_eq(card_holder["value"], cards, "选牌应先完成")
	assert_eq(choose_card_emitted.size(), 1, "选牌窗口不应被重新派发")
	assert_eq(action_emitted.size(), 1, "选牌结束后才派发 wait_action")

	input.respond_action("end_turn")
	await get_tree().create_timer(0.05).timeout
	assert_eq(action_holder["value"], "end_turn", "排队的 wait_action 应在选牌后返回")


func test_response_goes_to_active_request_not_queued_one() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var holder_a: Dictionary = {"value": null}
	var holder_b: Dictionary = {"value": null}

	_run_confirm(input, holder_a, "外层结算")
	_run_choose_card(input, holder_b, 1, "hand")

	input.respond_confirm(true)
	await get_tree().create_timer(0.05).timeout

	assert_eq(holder_a["value"], true, "活动中的 confirm 应收到自己的响应")
	assert_null(holder_b["value"], "排队的 choose_card 不应错收 confirm 的响应")

	var cards: Array = [Card.new()]
	input.respond_choose_card(cards)
	await get_tree().create_timer(0.05).timeout
	assert_eq(holder_b["value"], cards, "confirm 结束后 choose_card 应返回自己的响应")


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


func test_wait_action_is_preempted_by_nested_confirm() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var action_emitted: Array = []
	var confirm_emitted: Array = []
	input.action_requested.connect(func(_p): action_emitted.append(true))
	input.confirm_requested.connect(func(_m): confirm_emitted.append(true))

	var action_holder: Dictionary = {"value": "sentinel"}
	_run_wait_action(input, action_holder)
	await get_tree().create_timer(0.02).timeout
	assert_eq(action_emitted.size(), 1, "wait_action 应先派发")

	var confirm_holder: Dictionary = {"value": null}
	_run_confirm(input, confirm_holder, "插入确认")
	assert_eq(confirm_emitted.size(), 1, "wait_action 活动时 confirm 应抢占并立即派发")
	assert_eq(action_holder["value"], "sentinel", "wait_action 被抢占后不应结束")

	input.respond_confirm(true)
	await get_tree().create_timer(0.05).timeout
	assert_eq(confirm_holder["value"], true, "confirm 应返回 true")
	assert_eq(action_holder["value"], "sentinel", "confirm 结束后 wait_action 仍应等待")
	assert_eq(action_emitted.size(), 2, "插入结算结束后应重新派发 wait_action")

	input.respond_action("move")
	await get_tree().create_timer(0.05).timeout
	assert_eq(action_holder["value"], "move", "恢复后 wait_action 应返回真实行动")


func test_request_owner_is_propagated_and_restored() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var source := Player.new()
	var target := Player.new()
	var owners: Array = []
	input.request_owner_changed.connect(func(owner): owners.append(owner))

	var action_holder: Dictionary = {"value": "sentinel"}
	_run_wait_action_for_player(input, action_holder, source)
	input.set_request_owner(target)
	var card_holder: Dictionary = {"value": null}
	_run_choose_card(input, card_holder, 1, "hand")
	assert_eq(owners, [source, target], "嵌套请求应先切换到目标玩家")

	input.respond_choose_card([])
	await get_tree().create_timer(0.05).timeout
	assert_eq(owners, [source, target, source], "嵌套请求结束后应恢复外层玩家")
	input.respond_action(null)
	await get_tree().create_timer(0.05).timeout


func test_response_rejects_stale_request_identity() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var owner := Player.new()
	var request_info: Array = []
	input.confirm_requested.connect(func(_message): request_info.append([
		input.get_active_request_id(),
		input.get_active_request_owner(),
	]))

	input.set_request_owner(owner)
	var holder: Dictionary = {"value": "pending"}
	_run_confirm(input, holder, "身份校验")
	await get_tree().process_frame

	assert_eq(request_info.size(), 1)
	var request_id: int = request_info[0][0]
	assert_eq(request_info[0][1], owner)

	input.respond_confirm(true, request_id - 1, owner)
	await get_tree().create_timer(0.02).timeout
	assert_eq(holder["value"], "pending", "旧 request_id 不应完成当前请求")

	input.respond_confirm(true, request_id, owner)
	await get_tree().create_timer(0.02).timeout
	assert_true(holder["value"], "正确 request_id 和 owner 应完成请求")


func test_fire_and_forget_owner_does_not_leak_to_next_request() -> void:
	var input: GUIPlayerInput = GUIPlayerInput.new()
	var owner := Player.new()
	var owners: Array = []
	input.request_owner_changed.connect(func(value): owners.append(value))

	input.set_request_owner(owner)
	input.show_card(Card.new(), owner)
	input.confirm("下一次请求")
	await get_tree().process_frame

	assert_eq(owners, [owner, null], "单向通知消耗 owner 后不应污染下一次请求")
	input.respond_confirm(false, input.get_active_request_id(), null)
	await get_tree().create_timer(0.02).timeout


# === 协程辅助方法 ===

func _run_wait_action(input: GUIPlayerInput, holder: Dictionary) -> void:
	holder["value"] = await input.wait_action(null)


func _run_wait_action_for_player(input: GUIPlayerInput, holder: Dictionary, player: Player) -> void:
	holder["value"] = await input.wait_action(player)


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
