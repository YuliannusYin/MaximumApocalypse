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


func test_choose_target_applies_payload_hp_before_decode() -> void:
	var holder: Player = _make_player("P")
	holder.seat_number = 0
	var monster: Monster = Monster.new()
	monster.net_id = 41
	monster.hp = 5
	monster.max_hp = 5
	holder.monster_zone = [monster]
	Game.players = [holder]
	var input := NetClientInput.new()
	input._on_message({
		"message_type": NetProtocol.INPUT_REQUEST,
		"request_id": 8,
		"payload": {
			"seat_id": 0,
			"request_type": "choose_target",
			"payload": {
				"targets": [{
					"__kind": "monster",
					"net_id": 41,
					"hp": 2,
					"max_hp": 5,
				}],
			},
		},
	})
	assert_eq(monster.hp, 2, "第二次选目标前应先把显示层怪物血量写成 payload")
	var current: Dictionary = input.get_current_request(0)
	var decoded: Variant = current.get("decoded_payload", {})
	assert_true(decoded is Dictionary)
	var targets: Array = decoded.get("targets", [])
	assert_eq(targets.size(), 1)
	assert_eq(targets[0], monster)


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
