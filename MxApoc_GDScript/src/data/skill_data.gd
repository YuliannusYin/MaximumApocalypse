class_name SkillData
extends RefCounted

## 技能静态数据。
## 从 JSON 的 skill 对象构造。代码字段（filter/content 等）存为 String，由 CodeExecutor 懒编译。
## 字段规范见 GameDesignDocus/Engineering/DataFormat.md §三 与 IdentifierMapping.md §3.13。

var skill_name: String = ""
var english_name: String = ""
var skill_description: String = ""
var active: String = ""
var trigger: String = ""
var skill_type: String = ""
var forced: bool = false
var filter: String = ""
var filter_target: String = ""
var filter_target_range: String = ""
var filter_card: String = ""
var position: String = ""
var select_card: int = 0
var select_target: int = 0
var range: String = ""
var usable: int = -1
var content: String = ""
var target_type: String = ""
var confirm_prompt: String = ""
var defer_action_cost: bool = false


func _init(data: Dictionary = {}) -> void:
	skill_name = data.get("skill_name", "")
	english_name = data.get("english_name", "")
	skill_description = data.get("skill_description", "")
	active = data.get("active", "")
	trigger = data.get("trigger", "")
	skill_type = data.get("skill_type", "")
	forced = data.get("forced", false)
	filter = data.get("filter", "")
	filter_target = data.get("filter_target", "")
	filter_target_range = data.get("filter_target_range", "")
	filter_card = data.get("filter_card", "")
	position = data.get("position", "")
	select_card = int(data.get("select_card", 0))
	select_target = int(data.get("select_target", 0))
	range = data.get("range", "")
	usable = int(data.get("usable", -1))
	content = data.get("content", "")
	target_type = data.get("target_type", "")
	confirm_prompt = data.get("confirm_prompt", "")
	defer_action_cost = data.get("defer_action_cost", false)
