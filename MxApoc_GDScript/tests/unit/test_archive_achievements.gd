extends GutTest

## 成就定义与声明式条件求值单元测试。
## 覆盖：11 条初始成就定义加载、win_total / stat_total / stat_best /
## survivor_wins_all / missions_complete_all 各条件类型判定、
## 首达记录（first_at）、重复满足 count +1、win 类成就仅胜利结算满足、
## 未知条件类型 / 未知统计字段容忍。
## 对应 spec：.trae/specs/achievement-archive-system/spec.md（Task 3）
## 可测性方案：直接实例化 archive_manager.gd 脚本（不进节点树，绕过 autoload），
## 通过 load_archive(临时路径) 注入档案路径，用伪造 summary 多次驱动 record_game_result。

var _mgr
var _path: String
var _counter := 0


func before_each() -> void:
	_counter += 1
	_path = "user://test_ach_%d_%d.json" % [Time.get_ticks_msec(), _counter]
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


# === 成就定义加载 ===

func test_achievement_definitions_loaded() -> void:
	var defs: Array = _mgr.get_achievement_definitions()
	assert_eq(defs.size(), 11, "应加载 11 条初始成就")
	var ids := {}
	for def in defs:
		assert_ne(str(def.get("id", "")), "", "成就应含 id")
		assert_ne(str(def.get("name", "")), "", "成就应含 name")
		assert_ne(str(def.get("description", "")), "", "成就应含 description")
		assert_true(def.get("condition") is Dictionary, "成就 condition 应为声明式对象")
		ids[def.get("id")] = true
	for expected in ["first_win", "wins_10", "wins_50", "total_kills_100", "total_kills_500", "single_damage_30", "single_damage_60", "total_healing_50", "first_boss_kill", "all_survivors_win", "mission_complete_all"]:
		assert_has(ids, expected, "成就清单应包含 " + expected)


# === win_total 条件 ===

func test_first_win_only_on_win_result() -> void:
	var newly: Array = _mgr.record_game_result(_make_summary("lose", {"firefighter": _survivor_stats(10, 5)}, {}, 0, 1, 1000))
	assert_false(_has_id(newly, "first_win"), "失败结算不应达成 first_win")
	assert_false(_mgr.archive["achievements"].has("first_win"), "失败结算后 first_win 不应被记录")
	newly = _mgr.record_game_result(_make_summary("win", {"firefighter": _survivor_stats()}, {}, 0, 1, 1000))
	assert_true(_has_id(newly, "first_win"), "胜利结算应达成 first_win")
	var entry: Dictionary = _mgr.archive["achievements"]["first_win"]
	assert_eq(entry["count"], 1, "首次达成 count 应为 1")
	assert_ne(str(entry["first_at"]), "", "首次达成应记录 first_at")


func test_wins_10_unlocks_at_tenth_win() -> void:
	var last_newly: Array = []
	for i in range(10):
		last_newly = _mgr.record_game_result(_make_summary("win", {}, {}, 0, 1, 1000))
		if i < 9:
			assert_false(_has_id(last_newly, "wins_10"), "前 9 胜不应达成 wins_10")
	assert_true(_has_id(last_newly, "wins_10"), "第 10 胜应达成 wins_10")
	assert_false(_has_id(last_newly, "wins_50"), "10 胜不应达成 wins_50")


# === stat_total 条件（跨局跨求生者累计） ===

func test_stat_total_kills_across_survivors_and_losses() -> void:
	var newly: Array = _mgr.record_game_result(_make_summary("lose", {"hunter": _survivor_stats(0, 60)}, {}, -1, 1, 0))
	assert_false(_has_id(newly, "total_kills_100"), "累计 60 杀不应达成 total_kills_100")
	# 跨求生者累计：hunter 60 + surgeon 40 = 100（失败结算同样累计与评估）
	newly = _mgr.record_game_result(_make_summary("lose", {"surgeon": _survivor_stats(0, 40)}, {}, -1, 1, 0))
	assert_true(_has_id(newly, "total_kills_100"), "跨求生者累计 100 杀应达成 total_kills_100")
	assert_false(_has_id(newly, "total_kills_500"), "累计 100 杀不应达成 total_kills_500")


