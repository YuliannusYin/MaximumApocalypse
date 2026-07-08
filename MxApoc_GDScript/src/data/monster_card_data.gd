class_name MonsterCardData
extends RefCounted

## 怪物卡静态数据。
## 从 data/monsters/*.json 的 monsters 数组项构造。
## 字段规范见 GameDesignDocus/Engineering/DataFormat.md §2.3。

var monster_name: String = ""
var english_name: String = ""
var monster_level: String = ""  # "boss" / "elite" / "normal"
var max_hp: int = 0
var initial_hp: int = 0
var attack_damage: int = 0
var range: String = ""  # "none" / "short" / "medium" / "long" / "infinity"
var skills: Array = []  # Array[SkillData]


func _init(data: Dictionary = {}) -> void:
	monster_name = data.get("monster_name", "")
	english_name = data.get("english_name", "")
	monster_level = data.get("monster_level", "normal")
	max_hp = int(data.get("max_hp", 0))
	initial_hp = int(data.get("initial_hp", 0))
	attack_damage = int(data.get("attack_damage", 0))
	range = data.get("range", "none")
	var raw_skills: Array = data.get("skills", [])
	for raw in raw_skills:
		if raw is Dictionary:
			skills.append(SkillData.new(raw))
