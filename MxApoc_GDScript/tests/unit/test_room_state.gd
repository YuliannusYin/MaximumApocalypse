extends TestBase

## RoomState 房间配置持久化：按模式分文件、读写往返、损坏回退、重置覆盖存档。

const PLAYER_PATH := "user://room_state_test_player.json"
const DEBUG_PATH := "user://room_state_test_debug.json"


func before_each() -> void:
	super.before_each()
	_remove_test_files()
	RoomState.set_config_paths(PLAYER_PATH, DEBUG_PATH)
	RoomState.clear()


func after_each() -> void:
	_remove_test_files()
	RoomState.set_config_paths("", "")
	RoomState.load_from_disk()
	super.after_each()


func _remove_test_files() -> void:
	for path in [PLAYER_PATH, DEBUG_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _survivor(english_name: String) -> SurvivorData:
	assert_true(DataManager.has_survivor(english_name), "%s 应存在" % english_name)
	return DataManager.get_survivor(english_name)


func test_missing_file_loads_defaults() -> void:
	RoomState.selected_mission_is_random = false
	RoomState.selected_mission = DataManager.get_mission(0)
	RoomState.seats = [
		{"type": "human", "survivor": _survivor("firefighter")},
		{"type": "ai", "survivor": _survivor("hunter")},
	]
	RoomState.load_from(PLAYER_PATH)
	assert_true(RoomState.selected_mission_is_random)
	assert_null(RoomState.selected_mission)
	assert_eq(RoomState.seats.size(), 1)
	assert_eq(RoomState.seats[0].type, "human")
	assert_null(RoomState.seats[0].survivor)


func test_save_load_roundtrip_mission_variants_seats() -> void:
	RoomState.selected_mission_is_random = false
	RoomState.selected_mission = DataManager.get_mission(0)
	RoomState.variants = {"crisis": true, "famine": false, "shared_fate": true}
	RoomState.seats = [
		{"type": "human", "survivor": _survivor("firefighter")},
		{"type": "ai", "survivor": _survivor("hunter")},
		{"type": "empty", "survivor": null},
	]
	RoomState.save_to(PLAYER_PATH)
	RoomState.clear()
	RoomState.load_from(PLAYER_PATH)
	assert_false(RoomState.selected_mission_is_random)
	assert_not_null(RoomState.selected_mission)
	assert_eq(RoomState.selected_mission.mission_id, 0)
	var variants_unlocked := Settings.dev_mode or ArchiveManager.is_random_and_variants_unlocked()
	if variants_unlocked:
		assert_true(RoomState.variants["crisis"])
		assert_false(RoomState.variants["famine"])
		assert_true(RoomState.variants["shared_fate"])
	else:
		assert_false(RoomState.variants["crisis"])
		assert_false(RoomState.variants["famine"])
		assert_false(RoomState.variants["shared_fate"])
	assert_eq(RoomState.seats.size(), 3)
	assert_eq(RoomState.seats[0].type, "human")
	assert_eq(RoomState.seats[0].survivor.english_name, "firefighter")
	assert_eq(RoomState.seats[1].type, "ai")
	assert_eq(RoomState.seats[1].survivor.english_name, "hunter")
	assert_eq(RoomState.seats[2].type, "empty")
	assert_null(RoomState.seats[2].survivor)


func test_clear_does_not_write_disk() -> void:
	RoomState.selected_mission_is_random = false
	RoomState.selected_mission = DataManager.get_mission(0)
	RoomState.seats = [{"type": "human", "survivor": _survivor("firefighter")}]
	RoomState.save_to(PLAYER_PATH)
	RoomState.clear()
	assert_true(RoomState.selected_mission_is_random)
	assert_null(RoomState.seats[0].survivor)
	RoomState.load_from(PLAYER_PATH)
	assert_false(RoomState.selected_mission_is_random)
	assert_eq(RoomState.selected_mission.mission_id, 0)
	assert_eq(RoomState.seats[0].survivor.english_name, "firefighter")


func test_reset_to_default_overwrites_saved_config() -> void:
	RoomState.selected_mission_is_random = false
	RoomState.selected_mission = DataManager.get_mission(0)
	RoomState.seats = [
		{"type": "human", "survivor": _survivor("firefighter")},
		{"type": "ai", "survivor": _survivor("hunter")},
	]
	RoomState.save()
	RoomState.reset_to_default()
	assert_true(RoomState.selected_mission_is_random)
	assert_eq(RoomState.seats.size(), 1)
	RoomState.clear()
	RoomState.load_from_disk()
	assert_true(RoomState.selected_mission_is_random)
	assert_eq(RoomState.seats.size(), 1)
	assert_null(RoomState.seats[0].survivor)


func test_player_and_debug_files_are_independent() -> void:
	RoomState.selected_mission_is_random = false
	RoomState.selected_mission = DataManager.get_mission(0)
	RoomState.seats = [{"type": "human", "survivor": _survivor("firefighter")}]
	RoomState.save_to(PLAYER_PATH)
	RoomState.selected_mission = DataManager.get_mission(1)
	RoomState.seats = [
		{"type": "human", "survivor": _survivor("gunslinger")},
		{"type": "ai", "survivor": _survivor("mechanic")},
	]
	RoomState.save_to(DEBUG_PATH)
	RoomState.load_from(PLAYER_PATH)
	assert_eq(RoomState.selected_mission.mission_id, 0)
	assert_eq(RoomState.seats.size(), 1)
	assert_eq(RoomState.seats[0].survivor.english_name, "firefighter")
	RoomState.load_from(DEBUG_PATH)
	assert_eq(RoomState.selected_mission.mission_id, 1)
	assert_eq(RoomState.seats.size(), 2)
	assert_eq(RoomState.seats[0].survivor.english_name, "gunslinger")
	assert_eq(RoomState.seats[1].survivor.english_name, "mechanic")


func test_load_from_disk_uses_current_mode_path() -> void:
	RoomState.selected_mission_is_random = false
	RoomState.selected_mission = DataManager.get_mission(0)
	RoomState.seats = [{"type": "human", "survivor": _survivor("firefighter")}]
	RoomState.save_to(PLAYER_PATH)
	RoomState.selected_mission = DataManager.get_mission(1)
	RoomState.seats = [{"type": "human", "survivor": _survivor("surgeon")}]
	RoomState.save_to(DEBUG_PATH)
	RoomState.load_from_disk()
	if Settings.dev_mode:
		assert_eq(RoomState.selected_mission.mission_id, 1)
		assert_eq(RoomState.seats[0].survivor.english_name, "surgeon")
	else:
		assert_eq(RoomState.selected_mission.mission_id, 0)
		assert_eq(RoomState.seats[0].survivor.english_name, "firefighter")


func test_invalid_survivor_and_mission_are_dropped() -> void:
	var payload := {
		"mission_is_random": false,
		"mission_id": 99999,
		"variants": {},
		"seats": [
			{"type": "human", "survivor": "not_a_real_survivor"},
		],
	}
	var file := FileAccess.open(PLAYER_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	RoomState.load_from(PLAYER_PATH)
	assert_false(RoomState.selected_mission_is_random)
	assert_null(RoomState.selected_mission)
	assert_eq(RoomState.seats.size(), 1)
	assert_null(RoomState.seats[0].survivor)


func test_extra_seats_clamped_and_seat_zero_can_be_ai() -> void:
	var seats: Array = []
	for i in range(8):
		seats.append({"type": "ai", "survivor": "hunter"})
	var payload := {
		"mission_is_random": true,
		"mission_id": -1,
		"variants": {},
		"seats": seats,
	}
	var file := FileAccess.open(PLAYER_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	RoomState.load_from(PLAYER_PATH)
	assert_eq(RoomState.seats.size(), RoomState.MAX_SEATS)
	assert_eq(RoomState.seats[0].type, "ai")
	assert_eq(RoomState.seats[1].type, "ai")


func test_seat_zero_ai_roundtrip() -> void:
	RoomState.seats = [
		{"type": "ai", "survivor": _survivor("hunter")},
		{"type": "human", "survivor": _survivor("firefighter")},
	]
	RoomState.save_to(PLAYER_PATH)
	RoomState.clear()
	RoomState.load_from(PLAYER_PATH)
	assert_eq(RoomState.seats.size(), 2)
	assert_eq(RoomState.seats[0].type, "ai")
	assert_eq(RoomState.seats[0].survivor.english_name, "hunter")
	assert_eq(RoomState.seats[1].type, "human")
	assert_eq(RoomState.seats[1].survivor.english_name, "firefighter")


func test_is_ready_to_start_requires_occupant() -> void:
	RoomState.seats = [{"type": "empty", "survivor": null}]
	assert_false(RoomState.is_ready_to_start())
	RoomState.seats = [{"type": "ai", "survivor": null}]
	assert_false(RoomState.is_ready_to_start())
	RoomState.seats = [{"type": "ai", "survivor": _survivor("hunter")}]
	assert_true(RoomState.is_ready_to_start())


func test_corrupt_file_falls_back_to_defaults() -> void:
	var file := FileAccess.open(PLAYER_PATH, FileAccess.WRITE)
	file.store_string("[]")
	file.close()
	RoomState.seats = [{"type": "human", "survivor": _survivor("firefighter")}]
	RoomState.load_from(PLAYER_PATH)
	assert_true(RoomState.selected_mission_is_random)
	assert_eq(RoomState.seats.size(), 1)
	assert_null(RoomState.seats[0].survivor)
