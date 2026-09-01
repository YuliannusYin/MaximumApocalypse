class_name Equipment
extends Entity

## 装备实体类。
## 装备牌进入玩家装备区时由 EquipmentCard.instantiate(player) 实体化为本类实例。
## 镜像 Monster 的实体化模式：装备区持有实体，弃牌堆/EventBus/钩子收到的永远是来源 EquipmentCard。
## 设计文档：GameDesignDocus/GameSystem/Entities/Equipment.md

## 装备名（来自 EquipmentCard.card_name）
var equipment_name: String = ""

## 卡牌名（= equipment_name，兼容下游按 card_name 查询）
var card_name: String = ""

## 英文名
var english_name: String = ""

## 卡牌类型（= "equipment"）
var card_type: String = "equipment"

## 卡牌子类型（"equipment" / "action"）
var card_subtype: String = ""

## 卡牌来源："scavenge" / "game"
var source: String = ""

## 占用装备栏格数
var size: int = 0

## 射程："none" / "short" / "medium" / "long" / "infinity"
var range: String = "none"

## 填充物类型："ammo" / "fuel" / "hollow_point" 等
var charge_type: String = ""

## 填充物上限
var charge_max: int = 0

## 装备区标记：实体在装备区时为 true
var in_equipment_area: bool = false

## 来源装备卡回引（弃置/回收时入弃牌堆用）
var equipment_card: EquipmentCard = null

## 当前填充物数量。委托给 equipment_card.charge_current。
## 进入装备区时由 EquipmentCard.instantiate 把来源卡重置为满填充 + 印刷类型。
var charge_current: int:
	get:
		return equipment_card.charge_current if equipment_card != null else 0
	set(value):
		if equipment_card != null:
			equipment_card.charge_current = value


# === 类型判断 ===

## 是否为装备实体。
func is_equipment() -> bool:
	return true


# === 填充物接口（委托给 equipment_card） ===

## 返回当前填充物数量。
func get_charge() -> int:
	if equipment_card != null:
		return equipment_card.get_charge()
	return 0


## 是否有至少 1 个填充物。
func has_charge() -> bool:
	if equipment_card != null:
		return equipment_card.has_charge()
	return false


## 消耗 n 个填充物。成功返回 true，不足返回 false。
func consume_charge(n: int) -> bool:
	if equipment_card != null:
		return equipment_card.consume_charge(n)
	return false


## 添加指定类型的填充物（不超过上限）。
func add_charge(amount: int, type: String) -> void:
	if equipment_card != null:
		equipment_card.add_charge(amount, type)


## 将填充物填满到上限。
func fill_charge() -> void:
	if equipment_card != null:
		equipment_card.fill_charge()


## 补充填充物（不超过上限）。
func refill(n: int) -> void:
	if equipment_card != null:
		equipment_card.refill(n)


## 修改填充物类型。
func change_charge_type(type: String) -> void:
	charge_type = type
	if equipment_card != null:
		equipment_card.change_charge_type(type)


## 是否为武器牌（用于 damage 流程的 card 参数判断）。
func is_weapon_card() -> bool:
	if equipment_card != null:
		return equipment_card.is_weapon_card()
	return false
