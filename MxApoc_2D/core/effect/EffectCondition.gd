# EffectCondition.gd
class_name EffectCondition
extends RefCounted

## 条件校验节点的抽象基类

## 校验当前上下文是否满足条件
## @return: true 表示通过校验，false 表示未通过
func is_satisfied(context: EffectContext) -> bool:
	return true

class AddMonsterMarkAdjacent extends Effect:
	var amount: int = 1
	var include_diagonals: bool = false
	
	func _init(p_amount: int = 1, p_include_diagonals: bool = false) -> void:
		amount = p_amount
		include_diagonals = p_include_diagonals
		
	func execute(context: EffectContext) -> void:
		# 这里实现向相邻地块添加怪物标记的逻辑
		pass