extends TestBase

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
	event.mark_cancelled()

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


func test_enqueue_input_attaches_to_current_event() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	var owner := Player.new()
	var parent: Variant = scheduler.create_event("action", owner, null)
	var captured: Array = []
	await scheduler.run_event(parent, func(_event: Variant) -> Variant:
		var request: Variant = scheduler.enqueue_input(owner, func() -> void:
			pass
		)
		captured.append(request)
		assert_eq(request.parent, parent, "输入请求应挂到当前 GameEvent")
		assert_true(parent.children.has(request))
		scheduler.respond(true, request.id, owner)
		await scheduler.wait_request(request)
		assert_eq(request.status, GameEventScript.Status.COMPLETED)
		return null
	)
	assert_eq(captured.size(), 1, "run_event 期间应发出一次输入请求")
	assert_eq(captured[0].parent, parent)
	assert_eq(captured[0].status, GameEventScript.Status.COMPLETED)


func test_reset_cancels_active_input_and_unblocks_wait() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	var owner := Player.new()
	var request: Variant = scheduler.enqueue_input(owner, func() -> void:
		pass
	)
	scheduler.reset()
	assert_true(request.received, "reset 应取消活动输入请求")
	assert_null(await scheduler.wait_request(request), "取消后 wait_request 应返回 null")


func test_enqueue_turn_keeps_seat_order_and_extra_at_front() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	var p1 := Player.new()
	var p2 := Player.new()
	var p3 := Player.new()
	scheduler.enqueue_turn(p1)
	scheduler.enqueue_turn(p2)
	scheduler.enqueue_turn(p3, true)
	assert_eq(scheduler.get_pending_turn_players(), [p3, p1, p2])
	assert_eq(scheduler.pop_turn(), p3)
	assert_eq(scheduler.pop_turn(), p1)
	assert_eq(scheduler.pop_turn(), p2)
	assert_false(scheduler.has_pending_turns())
	assert_null(scheduler.pop_turn())


func test_flush_domain_operations_does_not_consume_turns() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	var player := Player.new()
	scheduler.enqueue_turn(player)
	var ran: Array = []
	scheduler.enqueue("side", func() -> void:
		ran.append(true)
	)
	await scheduler.flush()
	assert_eq(ran, [true])
	assert_true(scheduler.has_pending_turns(), "领域 flush 不得冲掉未开始的回合")
	assert_eq(scheduler.pop_turn(), player)


func test_reset_clears_turn_queue() -> void:
	var scheduler: Variant = EventSchedulerScript.new()
	scheduler.enqueue_turn(Player.new())
	scheduler.reset()
	assert_false(scheduler.has_pending_turns())
