class_name EffectNodes
extends RefCounted

## 效果节点容器

class BranchByTrigger extends Effect:
	var branch_map: Dictionary = {}
	func _init(p_branches: Dictionary) -> void:
		branch_map = p_branches
	func execute(context: EffectContext) -> void:
		var trig = context.trigger_name
		if branch_map.has(trig):
			var effects: Array = branch_map[trig]
			for eff in effects:
				eff.execute(context)

class Branch extends Effect:
	var condition: EffectCondition
	var true_effects: Array[Effect] = []
	var false_effects: Array[Effect] = []
	func _init(p_cond: EffectCondition, p_true: Array[Effect] = [], p_false: Array[Effect] = []) -> void:
		condition = p_cond
		true_effects = p_true
		false_effects = p_false
	func execute(context: EffectContext) -> void:
		var pass_check = true
		if condition != null:
			pass_check = condition.is_satisfied(context)
		if pass_check:
			for eff in true_effects: eff.execute(context)
		else:
			for eff in false_effects: eff.execute(context)

class DrawScavenge extends Effect:
	var count: int = 1
	var use_block_color: bool = true
	func _init(p_c: int = 1, p_u: bool = true) -> void: count = p_c; use_block_color = p_u
	func execute(_context: EffectContext) -> void: print("执行 Effect: 拾荒抽牌 ", count)

class DrawMonster extends Effect:
	var count: int = 1
	var target_player: String = ""
	func _init(p_c: int = 1, p_t: String = "") -> void: count = p_c; target_player = p_t
	func execute(_context: EffectContext) -> void: print("执行 Effect: 抽怪物牌 ", count)

class DrawCard extends Effect:
	var count: int = 1
	func _init(p_c: int = 1) -> void: count = p_c
	func execute(_context: EffectContext) -> void: print("执行 Effect: 抽基础牌 ", count)

class AddStatusMark extends Effect:
	var mark_name: String = ""
	var amount: int = 1
	var duration: String = ""
	func _init(p_m: String, p_a: int = 1, p_d: String = "") -> void: mark_name = p_m; amount = p_a; duration = p_d
	func execute(_context: EffectContext) -> void: print("执行 Effect: 增加状态标记 ", mark_name)

class CancelEvent extends Effect:
	func execute(_context: EffectContext) -> void: print("执行 Effect: 取消事件")

class ConsumeAction extends Effect:
	var amount: int = 1
	func _init(p_a: int = 1) -> void: amount = p_a
	func execute(_context: EffectContext) -> void: print("执行 Effect: 消耗行动点 ", amount)

class MoveToTarget extends Effect:
	func execute(_context: EffectContext) -> void: print("执行 Effect: 移动至目标")

class Heal extends Effect:
	var amount: int = 1
	func _init(p_a: int = 1) -> void: amount = p_a
	func execute(_context: EffectContext) -> void: print("执行 Effect: 治疗 ", amount)

class Damage extends Effect:
	var amount: int = 1
	func _init(p_a: int = 1) -> void: amount = p_a
	func execute(_context: EffectContext) -> void: print("执行 Effect: 造成伤害 ", amount)

class ChangeHunger extends Effect:
	var amount: int = 1
	func _init(p_a: int = 1) -> void: amount = p_a
	func execute(_context: EffectContext) -> void: print("执行 Effect: 改变饥饿值 ", amount)

class ChooseToDiscard extends Effect:
	var count: int = 1
	func _init(p_c: int = 1) -> void: count = p_c
	func execute(_context: EffectContext) -> void: print("执行 Effect: 选择弃牌 ", count)

class AddMonsterMarkAdjacent extends Effect:
	var amount: int = 1
	var include_diagonals: bool = false
	
	func _init(p_amount: int = 1, p_include_diagonals: bool = false) -> void:
		amount = p_amount
		include_diagonals = p_include_diagonals
		
	func execute(context: EffectContext) -> void:
		# TODO: 在此处编写给相邻地块增加怪物标记的逻辑
		pass