class_name SurvivorGameCard
extends Card

## 求生者游戏牌。
## 玩家游戏牌堆中的牌。分为行动牌与装备牌两种。
## 设计文档：GameDesignDocus/GameSystem/Entities/Card.md#SurvivorGameCard

## 卡牌子类型："action"（行动牌）/ "equipment"（装备牌）
var card_subtype: String = ""

## 占用装备栏的格数（仅装备牌）
var size: int = 0

## 射程："none" / "short" / "medium" / "long" / "infinity"
var range: String = "none"
