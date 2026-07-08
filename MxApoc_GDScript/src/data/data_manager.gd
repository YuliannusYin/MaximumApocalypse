extends Node

## DataManager 数据管理器（autoload）。
## 阶段 1：作为现有 data/*.gd 硬编码数据的适配器，提供统一查询接口。
## 阶段 1 后期（P1 数据层迁移）：替换为从 JSON 加载，详见 AGENTS.md §五.3。


func _ready() -> void:
	pass


## 获取求生者数据。
func get_survivor(id: String) -> Resource:
	var survivor: Resource = Survivors.get_by_id(id)
	if survivor == null:
		push_error("DataManager: survivor not found: " + id)
		return null
	return survivor


## 获取所有求生者数据。
func get_all_survivors() -> Array:
	return Survivors.get_all()


## 获取任务数据。
func get_mission(id: int) -> Resource:
	var mission: Resource = Missions.get_by_id(id)
	if mission == null:
		push_error("DataManager: mission not found: " + str(id))
	return mission


## 获取所有任务数据。
func get_all_missions() -> Array:
	return Missions.get_all()


## 获取变体数据。
func get_variant(id: String) -> Resource:
	return Variants.get_by_id(id)


## 获取所有变体数据。
func get_all_variants() -> Array:
	return Variants.get_all()


## 检查求生者是否存在。
func has_survivor(id: String) -> bool:
	return Survivors.get_by_id(id) != null


## 检查任务是否存在。
func has_mission(id: int) -> bool:
	return Missions.get_by_id(id) != null


## 获取怪物卡定义（stub，需 MonsterPacks 数据加载后完整实现）。
func get_monster_card(id: String) -> Resource:
	print("DataManager.get_monster_card stub: " + id)
	return null


## 获取拾荒卡定义（stub，需 ScavengePacks 数据加载后完整实现）。
func get_scavenge_card(id: String) -> Resource:
	print("DataManager.get_scavenge_card stub: " + id)
	return null


## 获取地图块定义（stub，需 MapBlocksPack 数据加载后完整实现）。
func get_map_block_def(id: String) -> Resource:
	print("DataManager.get_map_block_def stub: " + id)
	return null


## 获取任务包（stub，需 MissionPacks 数据加载后完整实现）。
func get_mission_pack(id: int) -> Resource:
	print("DataManager.get_mission_pack stub: " + str(id))
	return null
