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
