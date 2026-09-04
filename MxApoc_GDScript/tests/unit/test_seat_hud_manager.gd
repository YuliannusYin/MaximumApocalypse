extends TestBase

## SeatHudManager：稳定座位映射与单一可见焦点。

const SeatHudManagerScript = preload("res://src/ui/seat_hud_manager.gd")
const EventSchedulerScript = preload("res://src/core/event_scheduler.gd")


func test_focus_switches_only_the_requested_seat_hud() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	var player_a := Player.new()
	var player_b := Player.new()
	var manager: Node = SeatHudManagerScript.new()
	add_child_autofree(manager)
	manager.setup(parent)
	manager.build([player_a, player_b])

	manager.focus_player(player_a)
	assert_true(manager.get_hud(player_a).visible)
	assert_false(manager.get_hud(player_b).visible)

	manager.focus_player(player_b)
	assert_false(manager.get_hud(player_a).visible)
	assert_true(manager.get_hud(player_b).visible)
	assert_eq(manager.get_focused_player(), player_b)


func test_request_owner_is_observed_separately_from_focused_player() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	var focused_player := Player.new()
	var request_owner := Player.new()
	var scheduler: Variant = EventSchedulerScript.new()
	var manager: Node = SeatHudManagerScript.new()
	add_child_autofree(manager)
	manager.setup(parent)
	manager.set_event_scheduler(scheduler)
	manager.build([focused_player, request_owner])
	manager.focus_player(focused_player)

	var request: Variant = scheduler.enqueue_input(request_owner, func() -> void:
		pass
	)
	assert_eq(manager.get_input_request(), request)
	assert_eq(manager.get_input_request_owner(), request_owner)
	assert_eq(manager.get_focused_player(), focused_player)

	scheduler.respond(true, request.id, request_owner)
	await scheduler.wait_request(request)
