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
