extends GutTest

## 任务 8「情报恢复」专用脚本（Mission8IntelRecovery）单元测试。
## 覆盖：注册表内置注册、setup 状态默认值、check_win 三态、check_lose、
## get_action_options 条件分支、_do_rescue 解救流程与选项 execute 调用。
## 说明：on_event 的 objective_mark_triggered 完整链路含随机投骰（sneak_judge），
## 留给集成测试；此处通过手动置 mission_state 键验证各分支判定逻辑。


# === 辅助方法 ===

func _make_player(hp: int = 10, max_hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.hp = hp
	p.max_hp = max_hp
	p.player_name = "TestPlayer"
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_block(block_name: String = "test_block", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = block_name
	b.set_coordinate(x, y)
	return b


func _setup_game_for_player(p: Player) -> void:
	Game.players = [p]
	Game.map_area = []
	Game.monster_pile = Pile.new()
	Game.monster_discard_pile = Pile.new()
	Game.scavenge_discard_pile = Pile.new()
	Game.red_scavenge_pile = Pile.new()
	Game.green_scavenge_pile = Pile.new()
	Game.blue_scavenge_pile = Pile.new()
	Game.coop_death_mode = false
	Game.mission_config = null
	Game.removed_cards = []
	Game.game_over_called = false
	Game.game_result = ""
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func _clear_game() -> void:
	Game.players = []
	Game.map_area = []
	Game.monster_pile = null
	Game.monster_discard_pile = null
	Game.scavenge_discard_pile = null
	Game.red_scavenge_pile = null
	Game.green_scavenge_pile = null
	Game.blue_scavenge_pile = null
	Game.mission_config = null
	Game.removed_cards = []
	Game.game_over_called = false
	Game.game_result = ""
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


## 创建已 setup 的脚本实例：新建 MissionConfig 挂到 Game 并初始化 mission_state 默认键。
func _make_script() -> Mission8IntelRecovery:
	var mc: MissionConfig = MissionConfig.new()
	mc.mission_state = {}
	Game.mission_config = mc
	var script: Mission8IntelRecovery = Mission8IntelRecovery.new()
	script.setup(Game, mc)
	return script


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()


# === 1. 注册表内置注册 ===

func test_registry_builtin_registered() -> void:
	assert_true(MissionScriptRegistry.has("mission_8_intel_recovery"), "内置脚本应已注册")
	var script: MissionScript = MissionScriptRegistry.create("mission_8_intel_recovery")
	assert_not_null(script, "create 应返回实例")
	assert_true(script is Mission8IntelRecovery, "实例应为 Mission8IntelRecovery")
	assert_eq(script.params, {}, "缺省 params 应为空字典")


# === 2. setup 状态默认值 ===

func test_setup_initializes_state_defaults() -> void:
	var script: Mission8IntelRecovery = _make_script()
	var state: Dictionary = Game.mission_config.mission_state
	assert_false(state.get("intel_attempted", true), "intel_attempted 默认 false")
	assert_false(state.get("scientist_available", true), "scientist_available 默认 false")
	assert_false(state.get("scientist_rescued", true), "scientist_rescued 默认 false")
	assert_null(state.get("scientist_holder"), "scientist_holder 默认 null")
	assert_false(state.get("scientist_info_recorded", true), "scientist_info_recorded 默认 false")
	assert_null(state.get("info_recorder"), "info_recorder 默认 null")
	assert_false(state.get("intel_failed_no_diary", true), "intel_failed_no_diary 默认 false")


# === 3. check_win 三态 ===

func test_check_win_default_false() -> void:
	var script: Mission8IntelRecovery = _make_script()
	assert_false(script.check_win(Game), "未做任何事不应胜利")


func test_check_win_rescued_holder_at_base() -> void:
	var script: Mission8IntelRecovery = _make_script()
	var p: Player = _make_player()
	p.current_block = _make_block("军事基地")
	var state: Dictionary = Game.mission_config.mission_state
	state["scientist_rescued"] = true
	state["scientist_holder"] = p
	assert_true(script.check_win(Game), "科学家被解救且持有者在军事基地应胜利")


func test_check_win_rescued_holder_elsewhere() -> void:
	var script: Mission8IntelRecovery = _make_script()
	var p: Player = _make_player()
	p.current_block = _make_block("加油站")
	var state: Dictionary = Game.mission_config.mission_state
	state["scientist_rescued"] = true
	state["scientist_holder"] = p
	assert_false(script.check_win(Game), "持有者在其他地块不应胜利")


func test_check_win_rescued_holder_dead() -> void:
	var script: Mission8IntelRecovery = _make_script()
	var p: Player = _make_player(0, 10)
	p.current_block = _make_block("军事基地")
	var state: Dictionary = Game.mission_config.mission_state
	state["scientist_rescued"] = true
	state["scientist_holder"] = p
	assert_false(script.check_win(Game), "持有者已死亡不应胜利")


func test_check_win_rescued_holder_no_block() -> void:
	var script: Mission8IntelRecovery = _make_script()
	var p: Player = _make_player()
	var state: Dictionary = Game.mission_config.mission_state
	state["scientist_rescued"] = true
	state["scientist_holder"] = p
	assert_false(script.check_win(Game), "持有者不在任何地块不应胜利")


func test_check_win_info_recorded_recorder_at_base() -> void:
	var script: Mission8IntelRecovery = _make_script()
	var p: Player = _make_player()
	p.current_block = _make_block("军事基地")
	var state: Dictionary = Game.mission_config.mission_state
	state["scientist_info_recorded"] = true
	state["info_recorder"] = p
	assert_true(script.check_win(Game), "信息被记录且记录者在军事基地应胜利")


func test_check_win_info_recorded_recorder_elsewhere() -> void:
	var script: Mission8IntelRecovery = _make_script()
	var p: Player = _make_player()
	p.current_block = _make_block("医院")
	var state: Dictionary = Game.mission_config.mission_state
	state["scientist_info_recorded"] = true
	state["info_recorder"] = p
	assert_false(script.check_win(Game), "记录者在其他地块不应胜利")


# === 4. check_lose ===

func test_check_lose_default_false() -> void:
	var script: Mission8IntelRecovery = _make_script()
	assert_false(script.check_lose(Game), "默认不应失败")


func test_check_lose_no_diary_true() -> void:
	var script: Mission8IntelRecovery = _make_script()
	Game.mission_config.mission_state["intel_failed_no_diary"] = true
	assert_true(script.check_lose(Game), "检定失败且无日记本应失败")


# === 5. get_action_options 条件 ===

func test_action_options_not_available() -> void:
	var script: Mission8IntelRecovery = _make_script()
	var p: Player = _make_player()
	p.action_count = 2
	assert_eq(script.get_action_options(Game, p).size(), 0, "科学家未待解救时无选项")


func test_action_options_available() -> void:
	var script: Mission8IntelRecovery = _make_script()
	var p: Player = _make_player()
	p.action_count = 2
	Game.mission_config.mission_state["scientist_available"] = true
	var options: Array = script.get_action_options(Game, p)
	assert_eq(options.size(), 1, "待解救且有行动时应提供 1 个选项")
	assert_eq(options[0]["id"], "mission_8_rescue_scientist", "选项 id 应正确")
	assert_eq(options[0]["label"], "花费 1 行动解救科学家", "选项 label 应正确")
	assert_true(options[0]["execute"] is Callable, "选项应携带 execute 可调用对象")


func test_action_options_empty_after_rescued() -> void:
	var script: Mission8IntelRecovery = _make_script()
	var p: Player = _make_player()
	p.action_count = 2
	var state: Dictionary = Game.mission_config.mission_state
	state["scientist_available"] = true
	state["scientist_rescued"] = true
	assert_eq(script.get_action_options(Game, p).size(), 0, "已解救后不再提供选项")


func test_action_options_empty_when_no_action() -> void:
	var script: Mission8IntelRecovery = _make_script()
	var p: Player = _make_player()
	p.action_count = 0
	Game.mission_config.mission_state["scientist_available"] = true
	assert_eq(script.get_action_options(Game, p).size(), 0, "无行动次数时不提供选项")


# === 6. _do_rescue 解救流程 ===

func test_do_rescue_flow() -> void:
	var p: Player = _make_player()
	p.action_count = 3
	_setup_game_for_player(p)
	var script: Mission8IntelRecovery = _make_script()
	var state: Dictionary = Game.mission_config.mission_state
	state["scientist_available"] = true
	await script._do_rescue(Game, p)
	assert_true(state["scientist_rescued"], "解救后 scientist_rescued 应为 true")
	assert_eq(state["scientist_holder"], p, "解救后 scientist_holder 应为该玩家")
	assert_false(state["scientist_available"], "解救后 scientist_available 应回到 false")
	assert_eq(p.action_count, 2, "行动数应减 1")
	assert_eq(p.equipment_zone.size(), 1, "装备区应出现科学家卡")
	assert_eq(p.equipment_zone[0].card_name, "科学家", "装备区卡牌应为科学家")
	var logged: bool = false
	for msg in Game.log_list:
		if "解救了科学家" in msg:
			logged = true
	assert_true(logged, "应输出解救日志")


func test_rescue_option_execute_callable() -> void:
	var p: Player = _make_player()
	p.action_count = 2
	_setup_game_for_player(p)
	var script: Mission8IntelRecovery = _make_script()
	var state: Dictionary = Game.mission_config.mission_state
	state["scientist_available"] = true
	var options: Array = script.get_action_options(Game, p)
	assert_eq(options.size(), 1, "应提供解救选项")
	await options[0]["execute"].call()
	assert_true(state["scientist_rescued"], "执行选项后应完成解救")
	assert_eq(p.action_count, 1, "执行选项后行动数应减 1")
	assert_eq(p.equipment_zone.size(), 1, "执行选项后装备区应有科学家卡")
