class_name ScavengeCard
extends Card

## 拾荒卡。
## 从拾荒牌堆获取的牌。使用后进入拾荒弃牌堆（非游戏牌弃牌堆）。
## 设计文档：GameDesignDocus/GameSystem/Entities/Card.md#ScavengeCard

## 颜色：red / green / blue / gray。红色最危险（含伏击！），蓝色最安全
var color: String = ""

## 拾荒卡子类型："equipment"（装备）/ "consumable"（消耗品）/ "ambush"（伏击）
var scavenge_type: String = ""
