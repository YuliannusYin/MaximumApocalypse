extends Node

## ArchiveManager 档案管理器（autoload）。
## 负责跨对局档案（user://archive.json）的加载、内存持有、更新与落盘，
## 以及成就定义（data/achievements.json，声明式条件）的加载与结算求值。
## 档案结构见 .trae/specs/achievement-archive-system/spec.md：
## achievements / survivors / missions / monsters 四大块 + win_total（累计胜利局数）。
## monsters 块以怪物卡 english_name 为键（见 refine-achievement-ui-monster-stats spec）；
## 旧档案的类型级键（monster_type）在加载时直接丢弃，不迁移。
## 可测性：核心逻辑不依赖节点树，测试可直接实例化本脚本并 load_archive(临时路径) 注入。

const DEFAULT_ARCHIVE_PATH := "user://archive.json"
const ACHIEVEMENTS_PATH := "res://data/achievements.json"

## monsters 块的旧格式类型级键（按 monster_type 记录的历史数据）。
## 加载旧档案时直接丢弃（不迁移），避免与 english_name 键语义混淆。
const LEGACY_MONSTER_TYPE_KEYS := ["zombie", "alien", "mutant", "robot"]

## 求生者档案整型字段。前 9 项为 spec 规定的统计字段；
## wins 为成就求值（survivor_wins_all）增补字段，仅胜利结算 +1，最终展示层可不展示。
const SURVIVOR_INT_FIELDS := [
	"total_damage", "best_damage",
	"total_kills", "best_kills",
	"boss_kills",
	"total_healing", "best_healing",
	"total_turns", "best_turns",
	"wins",
]

## 当前档案数据（四大块 + win_total）。
var archive: Dictionary = {}

var _archive_path: String = DEFAULT_ARCHIVE_PATH
var _achievement_definitions: Array = []
var _definitions_loaded: bool = false


func _ready() -> void:
	load_archive(_archive_path)


# === 加载 / 落盘 ===

## 从指定路径加载档案（autoload 默认 user://archive.json；测试可注入临时路径）。
## 文件不存在 → 空档案；JSON 解析失败或非对象 → 损坏文件重命名为
## <文件名>.bak.<时间戳> 后使用空档案；缺失/类型异常字段给防御性默认值。
func load_archive(path: String) -> void:
	_archive_path = path
	archive = _empty_archive()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ArchiveManager: 无法读取档案文件: " + path)
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		_backup_corrupt_file(path)
		return
	archive = _sanitize_archive(parsed)


## 将当前档案以 JSON（缩进 2 空格）写盘。
func save() -> void:
	var file := FileAccess.open(_archive_path, FileAccess.WRITE)
	if file == null:
		push_error("ArchiveManager: 无法写入档案文件: " + _archive_path)
		return
	file.store_string(JSON.stringify(archive, "  "))
	file.close()


func _backup_corrupt_file(path: String) -> void:
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		push_error("ArchiveManager: 无法打开档案目录用于备份: " + path.get_base_dir())
		return
	var file_name := path.get_file()
	# ISO8601 时间串含 ":"，Windows 文件名非法，替换掉
	var timestamp := Time.get_datetime_string_from_system().replace(":", "")
	var backup_name := file_name + ".bak." + timestamp
	var err := dir.rename(file_name, backup_name)
	if err != OK:
		push_error("ArchiveManager: 损坏档案备份失败: " + path)
	else:
		push_warning("ArchiveManager: 档案损坏，已备份为 %s/%s，从空档案开始" % [path.get_base_dir(), backup_name])


func _empty_archive() -> Dictionary:
	return {
		"achievements": {},
		"survivors": {},
		"missions": {},
		"monsters": {},
		"win_total": 0,
	}


