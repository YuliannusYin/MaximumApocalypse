extends GutTest


func test_skill_content_flushes_registered_actions_before_returning() -> void:
	var player := Player.new()
	player.hp = 10
	player.max_hp = 10
	player.action_count = 1
	var skill := Skill.new()
	skill.content = CodeExecutor.compile_content("actions.consume_action(player, 1)")
	var event := EventSystem.create_event({"player": player})

	await skill.execute_content(player, event)

	assert_eq(player.action_count, 0, "无需 await 的 actions 调用应在 content 返回前完成")


func test_skill_content_awaits_choose_to_discard_before_returning() -> void:
	var player := Player.new()
	player.player_name = "TestPlayer"
	player.game_discard_pile = Pile.new()
	var card := Card.new()
	card.card_name = "discard_me"
	card.card_type = "action"
	card.source = "game"
	player.hand.append(card)
	var cli := CliPlayerInput.new()
	cli.queue_choose_card([card])
	player.input = cli
	var skill := Skill.new()
	skill.content = CodeExecutor.compile_content(
		"if event.trigger_name == \"on_turn_end\":\n\tactions.choose_to_discard(player, 1)"
	)
	var event := EventSystem.create_event({"player": player})
	EventSystem.set_trigger_name(event, "on_turn_end")

	await skill.execute_content(player, event)

	assert_false(player.hand.has(card), "content 返回前应已完成选弃")
	assert_true(player.game_discard_pile.get_all().has(card), "选中的牌应进入弃牌堆")


func test_evented_consume_action_can_be_cancelled() -> void:
	var player := Player.new()
	player.hp = 10
	player.max_hp = 10
	player.action_count = 1
	var blocker := Skill.new()
	blocker.trigger = "before_consume_action"
	blocker.forced = true
	blocker.content = func(_player, _target, event: Dictionary, _game) -> void:
		EventSystem.cancel(event)
	player.add_skill(blocker)

	var result: bool = await player.consume_action_evented(1)

	assert_false(result)
	assert_eq(player.action_count, 1)
