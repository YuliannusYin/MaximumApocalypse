extends TestBase

## ActionSelectionController：手牌取消底线、未提交意图互切、领域锁定不可切走。


class FakeHandArea extends Node:
	var clear_calls: int = 0

	func clear_selection() -> void:
		clear_calls += 1


func _make_controller() -> ActionSelectionController:
	var ui := Control.new()
	add_child_autofree(ui)
	var controller := ActionSelectionController.new()
	controller.setup(ui)
	add_child_autofree(controller)
	controller.build_buttons()
	return controller


func _make_skill(sname: String) -> Skill:
	var skill := Skill.new()
	skill.skill_name = sname
	skill.skill_description = sname + "描述"
	skill.active = "action"
	return skill


func _make_acting_player() -> Player:
	var player: Player = _make_player()
	player.in_phase = "action"
	player.action_count = 2
	return player


func test_cancel_clears_selected_card_without_hand_area() -> void:
	var controller := _make_controller()
	var card: Card = _make_card("测试牌")
	controller.on_card_selected(card)
	assert_eq(controller._selected_card, card)
	assert_eq(controller._cancel_end_button.text, "取消 (C)")
	assert_false(controller._cancel_end_button.disabled)

	controller.handle_shortcut(KEY_C)

	assert_null(controller._selected_card, "未注入手牌区时取消仍应清掉选中")
	assert_eq(controller._prompt_label.text, "")


func test_cancel_calls_hand_area_clear_selection() -> void:
	var controller := _make_controller()
	var fake := FakeHandArea.new()
	add_child_autofree(fake)
	controller.set_hand_area(fake)
	var card: Card = _make_card("测试牌")
	controller.on_card_selected(card)
	assert_eq(fake.clear_calls, 0)

	controller.handle_shortcut(KEY_C)

	assert_eq(fake.clear_calls, 1, "注入手牌区后取消应调用 clear_selection")
	assert_null(controller._selected_card)


func test_skill_a_to_skill_b_switches_prompt() -> void:
	var controller := _make_controller()
	var punch := _make_skill("拳打")
	var balance := _make_skill("制衡")
	controller.enter_skill_confirm_mode(punch)
	assert_true(controller._skill_confirm_mode)
	assert_true(controller._prompt_label.text.contains("拳打"))

	controller.enter_skill_confirm_mode(balance)

	assert_true(controller._skill_confirm_mode)
	assert_eq(controller._pending_skill, balance)
	assert_true(controller._prompt_label.text.contains("制衡"))
	assert_false(controller._prompt_label.text.contains("拳打"))


func test_same_skill_again_exits_confirm() -> void:
	var controller := _make_controller()
	var punch := _make_skill("拳打")
	controller.enter_skill_confirm_mode(punch)
	controller.enter_skill_confirm_mode(punch)
	assert_false(controller._skill_confirm_mode)
	assert_null(controller._pending_skill)
	assert_eq(controller._prompt_label.text, "")


func test_skill_confirm_then_card_switches_to_card() -> void:
	var controller := _make_controller()
	controller.enter_skill_confirm_mode(_make_skill("拳打"))
	var card: Card = _make_card("手牌")
	controller.on_card_selected(card)
	assert_false(controller._skill_confirm_mode)
	assert_eq(controller._selected_card, card)


func test_skill_confirm_then_pile_switches_to_pile() -> void:
	var controller := _make_controller()
	controller.enter_skill_confirm_mode(_make_skill("拳打"))
	controller.on_pile_selected("red", "红色拾荒牌堆")
	assert_false(controller._skill_confirm_mode)
	assert_eq(controller.get_selected_pile_key(), "red")
	assert_true(controller._prompt_label.text.contains("红色拾荒牌堆"))


func test_same_pile_again_clears_selection() -> void:
	var controller := _make_controller()
	controller.on_pile_selected("red", "红色拾荒牌堆")
	assert_eq(controller.get_selected_pile_key(), "red")
	controller.on_pile_selected("red", "红色拾荒牌堆")
	assert_eq(controller.get_selected_pile_key(), "")
	assert_eq(controller._prompt_label.text, "")


