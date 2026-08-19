class_name ScavengeCardData
extends RefCounted

## 拾荒卡静态数据。
## 从 data/scavenge/*.json 的 cards 数组项构造。
## 字段规范见 GameDesignDocus/Engineering/DataFormat.md §2.2。

var card_name: String = ""
var english_name: String = ""
var card_type: String = ""  # "action" / "equipment"
var size: int = 0
## 射程："none" / "short" / "medium" / "long" / "infinity"
var range: String = "none"
var charge_type: String = ""
var charge_max: int = 0
var charge_initial: int = 0
var value: int = 0
var skills: Array = []  # Array[SkillData]


func _init(data: Dictionary = {}) -> void:
	card_name = data.get("card_name", "")
	english_name = data.get("english_name", "")
	card_type = data.get("card_type", "")
	size = int(data.get("size", 0))
	range = data.get("range", "none")
	charge_type = data.get("charge_type", "")
	charge_max = int(data.get("charge_max", 0))
	charge_initial = int(data.get("charge_initial", 0))
	value = int(data.get("value", 0))
	var raw_skills: Array = data.get("skills", [])
	for raw in raw_skills:
		if raw is Dictionary:
			skills.append(SkillData.new(raw))
