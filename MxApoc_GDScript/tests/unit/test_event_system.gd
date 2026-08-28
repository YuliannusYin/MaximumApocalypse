extends GutTest

## EventSystem 单元测试。


func test_cancel_sets_cancelled_true() -> void:
	var event: Dictionary = EventSystem.create_event()
	assert_false(EventSystem.is_cancelled(event), "初始未取消")
	EventSystem.cancel(event)
	assert_true(EventSystem.is_cancelled(event), "cancel() 后应已取消")


func test_cancel_callable_in_event_works() -> void:
	var event: Dictionary = EventSystem.create_event()
	var cancel_fn: Callable = event["cancel"]
	assert_true(cancel_fn.is_valid(), "cancel 应为有效 Callable")
	cancel_fn.call()
	assert_true(event["cancelled"], "调用 event['cancel'].call() 后 cancelled 应为 true")


func test_create_damage_event_fields() -> void:
	var target: Entity = Entity.new()
	var source: Entity = Entity.new()
	var event: Dictionary = EventSystem.create_damage_event(target, source, 5, 0, null)
	assert_eq(event["target"], target)
	assert_eq(event["source"], source)
	assert_eq(event["num"], 5)
	assert_eq(event["type"], 0)
	assert_null(event["card"])
	assert_false(event["cancelled"])


func test_create_recover_event() -> void:
	var event: Dictionary = EventSystem.create_recover_event(null, 4)
	assert_eq(event["num"], 4)
	assert_true(event.has("player"))


func test_create_move_event() -> void:
	var event: Dictionary = EventSystem.create_move_event(null, null, null)
	assert_true(event.has("source_block"))
	assert_true(event.has("target_block"))


func test_create_draw_game_card_event() -> void:
	var event: Dictionary = EventSystem.create_draw_game_card_event(null, 3)
	assert_eq(event["num"], 3)
	assert_eq(event["cards"], [])
	assert_true(event.has("cancel"))


func test_create_draw_scavenge_event() -> void:
	var event: Dictionary = EventSystem.create_draw_scavenge_event(null, null, 2)
	assert_eq(event["num"], 2)
	assert_true(event.has("pile"))
	assert_true(event.has("card"))


func test_create_sneak_judge_event() -> void:
	var event: Dictionary = EventSystem.create_sneak_judge_event(null, 5)
	assert_eq(event["sneak_value"], 5)
	assert_true(event.has("result"))
	assert_false(event["skip_judge"])


func test_create_destroy_block_event() -> void:
	var event: Dictionary = EventSystem.create_destroy_block_event(null, null)
	assert_true(event.has("source"))
	assert_true(event.has("block"))


func test_create_active_skill_event() -> void:
	var targets: Array = []
	var event: Dictionary = EventSystem.create_active_skill_event(null, targets)
	assert_eq(event["targets"], targets)


func test_initial_fields_override() -> void:
	var event: Dictionary = EventSystem.create_event({"num": 10, "custom": "value"})
	assert_eq(event["num"], 10)
	assert_eq(event["custom"], "value")
	assert_false(event["cancelled"])
