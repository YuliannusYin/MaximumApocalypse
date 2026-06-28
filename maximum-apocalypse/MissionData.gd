# #============================================================================
# # 📄 MissionData.gd
# #============================================================================

class_name MissionData
extends Resource

# --- 1. 任务基本信息 ---

## 任务唯一标识符 (例如: mission_00_tutorial, mission_05_hell)
@export var id: String 

## 任务显示名称 (用于UI和剧本选关界面渲染)
@export var mission_name: String 

## 任务难度评级 (特别简单、简单、普通、困难、地狱)
@export_enum("特别简单", "简单", "普通", "困难", "地狱") var difficulty: String

## 任务背景介绍/风味文本 (支持多行输入，供UI战前展示)
@export_multiline var description: String 

## 任务核心目标说明 (用于局内悬顶UI的目标提醒显示)
@export_multiline var objective_text: String 

## 任务怪物包类型 (zombie, mutant, alien, robot)
@export var monster_type: Enums.MonsterPack


# --- 2. 局内核心通关条件 ---

## 启动面包车或达成胜利所需的燃料数量 (如果没有相关要求则不处理)
@export var required_van_fuel: int 


# --- 3. 地图网格发牌配置 ---

## 局内玩家的初始起始地块 ID (例如: shopping_center, van)
@export var starting_tile_id: String 

## 任务初始设置的特殊规则说明 (文本提示，例如玩家初始携带的额外物资)
@export_multiline var initial_setup_rule: String 

## 剧本地块清单字典
## 键(Key) 为地块 ID 字符串，值(Value) 为该地块在发牌池中需要的数量(int)
## 示例: {"shopping_center": 1, "wilderness": 1, "gas_station": 2}
@export var tile_manifest: Dictionary


# --- 4. 剧本专属：拾荒牌堆动态配比配置 ---
# 键(Key) 为卡牌的专属 ID (对应 ScavengeCardData 的 id)，值(Value) 为加入该牌堆的数量(int)。

## 红色补给牌堆独立裁剪配比 (示例: {"food": 2, "fuel": 4})
@export var red_scavenge_pool: Dictionary

## 绿色食物牌堆独立裁剪配比 (示例: {"food": 6, "fuel": 2})
@export var green_scavenge_pool: Dictionary

## 蓝色战备牌堆独立裁剪配比 (示例: {"ammo": 3, "pistol": 1})
@export var blue_scavenge_pool: Dictionary


# --- 5. 特殊机制扩展 ---

## 任务地图的额外特殊生成要求 (例如：特定地块必须相邻，或者某些地块初始翻开)
@export_multiline var special_map_requirements: String