extends Node

var selected_mission: MissionData = null
var selected_mission_is_random: bool = true
var variants: Dictionary = {"crisis": false, "famine": false, "shared_fate": false}
var seats: Array = []

func _ready() -> void:
	clear()

func clear() -> void:
	selected_mission = null
	selected_mission_is_random = true
	variants = {"crisis": false, "famine": false, "shared_fate": false}
	seats = [{"type": "human", "survivor": null}]

func is_ready_to_start() -> bool:
	if seats.is_empty():
		return false
	for seat in seats:
		if seat.type == "empty":
			continue
		if seat.survivor == null:
			return false
	return true

func snapshot() -> String:
	var lines := PackedStringArray([])
	if selected_mission_is_random:
		lines.append("任务：随机任务（开局时抽取）")
	elif selected_mission != null:
		lines.append("任务：%s（%s）" % [selected_mission.name, selected_mission.difficulty])
	else:
		lines.append("任务：未选择")

	var active_variants := PackedStringArray([])
	for key in variants:
		if variants[key]:
			var v := Variants.get_by_id(key)
			if v != null:
				active_variants.append(v.display_name)
	if active_variants.is_empty():
		lines.append("变体：无")
	else:
		lines.append("变体：" + ", ".join(active_variants))

	lines.append("玩家：")
	for i in range(seats.size()):
		var seat = seats[i]
		var survivor_text = "未选择"
		if seat.survivor != null:
			survivor_text = seat.survivor.display_name
		lines.append("  座位%d [%s] - %s" % [i + 1, seat.type, survivor_text])

	return "\n".join(lines)
