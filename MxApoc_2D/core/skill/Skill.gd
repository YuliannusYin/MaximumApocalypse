# Skill.gd
class_name Skill
extends RefCounted

var skill_name: String
var english_name: String
var skill_description: String
var skill_type: String 
var trigger: String
var active_phase: String 
var forced: bool
var select_target: int
var target_type: String
var filter_condition: EffectCondition
var filter_target_condition: EffectCondition
var effects: Array[Effect] = []
var usable_limit: int = -1
var used_count: int = 0


# 判断本技能是否响应指定的 trigger 触发事件名
func matches_trigger(event_trigger_name: String) -> bool:
	if trigger.is_empty():
		return false
	var triggers: PackedStringArray = trigger.split("、")
	return triggers.has(event_trigger_name)


# 判断本技能是否为可在指定阶段主动释放的技能
func is_active_in_phase(current_phase: String) -> bool:
	if active_phase.is_empty():
		return false
	return active_phase == current_phase


# 校验前置触发条件（filter）
func check_filter(context: EffectContext) -> bool:
	if filter_condition == null:
		return true
	return filter_condition.is_satisfied(context)


# 校验目标合法性（filter_target）
func check_target_filter(context: EffectContext) -> bool:
	if filter_target_condition == null:
		return true
	return filter_target_condition.is_satisfied(context)


# 检查本回合是否仍可使用（受 usable 限制）
func is_usable() -> bool:
	if usable_limit < 0:
		return true
	return used_count < usable_limit


# 记录一次使用
func record_use() -> void:
	used_count += 1


# 重置使用次数（回合开始/结束时调用）
func reset_use_count() -> void:
	used_count = 0