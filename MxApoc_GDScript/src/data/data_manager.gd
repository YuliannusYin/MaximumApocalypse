extends Node

## DataManager 数据管理器（autoload）。
## 从 data/ 下的 JSON 文件加载所有静态数据，提供统一查询接口。
## 数据类为 RefCounted 子类（非 Resource），通过 _init(data: Dictionary) 解析 JSON。
## 字段规范见 GameDesignDocus/Engineering/DataFormat.md。


var _survivors: Dictionary = {}        # english_name -> SurvivorData
var _variants: Dictionary = {}         # id -> VariantData
var _scavenge_piles: Dictionary = {}   # color -> Array[ScavengeCardData]
var _monster_packs: Dictionary = {}    # monster_type -> Array[MonsterCardData]
var _missions: Dictionary = {}         # mission_id (int) -> MissionData
var _map_blocks: Dictionary = {}       # english_name -> MapBlockData
var _map_blocks_by_name: Dictionary = {}  # block_name (Chinese) -> MapBlockData
var _common_skills: Array = []         # Array[SkillData]


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	_load_survivors()
	_load_variants()
	_load_scavenge_piles()
	_load_monster_packs()
	_load_missions()
	_load_map_blocks()
	_load_common_skills()


func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataManager: failed to open JSON: " + path)
		return null
	var text := file.get_as_text()
	file.close()
	var result: Variant = JSON.parse_string(text)
	if result == null:
		push_error("DataManager: failed to parse JSON: " + path)
	return result


func _load_survivors() -> void:
	_load_dir("res://data/survivors/", _add_survivor)


func _add_survivor(data: Variant) -> void:
	if not (data is Dictionary):
		return
	var survivor := SurvivorData.new(data)
	_survivors[survivor.english_name] = survivor


func _load_variants() -> void:
	_load_dir("res://data/variants/", _add_variant)


func _add_variant(data: Variant) -> void:
	if not (data is Dictionary):
		return
	var variant := VariantData.new(data)
	_variants[variant.id] = variant


func _load_scavenge_piles() -> void:
	_load_dir("res://data/scavenge/", _add_scavenge_pile)


func _add_scavenge_pile(data: Variant) -> void:
	if not (data is Dictionary):
		return
	var dict: Dictionary = data
	var color: String = dict.get("color", "")
	if color == "":
		push_error("DataManager: scavenge pile missing 'color' field")
		return
	var cards: Array = []
	for raw in dict.get("cards", []):
		if raw is Dictionary:
			cards.append(ScavengeCardData.new(raw))
	_scavenge_piles[color] = cards


func _load_monster_packs() -> void:
	_load_dir("res://data/monsters/", _add_monster_pack)


func _add_monster_pack(data: Variant) -> void:
	if not (data is Dictionary):
		return
	var dict: Dictionary = data
	var monster_type: String = dict.get("monster_type", "")
	if monster_type == "":
		push_error("DataManager: monster pack missing 'monster_type' field")
		return
	var monsters: Array = []
	for raw in dict.get("cards", []):
		if raw is Dictionary:
			monsters.append(MonsterCardData.new(raw))
	_monster_packs[monster_type] = monsters


func _load_missions() -> void:
	_load_dir("res://data/missions/", _add_mission)


func _add_mission(data: Variant) -> void:
	if not (data is Dictionary):
		return
	var mission := MissionData.new(data)
	_missions[mission.mission_id] = mission


func _load_map_blocks() -> void:
	var data: Variant = _load_json("res://data/map_blocks/map_blocks.json")
	if data == null or not (data is Dictionary):
		return
	var dict: Dictionary = data
	for raw in dict.get("blocks", []):
		if raw is Dictionary:
			var block := MapBlockData.new(raw)
			_map_blocks[block.english_name] = block
			_map_blocks_by_name[block.block_name] = block


func _load_common_skills() -> void:
	var data: Variant = _load_json("res://data/common_skills.json")
	if data == null or not (data is Array):
		push_error("DataManager: failed to load common_skills.json")
		return
	for raw in data:
		if raw is Dictionary:
			_common_skills.append(SkillData.new(raw))


func _load_dir(dir_path: String, callback: Callable) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("DataManager: failed to open directory: " + dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var data: Variant = _load_json(dir_path + file_name)
			if data != null:
				callback.call(data)
		file_name = dir.get_next()
	dir.list_dir_end()


# === 查询接口 ===

## 获取求生者数据。
func get_survivor(english_name: String) -> SurvivorData:
	if not _survivors.has(english_name):
		push_error("DataManager: survivor not found: " + english_name)
		return null
	return _survivors[english_name]


## 获取所有求生者数据。
func get_all_survivors() -> Array:
	return _survivors.values()


## 检查求生者是否存在。
func has_survivor(english_name: String) -> bool:
	return _survivors.has(english_name)


## 获取变体数据。
func get_variant(id: String) -> VariantData:
	return _variants.get(id)


## 获取所有变体数据。
func get_all_variants() -> Array:
	return _variants.values()


## 获取任务数据。
func get_mission(mission_id: int) -> MissionData:
	if not _missions.has(mission_id):
		push_error("DataManager: mission not found: " + str(mission_id))
		return null
	return _missions[mission_id]


## 获取所有任务数据（按 mission_id 排序）。
func get_all_missions() -> Array:
	var result: Array = _missions.values()
	result.sort_custom(func(a, b): return a.mission_id < b.mission_id)
	return result


## 检查任务是否存在。
func has_mission(mission_id: int) -> bool:
	return _missions.has(mission_id)


## 获取拾荒牌堆（按颜色）。
func get_scavenge_pile(color: String) -> Array:
	return _scavenge_piles.get(color, [])


## 获取怪物包（按怪物类型）。
func get_monster_pack(monster_type: String) -> Array:
	return _monster_packs.get(monster_type, [])


## 获取地图块定义。
func get_map_block_def(english_name: String) -> MapBlockData:
	return _map_blocks.get(english_name)


## 按中文名获取地图块定义。
func get_map_block_def_by_name(block_name: String) -> MapBlockData:
	return _map_blocks_by_name.get(block_name)


## 获取通用主动技能数据。
func get_common_skills() -> Array:
	return _common_skills
