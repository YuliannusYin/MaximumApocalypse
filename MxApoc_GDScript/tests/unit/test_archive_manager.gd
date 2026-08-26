extends GutTest

## ArchiveManager 档案管理器单元测试。
## 覆盖：首次写入、best 值刷新与保持、任务按玩家数分档、损坏文件恢复（.bak 备份）、
## 防御性加载默认值、失败结算不更新任务记录但更新 survivors/monsters、
## 重启加载持久化、无效 mission_id 不记录、未知成就 id 容忍、
## 旧档案 monsters 类型级键丢弃（怪物统计细化，见 refine-achievement-ui-monster-stats spec）。
## 对应 spec：.trae/specs/achievement-archive-system/spec.md（Task 2）
## 可测性方案：直接实例化 archive_manager.gd 脚本（不进节点树，绕过 autoload），
## 通过 load_archive(临时路径) 注入档案路径，测试间互不干扰。

var _mgr
var _path: String
var _counter := 0


func before_each() -> void:
	_counter += 1
	_path = "user://test_archive_%d_%d.json" % [Time.get_ticks_msec(), _counter]
	_mgr = load("res://src/core/archive_manager.gd").new()
	_mgr.load_archive(_path)


func after_each() -> void:
	if is_instance_valid(_mgr):
		_mgr.free()
	_cleanup_files()


# === 辅助方法 ===

func _make_summary(result: String, survivors: Dictionary, monsters: Dictionary = {}, mission_id = -1, player_count: int = 1, duration_msec: int = 0) -> Dictionary:
	return {
		"result": result,
		"duration_msec": duration_msec,
		"player_count": player_count,
		"mission_id": mission_id,
		"survivors": survivors,
		"monsters": monsters,
	}


func _survivor_stats(damage := 0, kills := 0, healing := 0, turns := 0, boss_kills := 0) -> Dictionary:
	return {"damage": damage, "kills": kills, "healing": healing, "turns": turns, "boss_kills": boss_kills}


func _has_id(newly: Array, ach_id: String) -> bool:
	for def in newly:
		if str(def.get("id", "")) == ach_id:
			return true
	return false


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)


func _bak_exists() -> bool:
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	var base := _path.get_file()
	var found := false
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.begins_with(base + ".bak."):
			found = true
		fname = dir.get_next()
	dir.list_dir_end()
	return found


func _cleanup_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var base := _path.get_file()
	var to_remove: Array = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname == base or fname.begins_with(base + ".bak."):
			to_remove.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	for f in to_remove:
		dir.remove(f)


# === 首次写入 ===

func test_first_record_creates_archive_file() -> void:
	assert_false(FileAccess.file_exists(_path), "测试前置：临时档案文件不应存在")
	var newly: Array = _mgr.record_game_result(_make_summary("win", {"firefighter": _survivor_stats(5, 2, 1, 8, 1)}, {"zombie_dog": 2}, 3, 2, 90000))
	assert_true(FileAccess.file_exists(_path), "首次结算归档后应创建档案文件")
	assert_true(_has_id(newly, "first_win"), "首胜结算应新达成 first_win")
	# 落盘内容可解析且结构正确
	var data: Variant = _read_json(_path)
	assert_true(data is Dictionary, "档案文件应为 JSON 对象")
	var archive_data: Dictionary = data
	assert_eq(archive_data.get("win_total"), 1, "首次胜利后 win_total 应为 1")
	var survivor: Dictionary = archive_data["survivors"]["firefighter"]
	assert_eq(survivor["total_damage"], 5, "total_damage 应为本局伤害")
	assert_eq(survivor["best_damage"], 5, "首次 best_damage 应为本局伤害")
	assert_eq(survivor["total_kills"], 2, "total_kills 应为本局击杀")
	assert_eq(survivor["boss_kills"], 1, "boss_kills 应为本局首领击杀")
	assert_eq(survivor["total_healing"], 1, "total_healing 应为本局治疗")
	assert_eq(survivor["total_turns"], 8, "total_turns 应为本局回合数")
	assert_eq(survivor["wins"], 1, "胜利结算 wins 应 +1")
	var bucket: Dictionary = archive_data["missions"]["3"]["2"]
	assert_eq(bucket["win_count"], 1, "任务 3 的 2 人档 win_count 应为 1")
	assert_eq(bucket["best_time_msec"], 90000, "首次通关 best_time_msec 应直接赋值")
	assert_eq(archive_data["monsters"]["zombie_dog"], 2, "怪物累计击杀数应为 2")


# === best 值刷新与保持 ===

