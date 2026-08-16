class_name ScavengeCard
extends EquipmentCard

## 拾荒卡。
## 从拾荒牌堆获取的牌。使用后进入拾荒弃牌堆（非游戏牌弃牌堆）。
## 继承 EquipmentCard 以便拾荒包中的装备卡（手枪/防弹背心/背包等）具备
## charge_type/charge_max/charge_current/in_equipment_area 字段及
## consume_charge/refill/fill_charge/add_charge 等方法，同时通过
## `card is EquipmentCard` 类型守卫。非装备类拾荒卡的 charge 字段保持默认 0/空。
## 设计文档：GameDesignDocus/GameSystem/Entities/Card.md#ScavengeCard

## 颜色：red / green / blue / gray。红色最危险（含伏击！），蓝色最安全
var color: String = ""

## 拾荒卡子类型："equipment"（装备）/ "consumable"（消耗品）/ "ambush"（伏击）
var scavenge_type: String = ""


# === 1. 查询方法 ===

## 返回拾荒卡颜色（"red"/"green"/"blue"/"gray"）。
func get_color() -> String:
	return color
