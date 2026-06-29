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

## 牌库中该卡牌的数量（根据角色卡包文档配置）
@export var deck_quantity: int = 1

## 武器最大弹药量（0=被动装备，-1=无弹药武器（近战/弓），>0=弹药武器每次攻击消耗1弹药）
@export var max_ammo: int = 0
