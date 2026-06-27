# ==========================================
#  CharacterCardData.gd
# ==========================================
class_name CharacterCardData
extends Resource


## 专属卡牌唯一标识符
@export var id: String 

## 卡牌显示名称
@export var card_name: String 

## 核心绑定：属于哪个角色的专属卡
@export var owner_character_id: String 

## 卡牌纯文本效果描述（支持在编辑器里换行输入，供 UI 渲染展示）
@export_multiline var description: String 

## 核心：供局内 RuleEngine/EffectManager 匹配执行具体代码逻辑的 ID
@export var effect_script_id: String 

## 卡牌类型
@export var card_type: Enums.CharacterCard

## 装备槽位占用
@export var equipment_cost: int

## 射程类型
@export var range_type: Enums.RangeType

@export var action_condition: String