func test_stat_total_healing() -> void:
	var newly: Array = _mgr.record_game_result(_make_summary("win", {"surgeon": _survivor_stats(0, 0, 50)}, {}, 0, 1, 0))
	assert_true(_has_id(newly, "total_healing_50"), "累计治疗 50 应达成 total_healing_50")


func test_stat_total_boss_kills() -> void:
	# first_boss_kill 统一表达为 stat_total + boss_kills + 1
	var newly: Array = _mgr.record_game_result(_make_summary("lose", {"firefighter": _survivor_stats(0, 0, 0, 0, 1)}, {}, -1, 1, 0))
	assert_true(_has_id(newly, "first_boss_kill"), "首次首领击杀应达成 first_boss_kill")
	assert_eq(_mgr.archive["achievements"]["first_boss_kill"]["count"], 1, "首次达成 count 应为 1")


# === stat_best 条件（单局最佳） ===

func test_stat_best_damage() -> void:
	var newly: Array = _mgr.record_game_result(_make_summary("lose", {"gunslinger": _survivor_stats(35)}, {}, -1, 1, 0))
	assert_true(_has_id(newly, "single_damage_30"), "单局伤害 35 应达成 single_damage_30")
	assert_false(_has_id(newly, "single_damage_60"), "单局伤害 35 不应达成 single_damage_60")
	newly = _mgr.record_game_result(_make_summary("win", {"gunslinger": _survivor_stats(60)}, {}, 0, 1, 0))
	assert_true(_has_id(newly, "single_damage_60"), "单局伤害 60 应达成 single_damage_60")


# === survivor_wins_all 条件 ===

func test_survivor_wins_all() -> void:
	var survivors: Array = DataManager.get_all_survivors()
	assert_gt(survivors.size(), 0, "测试前置：DataManager 应已加载求生者")
	var last_newly: Array = []
	for survivor in survivors:
		last_newly = _mgr.record_game_result(_make_summary("win", {survivor.english_name: _survivor_stats()}, {}, 0, 1, 1000))
	assert_true(_has_id(last_newly, "all_survivors_win"), "全部求生者各胜一局后应达成 all_survivors_win")
	assert_eq(_mgr.archive["achievements"]["all_survivors_win"]["count"], 1, "all_survivors_win 应仅在最后一局满足一次")


# === missions_complete_all 条件 ===

func test_mission_complete_all() -> void:
	var missions: Array = DataManager.get_all_missions()
	assert_gt(missions.size(), 0, "测试前置：DataManager 应已加载任务")
	var last_newly: Array = []
	for mission in missions:
		last_newly = _mgr.record_game_result(_make_summary("win", {}, {}, mission.mission_id, 1, 1000))
	assert_true(_has_id(last_newly, "mission_complete_all"), "通关全部任务后应达成 mission_complete_all")
	assert_eq(_mgr.archive["achievements"]["mission_complete_all"]["count"], 1, "mission_complete_all 应仅在最后一局满足一次")


# === 重复满足与 count 累计 ===

func test_repeat_satisfaction_increments_count() -> void:
	_mgr.record_game_result(_make_summary("win", {}, {}, 0, 1, 1000))
	assert_eq(_mgr.archive["achievements"]["first_win"]["count"], 1, "首次达成 count 应为 1")
	var newly: Array = _mgr.record_game_result(_make_summary("win", {}, {}, 0, 1, 1000))
	assert_false(_has_id(newly, "first_win"), "已解锁成就不应再次进入新达成列表")
	assert_eq(_mgr.archive["achievements"]["first_win"]["count"], 2, "条件再次成立时 count 应 +1")


# === 未知条件类型容忍 ===

func test_unknown_condition_type_returns_false() -> void:
	assert_false(_mgr._evaluate_condition({"type": "bogus_type", "value": 1}), "未知条件类型应返回 false")
	assert_false(_mgr._evaluate_condition({"type": "stat_total", "stat": "no_such_stat", "value": 1}), "未知统计字段应返回 false")
	assert_false(_mgr._evaluate_condition(null), "condition 缺失应返回 false")
