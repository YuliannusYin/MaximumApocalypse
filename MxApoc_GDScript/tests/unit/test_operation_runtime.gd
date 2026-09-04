extends GutTest

const EventSchedulerScript = preload("res://src/core/event_scheduler.gd")

func test_flushes_operations_in_registration_order() -> void:
	var runtime := EventSchedulerScript.new()
	var order: Array[String] = []
	var first: Dictionary = runtime.enqueue("first", func() -> String:
		order.append("first")
		return "one")
	var second: Dictionary = runtime.enqueue("second", func() -> String:
		order.append("second")
		return "two")

	await runtime.flush()

	assert_eq(order, ["first", "second"])
	assert_eq(first["status"], "completed")
	assert_eq(first["result"], "one")
	assert_eq(second["result"], "two")


func test_cancelled_operation_is_not_executed() -> void:
	var runtime := EventSchedulerScript.new()
	var called := false
	var operation: Dictionary = runtime.enqueue("cancelled", func() -> void:
		called = true)
	EventSystem.cancel(operation)

	await runtime.flush()

	assert_false(called)
	assert_eq(operation["status"], "cancelled")


func test_nested_dispatch_uses_stack_order() -> void:
	var runtime: Variant = EventSchedulerScript.new()
	var order: Array[String] = []

	var c_executor: Callable = func() -> void:
		order.append("C")
	var b_executor: Callable = func() -> void:
		order.append("B")
		await runtime.dispatch("C", c_executor)
	var a_executor: Callable = func() -> void:
		order.append("A-start")
		await runtime.dispatch("B", b_executor)
		order.append("A-end")

	await runtime.dispatch("A", a_executor)

	assert_eq(order, ["A-start", "B", "C", "A-end"])


func test_nested_operations_expose_owner_source_and_restore_parent() -> void:
	var runtime: Variant = EventSchedulerScript.new()
	var source := Player.new()
	var target := Player.new()
	var observed: Array = []

	var parent_executor: Callable = func() -> void:
		observed.append([
			runtime.get_current_owner(),
			runtime.get_current_source(),
			runtime.get_current_operation().get("kind", ""),
		])
		await runtime.dispatch(
			"child",
			func() -> void:
				observed.append([
					runtime.get_current_owner(),
					runtime.get_current_source(),
					runtime.get_current_operation().get("kind", ""),
					runtime.get_current_operation().get("rules", {}).get("max_cards", 0),
				]),
			{},
			target,
			source,
			"limited_card_use",
			{"max_cards": 2}
		)
		observed.append([
			runtime.get_current_owner(),
			runtime.get_current_source(),
			runtime.get_current_operation().get("kind", ""),
		])

	await runtime.dispatch(
		"parent",
		parent_executor,
		{},
		source,
		null,
		"card_effect",
		{}
	)

	assert_eq(observed[0], [source, null, "card_effect"])
	assert_eq(observed[1], [target, source, "limited_card_use", 2])
	assert_eq(observed[2], [source, null, "card_effect"])
	assert_eq(runtime.get_current_operation(), {})


func test_operation_context_is_inherited_by_nested_operations() -> void:
	var runtime := EventSchedulerScript.new()
	var source := Player.new()
	var target := Player.new()
	var context: Dictionary = runtime.create_limited_action_context(target, source, 2)
	var observed: Array = []
	var child_executor: Callable = func() -> void:
		observed.append(runtime.get_current_context())
	var parent_executor: Callable = func() -> void:
		observed.append(runtime.get_current_context())
		await runtime.dispatch("child", child_executor)

	await runtime.dispatch(
		"parent",
		parent_executor,
		{},
		target,
		source,
		"limited_action",
		{},
		context
	)

	assert_eq(observed[0], context)
	assert_eq(observed[1], context)
	assert_eq(runtime.get_current_context(), {})
