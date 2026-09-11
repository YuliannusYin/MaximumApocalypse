extends TestBase

## 加载页：联机客机不 initialize；单机仍 initialize。

const LoadingScreenScript = preload("res://src/ui/loading_screen.gd")


func test_online_client_does_not_initialize_from_room() -> void:
	var session := {"session_role": "client"}
	assert_false(LoadingScreenScript.should_initialize_from_room_state(
		session, {"online_multiplayer": true}))


func test_solo_still_initializes_from_room() -> void:
	assert_true(LoadingScreenScript.should_initialize_from_room_state(
		null, {"online_multiplayer": false}))
	var session := {"session_role": "none"}
	assert_true(LoadingScreenScript.should_initialize_from_room_state(
		session, {"online_multiplayer": false}))


func test_return_to_room_keeps_session_and_skips_prepare() -> void:
	LoadingScreenScript.configure_return_to_room()
	var cfg: Dictionary = LoadingScreenScript.pending_load_config()
	assert_eq(String(cfg.get("next_scene_path", "")), "res://scenes/GameRoom.tscn")
	assert_false(bool(cfg.get("abort_session", true)))
	assert_false(bool(cfg.get("prepare_game", true)))
	assert_true(bool(cfg.get("return_to_room", false)))
	assert_true(LoadingScreenScript.consume_returning_to_room())
	assert_false(LoadingScreenScript.consume_returning_to_room())
	LoadingScreenScript.reset_pending_load()
