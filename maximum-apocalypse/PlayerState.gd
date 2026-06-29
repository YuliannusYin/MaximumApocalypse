# PlayerState.gd
class_name PlayerState
extends RefCounted

var id: String
var character_name: String
var max_hp: int
var current_hp: int

# 饥饿系统
var hunger_level: int = 1            # 1-5正常，6+饥饿
var is_starving: bool = false
var starving_damage_stage: int = 0   # 0:未受伤害, 1:2点, 2:4点...

# 坐标
var position: Vector2i = Vector2i.ZERO # Godot 的网格坐标直接用 Vector2i

# 属性与行动力
var base_stealth: int = 7
var starving_stealth: int = 6
var action_points: int = 40

# 状态效果
var poison_tokens: int = 0
var is_stunned: bool = false

# 玩家牌组 (存放 CardRuntime 实例)
var hand: Array[CardRuntime] = []
var equipment_zone: Array[CardRuntime] = []
var deck: Array[CardRuntime] = []
var discard_pile: Array[CardRuntime] = []
var monster_zone: Array[CardRuntime] = []  # 纠缠玩家的怪物

# 装备栏槽位
var base_equipment_slots: int = 4  # 基础4格装备栏