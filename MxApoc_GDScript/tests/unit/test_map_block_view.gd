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
