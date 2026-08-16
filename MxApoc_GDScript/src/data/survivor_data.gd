class_name SurvivorData
extends RefCounted

## 求生者静态数据。
## 从 data/survivors/*.json 构造。
## 字段规范见 GameDesignDocus/Engineering/DataFormat.md §2.1。

var character_name: String = ""
var english_name: String = ""
var max_hp: int = 0
var initial_hp: int = 0
var stealth: int = 0
var hunger_stealth: int = 0
var equipment_slot: int = 4
var hand_size_limit: int = 10
var intrinsic_skills: Array = []  # Array[SkillData]
var deck: Array = []  # Array[Dictionary]：每项含 card_name/english_name/count/card_type/skills
var sub_survivors: Array = []  # Array[Dictionary]：双子角色数据（仅 veteran 使用）


func _init(data: Dictionary = {}) -> void:
	character_name = data.get("character_name", "")
	english_name = data.get("english_name", "")
	max_hp = int(data.get("max_hp", 0))
	initial_hp = int(data.get("initial_hp", 0))
	stealth = int(data.get("stealth", 0))
	hunger_stealth = int(data.get("hunger_stealth", 0))
	equipment_slot = int(data.get("equipment_slot", 4))
	hand_size_limit = int(data.get("hand_size_limit", 10))
	var raw_skills: Array = data.get("intrinsic_skills", [])
	for raw in raw_skills:
		if raw is Dictionary:
			intrinsic_skills.append(SkillData.new(raw))
	deck = data.get("deck", [])
	sub_survivors = data.get("sub_survivors", [])
