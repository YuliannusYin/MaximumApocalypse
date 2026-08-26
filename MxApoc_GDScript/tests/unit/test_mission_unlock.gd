extends GutTest

## 任务解锁系统单元测试（ArchiveManager 解锁查询 API + DataManager 过滤）。
## 对应 spec：.trae/specs/mission-unlock-progression/spec.md（Task 1 / Task 2）
## 规则：任务 0 恒解锁；任务 N 需任务 N-1 任意人数档 win_count > 0；
## 全部任务通关（任意人数）→ 随机任务与变体解锁；已有档案自动推导解锁进度。
## 可测性方案：直接实例化 archive_manager.gd（不进节点树，绕过 autoload），
## 通过 load_archive(临时路径) 注入档案路径，测试间互不干扰。
## DataManager 层测试（get_available_missions）依赖 ArchiveManager autoload：
## 仅操纵其内存档案字典（不落盘），before/after_each 保存并还原原始状态
## （含 Settings.dev_mode），不污染真实档案。

var _mgr
var _path: String
var _counter := 0
var _saved_dev_mode: bool = false
var _saved_archive: Dictionary = {}


func before_each() -> void:
	_counter += 1
	_path = "user://test_mission_unlock_%d_%d.json" % [Time.get_ticks_msec(), _counter]
	_mgr = load("res://src/core/archive_manager.gd").new()
	_mgr.load_archive(_path)
	_saved_dev_mode = Settings.dev_mode
	_saved_archive = ArchiveManager.archive.duplicate(true)


func after_each() -> void:
	if is_instance_valid(_mgr):
		_mgr.free()
	_cleanup_files()
	Settings.dev_mode = _saved_dev_mode
	ArchiveManager.archive = _saved_archive.duplicate(true)


# === 辅助方法 ===

func _win_summary(mission_id: int, player_count: int) -> Dictionary:
	return {
		"result": "win",
		"duration_msec": 60000,
		"player_count": player_count,
		"mission_id": mission_id,
		"survivors": {},
		"monsters": {},
	}


## 在内存档案中直接标记任务 mission_id 已以 player_count 人通关一次
## （直接改实例内部档案字典，不落盘）。
func _mark_won(mission_id: int, player_count: int = 1) -> void:
	var missions: Dictionary = _mgr.archive["missions"]
	var key := str(mission_id)
	if not (missions.get(key) is Dictionary):
		missions[key] = {}
	var buckets: Dictionary = missions[key]
	var pc := str(player_count)
	if not (buckets.get(pc) is Dictionary):
		buckets[pc] = {"win_count": 0, "best_time_msec": 0}
	var bucket: Dictionary = buckets[pc]
	bucket["win_count"] = int(bucket["win_count"]) + 1


## 将档案字典写入临时路径（合法 JSON，解析不会失败）。
func _write_archive_json(data: Dictionary) -> void:
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


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


# === 空档案：仅任务 0 解锁 ===

func test_empty_archive_only_mission_zero_unlocked() -> void:
	assert_true(_mgr.is_mission_unlocked(0), "任务 0 默认解锁")
	assert_false(_mgr.is_mission_unlocked(1), "空档案任务 1 应锁定")
	assert_false(_mgr.is_mission_unlocked(12), "空档案任务 12 应锁定")
	assert_false(_mgr.are_all_missions_completed(), "空档案不应判定全通")
	assert_false(_mgr.is_random_and_variants_unlocked(), "空档案随机任务/变体应锁定")


func test_non_positive_id_always_unlocked() -> void:
	assert_true(_mgr.is_mission_unlocked(-1), "id=-1（无有效任务）应恒解锁")
	assert_true(_mgr.is_mission_unlocked(0), "id=0 应恒解锁")


# === 通关解锁下一任务 ===

func test_win_result_unlocks_next_mission() -> void:
	assert_false(_mgr.is_mission_unlocked(3), "任务 2 未通关前任务 3 应锁定")
	_mgr.record_game_result(_win_summary(2, 2))
	assert_true(_mgr.is_mission_unlocked(3), "任务 2 通关（2 人档）后任务 3 应解锁")
	assert_false(_mgr.is_mission_unlocked(4), "任务 3 未通关，任务 4 应仍锁定")


func test_any_player_count_bucket_unlocks_next() -> void:
	_mark_won(5, 2)
	assert_true(_mgr.is_mission_unlocked(6), "任务 5 仅 2 人档通关，任务 6 也应解锁")


func test_zero_win_count_does_not_unlock() -> void:
	var missions: Dictionary = _mgr.archive["missions"]
	missions["8"] = {"3": {"win_count": 0, "best_time_msec": 0}}
	assert_false(_mgr.is_mission_unlocked(9), "win_count==0 的记录不应解锁任务 9")


