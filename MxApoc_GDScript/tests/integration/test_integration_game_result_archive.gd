extends GutTest

## 集成测试：结算流程接入归档（成就/存档系统 Task 4）。
## 以"结算场景函数级"测试替代完整跑一局到结算：直接实例化 GameResult 场景
## 并加入场景树（_ready → _record_archive 触发归档 + 新成就展示），验证：
## - 玩家模式（dev_mode=false）胜利结算 → 档案落盘且内容正确
##   （win_total / 任务分档 / 求生者统计 / 怪物击杀 / first_win 成就）
## - 玩家模式失败结算 → 求生者/怪物归档、任务记录与胜利计数不变、无新成就区块
## - 开发者模式（dev_mode=true）结算 → 完全不归档（不落盘、内存档案不变）
## - 状态机未记录胜负（game_result=-1，未结算直入结算页）→ 不归档
## - 同一结算页实例二次触发归档 → 防重入（只归档一次）
## 防污染方案：将 ArchiveManager autoload 经 load_archive 重定向到临时路径
## （user://test_gr_archive_*.json），测试后删除临时档案并把 autoload 指回
## 默认 user://archive.json（仅重读，不写盘），玩家真实档案不受影响。

const _ARCHIVE_DEFAULT_PATH := "user://archive.json"

var _path: String
var _counter := 0


func before_each() -> void:
	_counter += 1
	_path = "user://test_gr_archive_%d_%d.json" % [Time.get_ticks_msec(), _counter]
	ArchiveManager.load_archive(_path)
	Settings.dev_mode = false
	_reset_game_state()


func after_each() -> void:
	Settings.dev_mode = false
	_cleanup_temp_files()
	# 恢复 autoload 指向默认路径（重新加载真实档案，不写盘）
	ArchiveManager.load_archive(_ARCHIVE_DEFAULT_PATH)
	_reset_game_state()


# === 辅助方法 ===

func _reset_game_state() -> void:
	Game.players = []
	Game.mission_config = null
	Game.current_mission = null
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()
	if Game.stats_tracker != null:
		Game.stats_tracker.reset([])


func _make_survivor_player(survivor_id: String, player_name: String = "P") -> Player:
	var p: Player = Player.new()
	p.player_name = player_name
	p.hp = 10
	p.max_hp = 10
	var rc: RoleCard = RoleCard.new()
	rc.english_name = survivor_id
	p.role_card = rc
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_zombie(monster_name: String) -> Monster:
	var c: MonsterCard = MonsterCard.new()
	c.card_name = monster_name
	c.card_type = "monster"
	c.source = "monster"
	c.english_name = "zombie_stalker"
	c.monster_type = "zombie"
	c.monster_level = "normal"
	c.max_hp = 3
	c.damage_value = 2
	c.range = "none"
	return c.instantiate(null)


## 搭建一局"已正常结算"的对局状态：状态机 GAME_OVER + 结果 + 统计数据
## （1 名消防员玩家击杀 1 只僵尸），并返回该玩家。
func _setup_finished_game(result_enum: int) -> Player:
	var p: Player = _make_survivor_player("firefighter")
	Game.players = [p]
	Game.current_mission = DataManager.get_mission(0)
	Game.stats_tracker.reset([p])
	EventBus.monster_died.emit(_make_zombie("僵尸潜伏者"), p)
	Game.stats_tracker.start_timer()
	Game.stats_tracker.stop_timer()
	Game.state_machine.current_state = GameStateMachine.GameState.GAME_OVER
	Game.state_machine.game_result = result_enum
	return p


## 实例化结算场景并加入场景树（触发 _ready → 归档 + 新成就展示）。
func _spawn_result_scene() -> Node:
	var scene: Node = load("res://scenes/GameResult.tscn").instantiate()
	add_child_autofree(scene)
	return scene


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)


func _cleanup_temp_files() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.remove(_path.get_file())


# ============================================================
# 玩家模式（dev_mode = false）
# ============================================================

