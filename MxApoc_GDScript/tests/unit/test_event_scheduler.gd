extends GutTest

const EventSchedulerScript = preload("res://src/core/event_scheduler.gd")
const GameEventScript = preload("res://src/core/game_event.gd")


func test_scheduler_restores_preempted_request_in_lifo_order() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	var owners: Array = []
	var source := Player.new()
	var target := Player.new()
	var outer: Variant = null
	var inner: Variant = null
	var outer_emit: Callable = func() -> void:
		owners.append(scheduler.get_active_request_owner())
	var inner_emit: Callable = func() -> void:
		owners.append(scheduler.get_active_request_owner())

	outer = scheduler.enqueue_input(source, outer_emit, true)
	inner = scheduler.enqueue_input(target, inner_emit)

	assert_eq(owners, [source, target])
	scheduler.respond("inner", scheduler.get_active_request_id(), target)
	await scheduler.wait_request(inner)
	assert_eq(owners, [source, target, source])

	scheduler.respond("outer", scheduler.get_active_request_id(), source)
	assert_eq(await scheduler.wait_request(outer), "outer")


func test_scheduler_rejects_stale_identity() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	var owner := Player.new()
	var request: Variant = scheduler.enqueue_input(owner, func() -> void:
		pass
	)
	var request_id: int = scheduler.get_active_request_id()

	scheduler.respond(true, request_id - 1, owner)
	await Engine.get_main_loop().process_frame
	assert_false(request.received)

	scheduler.respond(true, request_id, owner)
	assert_eq(await scheduler.wait_request(request), true)


func test_scheduler_exposes_current_input_request_identity() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	var owner := Player.new()
	var request: Variant = scheduler.enqueue_input(owner, func() -> void:
		pass
	)

	assert_eq(scheduler.get_current_input_request(), request)
	assert_eq(scheduler.get_current_input_request_id(), request.id)
	assert_eq(scheduler.get_current_input_request_owner(), owner)

	scheduler.respond(true, request.id, owner)
	await scheduler.wait_request(request)
	assert_null(scheduler.get_current_input_request())


func test_scheduler_runs_game_event_and_restores_parent() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	var source := Player.new()
	var parent: Variant = scheduler.create_event("turn", source, null)
	var child: Variant = scheduler.create_event("phase", source, source)
	var observed: Array = []

	await scheduler.run_event(parent, func(event: Variant) -> void:
		observed.append([scheduler.get_current_event(), scheduler.get_current_owner()])
		await scheduler.run_event(child, func(child_event: Variant) -> void:
			observed.append([scheduler.get_current_event(), scheduler.get_current_owner()])
		)
		observed.append([scheduler.get_current_event(), scheduler.get_current_owner()])
	)

	assert_eq(observed[0][0], parent)
	assert_eq(observed[1][0], child)
	assert_eq(observed[2][0], parent)
	assert_eq(parent.status, GameEventScript.Status.COMPLETED)
	assert_eq(child.status, GameEventScript.Status.COMPLETED)
	assert_eq(child.parent, parent)
	assert_eq(child.root, parent.root)
	assert_eq(parent.children, [child])


func test_game_event_ids_are_unique_and_nonzero() -> void:
	var first: Variant = GameEventScript.new("first")
	var second: Variant = GameEventScript.new("second")

	assert_gt(first.id, 0)
	assert_gt(second.id, 0)
	assert_ne(first.id, second.id)
	assert_eq(first.root, first.id)
	assert_eq(second.root, second.id)


func test_queued_operation_is_parent_of_nested_operation() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	var parent_handle: Dictionary = scheduler.enqueue("parent", func() -> void:
		await scheduler.dispatch("child", func() -> String:
			return "child_result"
		)
	)

	await scheduler.flush()

	var parent_event: Variant = parent_handle["game_event"]
	assert_eq(parent_handle["status"], "completed")
	assert_eq(parent_event.children.size(), 1)
	assert_eq(parent_event.children[0].parent, parent_event)
	assert_eq(parent_event.children[0].root, parent_event.root)


func test_cancelled_event_is_not_completed() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	var event: Variant = scheduler.create_event("cancelled")
	var called: bool = false
	event.cancel()

	await scheduler.run_event(event, func(_event: Variant) -> void:
		called = true
	)

	assert_false(called)
	assert_eq(event.status, GameEventScript.Status.CANCELLED)


func test_failed_event_is_not_completed() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	var event: Variant = scheduler.create_event("failed")

	await scheduler.run_event(event, func(current: Variant) -> void:
		current.fail("expected failure")
	)

	assert_eq(event.status, GameEventScript.Status.FAILED)
	assert_eq(event.error, "expected failure")


func test_invalid_queued_executor_does_not_block_future_flushes() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	var invalid: Dictionary = scheduler.enqueue("invalid", Callable())
	var called: Array = []
	scheduler.enqueue("valid", func() -> void:
		called.append(true)
	)

	await scheduler.flush()

	assert_eq(invalid["status"], "failed")
	assert_eq(called, [true])
	assert_false(scheduler.has_pending_operations())


func test_scheduler_rejects_wrong_owner() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	var owner := Player.new()
	var wrong_owner := Player.new()
	var request: Variant = scheduler.enqueue_input(owner, func() -> void:
		pass
	)

	scheduler.respond(true, request.id, wrong_owner)
	await Engine.get_main_loop().process_frame
	assert_false(request.received)

	scheduler.respond(true, request.id, owner)
	assert_true(await scheduler.wait_request(request))
