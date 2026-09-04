extends TestBase

const PhaseEventScript = preload("res://src/core/phase_event.gd")
const TurnContextScript = preload("res://src/core/turn_context.gd")


func test_phase_event_captures_transition_metadata() -> void:
	var player := Player.new()
	var context: RefCounted = TurnContextScript.new(player, 3, 2)
	var event: RefCounted = PhaseEventScript.new(
		player,
		context,
		"idle",
		"action",
		4,
		"test"
	)

	assert_eq(event.player, player)
	assert_eq(event.context, context)
	assert_eq(event.old_phase, "idle")
	assert_eq(event.new_phase, "action")
	assert_eq(event.sequence, 4)
	assert_eq(event.reason, "test")
	assert_eq(event.action_remaining, 2)
