extends GutTest

const InputRequestScript = preload("res://src/core/input_request.gd")


func test_input_request_matches_identity() -> void:
	var owner := Player.new()
	var request: RefCounted = InputRequestScript.new(7, owner, Callable(), true)

	assert_true(request.matches(7, owner))
	assert_false(request.matches(6, owner))
	assert_false(request.matches(7, Player.new()))
	request.respond("ok")
	request.respond("ignored")
	assert_true(request.received)
	assert_eq(request.response, "ok")
