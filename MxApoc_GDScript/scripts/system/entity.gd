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

## 造成 num 点伤害。source=null 时为无来源伤害(跳过 source 侧钩子)。
## 8 节点钩子链见 GameSystem/DamageFlow.md。
func damage(num: int, source: Variant = null, type: String = "") -> void:
	if num <= 0:
		return
	if get_hp() <= 0:
		return

	var event := Event.new()
	event.target = self
	event.source = source
	event.num = num
	event.type = type

	if source != null:
		source.trigger("造成伤害前", event)
		trigger("受到伤害前", event)
	else:
		trigger("受到伤害前", event)

	if source != null:
		source.trigger("造成伤害时", event)
	trigger("受到伤害时", event)

	if event.cancelled:
		return

	reduce_hp(event.num)

	if source != null:
		source.trigger("造成伤害后", event)
	trigger("受到伤害后", event)

	if get_hp() <= 0:
		_on_death(source)


## 当前生命值。子类必须重写。
func get_hp() -> int:
	return 0

## 直接扣血 n 点(节点 5 非钩子)。子类必须重写。
func reduce_hp(n: int) -> void:
	pass

## 是否为玩家。子类重写。
func is_player() -> bool:
	return false

## 是否为怪物。子类重写。
func is_monster() -> bool:
	return false

func _run_filter(s: Skill, event: Event) -> bool:
	if s.filter.is_valid():
		return bool(s.filter.call(event))
	return true

func _run_content(s: Skill, event: Event) -> void:
	if s.content.is_valid():
		s.content.call(event)

## 死亡流程入口。子类重写为 playerDeath/monsterDeath。
## 本轮 stub:空实现 + 日志。
func _on_death(source: Variant) -> void:
	push_warning("Entity._on_death called, but no override. source=%s" % str(source))
