extends Node

## 当前选中的任务；为 null 表示未选择或随机任务。
var selected_mission: MissionData = null
## 是否为随机任务模式（开局时抽取）。
var selected_mission_is_random: bool = true
## 变体启用状态，键为变体 id，值为是否启用。
var variants: Dictionary = {"crisis": false, "famine": false, "shared_fate": false}
## 座位列表；每项为 {type, survivor, player_name, peer_id} 字典。
## type: "human" / "ai" / "empty"；peer_id: 座位归属的网络 peer（0 表示无网络归属）。
var seats: Array = []


func _ready() -> void:
	clear()


## 重置房间状态为初始值（1 个真人座，无任务，无变体）。
func clear() -> void:
	selected_mission = null
	selected_mission_is_random = true
	variants = {"crisis": false, "famine": false, "shared_fate": false}
	seats = [_make_seat("human", null, "", 0)]


func _make_seat(type: String, survivor: SurvivorData, player_name: String, peer_id: int) -> Dictionary:
	return {"type": type, "survivor": survivor, "player_name": player_name, "peer_id": peer_id}


## 主机模式初始化座位：主机座位 + 5 个空座位，供客机认领。
func init_host_seats(host_name: String, host_peer_id: int) -> void:
	seats = [_make_seat("human", null, host_name, host_peer_id)]
	for i in range(5):
		seats.append(_make_seat("empty", null, "", 0))


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


## 序列化为可网络传输的字典（求生者对象转为 english_name）。
func to_dict() -> Dictionary:
	return {
		"selected_mission_id": selected_mission.mission_id if selected_mission != null else -1,
		"selected_mission_is_random": selected_mission_is_random,
		"variants": variants.duplicate(true),
		"seats": seats_to_dict(),
	}


func seats_to_dict() -> Array:
	var out: Array = []
	for seat in seats:
		out.append({
			"type": str(seat.get("type", "empty")),
			"survivor_id": seat.survivor.english_name if seat.survivor != null else "",
			"player_name": str(seat.get("player_name", "")),
			"peer_id": int(seat.get("peer_id", 0)),
		})
	return out


## 从网络字典还原房间状态（求生者通过 english_name 查回对象）。
func apply_dict(d: Dictionary) -> void:
	selected_mission_is_random = bool(d.get("selected_mission_is_random", true))
	var mission_id := int(d.get("selected_mission_id", -1))
	selected_mission = null
	if mission_id >= 0:
		selected_mission = DataManager.get_mission(mission_id)
	variants = d.get("variants", {}).duplicate(true)
	if variants.is_empty():
		variants = {"crisis": false, "famine": false, "shared_fate": false}
	apply_seats(d.get("seats", []))


func apply_seats(arr: Array) -> void:
	seats = []
	for item in arr:
		var survivor: SurvivorData = null
		var sid := str(item.get("survivor_id", ""))
		if sid != "":
			survivor = DataManager.get_survivor(sid)
		seats.append({
			"type": str(item.get("type", "empty")),
			"survivor": survivor,
			"player_name": str(item.get("player_name", "")),
			"peer_id": int(item.get("peer_id", 0)),
		})


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
		var owner := ""
		if seat.get("peer_id", 0) != 0 and seat.get("player_name", "") != "":
			owner = " (%s)" % seat.player_name
		lines.append("  座位%d [%s]%s - %s" % [i + 1, seat.type, owner, survivor_text])

	return "\n".join(lines)
