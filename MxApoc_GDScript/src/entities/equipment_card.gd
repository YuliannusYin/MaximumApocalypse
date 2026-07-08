class_name EquipmentCard
extends SurvivorGameCard

## 装备牌。
## 装备到装备区的卡牌。占用装备栏格数（由 size 决定）。
## 装备牌进入装备区时其技能挂载到 Player 身上；离开装备区时移除。
## 设计文档：GameDesignDocus/GameSystem/Entities/Card.md#EquipmentCard

## 填充物类型："ammo"（弹药）/ "fuel"（燃料）/ "hollow_point"（空尖弹）等
var charge_type: String = ""

## 填充物上限
var charge_max: int = 0

## 当前填充物数量。耗尽时触发「填充物耗尽时」trigger
var charge_current: int = 0


## 消耗 n 个填充物。成功返回 true，不足返回 false。
func consume_charge(n: int) -> bool:
	if charge_current < n:
		return false
	charge_current -= n
	return true


## 是否有至少 1 个填充物。
func has_charge() -> bool:
	return charge_current > 0


## 返回当前填充物数量。
func get_charge() -> int:
	return charge_current


## 补充填充物（不超过上限）。
func refill(n: int) -> void:
	charge_current = mini(charge_current + n, charge_max)


## 是否为武器牌（用于 damage 流程的 card 参数判断）。
func is_weapon_card() -> bool:
	return range != "none" and card_subtype == "equipment"
