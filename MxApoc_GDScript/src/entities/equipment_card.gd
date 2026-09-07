class_name EquipmentCard
extends SurvivorGameCard

## 装备牌。
## 装备到装备区的卡牌。占用装备栏格数（由 size 决定）。
## 装备牌进入装备区时其技能挂载到 Player 身上；离开装备区时移除。
## 设计文档：GameDesignDocus/GameSystem/Entities/Card.md#EquipmentCard

## 填充物类型："ammo"（弹药）/ "fuel"（燃料）/ "hollow_point"（空尖弹）等
## 运行时可能被改写（如空尖弹）；卡面印刷类型见 charge_type_printed。
var charge_type_printed: String = ""
var _charge_type: String = ""
var charge_type: String:
	get:
		return _charge_type
	set(value):
		if charge_type_printed.is_empty() and not value.is_empty():
			charge_type_printed = value
		_charge_type = value

## 填充物上限
var charge_max: int = 0

## 当前填充物数量。耗尽时触发「填充物耗尽时」trigger
var charge_current: int = 0

## 装备区标记：是否在玩家装备区内
var in_equipment_area: bool = false

## 是否为武器牌（会造成伤害的装备）。由 JSON `weapon` 字段声明，缺省 false。
var weapon: bool = false


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


## 添加指定类型的填充物。
## 当 type 匹配 charge_type（或 charge_type 为空时接受任意类型）时，
## 将 charge_current 增加 amount，但不超过 charge_max。
## type 不匹配则什么都不做（用于弹药/燃料等 content 代码按类型补充）。
func add_charge(amount: int, type: String) -> void:
	if charge_type != "" and charge_type != type:
		return
	charge_current = mini(charge_current + amount, charge_max)


## 将填充物填满到上限。
func fill_charge() -> void:
	charge_current = charge_max


## 修改填充物类型。
func change_charge_type(type: String) -> void:
	charge_type = type


## 是否为武器牌（用于 damage 流程的 card 参数判断与升级目标过滤）。
func is_weapon_card() -> bool:
	return weapon


## 实体化：复制卡面数据到 Equipment 实例，并把来源卡重置为全新填充物状态。
## 由 Player.equip 调用。装备区持有实体，来源卡通过 equipment_card 回引。
func instantiate(player: Player = null) -> Equipment:
	_reset_fresh_charge_state()
	var eq: Equipment = Equipment.new()
	eq.equipment_name = card_name
	eq.card_name = card_name
	eq.english_name = english_name
	eq.card_type = card_type
	eq.card_subtype = card_subtype
	eq.source = source
	eq.size = size
	eq.range = range
	eq.charge_type = charge_type
	eq.charge_max = charge_max
	eq.weapon = weapon
	eq.in_equipment_area = true
	eq.equipment_card = self
	eq.equipped_player = player
	for s in skills:
		eq.add_skill(s)
	return eq


## 进入装备区时恢复卡面状态：填充物类型还原为印刷类型，数量补满到上限。
func _reset_fresh_charge_state() -> void:
	if not charge_type_printed.is_empty():
		_charge_type = charge_type_printed
	charge_current = charge_max
