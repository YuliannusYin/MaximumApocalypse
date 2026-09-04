extends GutTest

## SeatHudManager：稳定座位映射与单一可见焦点。

const SeatHudManagerScript = preload("res://src/ui/seat_hud_manager.gd")


func test_focus_switches_only_the_requested_seat_hud() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	var player_a := Player.new()
	var player_b := Player.new()
	var manager: Node = SeatHudManagerScript.new()
	add_child_autofree(manager)
	manager.setup(parent)
	manager.build([player_a, player_b])

	manager.focus_player(player_a)
	assert_true(manager.get_hud(player_a).visible)
	assert_false(manager.get_hud(player_b).visible)

	manager.focus_player(player_b)
	assert_false(manager.get_hud(player_a).visible)
	assert_true(manager.get_hud(player_b).visible)
	assert_eq(manager.get_focused_player(), player_b)