## 对加载的档案做防御性修正：缺失/类型异常的块补空容器、已知字段补默认值；
## 未知字段与未知成就 id 原样保留（容忍，不崩溃）；
## monsters 块的旧类型级键（LEGACY_MONSTER_TYPE_KEYS）直接丢弃（不迁移）。
func _sanitize_archive(raw: Dictionary) -> Dictionary:
	var data: Dictionary = raw.duplicate(true)
	for key in ["achievements", "survivors", "missions", "monsters"]:
		if not (data.get(key) is Dictionary):
			data[key] = {}
	data["win_total"] = int(data.get("win_total", 0))

	var survivors: Dictionary = data["survivors"]
	for sid in survivors.keys():
		if not (survivors[sid] is Dictionary):
			survivors[sid] = {}
		var entry: Dictionary = survivors[sid]
		for field in SURVIVOR_INT_FIELDS:
			entry[field] = int(entry.get(field, 0))

	var missions: Dictionary = data["missions"]
	for mid in missions.keys():
		if not (missions[mid] is Dictionary):
			missions[mid] = {}
			continue
		var buckets: Dictionary = missions[mid]
		for pc in buckets.keys():
			if not (buckets[pc] is Dictionary):
				buckets[pc] = {}
			var bucket: Dictionary = buckets[pc]
			bucket["win_count"] = int(bucket.get("win_count", 0))
			bucket["best_time_msec"] = int(bucket.get("best_time_msec", 0))

	var monsters: Dictionary = data["monsters"]
	# 旧格式清理：丢弃按 monster_type 记录的类型级键（不迁移），english_name 级键保留
	for legacy_key in LEGACY_MONSTER_TYPE_KEYS:
		monsters.erase(legacy_key)
	for mid in monsters.keys():
		monsters[mid] = int(monsters.get(mid, 0))

	var achievements: Dictionary = data["achievements"]
	for ach_id in achievements.keys():
		if not (achievements[ach_id] is Dictionary):
			achievements[ach_id] = {}
		var ach_entry: Dictionary = achievements[ach_id]
		ach_entry["first_at"] = str(ach_entry.get("first_at", ""))
		ach_entry["count"] = int(ach_entry.get("count", 0))
	return data


# === 结算归档 ===

## 结算归档入口：按 summary 更新档案并立即落盘，返回本局新达成的成就定义列表
## （Array[Dictionary]，元素含 id/name/description/condition）。
## summary 结构见 StatsTracker.get_archive_summary()：
## {result: "win"/"lose", duration_msec, player_count, mission_id, survivors, monsters}。
## - survivors / monsters：胜负结算均归档；
## - missions / win_total / survivors 的 wins：仅胜利结算更新；
## - achievements：每次结算重新评估全部成就条件。
func record_game_result(summary: Dictionary) -> Array:
	if archive.is_empty():
		archive = _empty_archive()
	var result := str(summary.get("result", ""))
	_update_survivors(summary.get("survivors", {}), result)
	_update_monsters(summary.get("monsters", {}))
	if result == "win":
		archive["win_total"] = int(archive.get("win_total", 0)) + 1
		_update_mission(summary)
	var newly_achieved := _evaluate_achievements()
	save()
	return newly_achieved


## 求生者统计归档：total_* 累加、best_* 取 max、boss_kills 累计（无单局 best）、
## wins 仅胜利 +1（成就 survivor_wins_all 求值用）。
func _update_survivors(survivors: Variant, result: String) -> void:
	if not (survivors is Dictionary):
		return
	var archive_survivors := _block("survivors")
	for sid in survivors.keys():
		var raw: Variant = survivors[sid]
		if not (raw is Dictionary):
			continue
		var s: Dictionary = raw
		var entry := _ensure_survivor_entry(str(sid))
		var damage := int(s.get("damage", 0))
		var kills := int(s.get("kills", 0))
		var healing := int(s.get("healing", 0))
		var turns := int(s.get("turns", 0))
		var boss_kills := int(s.get("boss_kills", 0))
		entry["total_damage"] = int(entry.get("total_damage", 0)) + damage
		entry["best_damage"] = max(int(entry.get("best_damage", 0)), damage)
		entry["total_kills"] = int(entry.get("total_kills", 0)) + kills
		entry["best_kills"] = max(int(entry.get("best_kills", 0)), kills)
		entry["boss_kills"] = int(entry.get("boss_kills", 0)) + boss_kills
		entry["total_healing"] = int(entry.get("total_healing", 0)) + healing
		entry["best_healing"] = max(int(entry.get("best_healing", 0)), healing)
		entry["total_turns"] = int(entry.get("total_turns", 0)) + turns
		entry["best_turns"] = max(int(entry.get("best_turns", 0)), turns)
		if result == "win":
			entry["wins"] = int(entry.get("wins", 0)) + 1


func _update_monsters(monsters: Variant) -> void:
	if not (monsters is Dictionary):
		return
	var archive_monsters := _block("monsters")
	for mid in monsters.keys():
		archive_monsters[mid] = int(archive_monsters.get(mid, 0)) + int(monsters[mid])


