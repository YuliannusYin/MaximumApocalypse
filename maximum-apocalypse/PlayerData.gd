# PlayerData.gd
class_name PlayerData
extends Resource

# 基础属性
@export var id: String
@export var character_name: String
@export var max_hp: int
@export var current_hp: int

# 饥饿系统相关属性
@export var hunger_level: int
@export var is_starving: bool  #  修复：boolean 改为 bool
@export var starving_damage_stage: int

# 位置与属性
@export var position: Vector2i = Vector2i.ZERO
@export var base_stealth: int 
@export var starving_stealth: int 
@export var action_points: int 

# 状态效果
@export var poison_tokens: int 
@export var is_stunned: bool 

#  局内动态运行时数据
#  修复：去掉 @export。因为 CardRuntime 在局内是动态生成的，不需要在 .tres 文件里预先手动填写。
var hand: Array[CardRuntime] = []
var equipment_zone: Array[CardRuntime] = []
var deck: Array[CardRuntime] = []
var discard_pile: Array[CardRuntime] = []