func test_best_values_keep_and_refresh() -> void:
	_mgr.record_game_result(_make_summary("lose", {"hunter": _survivor_stats(30, 4, 10, 20)}, {}, 1, 1, 5000))
	_mgr.record_game_result(_make_summary("lose", {"hunter": _survivor_stats(25, 2, 12, 18)}, {}, 1, 1, 6000))
	var entry: Dictionary = _mgr.archive["survivors"]["hunter"]
	assert_eq(entry["best_damage"], 30, "本局 25 低于历史 30，best_damage 应保持 30")
	assert_eq(entry["total_damage"], 55, "total_damage 应累加为 55")
	assert_eq(entry["best_healing"], 12, "本局治疗 12 高于历史 10，best_healing 应刷新")
	assert_eq(entry["total_healing"], 22, "total_healing 应累加为 22")
	assert_eq(entry["best_kills"], 4, "best_kills 应保持单局最高 4")
	assert_eq(entry["total_kills"], 6, "total_kills 应累加为 6")
	assert_eq(entry["best_turns"], 20, "best_turns 应保持单局最高 20")
	assert_eq(entry["total_turns"], 38, "total_turns 应累加为 38")
	assert_eq(entry["wins"], 0, "失败结算 wins 不应增加")


# === 任务按玩家数分档 ===

func test_mission_buckets_by_player_count() -> void:
	_mgr.record_game_result(_make_summary("win", {}, {}, 1, 2, 120000))
	_mgr.record_game_result(_make_summary("win", {}, {}, 1, 4, 90000))
	_mgr.record_game_result(_make_summary("win", {}, {}, 1, 2, 100000))
	var missions: Dictionary = _mgr.archive["missions"]
	assert_true(missions.has("1"), "任务 1 应有记录")
	var mission: Dictionary = missions["1"]
	assert_true(mission.has("2"), "2 人档应独立存在")
	assert_true(mission.has("4"), "4 人档应独立存在")
	assert_eq(mission["2"]["win_count"], 2, "2 人档通关数应为 2")
	assert_eq(mission["2"]["best_time_msec"], 100000, "2 人档最短时间应刷新为 100000")
	assert_eq(mission["4"]["win_count"], 1, "4 人档通关数应为 1")
	assert_eq(mission["4"]["best_time_msec"], 90000, "4 人档最短时间应为 90000")


# === 损坏文件恢复 ===

func test_corrupt_file_backup_and_recovery() -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("{ 这不是合法 JSON !!!")
	file.close()
	_mgr.load_archive(_path)
	# JSON.parse_string 解析失败会产生引擎错误（Parse JSON failed），声明为预期错误
	assert_engine_error("Parse JSON failed", "损坏 JSON 解析失败应产生引擎错误")
	assert_eq(_mgr.archive.get("win_total", -1), 0, "损坏档案应回退为空档案")
	assert_eq(_mgr.archive["survivors"].size(), 0, "空档案 survivors 应为空")
	assert_eq(_mgr.archive["achievements"].size(), 0, "空档案 achievements 应为空")
	assert_true(_bak_exists(), "损坏文件应被重命名为 .bak.<时间戳> 备份")
	# 恢复后可继续正常归档
	_mgr.record_game_result(_make_summary("lose", {"mechanic": _survivor_stats(3)}, {}, -1, 1, 0))
	assert_eq(_mgr.archive["survivors"]["mechanic"]["total_damage"], 3, "恢复后应可继续归档")


func test_non_object_json_backup_and_recovery() -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()
	_mgr.load_archive(_path)
	assert_eq(_mgr.archive["win_total"], 0, "非对象 JSON 应视为损坏并使用空档案")
	assert_true(_bak_exists(), "非对象 JSON 文件应被备份")


# === 防御性加载默认值 ===

func test_load_applies_defensive_defaults() -> void:
	var partial := {
		"survivors": {"firefighter": {"total_damage": 10, "unknown_field": "x"}},
		"win_total": 3,
		"unknown_top": true,
		"achievements": {"ghost": {"count": 2}},
	}
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(partial))
	file.close()
	_mgr.load_archive(_path)
	# 缺失块补空容器
	assert_eq(_mgr.archive["missions"].size(), 0, "缺失 missions 块应补空字典")
	assert_eq(_mgr.archive["monsters"].size(), 0, "缺失 monsters 块应补空字典")
	# 缺失字段补默认值，未知字段保留
	var entry: Dictionary = _mgr.archive["survivors"]["firefighter"]
	assert_eq(entry["total_damage"], 10, "已有字段应保留")
	assert_eq(entry["best_damage"], 0, "缺失 best_damage 应默认 0")
	assert_eq(entry["wins"], 0, "缺失 wins 应默认 0")
	assert_eq(entry["unknown_field"], "x", "未知字段应保留")
	assert_eq(_mgr.archive["win_total"], 3, "win_total 应保留")
	# 成就条目缺失字段补默认值
	var ghost: Dictionary = _mgr.archive["achievements"]["ghost"]
	assert_eq(ghost["count"], 2, "已有 count 应保留")
	assert_eq(ghost["first_at"], "", "缺失 first_at 应默认空串")
	assert_true(_mgr.archive["unknown_top"], "未知顶层字段应保留")


# === 失败结算 ===

