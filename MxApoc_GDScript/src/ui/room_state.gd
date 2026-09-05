extends Node

## 房间状态（autoload）。任务 / 变体 / 座位在游戏房间中编辑，
## 按开发者模式分别写入 user://room.json 与 user://room_debug.json。
## 打完一局或重启游戏后再进房间，恢复上次配置。

const CONFIG_PATH_PLAYER := "user://room.json"
const CONFIG_PATH_DEBUG := "user://room_debug.json"
const MIN_SEATS := 1
const MAX_SEATS := 6
const DEFAULT_VARIANTS := {"crisis": false, "famine": false, "shared_fate": false}

## 当前选中的任务；为 null 表示未选择或随机任务。
var selected_mission: MissionData = null
## 是否为随机任务模式（开局时抽取）。
var selected_mission_is_random: bool = true
## 变体启用状态，键为变体 id，值为是否启用。
var variants: Dictionary = DEFAULT_VARIANTS.duplicate()
## 座位列表；每项为 {type: String, survivor: SurvivorData} 字典。
var seats: Array = []

var _path_player: String = CONFIG_PATH_PLAYER
var _path_debug: String = CONFIG_PATH_DEBUG


func _ready() -> void:
	clear()
	Settings.dev_mode_changed.connect(_on_dev_mode_changed)
	# Settings 在本 autoload 之后 _ready；推迟到下一帧再读盘，才能按 dev_mode 选文件。
	call_deferred("load_from_disk")


## 重置房间状态为初始值（1 个真人座，随机任务，无变体）。不写盘。
func clear() -> void:
	selected_mission = null
	selected_mission_is_random = true
	variants = DEFAULT_VARIANTS.duplicate()
	seats = [{"type": "human", "survivor": null}]


## 重置为默认并覆盖当前模式的已保存配置。
func reset_to_default() -> void:
	clear()
	save()


## 是否满足开局条件：非空座位均已选择求生者。
func is_ready_to_start() -> bool:
	if seats.is_empty():
		return false
	for seat in seats:
		if seat.type == "empty":
			continue
		if seat.survivor == null:
			return false
	return true


## 当前模式对应的房间配置路径。
func get_config_path() -> String:
	return _path_debug if Settings.dev_mode else _path_player


## 注入读写路径（测试用）。空字符串表示恢复内置默认路径。
func set_config_paths(player_path: String, debug_path: String) -> void:
	_path_player = CONFIG_PATH_PLAYER if player_path.is_empty() else player_path
	_path_debug = CONFIG_PATH_DEBUG if debug_path.is_empty() else debug_path


## 从当前模式的配置文件加载；文件不存在或损坏时回退为默认。
func load_from_disk() -> void:
	load_from(get_config_path())


## 将当前房间状态写入当前模式的配置文件。
func save() -> void:
	save_to(get_config_path())


func load_from(path: String) -> void:
	clear()
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("RoomState: 无法读取房间配置: " + path)
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		push_warning("RoomState: 房间配置损坏，已回退默认: " + path)
		return
	_apply_serialized(parsed)


func save_to(path: String) -> void:
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("RoomState: 无法写入房间配置: " + path)
		return
	file.store_string(JSON.stringify(_to_serialized(), "  "))
	file.close()


## 生成房间状态的文本快照，供 GameScene 占位展示。
func snapshot() -> String:
	var lines := PackedStringArray([])
	if selected_mission_is_random:
		lines.append("任务：随机任务（开局时抽取）")
	elif selected_mission != null:
		lines.append("任务：%s（%s）" % [selected_mission.mission_name, selected_mission.difficulty_display])
	else:
		lines.append("任务：未选择")

	var active_variants := PackedStringArray([])
	for key in variants:
		if variants[key]:
			var variant := DataManager.get_variant(key)
			if variant != null:
				active_variants.append(variant.display_name)
	if active_variants.is_empty():
		lines.append("变体：无")
	else:
		lines.append("变体：" + ", ".join(active_variants))

	lines.append("玩家：")
	for i in range(seats.size()):
		var seat = seats[i]
		var survivor_text = "未选择"
		if seat.survivor != null:
			survivor_text = seat.survivor.character_name
		lines.append("  座位%d [%s] - %s" % [i + 1, seat.type, survivor_text])

	return "\n".join(lines)


func _on_dev_mode_changed(_value: bool) -> void:
	# 信号发出时 Settings.dev_mode 已是新模式；内存仍是旧模式的房间配置。
	save_to(_path_debug if not Settings.dev_mode else _path_player)
	load_from_disk()


func _to_serialized() -> Dictionary:
	var seat_rows: Array = []
	for seat in seats:
		var sid := ""
		if seat.survivor != null:
			sid = String(seat.survivor.english_name)
		seat_rows.append({
			"type": String(seat.get("type", "human")),
			"survivor": sid,
		})
	var mission_id := -1
	if selected_mission != null:
		mission_id = selected_mission.mission_id
	return {
		"mission_is_random": selected_mission_is_random,
		"mission_id": mission_id,
		"variants": variants.duplicate(),
		"seats": seat_rows,
	}


func _apply_serialized(data: Dictionary) -> void:
	selected_mission_is_random = bool(data.get("mission_is_random", true))
	selected_mission = null
	if not selected_mission_is_random:
		var mission_id := int(data.get("mission_id", -1))
		if DataManager.has_mission(mission_id):
			selected_mission = DataManager.get_mission(mission_id)
		else:
			selected_mission_is_random = false
			selected_mission = null

	variants = DEFAULT_VARIANTS.duplicate()
	var raw_variants: Variant = data.get("variants", {})
	if raw_variants is Dictionary:
		for key in variants:
			variants[key] = bool(raw_variants.get(key, false))
	if not Settings.dev_mode and not ArchiveManager.is_random_and_variants_unlocked():
		for key in variants:
			variants[key] = false

	var available_ids: Dictionary = {}
	for survivor in DataManager.get_available_survivors():
		available_ids[survivor.english_name] = survivor

	seats = []
	var raw_seats: Variant = data.get("seats", [])
	if raw_seats is Array:
		for raw in raw_seats:
			if not (raw is Dictionary):
				continue
			if seats.size() >= MAX_SEATS:
				break
			seats.append(_sanitize_seat(raw, seats.size(), available_ids))
	if seats.is_empty():
		seats = [{"type": "human", "survivor": null}]
	seats[0]["type"] = "human"


func _sanitize_seat(raw: Dictionary, index: int, available_ids: Dictionary) -> Dictionary:
	var type_text := String(raw.get("type", "ai"))
	if type_text != "human" and type_text != "ai" and type_text != "empty":
		type_text = "ai" if index > 0 else "human"
	if index == 0:
		type_text = "human"
	var survivor = null
	if type_text != "empty":
		var sid := String(raw.get("survivor", ""))
		if available_ids.has(sid):
			survivor = available_ids[sid]
	return {"type": type_text, "survivor": survivor}
