extends TestBase

## SeatHud 为每个座位独立持有私有交互组件。


func test_seat_hud_builds_independent_private_components() -> void:
	var parent := Control.new()
	add_child_autofree(parent)
	var player := Player.new()
	player.hand = []
	var hud := SeatHud.new()
	hud.setup(player, parent)
	await get_tree().process_frame

	assert_eq(hud.player, player)
	assert_not_null(hud.hand_area)
	assert_not_null(hud.active_skill_bar)
	assert_not_null(hud.action_controller)
	assert_true(hud.visible)
	assert_eq(hud.mouse_filter, Control.MOUSE_FILTER_IGNORE, "全屏 SeatHud 容器不能拦截公共控件鼠标输入")

	hud.set_active(false)
	assert_false(hud.visible)
	hud.set_active(true)
	assert_true(hud.visible)