## 任务记录归档（仅胜利调用）：以 (mission_id, player_count) 为分档键维护
## win_count 与 best_time_msec（取更短者，历史为 0 时直接赋值）。
## mission_id 为 -1/空（本局无有效任务）或 player_count ≤ 0 时不记录。
func _update_mission(summary: Dictionary) -> void:
	var mid_raw: Variant = summary.get("mission_id", null)
	if mid_raw == null:
		return
	var mid_key := str(mid_raw)
	if mid_key == "" or mid_key == "-1":
		return
	var player_count := int(summary.get("player_count", 0))
	if player_count <= 0:
		return
	var pc_key := str(player_count)
	var missions := _block("missions")
	if not (missions.get(mid_key) is Dictionary):
		missions[mid_key] = {}
	var buckets: Dictionary = missions[mid_key]
	if not (buckets.get(pc_key) is Dictionary):
		buckets[pc_key] = {"win_count": 0, "best_time_msec": 0}
	var bucket: Dictionary = buckets[pc_key]
	bucket["win_count"] = int(bucket.get("win_count", 0)) + 1
	var duration := int(summary.get("duration_msec", 0))
	var best := int(bucket.get("best_time_msec", 0))
	if best <= 0 or (duration > 0 and duration < best):
		bucket["best_time_msec"] = duration


# === 任务解锁查询（mission-unlock-progression spec Task 1）===

## 任务 N 是否已解锁（仅由内存档案推导，不落盘）：
## id <= 0 恒解锁；id >= 1 需前一任务（N-1）在任意 player_count 档下
## win_count > 0（即至少通关一次，任意人数）。
## 开发者模式的全解锁由调用方（GameRoom UI / get_available_missions 过滤）负责。
func is_mission_unlocked(mission_id: int) -> bool:
	if mission_id <= 0:
		return true
	var missions: Variant = archive.get("missions", {})
	if not (missions is Dictionary):
		return false
	var buckets: Variant = missions.get(str(mission_id - 1))
	if not (buckets is Dictionary):
		return false
	for bucket_value in buckets.values():
		if bucket_value is Dictionary and int(bucket_value.get("win_count", 0)) > 0:
			return true
	return false


## 全部任务（DataManager.get_all_missions() 全集，随数据自动扩展）是否均
## 至少通关一次（任意人数）。DataManager 不可用（非 autoload 上下文）或
## 任务集为空时返回 false（防御，不崩溃）。
func are_all_missions_completed() -> bool:
	return _all_missions_completed()


## “随机任务”与全部游戏变体的解锁判定：等价于全部任务通关。
func is_random_and_variants_unlocked() -> bool:
	return are_all_missions_completed()


# === 成就定义与求值 ===

## 成就定义列表（data/achievements.json：Array[{id,name,description,condition}]）。
## 懒加载并缓存；文件缺失/格式非法时返回空数组（无成就可评估，不崩溃）。
func get_achievement_definitions() -> Array:
	if not _definitions_loaded:
		_definitions_loaded = true
		_achievement_definitions = _load_achievement_definitions()
	return _achievement_definitions


func _load_achievement_definitions() -> Array:
	var file := FileAccess.open(ACHIEVEMENTS_PATH, FileAccess.READ)
	if file == null:
		push_error("ArchiveManager: 无法读取成就定义: " + ACHIEVEMENTS_PATH)
		return []
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Array):
		push_error("ArchiveManager: 成就定义格式非法（应为数组）: " + ACHIEVEMENTS_PATH)
		return []
	var definitions: Array = []
	for raw in parsed:
		if raw is Dictionary and str(raw.get("id", "")) != "":
			definitions.append(raw)
	return definitions


## 重新评估全部成就条件；条件成立时：首次 → 记录 first_at（ISO8601 本地时间）
## 并加入返回列表；count 每次条件成立 +1（含首次）。
## 档案中的未知成就 id 条目不参与评估且原样保留。
func _evaluate_achievements() -> Array:
	var newly_achieved: Array = []
	var achievements := _block("achievements")
	for def in get_achievement_definitions():
		var ach_id := str(def.get("id", ""))
		if ach_id == "":
			continue
		if not _evaluate_condition(def.get("condition", {})):
			continue
		var is_new := not achievements.has(ach_id)
		var entry: Dictionary = {}
		if is_new:
			entry = {"first_at": Time.get_datetime_string_from_system(), "count": 0}
		elif achievements[ach_id] is Dictionary:
			entry = achievements[ach_id]
		entry["count"] = int(entry.get("count", 0)) + 1
		achievements[ach_id] = entry
		if is_new:
			newly_achieved.append(def)
	return newly_achieved