func test_lose_result_does_not_unlock() -> void:
	var summary := _win_summary(1, 1)
	summary["result"] = "lose"
	_mgr.record_game_result(summary)
	assert_false(_mgr.is_mission_unlocked(2), "失败结算不应解锁任务 2")


# === 全通判定与随机任务/变体解锁 ===

func test_all_missions_completed_unlocks_random_and_variants() -> void:
	var all_missions: Array = DataManager.get_all_missions()
	assert_eq(all_missions.size(), 13, "前置：任务全集应为 13 个（mission 0~12）")
	for mission in all_missions:
		_mark_won(int(mission.mission_id), 2)
	assert_true(_mgr.are_all_missions_completed(), "13 个任务全部通关应判定全通")
	assert_true(_mgr.is_random_and_variants_unlocked(), "全通后随机任务与变体应解锁")


func test_missing_one_mission_not_completed() -> void:
	for mid in range(0, 12):
		_mark_won(mid, 1)
	assert_false(_mgr.are_all_missions_completed(), "缺任务 12 不应判定全通")
	assert_false(_mgr.is_random_and_variants_unlocked(), "缺任务 12 随机任务/变体应锁定")
	assert_true(_mgr.is_mission_unlocked(12), "任务 11 已通关，任务 12 本身应解锁（线性解锁与全通判定独立）")


# === 已有档案自动推导 ===

func test_existing_archive_auto_derives_unlock() -> void:
	var data := {"win_total": 6, "missions": {}}
	for mid in range(0, 6):
		data["missions"][str(mid)] = {"1": {"win_count": 1, "best_time_msec": 50000}}
	_write_archive_json(data)
	_mgr.load_archive(_path)
	for mid in range(1, 7):
		assert_true(_mgr.is_mission_unlocked(mid), "档案含任务 0~5 通关，任务 %d 应解锁" % mid)
	assert_false(_mgr.is_mission_unlocked(7), "任务 6 未通关，任务 7 应锁定")
	assert_false(_mgr.is_mission_unlocked(12), "任务 12 应锁定")
	assert_false(_mgr.are_all_missions_completed(), "仅通关 0~5 不应判定全通")


# === DataManager.get_available_missions 解锁过滤（Task 2）===
# 依赖 autoload（DataManager / Settings / ArchiveManager）。仅操纵
# ArchiveManager 的内存档案字典（不调用 save()，不落盘），
# Settings.dev_mode 与档案原状由 before/after_each 还原。

## dev 模式：无视档案进度，返回全部任务。
func test_get_available_missions_dev_mode_returns_all() -> void:
	ArchiveManager.archive = {}
	Settings.dev_mode = true
	var available: Array = DataManager.get_available_missions()
	var all: Array = DataManager.get_all_missions()
	assert_eq(all.size(), 13, "前置：任务全集应为 13 个（mission 0~12）")
	assert_eq(available.size(), all.size(), "dev 模式即使空档案也应返回全部任务")


## 玩家模式 + 空档案：仅任务 0 可用。
func test_get_available_missions_player_empty_archive_only_zero() -> void:
	Settings.dev_mode = false
	ArchiveManager.archive = {}
	var available: Array = DataManager.get_available_missions()
	assert_eq(available.size(), 1, "空档案玩家模式应仅任务 0 可用")
	assert_eq(int(available[0].mission_id), 0, "唯一可用任务应为任务 0")


## 玩家模式 + 任务 0 已通关：任务 0 与 1 可用。
func test_get_available_missions_player_after_winning_mission_zero() -> void:
	Settings.dev_mode = false
	ArchiveManager.archive = {
		"missions": {"0": {"1": {"win_count": 1, "best_time_msec": 60000}}},
	}
	var available: Array = DataManager.get_available_missions()
	assert_eq(available.size(), 2, "任务 0 通关后应仅任务 0 与 1 可用")
	assert_eq(int(available[0].mission_id), 0, "第 1 项应为任务 0")
	assert_eq(int(available[1].mission_id), 1, "第 2 项应为任务 1")


## 玩家模式线性链：任务 0、1 均通关 → 任务 0~2 可用（结果按 id 升序）。
func test_get_available_missions_player_progressive_chain() -> void:
	Settings.dev_mode = false
	ArchiveManager.archive = {
		"missions": {
			"0": {"2": {"win_count": 1, "best_time_msec": 60000}},
			"1": {"1": {"win_count": 3, "best_time_msec": 60000}},
		},
	}
	var available: Array = DataManager.get_available_missions()
	assert_eq(available.size(), 3, "任务 0、1 通关后应仅任务 0~2 可用")
	assert_eq(int(available[0].mission_id), 0, "第 1 项应为任务 0")
	assert_eq(int(available[1].mission_id), 1, "第 2 项应为任务 1")
	assert_eq(int(available[2].mission_id), 2, "第 3 项应为任务 2")
