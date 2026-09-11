extends TestBase

## NetworkPlayerInput：演出不再进 pending、不等客机 ACK。


func test_visual_methods_do_not_block_on_input_response() -> void:
	var input := NetworkPlayerInput.new()
	var seen: Array = []
	input.visual_requested.connect(func(request_type: String, seat_id: int, _payload: Dictionary) -> void:
		seen.append({"type": request_type, "seat": seat_id})
	)
	var player := Player.new()
	player.seat_number = 0
	input.set_request_owner(player)
	input.play_monster_draw_animation(player, null)
	input.play_dice_animation(1, 2, "test", "ok")
	assert_eq(seen.size(), 2)
	assert_eq(seen[0].type, "monster_draw_animation")
	assert_eq(seen[1].type, "dice_animation")
	assert_eq(input._pending.size(), 0, "演出不应进入 pending")


func test_abort_pending_unblocks_without_waiting_for_client() -> void:
	var input := NetworkPlayerInput.new()
	input._pending[3] = {
		"value": null,
		"received": false,
		"selection_map": {},
		"request_type": "action",
	}
	input.abort_pending()
	assert_true(bool(input._pending[3].received))
	assert_eq(input._pending[3].value, null)
	input.detach()
	assert_eq(input._pending[3].received, true)


func test_token_request_without_selection_map_does_not_decode_game() -> void:
	var holder: Player = _make_player("P")
	holder.seat_number = 0
	var monster: Monster = Monster.new()
	monster.hp = 5
	monster.max_hp = 5
	holder.monster_zone = [monster]
	Game.players = [holder]
	var input := NetworkPlayerInput.new()
	var encoded: Variant = NetInputCodec.encode(monster)
	encoded["hp"] = 0
	var resolved: Variant = input._resolve_response_value("choose_target", encoded, {})
	assert_eq(resolved, [])
	assert_eq(monster.hp, 5, "无 token 时不得把客机怪物字典 decode 到权威 Game")
	input.detach()


func test_new_request_aborts_unanswered_request_for_same_seat() -> void:
	var input := NetworkPlayerInput.new()
	input._pending[3] = {
		"value": null,
		"received": false,
		"selection_map": {},
		"request_type": "confirm",
		"seat_id": 0,
	}
	input._abort_unanswered_for_seat(0)
	assert_true(bool(input._pending[3].received))
	assert_eq(input._pending[3].value, false, "被替换的 confirm 应中止为 false")
	input.detach()