## 声明式条件求值（不使用代码字符串沙箱）。条件类型：
## - {"type": "win_total", "value": N}：累计胜利局数 ≥ N（win_total 仅胜利结算推进，
##   故 win 类成就只在胜利结算满足）
## - {"type": "stat_total", "stat": S, "value": N}：跨全部求生者累计 S 之和 ≥ N
##   （S 支持 total_kills / total_healing / boss_kills / total_damage / total_turns …；
##   first_boss_kill 统一表达为 stat_total + boss_kills + 1）
## - {"type": "stat_best", "stat": S, "value": N}：任一求生者单局最佳 S ≥ N
##   （S 支持 best_damage / best_kills / best_healing / best_turns）
## - {"type": "survivor_wins_all"}：所有求生者（DataManager 加载）均至少胜利一局
## - {"type": "missions_complete_all"}：所有任务（DataManager 加载）均至少胜利一次（任意人数）
## 未知条件类型 / 未知统计字段 → false（容忍，不崩溃）。
func _evaluate_condition(condition: Variant) -> bool:
	if not (condition is Dictionary):
		return false
	var cond: Dictionary = condition
	var value := int(cond.get("value", 0))
	match str(cond.get("type", "")):
		"win_total":
			return int(archive.get("win_total", 0)) >= value
		"stat_total":
			return _sum_survivor_stat(str(cond.get("stat", ""))) >= value
		"stat_best":
			return _max_survivor_stat(str(cond.get("stat", ""))) >= value
		"survivor_wins_all":
			return _all_survivors_won()
		"missions_complete_all":
			return _all_missions_completed()
	return false


func _sum_survivor_stat(stat: String) -> int:
	if stat == "":
		return 0
	var total := 0
	for entry_value in _block("survivors").values():
		if entry_value is Dictionary:
			total += int(entry_value.get(stat, 0))
	return total


func _max_survivor_stat(stat: String) -> int:
	if stat == "":
		return 0
	var best := 0
	for entry_value in _block("survivors").values():
		if entry_value is Dictionary:
			best = max(best, int(entry_value.get(stat, 0)))
	return best


## 所有求生者（DataManager 从 data/survivors/ 加载）均至少胜利一局。
func _all_survivors_won() -> bool:
	if DataManager == null or not is_instance_valid(DataManager):
		return false
	var all_survivors: Array = DataManager.get_all_survivors()
	if all_survivors.is_empty():
		return false
	var survivors := _block("survivors")
	for survivor in all_survivors:
		var sid := str(survivor.english_name)
		var entry: Variant = survivors.get(sid)
		if not (entry is Dictionary) or int(entry.get("wins", 0)) < 1:
			return false
	return true


## 所有任务（DataManager 从 data/missions/ 加载）均至少胜利一次（任意人数分档）。
func _all_missions_completed() -> bool:
	if DataManager == null or not is_instance_valid(DataManager):
		return false
	var all_missions: Array = DataManager.get_all_missions()
	if all_missions.is_empty():
		return false
	var missions := _block("missions")
	for mission in all_missions:
		var mid_key := str(mission.mission_id)
		var buckets: Variant = missions.get(mid_key)
		if not (buckets is Dictionary):
			return false
		var won := false
		for bucket_value in buckets.values():
			if bucket_value is Dictionary and int(bucket_value.get("win_count", 0)) > 0:
				won = true
				break
		if not won:
			return false
	return true


# === 内部工具 ===

## 取档案顶层块；不存在或非字典时补空字典（返回可变引用）。
func _block(key: String) -> Dictionary:
	var value: Variant = archive.get(key)
	if not (value is Dictionary):
		value = {}
		archive[key] = value
	return value


## 取求生者档案条目；不存在时创建并补全全部整型字段（返回可变引用）。
func _ensure_survivor_entry(sid: String) -> Dictionary:
	var survivors := _block("survivors")
	var entry: Variant = survivors.get(sid)
	if not (entry is Dictionary):
		entry = {}
		survivors[sid] = entry
	for field in SURVIVOR_INT_FIELDS:
		if not entry.has(field):
			entry[field] = 0
	return entry
