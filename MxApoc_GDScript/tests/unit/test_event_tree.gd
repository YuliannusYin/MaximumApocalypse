extends GutTest

const GameEventScript = preload("res://src/core/game_event.gd")
const TurnEventScript = preload("res://src/core/turn_event.gd")


func test_operation_handle_and_game_event_share_lifecycle() -> void:
	var runtime := OperationRuntime.new()
	var handle: Dictionary = runtime.enqueue("queued", func() -> String:
		return "done"
	)

	assert_eq(handle["status"], "pending")
	assert_not_null(handle["game_event"])
	assert_eq(handle["game_event"].status, GameEventScript.Status.PENDING)

	await runtime.flush()

	assert_eq(handle["status"], "completed")
	assert_eq(handle["result"], "done")
	assert_eq(handle["game_event"].status, GameEventScript.Status.COMPLETED)
	assert_eq(handle["game_event"].result, "done")


func test_cancelled_operation_cancels_game_event_too() -> void:
	var runtime := OperationRuntime.new()
	var handle: Dictionary = runtime.enqueue("cancelled", func() -> void:
		assert_true(false, "取消的操作不应执行")
	)
	EventSystem.cancel(handle)

	await runtime.flush()

	assert_eq(handle["status"], "cancelled")
	assert_eq(handle["game_event"].status, GameEventScript.Status.CANCELLED)


func test_formal_turn_event_contains_phase_event_children() -> void:
	var player := Player.new()
	var phase: Variant = player.begin_turn_context("turn_start", 4, 3)
	var turn: Variant = player.get_turn_event()

	assert_true(turn is TurnEventScript)
	assert_eq(turn.owner, player)
	assert_eq(turn.turn_number, 4)
	assert_eq(turn.status, GameEventScript.Status.RUNNING)
	assert_eq(phase.parent, turn)
	assert_eq(turn.children, [phase])
	assert_eq(phase.new_phase, "turn_start")

	player._enter_turn_phase("idle", "test_finished")
	player.finish_turn_context()
	assert_eq(turn.status, GameEventScript.Status.COMPLETED)