func test_lose_result_updates_stats_not_missions() -> void:
	_mgr.record_game_result(_make_summary("lose", {"surgeon": _survivor_stats(5, 1, 2, 6)}, {"alien_drone": 1}, 5, 3, 60000))
	assert_eq(_mgr.archive["win_total"], 0, "失败结算不应累计 win_total")
	assert_eq(_mgr.archive["missions"].size(), 0, "失败结算不应更新任务记录")
	assert_eq(_mgr.archive["survivors"]["surgeon"]["total_damage"], 5, "失败结算仍应归档求生者统计")
	assert_eq(_mgr.archive["survivors"]["surgeon"]["total_kills"], 1, "失败结算仍应归档击杀数")
	assert_eq(_mgr.archive["monsters"]["alien_drone"], 1, "失败结算仍应归档怪物击杀")
	assert_false(_mgr.archive["achievements"].has("first_win"), "失败结算不应解锁首胜成就")


# === 重启加载持久化 ===

func test_reload_persists_archive() -> void:
	_mgr.record_game_result(_make_summary("win", {"mechanic": _survivor_stats(7, 3)}, {"robot_scout": 4}, 2, 1, 50000))
	var reloaded = load("res://src/core/archive_manager.gd").new()
	reloaded.load_archive(_path)
	assert_eq(reloaded.archive["win_total"], 1, "重启加载应恢复 win_total")
	assert_eq(reloaded.archive["survivors"]["mechanic"]["total_damage"], 7, "重启加载应恢复求生者统计")
	assert_eq(reloaded.archive["survivors"]["mechanic"]["wins"], 1, "重启加载应恢复 wins")
	assert_eq(reloaded.archive["missions"]["2"]["1"]["win_count"], 1, "重启加载应恢复任务记录")
	assert_eq(reloaded.archive["monsters"]["robot_scout"], 4, "重启加载应恢复怪物击杀")
	assert_true(reloaded.archive["achievements"].has("first_win"), "重启加载应恢复成就记录")
	reloaded.free()


# === 无效 mission_id 防御 ===

func test_invalid_mission_id_not_recorded() -> void:
	_mgr.record_game_result(_make_summary("win", {}, {}, -1, 2, 5000))
	assert_eq(_mgr.archive["missions"].size(), 0, "mission_id=-1（无有效任务）不应记录任务")
	assert_eq(_mgr.archive["win_total"], 1, "win_total 仍应累计")


# === 未知成就 id 容忍 ===

func test_unknown_achievement_id_tolerated() -> void:
	var data := {
		"achievements": {"legacy_ach": {"first_at": "2026-01-01T00:00:00", "count": 3}},
	}
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	_mgr.load_archive(_path)
	assert_eq(_mgr.archive["achievements"]["legacy_ach"]["count"], 3, "未知成就条目应保留")
	# 结算后未知条目不被评估也不被清除
	_mgr.record_game_result(_make_summary("win", {}, {}, 0, 1, 1000))
	assert_true(_mgr.archive["achievements"].has("legacy_ach"), "结算后未知成就条目应保留")
	assert_eq(_mgr.archive["achievements"]["legacy_ach"]["count"], 3, "未知成就条目 count 不应变化")


# === 旧档案兼容（monsters 类型级键丢弃） ===

func test_legacy_monster_type_keys_dropped_on_load() -> void:
	# 旧格式档案：monsters 含类型级键（zombie/alien/mutant/robot）与 english_name 级键混存
	var legacy := {
		"win_total": 2,
		"survivors": {"firefighter": {"total_kills": 3, "total_damage": 10}},
		"missions": {"0": {"1": {"win_count": 1, "best_time_msec": 5000}}},
		"achievements": {"first_win": {"first_at": "2026-01-01T00:00:00", "count": 1}},
		"monsters": {"zombie": 5, "alien": 2, "mutant": 1, "robot": 3, "zombie_dog": 4, "unknown_mon": 2},
	}
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	_mgr.load_archive(_path)
	# 旧类型级键直接丢弃（不迁移）
	var monsters: Dictionary = _mgr.archive["monsters"]
	assert_false(monsters.has("zombie"), "旧类型级键 zombie 应被丢弃")
	assert_false(monsters.has("alien"), "旧类型级键 alien 应被丢弃")
	assert_false(monsters.has("mutant"), "旧类型级键 mutant 应被丢弃")
	assert_false(monsters.has("robot"), "旧类型级键 robot 应被丢弃")
	# english_name 级键（含未知怪物）保留
	assert_eq(monsters.get("zombie_dog", 0), 4, "english_name 级键 zombie_dog 应保留")
	assert_eq(monsters.get("unknown_mon", 0), 2, "未知 english_name 键应容忍保留")
	# 其余数据块正常加载，不崩溃
	assert_eq(_mgr.archive["win_total"], 2, "win_total 应正常加载")
	assert_eq(_mgr.archive["survivors"]["firefighter"]["total_kills"], 3, "survivors 块应正常加载")
	assert_eq(_mgr.archive["missions"]["0"]["1"]["win_count"], 1, "missions 块应正常加载")
	assert_eq(_mgr.archive["achievements"]["first_win"]["count"], 1, "achievements 块应正常加载")
	# 丢弃后新归档可正常累计（不与旧类型数据叠加）
	_mgr.record_game_result(_make_summary("lose", {}, {"zombie_dog": 1}, -1, 1, 0))
	assert_eq(_mgr.archive["monsters"]["zombie_dog"], 5, "丢弃旧键后新归档应正常累计")
