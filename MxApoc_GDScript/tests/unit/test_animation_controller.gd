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
