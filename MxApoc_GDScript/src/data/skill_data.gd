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
var select_target_min: int = -1
var range: String = ""
var usable: int = -1
var content: String = ""
var target_type: String = ""
var confirm_prompt: String = ""
var defer_action_cost: bool = false
var window_prompt: String = ""

## 子技能：键为本地短名（如 "satiety"），值为 SkillData 实例。
## 由 _init 递归解析 JSON 中的 sub_skills 对象。
var sub_skills: Dictionary = {}


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
	# select_target 支持两种格式：
	# - Int（如 2）：精确选择 2 个目标（exact 模式，select_target_min 保持 -1）
	# - Array（如 [1, 3]）：范围选择，min=首元素，max=末元素（select_target_min=1, select_target=3）
	# -1 表示选全部；0 表示不选目标（缺省）
	var st_val: Variant = data.get("select_target", 0)
	if typeof(st_val) == TYPE_ARRAY:
		var st_arr: Array = st_val
		if st_arr.size() > 0:
			select_target_min = int(st_arr[0])
			select_target = int(st_arr[st_arr.size() - 1])
		else:
			# 空数组视为缺省（0），避免 int([]) 触发与 #报错相同的 int 构造崩溃
			select_target = 0
			select_target_min = -1
	else:
		select_target = int(st_val)
		select_target_min = -1
	range = data.get("range", "")
	usable = int(data.get("usable", -1))
	content = data.get("content", "")
	target_type = data.get("target_type", "")
	confirm_prompt = data.get("confirm_prompt", "")
	defer_action_cost = data.get("defer_action_cost", false)
	window_prompt = data.get("window_prompt", "")
	# 递归解析 sub_skills
	var raw_sub: Dictionary = data.get("sub_skills", {})
	for sub_key in raw_sub.keys():
		var sub_dict: Dictionary = raw_sub[sub_key]
		sub_skills[sub_key] = SkillData.new(sub_dict)
