extends TestBase

## 玩家面板新增死亡/怪物受伤反馈：进树后调用不应抛错，并 reuse Tween。


func test_death_and_monster_feedback_reuse_tweens() -> void:
	var panel := PlayerPanel.new()
	add_child_autofree(panel)
	await get_tree().process_frame
	panel.play_death_feedback()
	assert_not_null(panel._feedback_tween)
	var first: Tween = panel._feedback_tween
	panel.play_death_feedback()
	assert_not_null(panel._feedback_tween)
	assert_true(not first.is_valid() or panel._feedback_tween != first, "死亡反馈应 kill 旧 Tween")
	panel.play_monster_spawn_pulse()
	panel.play_monster_damage_feedback(3)
	assert_not_null(panel._monster_tween)