func test_player_mode_win_settlement_archives() -> void:
	_setup_finished_game(GameStateMachine.GameResult.WIN)
	var scene: Node = _spawn_result_scene()
	assert_true(FileAccess.file_exists(_path), "玩家模式胜利结算后应写入档案文件")
	var data: Variant = _read_json(_path)
	assert_true(data is Dictionary, "档案文件应为 JSON 对象")
	var archive: Dictionary = data
	assert_eq(int(archive.get("win_total")), 1, "胜利结算后 win_total 应为 1")
	var bucket: Dictionary = archive["missions"]["0"]["1"]
	assert_eq(int(bucket["win_count"]), 1, "任务 0 的 1 人档应记录 1 次通关")
	var survivor: Dictionary = archive["survivors"]["firefighter"]
	assert_eq(int(survivor["total_kills"]), 1, "求生者 total_kills 应归档本局击杀")
	assert_eq(int(survivor["wins"]), 1, "胜利结算 wins 应 +1")
	assert_eq(int(archive["monsters"]["zombie_stalker"]), 1, "怪物累计击杀数应按 english_name 归档")
	assert_true(archive["achievements"].has("first_win"), "首次胜利应解锁 first_win 成就")
	# 结算页展示本局新达成成就（first_win）：区块存在且含标题/名称/描述
	var panel: Node = scene.get_node_or_null("NewAchievements")
	assert_not_null(panel, "有新成就时应展示新成就区块")
	var texts: Array = []
	for label in panel.find_children("*", "Label", true, false):
		texts.append(label.text)
	assert_true(texts.has("新达成成就"), "区块应含标题「新达成成就」")
	assert_true(texts.has("末日幸存者"), "区块应含成就名称「末日幸存者」")
	assert_true(texts.has("首次以胜利结算一局"), "区块应含成就描述")


func test_player_mode_lose_settlement_archives_stats_not_missions() -> void:
	_setup_finished_game(GameStateMachine.GameResult.LOSE)
	var scene: Node = _spawn_result_scene()
	assert_true(FileAccess.file_exists(_path), "玩家模式失败结算仍应归档")
	var archive: Dictionary = _read_json(_path)
	assert_eq(int(archive.get("win_total")), 0, "失败结算不应累计 win_total")
	assert_eq(archive["missions"].size(), 0, "失败结算不应更新任务记录")
	assert_eq(int(archive["survivors"]["firefighter"]["total_kills"]), 1, "失败结算仍应归档求生者统计")
	assert_eq(int(archive["monsters"]["zombie_stalker"]), 1, "失败结算仍应按 english_name 归档怪物击杀")
	assert_false(archive["achievements"].has("first_win"), "失败结算不应解锁首胜成就")
	assert_null(scene.get_node_or_null("NewAchievements"), "无新成就时不应展示新成就区块")


# ============================================================
# 开发者模式（dev_mode = true）
# ============================================================

func test_dev_mode_settlement_does_not_archive() -> void:
	_setup_finished_game(GameStateMachine.GameResult.WIN)
	Settings.dev_mode = true
	_spawn_result_scene()
	assert_false(FileAccess.file_exists(_path), "开发者模式结算不应写入档案文件")
	assert_eq(ArchiveManager.archive.get("win_total", 0), 0, "开发者模式内存档案不应被更新")
	assert_eq(ArchiveManager.archive["survivors"].size(), 0, "开发者模式不应归档求生者统计")
	assert_eq(ArchiveManager.archive["monsters"].size(), 0, "开发者模式不应归档怪物击杀")


# ============================================================
# 未结算（无有效胜负结果）不归档
# ============================================================

func test_invalid_result_settlement_not_archived() -> void:
	_setup_finished_game(GameStateMachine.GameResult.WIN)
	# 状态机未记录胜负（game_result=-1，如未结算直接进入结算场景）
	Game.state_machine.game_result = -1
	_spawn_result_scene()
	assert_false(FileAccess.file_exists(_path), "未取得有效胜负结果时不应归档")
	assert_eq(ArchiveManager.archive.get("win_total", 0), 0, "未结算时内存档案不应被更新")


# ============================================================
# 防重入：同一结算页实例只归档一次
# ============================================================

func test_record_archive_runs_once_per_scene_instance() -> void:
	_setup_finished_game(GameStateMachine.GameResult.WIN)
	var scene: Node = _spawn_result_scene()
	assert_eq(ArchiveManager.archive.get("win_total"), 1, "首次 _ready 归档后 win_total 应为 1")
	# 模拟 _ready 重复触发/场景重入：再次调用归档私有函数应被防重入标记拦截
	scene.call("_record_archive", GameStateMachine.GameResult.WIN)
	assert_eq(ArchiveManager.archive.get("win_total"), 1, "二次触发归档不应重复累计 win_total")
	assert_eq(ArchiveManager.archive["survivors"]["firefighter"]["total_kills"], 1,
		"击杀数不应被重复累计")
