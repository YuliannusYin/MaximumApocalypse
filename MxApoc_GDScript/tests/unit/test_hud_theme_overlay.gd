extends TestBase

## 覆盖层打开动画与弹窗同一套参数：根节点先透明再淡入。


func test_play_overlay_appear_starts_transparent() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var panel := Panel.new()
	panel.size = Vector2(120, 80)
	root.add_child(panel)
	HudTheme.play_overlay_appear(root, panel)
	assert_eq(root.modulate.a, 0.0, "打开瞬间根节点应透明")
	assert_eq(panel.scale, HudTheme.OVERLAY_OPEN_SCALE, "内容面板应从 0.92 缩放起")
