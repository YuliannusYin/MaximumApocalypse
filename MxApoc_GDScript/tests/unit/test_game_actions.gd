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
