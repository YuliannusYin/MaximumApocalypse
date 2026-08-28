class_name MonsterCard
extends Card

## 怪物卡。
## 怪物牌堆中的卡。进入玩家怪物区时实体化为 Monster 实例。
## 设计文档：GameDesignDocus/GameSystem/Entities/Card.md#MonsterCard

## 怪物类型："alien"（外星人）/ "mutant"（突变体）/ "zombie"（僵尸）/ "robot"（机器人）
var monster_type: String = ""

## 怪物级别："boss"（首领）/ "elite"（精英）/ "normal"（普通）
var monster_level: String = "normal"

## 最大生命值
var max_hp: int = 0

## 攻击伤害值
var damage_value: int = 0

## 射程："none" / "short" / "medium" / "long" / "infinity"
var range: String = "none"

## 是否首领卡（任务特殊设置中洗入怪物牌堆）
var is_boss: bool = false


## 实体化：复制卡面数据到 Monster 实例。
## 由 Player.draw_monster 节点 2d 调用。
func instantiate(player: Player = null) -> Monster:
	var monster: Monster = Monster.new()
	monster.monster_name = card_name
	monster.monster_type = monster_type
	monster.english_name = english_name
	monster.monster_level = monster_level
	monster.max_hp = max_hp
	monster.hp = max_hp
	monster.damage_value = damage_value
	monster.range = range
	monster.attack_target = player
	monster.monster_card = self
	for s in skills:
		monster.add_skill(s)
	return monster