func test_player_move_toggles_off_on_second_enter() -> void:
	var controller := _make_controller()
	controller.set_acting_player(_make_acting_player())
	controller.enter_move_select_mode()
	assert_true(controller.is_in_move_mode())
	assert_false(controller.is_card_move_mode())
	controller.enter_move_select_mode()
	assert_false(controller.is_in_move_mode())


func test_skill_confirm_then_move_switches_to_move() -> void:
	var controller := _make_controller()
	controller.set_acting_player(_make_acting_player())
	controller.enter_skill_confirm_mode(_make_skill("拳打"))
	controller.enter_move_select_mode()
	assert_false(controller._skill_confirm_mode)
	assert_true(controller.is_in_move_mode())
	assert_true(controller._prompt_label.text.contains("移动"))


func test_card_move_mode_blocks_skill_and_card_switch() -> void:
	var controller := _make_controller()
	var fake := FakeHandArea.new()
	add_child_autofree(fake)
	controller.set_hand_area(fake)
	controller.enter_block_select_mode("选择地块", [], 1, "card")
	assert_true(controller.is_card_move_mode())
	var clears_after_enter: int = fake.clear_calls

	controller.enter_skill_confirm_mode(_make_skill("拳打"))
	assert_false(controller._skill_confirm_mode)
	assert_true(controller.is_card_move_mode())

	var card: Card = _make_card("手牌")
	controller.on_card_selected(card)
	assert_null(controller._selected_card)
	assert_eq(fake.clear_calls, clears_after_enter + 1, "锁定时应还原手牌视觉选中")
	assert_true(controller.is_card_move_mode())

	controller.on_pile_selected("red", "红色拾荒牌堆")
	assert_eq(controller.get_selected_pile_key(), "")
	assert_true(controller.is_card_move_mode())


func test_judge_confirm_blocks_skill_switch() -> void:
	var controller := _make_controller()
	controller.enter_judge_confirm_mode("检定确认", 30.0, true)
	assert_true(controller._judge_confirm_mode)
	controller.enter_skill_confirm_mode(_make_skill("拳打"))
	assert_false(controller._skill_confirm_mode)
	assert_true(controller._judge_confirm_mode)
	controller.exit_judge_confirm_mode()


func test_network_zero_ap_enables_end_turn() -> void:
	var controller := _make_controller()
	var player: Player = _make_player()
	player.in_phase = "action"
	player.action_count = 0
	controller.set_acting_player(player)
	controller.set_network_action_available(true)
	assert_eq(controller._cancel_end_button.text, "结束回合 (E)")
	assert_false(controller._cancel_end_button.disabled, "客机正式行动点用完时结束回合应可点")


func test_network_remaining_ap_keeps_end_turn_disabled() -> void:
	var controller := _make_controller()
	var player: Player = _make_player()
	player.in_phase = "action"
	player.action_count = 1
	controller.set_acting_player(player)
	controller.set_network_action_available(true)
	assert_true(controller._cancel_end_button.disabled, "还有正式行动点时结束回合应置灰")


func test_confirm_card_queues_play_outgoing() -> void:
	var controller := _make_controller()
	var area := HandDisplayArea.new()
	add_child_autofree(area)
	controller.set_hand_area(area)
	var player: Player = _make_acting_player()
	controller.set_acting_player(player)
	var card: Card = _make_card("砍刀", "equipment")
	player.hand.append(card)
	controller.on_card_selected(card)
	controller._on_confirm_pressed()
	assert_eq(area._pending_out_kind, "play", "确认打出应把离手动画标成 play")


func test_set_confirm_mode_clears_card_move_conflict() -> void:
	var controller := _make_controller()
	controller.enter_block_select_mode("选择地块", [], 1, "card")
	assert_true(controller.is_card_move_mode())
	controller.set_confirm_mode("是否立即装备 \"燃料\", 否则立即弃置")
	assert_false(controller.is_card_move_mode(), "确认模式应清掉卡牌移动锁定")
	assert_true(controller.is_in_confirm_mode())
	assert_true(controller._prompt_label.text.contains("燃料"))
