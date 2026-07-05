class_name Entity
extends RefCounted

## 该实体上所有技能(含角色固有、装备、临时、地块等)。子类可重写 get_all_skills 聚合多来源。
var _skills: Array[Skill] = []

## 返回所有技能。子类可重写以聚合多来源(角色+装备+地块)。
func get_all_skills() -> Array[Skill]:
	return _skills

## 添加技能。
func add_skill(s: Skill) -> void:
	_skills.append(s)

## 移除技能。
func remove_skill(s: Skill) -> void:
	_skills.erase(s)

## 遍历技能,依次触发匹配 trigger_name 的。规则见 GameSystem/EventTrigger.md。
func trigger(trigger_name: String, event: Event) -> void:
	event.trigger_name = trigger_name
	for s in get_all_skills():
		var trigger_list := s.trigger.split("、")
		if trigger_list.has(trigger_name) and _run_filter(s, event):
			_run_content(s, event)
			if event.cancelled:
				break

func _run_filter(s: Skill, event: Event) -> bool:
	if s.filter.is_valid():
		return bool(s.filter.call(event))
	return true

func _run_content(s: Skill, event: Event) -> void:
	if s.content.is_valid():
		s.content.call(event)
