extends GutTest

const InputRequestScript = preload("res://src/core/input_request.gd")


func test_input_request_matches_identity() -> void:
	var owner := Player.new()
	var request: RefCounted = InputRequestScript.new(owner, Callable(), true)

	assert_true(request.matches(request.id, owner))
	assert_false(request.matches(request.id - 1, owner))
	assert_false(request.matches(request.id, Player.new()))
	request.respond("ok")
	request.respond("ignored")
	assert_true(request.received)
	assert_eq(request.response, "ok")
