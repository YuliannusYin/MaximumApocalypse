
#  ScavengeCardData.gd

class_name ScavengeCardData
extends Resource

## 拾荒卡唯一标识符 (例如: ammo_small, food_box)
@export var id: String 

## 拾荒卡名称 (用于界面文字渲染)
@export var card_name: String 

## 拾荒卡大类 (例如: 战备、食物、补给、特殊)
@export var category: String

## 拾荒卡颜色堆映射 (必须严格使用 Enums 里的拾荒颜色)
## 对应：0:NONE, 1:GRAY(灰色), 2:GREEN(绿色), 3:BLUE(蓝色), 4:RED(红色)
@export var color: Enums.ScavengeCardColor

## 拾荒卡类型 (在 Inspector 中提供下拉菜单限定为“行动牌”或“装备牌”)
@export var card_type: Enums.ScavengeCardType

#装备牌占用槽位
@export var equipment_slot: int

## 拾荒卡文本描述 (支持在检查器里使用多行文本框换行输入)
@export_multiline var effect: String = ""

## 效果脚本ID，用于供局内 RuleEngine/EffectManager 匹配执行具体的代码逻辑
@export var effect_script_id: String 

