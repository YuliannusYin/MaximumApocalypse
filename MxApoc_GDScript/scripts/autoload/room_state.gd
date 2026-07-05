extends Node

## 当前选中的任务；为 null 表示未选择或随机任务。
var selected_mission: MissionData = null
## 是否为随机任务模式（开局时抽取）。
var selected_mission_is_random: bool = true
## 变体启用状态，键为变体 id，值为是否启用。
var variants: Dictionary = {"crisis": false, "famine": false, "shared_fate": false}
## 座位列表；每项为 {type: String, survivor: SurvivorData} 字典。
var seats: Array = []

func _ready() -> void:
	clear()

## 重置房间状态为初始值（1 个真人座，无任务，无变体）。
func clear() -> void:
	selected_mission = null
	selected_mission_is_random = true
	variants = {"crisis": false, "famine": false, "shared_fate": false}
	seats = [{"type": "human", "survivor": null}]

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

## 生成房间状态的文本快照，供 GameScene 占位展示。
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
			var variant := Variants.get_by_id(key)
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
			survivor_text = seat.survivor.display_name
		lines.append("  座位%d [%s] - %s" % [i + 1, seat.type, survivor_text])

	return "\n".join(lines)
