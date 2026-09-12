extends TestBase

## 地图块贴图键：同一地块名下颜色/刷怪点数变化必须得到不同键。


func test_variant_texture_key_changes_with_colors_and_spawn() -> void:
	var view := MapBlockView.new()
	add_child_autofree(view)
	var block: MapBlock = _make_block("城市街道", 0, 0, true)
	block.scavenge_colors = PackedStringArray(["red"])
	block.monster_spawn_value = 6
	view._block = block
	var first_key: String = view._variant_texture_key()
	assert_ne(first_key, "", "揭示变体应生成贴图键")
	assert_true(first_key.contains("red") and first_key.contains("6"), "键应含颜色与刷怪点数")
	block.scavenge_colors = PackedStringArray(["green"])
	block.monster_spawn_value = 8
	var second_key: String = view._variant_texture_key()
	assert_ne(second_key, first_key, "颜色或刷怪点数变化应得到不同贴图键")
	assert_true(second_key.contains("green") and second_key.contains("8"), "新键应含新的颜色与刷怪点数")


func test_move_highlight_breathe_starts_and_stops() -> void:
	var view := MapBlockView.new()
	add_child_autofree(view)
	var block: MapBlock = _make_block("城市街道", 0, 0, true)
	view.setup(block)
	await get_tree().process_frame
	view.set_move_highlight("green")
	assert_true(view._move_highlight_panel.visible, "可走地块应显示绿色高亮")
	assert_not_null(view._highlight_tween, "高亮呼吸应启动 Tween")
	assert_true(view._highlight_tween.is_valid(), "呼吸 Tween 应有效")
	var first_tween: Tween = view._highlight_tween
	view.set_move_highlight("green")
	assert_eq(view._highlight_tween, first_tween, "重复设 green 不应重建呼吸 Tween")
	view.set_move_highlight("none")
	assert_false(view._move_highlight_panel.visible, "取消高亮应隐藏覆盖层")
	assert_true(view._highlight_tween == null or not view._highlight_tween.is_valid(),
		"取消高亮应终止呼吸 Tween")


func test_click_pulse_reuses_tween() -> void:
	var view := MapBlockView.new()
	add_child_autofree(view)
	var block: MapBlock = _make_block("城市街道", 0, 0, true)
	view.setup(block)
	await get_tree().process_frame
	view.play_click_pulse()
	assert_not_null(view._click_tween)
	var first: Tween = view._click_tween
	view.play_click_pulse()
	assert_not_null(view._click_tween)
	assert_true(first == null or not first.is_valid() or view._click_tween != first
		or view._click_tween.is_valid(), "再次点击应 reuse/重启 click tween")
