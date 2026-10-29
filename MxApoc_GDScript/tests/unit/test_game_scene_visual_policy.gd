extends TestBase

const GameScene2DScript := preload("res://src/ui/game_scene_2d.gd")


func test_single_player_visual_keeps_existing_defer_policy() -> void:
	assert_true(GameScene2DScript.should_defer_state_for_visual(false, true))
	assert_false(GameScene2DScript.should_defer_state_for_visual(false, false))


func test_network_visual_never_defers_state_progress() -> void:
	assert_false(GameScene2DScript.should_defer_state_for_visual(true, true),
		"联机演出播放中也必须立即应用快照、确认与地图刷新")
