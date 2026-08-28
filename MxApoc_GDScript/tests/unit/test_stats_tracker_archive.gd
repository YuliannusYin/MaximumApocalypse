extends GutTest

## StatsTracker 归档扩展单元测试。
## 覆盖：玩家→survivor_id 映射、按单个怪物（english_name）击杀数、首领击杀归属、
## get_archive_summary() 结构完整性（result/duration_msec/player_count/mission_id/survivors/monsters）。
## 对应 spec：.trae/specs/refine-achievement-ui-monster-stats/spec.md（怪物统计细化）

var _tracker: StatsTracker


# === 辅助方法 ===

func _make_test_player(survivor_english_name: String, hp: int = 32, max_hp: int = 32) -> Player:
	var p: Player = Player.new()
	p.player_name = "测试玩家"
	p.hp = hp
	p.max_hp = max_hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	p.in_phase = "action"
	p.action_count = 2
	if survivor_english_name != "":
		var rc: RoleCard = RoleCard.new()
		rc.role_name = survivor_english_name
		rc.english_name = survivor_english_name
		p.role_card = rc
	return p


## 构造怪物实例。english_name 为归档统计键；monster_level 供首领击杀归属判定。
func _make_monster(english_name: String, monster_level: String) -> Monster:
	var mc: MonsterCard = MonsterCard.new()
	mc.card_name = "test_monster_" + english_name
	mc.english_name = english_name
	mc.monster_type = "zombie"
	mc.monster_level = monster_level
	mc.max_hp = 3
	mc.damage_value = 2
	mc.range = "none"
	return mc.instantiate(null)


func _reset_game_globals() -> void:
	Game.current_mission = null
	Game.game_result = ""
	Game.game_over_called = false
	Game.mission_config = null
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func before_each() -> void:
	_tracker = StatsTracker.new()
	_reset_game_globals()


func after_each() -> void:
	_reset_game_globals()


# === 玩家→survivor_id 映射 ===

func test_survivor_id_mapping() -> void:
	var p1: Player = _make_test_player("firefighter")
	var p2: Player = _make_test_player("hunter")
	var no_role: Player = _make_test_player("")
	_tracker.reset([p1, p2, no_role])
	assert_eq(_tracker.get_survivor_id(p1), "firefighter", "应从角色卡 english_name 读取 survivor id")
	assert_eq(_tracker.get_survivor_id(p2), "hunter", "应从角色卡 english_name 读取 survivor id")
	assert_eq(_tracker.get_survivor_id(no_role), "", "无角色卡玩家不应有 survivor id")


func test_survivor_mapping_reset_with_new_players() -> void:
	var p1: Player = _make_test_player("firefighter")
	var p2: Player = _make_test_player("gunslinger")
	_tracker.reset([p1])
	_tracker.reset([p2])
	assert_eq(_tracker.get_survivor_id(p1), "", "reset 后旧玩家映射应清除")
	assert_eq(_tracker.get_survivor_id(p2), "gunslinger", "reset 应记录新玩家映射")


# === 单个怪物击杀计数 ===

func test_monster_kills_by_english_name() -> void:
	var p: Player = _make_test_player("firefighter")
	_tracker.reset([p])
	EventBus.monster_died.emit(_make_monster("zombie_dog", "normal"), p)
	EventBus.monster_died.emit(_make_monster("zombie_dog", "normal"), p)
	EventBus.monster_died.emit(_make_monster("zombie_queen", "boss"), p)
	var summary: Dictionary = _tracker.get_archive_summary()
	var monsters: Dictionary = summary["monsters"]
	assert_eq(monsters.get("zombie_dog", 0), 2, "zombie_dog 击杀数应为 2")
	assert_eq(monsters.get("zombie_queen", 0), 1, "zombie_queen（boss）击杀数应为 1")
	assert_false(monsters.has("zombie"), "monsters 不应再出现 monster_type 类型级键")
	assert_eq(_tracker.get_stats(p).kills, 3, "玩家总击杀数应为 3")


func test_monster_kills_counted_without_player_source() -> void:
	# 无击杀来源（source=null，如地块效果致死）的怪物死亡也应计入分型击杀数
	var p: Player = _make_test_player("firefighter")
	_tracker.reset([p])
	EventBus.monster_died.emit(_make_monster("robot_scout", "normal"), null)
	var summary: Dictionary = _tracker.get_archive_summary()
	assert_eq(summary["monsters"].get("robot_scout", 0), 1, "无来源怪物死亡应计入分型击杀数")
	assert_eq(_tracker.get_stats(p).kills, 0, "无来源时不计入玩家击杀数")


func test_monster_kills_missing_english_name_fallback_unknown() -> void:
	# english_name 缺失/为空时以 "unknown" 兜底计数（击杀数据不丢失）
	var p: Player = _make_test_player("firefighter")
	_tracker.reset([p])
	EventBus.monster_died.emit(_make_monster("", "normal"), p)
	var summary: Dictionary = _tracker.get_archive_summary()
	assert_eq(summary["monsters"].get("unknown", 0), 1, "english_name 为空时应以 unknown 兜底计数")


# === 首领击杀归属 ===

