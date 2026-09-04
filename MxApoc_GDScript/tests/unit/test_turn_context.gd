extends TestBase

const TurnContextScript = preload("res://src/core/turn_context.gd")


func test_turn_context_tracks_phase_and_action_budget() -> void:
	var player := Player.new()
	var context: RefCounted = TurnContextScript.new(player, 7, 4)

	assert_eq(context.owner, player)
	assert_eq(context.turn_number, 7)
	assert_eq(context.phase, "idle")
	assert_eq(context.remaining_actions, 4)
	assert_eq(context.enter_phase("action"), "idle")
	assert_eq(context.phase, "action")
	assert_eq(context.consume_action(2), 2)
	assert_eq(context.remaining_actions, 2)
	context.add_action(1)
	assert_eq(context.remaining_actions, 3)
	context.finish()
	assert_false(context.active)
	assert_true(context.ended)


func test_turn_context_does_not_overconsume_budget() -> void:
	var context: RefCounted = TurnContextScript.new(null, 0, 1)

	assert_eq(context.consume_action(3), 1)
	assert_eq(context.remaining_actions, 0)
	assert_eq(context.consume_action(1), 0)
