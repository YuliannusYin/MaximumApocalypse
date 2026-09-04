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