func test_boss_kill_attribution() -> void:
	var p1: Player = _make_test_player("firefighter")
	var p2: Player = _make_test_player("surgeon")
	_tracker.reset([p1, p2])
	EventBus.monster_died.emit(_make_monster("zombie_queen", "boss"), p1)
	EventBus.monster_died.emit(_make_monster("zombie_dog", "normal"), p1)
	EventBus.monster_died.emit(_make_monster("alien_queen", "boss"), p2)
	var summary: Dictionary = _tracker.get_archive_summary()
	var survivors: Dictionary = summary["survivors"]
	assert_eq(survivors["firefighter"]["boss_kills"], 1, "firefighter 首领击杀数应为 1")
	assert_eq(survivors["surgeon"]["boss_kills"], 1, "surgeon 首领击杀数应为 1")
	assert_eq(survivors["firefighter"]["kills"], 2, "firefighter 总击杀数应为 2（首领+普通）")


# === get_archive_summary() 结构 ===

func test_archive_summary_structure() -> void:
	var p: Player = _make_test_player("mechanic")
	_tracker.reset([p])
	# 累计统计：造成伤害 / 治疗 / 回合数 / 击杀
	EventBus.damage_dealt.emit(p, _make_monster("zombie_dog", "normal"), 5)
	EventBus.healing_done.emit(p, p, 3)
	EventBus.player_turn_started.emit(p)
	EventBus.monster_died.emit(_make_monster("zombie_dog", "normal"), p)
	_tracker.game_duration_msec = 12345
	# 任务与胜负来源
	Game.current_mission = MissionData.new({"mission_id": 7})
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.game_result = GameStateMachine.GameResult.WIN
	var summary: Dictionary = _tracker.get_archive_summary()
	# 顶层键完整
	assert_has(summary, "result", "summary 应含 result 键")
	assert_has(summary, "duration_msec", "summary 应含 duration_msec 键")
	assert_has(summary, "player_count", "summary 应含 player_count 键")
	assert_has(summary, "mission_id", "summary 应含 mission_id 键")
	assert_has(summary, "survivors", "summary 应含 survivors 键")
	assert_has(summary, "monsters", "summary 应含 monsters 键")
	# 顶层值
	assert_eq(summary["result"], "win", "result 应从状态机读取为 win")
	assert_eq(summary["duration_msec"], 12345, "duration_msec 应取 game_duration_msec")
	assert_eq(summary["player_count"], 1, "player_count 应为本局玩家数")
	assert_eq(summary["mission_id"], 7, "mission_id 应从 Game.current_mission 读取")
	# survivors 内层键完整
	var survivors: Dictionary = summary["survivors"]
	assert_true(survivors.has("mechanic"), "survivors 应以 survivor id 为键")
	var s: Dictionary = survivors["mechanic"]
	assert_has(s, "damage", "survivor 统计应含 damage 键")
	assert_has(s, "kills", "survivor 统计应含 kills 键")
	assert_has(s, "healing", "survivor 统计应含 healing 键")
	assert_has(s, "turns", "survivor 统计应含 turns 键")
	assert_has(s, "boss_kills", "survivor 统计应含 boss_kills 键")
	# survivors 内层值
	assert_eq(s["damage"], 5, "damage 应为造成伤害量")
	assert_eq(s["kills"], 1, "kills 应为击杀数")
	assert_eq(s["healing"], 3, "healing 应为治疗量")
	assert_eq(s["turns"], 1, "turns 应为回合数")
	assert_eq(s["boss_kills"], 0, "无首领击杀时应为 0")
	# monsters
	assert_eq(summary["monsters"].get("zombie_dog", 0), 1, "monsters 应按单个怪物 english_name 统计")


func test_archive_summary_result_fallback_and_override() -> void:
	var p: Player = _make_test_player("hunter")
	_tracker.reset([p])
	# 状态机未结束时 result 为空（由调用方注入）
	assert_eq(_tracker.get_archive_summary()["result"], "", "状态机无结果时应为空串")
	# 调用方注入优先
	assert_eq(_tracker.get_archive_summary("win")["result"], "win", "result_override 应优先")
	# 状态机失败结果
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.game_result = GameStateMachine.GameResult.LOSE
	assert_eq(_tracker.get_archive_summary()["result"], "lose", "状态机失败结果应映射为 lose")
	assert_eq(_tracker.get_archive_summary("win")["result"], "win", "注入值应优先于状态机")


func test_archive_summary_defaults_without_game_context() -> void:
	# 无任务数据时 mission_id 为 -1；未计时 duration_msec 为 0；无事件 monsters/survivors 为空
	Game.current_mission = null
	var p: Player = _make_test_player("veteran")
	_tracker.reset([p])
	var summary: Dictionary = _tracker.get_archive_summary("lose")
	assert_eq(summary["mission_id"], -1, "无任务数据时 mission_id 应为 -1")
	assert_eq(summary["duration_msec"], 0, "未计时时 duration_msec 应为 0")
	assert_eq(summary["player_count"], 1, "player_count 应统计玩家数")
	assert_eq(summary["survivors"].size(), 1, "有 survivor id 的玩家应进入 survivors")
	assert_eq(summary["monsters"].size(), 0, "无怪物死亡时 monsters 应为空")
