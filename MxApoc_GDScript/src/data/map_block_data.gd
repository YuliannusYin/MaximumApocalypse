class_name MapBlockData
extends RefCounted

## 地图块静态数据。
## 从 data/map_blocks/map_blocks.json 的 blocks 数组项构造。
## 字段规范见 GameDesignDocus/Engineering/DataFormat.md §2.5。

var block_name: String = ""
var english_name: String = ""
var scavenge_colors: Array = []  # Array[String]：["red", "green", "blue"]
var monster_spawn_value: int = 0
var variants: Array = []  # Array[Dictionary]：[{"scavenge_colors": [...], "monster_spawn_value": int}, ...]
var skills: Array = []  # Array[SkillData]


func _init(data: Dictionary = {}) -> void:
	block_name = data.get("block_name", "")
	english_name = data.get("english_name", "")
	scavenge_colors = data.get("scavenge_colors", [])
	monster_spawn_value = int(data.get("monster_spawn_value", 0))
	variants = data.get("variants", [])
	var raw_skills: Array = data.get("skills", [])
	for raw in raw_skills:
		if raw is Dictionary:
			skills.append(SkillData.new(raw))
