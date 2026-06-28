# MonsterData.gd
# 怪物数据资源类 - 用于定义怪物卡牌的基础属性和能力

class_name MonsterData
extends Resource

## 怪物唯一标识符 (例如: zombie_grunt, alien_elite)
@export var id: String 

## 怪物显示名称 (用于UI渲染)
@export var monster_name: String 

## 怪物所属卡包类型 (限定为四种怪物包: ALIEN异形、MUTANT变种人、ROBOT机器人、ZOMBIE僵尸)
@export var pack: Enums.MonsterPack

## 怪物等级 (NORMAL普通怪、ELITE精英怪、BOSS首领怪)
@export var rank: Enums.MonsterLevel

## 怪物生命值上限
@export var max_hp: int 

## 怪物当前生命值
@export var current_hp: int 

## 怪物攻击伤害值
@export var damage: int 

## 怪物攻击射程类型 (使用枚举: NONE无射程、SHORT短距离、MEDIUM中距离、LONG长距离)
@export var range_type: Enums.RangeType

## 怪物文本描述 (支持多行输入，供UI展示)
@export_multiline var description: String 

## 怪物抓取触发时机脚本ID (供RuleEngine/EffectManager匹配执行具体逻辑)
@export var Grab_trigger_id: String 

## 怪物被动/攻击能力脚本ID (供RuleEngine/EffectManager匹配执行具体逻辑)
@export var Passive_id: String 

## 怪物死亡能力脚本ID (供RuleEngine/EffectManager匹配执行具体逻辑)
@export var Destroy_id: String 

## 该怪物卡牌在牌库中的数量 (默认为1)
@export var count: int = 1 
