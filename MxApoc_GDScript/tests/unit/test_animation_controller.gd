extends TestBase

## 统一动画控制器的装配测试。
## 主要验证所有动画入口由同一个控制器创建，避免 GameScene2D 漏挂某个视图。

func test_controller_builds_all_animation_views() -> void:
	var controller := AnimationController.new()
	add_child_autofree(controller)
	await get_tree().process_frame

	assert_eq(controller.get_child_count(), 9, "控制器应挂载 8 个动画视图和 1 个目标指向 CanvasLayer")
	assert_not_null(controller._dice_view)
	assert_not_null(controller._monster_draw_view)
	assert_not_null(controller._skill_trigger_view)
	assert_not_null(controller._monster_skill_trigger_view)
	assert_not_null(controller._monster_attack_view)
	assert_not_null(controller._card_destroy_view)
	assert_not_null(controller._turn_banner_view)
	assert_not_null(controller._target_link_view)
	assert_not_null(controller._card_motion_view)
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


func test_card_motion_uses_temporary_view_and_cleans_up() -> void:
	var controller := AnimationController.new()
	add_child_autofree(controller)
	await get_tree().process_frame
	var card := _make_card("轨迹牌")
	var motion := controller._card_motion_view
	var baseline_children := motion.get_child_count()

	await controller.play_card_motion(
		card,
		Rect2(Vector2(20, 20), Vector2(55, 75)),
		Rect2(Vector2(300, 300), Vector2(110, 150)),
		0.02)
	await get_tree().process_frame

	assert_false(motion.is_playing())
	assert_eq(motion.get_child_count(), baseline_children, "轨迹结束后应释放临时 CardView")


func test_animation_speed_modes_scale_duration() -> void:
	var previous_speed: int = Settings.animation_speed
	Settings.animation_speed = Settings.AnimationSpeed.STANDARD
	assert_almost_eq(Settings.get_animation_duration(1.0), 1.0, 0.001)
	Settings.animation_speed = Settings.AnimationSpeed.FAST
	assert_almost_eq(Settings.get_animation_duration(1.0),
		Settings.FAST_ANIMATION_MULTIPLIER, 0.001)
	Settings.animation_speed = Settings.AnimationSpeed.OFF
	assert_almost_eq(Settings.get_animation_duration(1.0), 0.0, 0.001)
	Settings.animation_speed = previous_speed


func test_animation_off_completes_fullscreen_views_immediately() -> void:
	var previous_speed: int = Settings.animation_speed
	Settings.animation_speed = Settings.AnimationSpeed.OFF
	var controller := AnimationController.new()
	add_child_autofree(controller)
	await get_tree().process_frame
	var card := _make_card("关闭动画")
	var monster_card := _make_monster_card("关闭怪物动画")
	var monster := _make_monster("关闭怪物反馈")

	await controller.play_dice(1, 2, "关闭骰子动画", "")
	await controller.play_scavenge_draw(card)
	await controller.play_card_destroy(card)
	await controller.play_monster_draw(monster_card, Vector2(200, 200))
	await controller.play_monster_skill_trigger(monster)
	await controller.play_monster_attack(monster, [Vector2(200, 200)])
	await controller.play_target_links(Vector2(20, 20), [Vector2(200, 200)], [])
	controller.play_turn_banner("关闭横幅")

	assert_false(controller.is_busy())
	assert_false(controller._dice_view.visible)
	assert_false(controller._skill_trigger_view.visible)
	assert_false(controller._card_destroy_view.visible)
	assert_false(controller._monster_draw_view.visible)
	assert_false(controller._monster_skill_trigger_view.visible)
	assert_false(controller._monster_attack_view.visible)
	assert_false(controller._target_link_view.visible)
	assert_false(controller._turn_banner_view.visible)
	Settings.animation_speed = previous_speed
