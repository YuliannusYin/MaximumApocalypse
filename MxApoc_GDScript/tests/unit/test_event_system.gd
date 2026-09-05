extends TestBase

## EventSystem 单元测试。


func test_cancel_sets_cancelled_true() -> void:
	var event: GameEvent = EventSystem.create_event()
	assert_false(EventSystem.is_cancelled(event), "初始未取消")
	EventSystem.cancel(event)
	assert_true(EventSystem.is_cancelled(event), "cancel() 后应已取消")


func test_cancel_callable_in_event_works() -> void:
	var event: GameEvent = EventSystem.create_event()
	var cancel_fn: Callable = event["cancel"]
	assert_true(cancel_fn.is_valid(), "cancel 应为有效 Callable")
	cancel_fn.call()
	assert_true(event["cancelled"], "调用 event['cancel'].call() 后 cancelled 应为 true")


func test_create_damage_event_fields() -> void:
	var target: Entity = Entity.new()
	var source: Entity = Entity.new()
	var event: GameEvent = EventSystem.create_damage_event(target, source, 5, 0, null)
	assert_eq(event["target"], target)
	assert_eq(event["source"], source)
	assert_eq(event["num"], 5)
	assert_eq(event.get_or("type", null), 0)
	assert_null(event.get_or("card", null))
	assert_false(event["cancelled"])


func test_create_recover_event() -> void:
	var event: GameEvent = EventSystem.create_recover_event(null, 4)
	assert_eq(event["num"], 4)
	assert_true(event.has("player"))
	assert_true(event.has("source"))
	assert_null(event["source"])

	var healer := Player.new()
	event = EventSystem.create_recover_event(null, 2, healer)
	assert_eq(event["source"], healer)


func test_create_move_event() -> void:
	var event: GameEvent = EventSystem.create_move_event(null, null, null)
	assert_true(event.has("source_block"))
	assert_true(event.has("target_block"))


func test_create_draw_game_card_event() -> void:
	var event: GameEvent = EventSystem.create_draw_game_card_event(null, 3)
	assert_eq(event["num"], 3)
	assert_eq(event["cards"], [])
	assert_true(event.has("cancel"))


func test_create_draw_scavenge_event() -> void:
	var event: GameEvent = EventSystem.create_draw_scavenge_event(null, null, 2)
	assert_eq(event["num"], 2)
	assert_true(event.has("pile"))
	assert_true(event.has("card"))


func test_create_sneak_judge_event() -> void:
	var event: GameEvent = EventSystem.create_sneak_judge_event(null, 5)
	assert_eq(event["sneak_value"], 5)
	assert_true(event.has("result"))
	assert_false(event["skip_judge"])


func test_create_destroy_block_event() -> void:
	var event: GameEvent = EventSystem.create_destroy_block_event(null, null)
	assert_true(event.has("source"))
	assert_true(event.has("block"))


func test_create_active_skill_event() -> void:
	var targets: Array = []
	var event: GameEvent = EventSystem.create_active_skill_event(null, targets)
	assert_eq(event["targets"], targets)


func test_initial_fields_override() -> void:
	var event: GameEvent = EventSystem.create_event({"num": 10, "custom": "value"})
	assert_eq(event["num"], 10)
	assert_eq(event["custom"], "value")
	assert_false(event["cancelled"])


func test_create_event_has_unified_node_metadata() -> void:
	var parent: GameEvent = EventSystem.create_event({"type": "parent"})
	var child: GameEvent = EventSystem.create_event({
		"type": "child",
		"parent": parent,
		"owner": "owner",
		"source": "source",
	})

	assert_gt(parent.id, 0)
	assert_eq(child.type, "child")
	assert_eq(child.parent, parent)
	assert_eq(child.root, parent.id)
	assert_eq(parent.children, [child])
	assert_eq(child.owner, "owner")
	assert_eq(child.source, "source")


func test_create_event_writes_payload_to_data() -> void:
	var event: GameEvent = EventSystem.create_damage_event(Entity.new(), null, 4, "hunger", null)
	assert_eq(event.data["num"], 4)
	assert_eq(event.data["type"], "hunger")
	assert_eq(event.get("num"), 4)
	assert_eq(event.get("type"), "hunger")


func test_skill_content_mutates_game_event() -> void:
	var e: Entity = Entity.new()
	var s: Skill = Skill.new()
	s.trigger = "on_take_damage"
	s.content = func(_p, _t, ev, _g) -> void:
		ev.num = 1
		EventSystem.cancel(ev)
	e.add_skill(s)
	var event: GameEvent = EventSystem.create_damage_event(e, null, 8, "poison", null)
	await e.trigger("on_take_damage", event)
	assert_eq(event["num"], 1)
	assert_eq(event.data["num"], 1)
	assert_true(EventSystem.is_cancelled(event))


func test_compiled_content_can_cancel_via_bracket_cancel() -> void:
	var e: Entity = Entity.new()
	var s: Skill = Skill.new()
	s.trigger = "on_take_damage"
	s.content = CodeExecutor.compile_content(
		"if event.trigger_name == \"on_take_damage\":\n\tevent[\"cancel\"].call()"
	)
	assert_true(s.content.is_valid(), "避难所同款 event[\"cancel\"] 语法应能编译")
	e.add_skill(s)
	var event: GameEvent = EventSystem.create_damage_event(e, null, 5, 0, null)
	await e.trigger("on_take_damage", event)
	assert_true(EventSystem.is_cancelled(event), "编译 content 里 event[\"cancel\"].call() 应取消事件")


func test_cancel_accepts_game_event() -> void:
	var event: GameEvent = EventSystem.create_event()
	EventSystem.cancel(event)
	assert_true(EventSystem.is_cancelled(event))
	assert_true(event["cancelled"])


func test_game_event_json_style_access() -> void:
	var event: GameEvent = EventSystem.create_damage_event(Entity.new(), null, 4, "hunger", null)
	EventSystem.set_trigger_name(event, "on_take_damage")
	assert_eq(event.type, "hunger", "JSON event.type 读节点字段，伤害类型 hunger 须命中")
	assert_eq(event.trigger_name, "on_take_damage")
	assert_true(event.has("num"))
	assert_eq(event.get("num"), 4)
	assert_eq(event.get_or("num", 0), 4)
	assert_eq(EventSystem.get_field(event, "num", 0), 4)
	assert_eq(event["num"], 4)
	assert_false(event.has("target_block"))
	assert_eq(event.get_or("missing", 9), 9)
	event.result = {"value": 7, "success": true}
	assert_eq(event.get("result")["value"], 7)
	assert_eq(event["result"]["value"], 7)
	event["cancel"].call()
	assert_true(EventSystem.is_cancelled(event))
