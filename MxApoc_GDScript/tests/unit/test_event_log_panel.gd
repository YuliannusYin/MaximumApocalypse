extends TestBase

## 事件日志新行闪一下，且只保留最近若干条。


func test_add_message_flashes_and_caps_lines() -> void:
	var panel := EventLogPanel.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	panel.add_message("第一条")
	assert_eq(panel._messages.size(), 1)
	assert_not_null(panel._flash_tween, "新日志应启动闪烁 Tween")
	var first: Tween = panel._flash_tween
	panel.add_message("第二条")
	assert_eq(panel._messages.size(), 2)
	assert_not_null(panel._flash_tween)
	assert_true(not first.is_valid() or panel._flash_tween != first, "新消息应重启闪烁 Tween")
	for i in range(20):
		panel.add_message("overflow_%d" % i)
	assert_eq(panel._messages.size(), EventLogPanel.MAX_LINES)
