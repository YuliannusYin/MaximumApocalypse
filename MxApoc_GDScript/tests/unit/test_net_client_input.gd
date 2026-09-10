extends TestBase

## 客机每个座位同时只保留权威当前那一个 INPUT_REQUEST。


func test_new_request_replaces_stale_request_for_same_seat() -> void:
	var input := NetClientInput.new()
	input._on_message(_make_input_request(5, 1, "action"))
	assert_true(input.is_action_available(1))
	input._on_message(_make_input_request(6, 1, "choose_target"))
	assert_false(input.is_action_available(1), "选目标应盖掉旧 action")
	assert_eq(input.get_action_request(1), {})
	input._on_message(_make_input_request(7, 1, "action"))
	assert_true(input.is_action_available(1), "新 wait_action 应恢复可操作")
	assert_eq(int(input.get_action_request(1).get("request_id", -1)), 7)


func test_visual_input_requests_are_ignored() -> void:
	var input := NetClientInput.new()
	input._on_message(_make_input_request(9, 0, "dice_animation"))
	assert_eq(input.get_current_request(0), {})
	assert_false(input.is_action_available(0))


func test_other_seat_requests_do_not_block() -> void:
	var input := NetClientInput.new()
	input._on_message(_make_input_request(1, 0, "action"))
	input._on_message(_make_input_request(2, 1, "choose_target"))
	assert_true(input.is_action_available(0))
	assert_false(input.is_action_available(1))


func _make_input_request(request_id: int, seat_id: int, request_type: String) -> Dictionary:
	return {
		"message_type": NetProtocol.INPUT_REQUEST,
		"request_id": request_id,
		"payload": {
			"seat_id": seat_id,
			"request_type": request_type,
			"payload": {},
		},
	}
