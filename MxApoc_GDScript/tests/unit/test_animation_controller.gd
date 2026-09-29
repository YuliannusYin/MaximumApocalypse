extends TestBase

## 统一动画控制器的装配测试。
## 主要验证所有动画入口由同一个控制器创建，避免 GameScene2D 漏挂某个视图。

func test_controller_builds_all_animation_views() -> void:
	var controller := AnimationController.new()
	add_child_autofree(controller)
	await get_tree().process_frame

	assert_eq(controller.get_child_count(), 8, "控制器应挂载 7 个动画视图和 1 个目标指向 CanvasLayer")
	assert_not_null(controller._dice_view)
	assert_not_null(controller._monster_draw_view)
	assert_not_null(controller._skill_trigger_view)
	assert_not_null(controller._monster_skill_trigger_view)
	assert_not_null(controller._monster_attack_view)
	assert_not_null(controller._card_destroy_view)
	assert_not_null(controller._turn_banner_view)
	assert_not_null(controller._target_link_view)
	assert_false(controller.is_dice_playing(), "默认不应在播放骰子")
	assert_false(controller.is_busy(), "默认不应处于演出中")


func test_is_busy_follows_view_playing_flags() -> void:
	var controller := AnimationController.new()
	var dice := DiceAnimationView.new()
	var destroy := CardDestroyAnimationView.new()
	controller._dice_view = dice
	controller._card_destroy_view = destroy
	assert_false(controller.is_busy(), "未播放时不应占用")
	dice._playing = true
	assert_true(controller.is_busy(), "骰子播放中应视为演出占用")
	dice._playing = false
	destroy._playing = true
	assert_true(controller.is_busy(), "毁牌播放中应视为演出占用")
	destroy._playing = false
	assert_false(controller.is_busy(), "全部视图空闲后不应占用")
	controller.free()
	dice.free()
	destroy.free()


func test_network_animation_queue_preserves_fifo_order() -> void:
	var controller := AnimationController.new()
	add_child(controller)
	var events: Array[String] = []
	controller.enqueue_network_animation(func() -> void:
		events.append("first_start")
		await get_tree().create_timer(0.02).timeout
		events.append("first_end"))
	controller.enqueue_network_animation(func() -> void:
		events.append("second_start")
		events.append("second_end"))

	assert_true(controller.is_network_animation_queue_busy())
	assert_eq(controller.get_network_animation_queue_size(), 1)
	await controller.network_animation_queue_drained

	assert_eq(events, [
		"first_start",
		"first_end",
		"second_start",
		"second_end",
	], "联机动画队列应按 FIFO 完整执行，不丢弃后续动画")
	assert_false(controller.is_network_animation_queue_busy())
	assert_false(controller.is_busy())
	controller.queue_free()
	await get_tree().process_frame
