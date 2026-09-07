extends TestBase

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


func test_input_request_matches_rejects_mismatched_owner_types() -> void:
	var request: RefCounted = InputRequestScript.new("__system__", Callable(), false)
	assert_true(request.matches(request.id, "__system__"))
	assert_false(request.matches(request.id, Player.new()), "字符串 owner 与 Player 不能用 == 比较")
