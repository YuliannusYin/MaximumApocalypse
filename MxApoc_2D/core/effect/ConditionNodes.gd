class_name ConditionNodes
extends RefCounted

## 条件校验节点容器

class And extends EffectCondition:
	var conditions: Array[EffectCondition] = []
	func _init(p_conditions: Array[EffectCondition] = []) -> void:
		conditions = p_conditions
	func is_satisfied(context: EffectContext) -> bool:
		for cond in conditions:
			if not cond.is_satisfied(context):
				return false
		return true

class Not extends EffectCondition:
	var condition: EffectCondition
	func _init(p_condition: EffectCondition) -> void:
		condition = p_condition
	func is_satisfied(context: EffectContext) -> bool:
		if condition == null:
			return true
		return not condition.is_satisfied(context)

class HasStatusMark extends EffectCondition:
	var mark_name: String = ""
	func _init(p_mark: String) -> void:
		mark_name = p_mark
	func is_satisfied(_context: EffectContext) -> bool:
		return false

class InPhase extends EffectCondition:
	var phase_name: String = ""
	func _init(p_phase: String) -> void:
		phase_name = p_phase
	func is_satisfied(context: EffectContext) -> bool:
		return context.extra_data.get("current_phase", "") == phase_name

class HasActionPoints extends EffectCondition:
	var min_amount: int = 1
	func _init(p_min: int = 1) -> void: min_amount = p_min
	func is_satisfied(_context: EffectContext) -> bool: return true

class HasCardType extends EffectCondition:
	var card_type: String = ""
	func _init(p_type: String) -> void: card_type = p_type
	func is_satisfied(_context: EffectContext) -> bool: return true

class BlockHasNoMonsters extends EffectCondition:
	func is_satisfied(_context: EffectContext) -> bool: return true

class IsRevealed extends EffectCondition:
	func is_satisfied(context: EffectContext) -> bool:
		if context.source is MapBlock:
			return context.source.is_revealed
		return false

class NotSelfBlock extends EffectCondition:
	func is_satisfied(_context: EffectContext) -> bool: return true

class HasSkill extends EffectCondition:
	var target_skill_name: String
	
	func _init(p_skill_name: String) -> void:
		target_skill_name = p_skill_name
		
	func check(context: EffectContext) -> bool:
		if context.source and context.source.has_method("has_skill"):
			return context.source.has_skill(target_skill_name)
		return false