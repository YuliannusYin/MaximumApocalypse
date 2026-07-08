class_name RoleCard
extends RefCounted

## 角色卡类。
## 表示玩家角色的正反面状态。RoleCard 不继承 Entity（无技能、无 trigger），是状态标记。
## 饥饿值达 6 后翻面，减少饥饿值后恢复正面。
## 设计文档：GameDesignDocus/GameSystem/Common/RoleCard.md

## 正反面状态：true = 正面，false = 反面（饥饿状态）
var is_front_side: bool = true

## 角色名称（如"猎人"、"消防员"）
var role_name: String = ""

## 生命值上限
var max_hp: int = 0

## 初始生命值
var initial_hp: int = 0

## 正面潜行值
var sneak: int = 0

## 反面（饥饿状态）潜行值
var hunger_sneak: int = 0

## 装备栏格数上限
var equipment_capacity: int = 5

## 角色固有技能（开局即拥有，非卡牌）
var intrinsic_skills: Array[Skill] = []


## 翻面角色卡（正面 ↔ 反面）。
## 触发场景：饥饿值达到 6 时翻面；减少饥饿值后恢复正面。
func flip() -> void:
	is_front_side = not is_front_side


## 判断角色卡是否正面朝上。
func is_front() -> bool:
	return is_front_side


## 获取当前潜行值（根据正反面返回对应值）。
func get_sneak() -> int:
	if is_front_side:
		return sneak
	return hunger_sneak
