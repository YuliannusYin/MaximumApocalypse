extends GutTest

## 集成测试：任务系统三层架构全链路。
## 覆盖：任务 JSON 声明（win_conditions / actions / mission_script）→
## Game._mount_mission_components 注册表实例化 → MissionConfig 编排
## （setup_components / check_win / check_lose / get_action_options / on_event）→
## GameStateMachine.check_win_condition 判定链（失败优先 → 组件 AND + 脚本 → 面包车判定），
## 以及 EventBus 信号 → Game 事件转发、player.wait_player_action 的 mission_action 路径。
## 对应任务配置：mission_1（解救科学家）/ mission_10（运输）。
## 脚本通道（第三层）不依赖具体任务脚本，使用内嵌 StubMissionScript
## 覆盖挂载 / on_event 转发 / 选项聚合 / check_win / check_lose 的通用链路。


# === 测试用内嵌任务脚本 ===

# 临时任务脚本：通过 mission_state 键（stub_*）驱动行为，
# 用于验证第三层通用脚本通道（挂载 / setup / on_event / 选项聚合 / 判定链）。
class StubMissionScript extends MissionScript:
	func setup(game: Game, mission_config: MissionConfig) -> void:
		mission_config.mission_state["stub_setup_done"] = true


	func on_event(game: Game, event_name: String, event: Dictionary) -> void:
		var state: Dictionary = _state(game)
		state["stub_last_event"] = event_name
		if event_name == "objective_mark_triggered":
			state["stub_mark_reached"] = true


	func get_action_options(game: Game, player: Player) -> Array:
		if player == null or not is_instance_valid(player) or player.action_count < 1:
			return []
		if not _state(game).get("stub_option_available", false):
			return []
		return [{
			"id": "stub_script_action",
			"label": "临时脚本行动",
			"execute": func() -> void:
				_state(game)["stub_action_done"] = true
				player.reduce_action_count(1),
		}]


	func check_win(game: Game) -> bool:
		return _state(game).get("stub_win", false)


	func check_lose(game: Game) -> bool:
		return _state(game).get("stub_lose", false)


	func _state(game: Game) -> Dictionary:
		if game != null and game.mission_config != null:
			return game.mission_config.mission_state
		return {}


# === 辅助方法 ===

func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_card(card_name: String = "test_card") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.card_type = "action"
	c.source = "game"
	return c


func _make_block(block_name: String = "B", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = block_name
	b.set_coordinate(x, y)
	b.revealed = true
	return b


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
	Game.coop_death_mode = false
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


## 轮询等待条件成立（on_event 转发链路含协程时的时序兜底），超时返回最后一次求值。
func _wait_until(condition: Callable, timeout_sec: float = 2.0) -> bool:
	var waited: float = 0.0
	while waited < timeout_sec:
		if condition.call():
			return true
		await get_tree().create_timer(0.02).timeout
		waited += 0.02
	return condition.call()


## 设置玩家、地图与全局牌堆，并进入 PLAYING 状态。
func _setup_game_env(players: Array, map_blocks: Array = []) -> void:
	Game.players = players
	Game.map_area = map_blocks
	Game.monster_pile = Pile.new()
	Game.monster_discard_pile = Pile.new()
	Game.scavenge_discard_pile = Pile.new()
	Game.red_scavenge_pile = Pile.new()
	Game.green_scavenge_pile = Pile.new()
	Game.blue_scavenge_pile = Pile.new()
	Game.state_machine.transition_to(GameStateMachine.GameState.PLAYING)


## 构造任务 1 风格 MissionConfig（escort + spend_action_rescue + 面包车燃料），挂到 Game。
func _make_mission_1_config() -> MissionConfig:
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = 4
	mc.win_condition_components.append(MissionComponentRegistry.create(
		"escort_equipment_at_block",
		{"card_name": "科学家", "block_name": "面包车"}))
	mc.action_components.append(MissionComponentRegistry.create(
		"spend_action_rescue",
		{"block_name": "警察局", "cost": 2, "card_name": "科学家"}))
	mc.setup_components(Game)
	Game.mission_config = mc
	return mc


## 构造挂载临时脚本的 MissionConfig（不通过面包车胜利），挂到 Game。
func _make_script_config() -> MissionConfig:
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = -1
	mc.mission_script_instance = StubMissionScript.new()
	mc.setup_components(Game)
	Game.mission_config = mc
	return mc


## 构造任务 10 风格 MissionConfig（collect_items + all_players_at_block），挂到 Game。
func _make_mission_10_config() -> MissionConfig:
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = -1
	mc.win_condition_components.append(MissionComponentRegistry.create(
		"collect_items", {"items": {"燃料": 2, "医疗用品": 1}}))
	mc.win_condition_components.append(MissionComponentRegistry.create(
		"all_players_at_block", {"block_name": "军事基地"}))
	mc.setup_components(Game)
	Game.mission_config = mc
	return mc


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()
	# 清理挂载用例注册的临时脚本 id，避免泄漏到其他用例
	MissionScriptRegistry.reset()


# === 1. 任务 JSON 声明 → 组件/脚本挂载（真实数据） ===

func test_mission_1_json_mounts_rescue_and_escort_components() -> void:
	var mission: MissionData = DataManager.get_mission(1)
	assert_not_null(mission, "任务 1 数据应已加载")
	if mission == null:
		return
	Game.mission_config = MissionConfig.new()
	Game._mount_mission_components(mission)
	assert_eq(Game.mission_config.win_condition_components.size(), 1, "任务 1 应挂载 1 个胜利组件")
	var win_c: MissionComponent = Game.mission_config.win_condition_components[0]
	assert_true(win_c is MissionComponentEscortEquipmentAtBlock, "胜利组件应为 escort_equipment_at_block")
	assert_eq(win_c.params.get("card_name"), "科学家", "护送卡牌应为科学家")
	assert_eq(win_c.params.get("block_name"), "面包车", "护送目标应为面包车")
	assert_eq(Game.mission_config.action_components.size(), 1, "任务 1 应挂载 1 个行动选项组件")
	var act_c: MissionComponent = Game.mission_config.action_components[0]
	assert_true(act_c is MissionComponentSpendActionRescue, "行动组件应为 spend_action_rescue")
	assert_eq(act_c.params.get("block_name"), "警察局", "解救地点应为警察局")
	assert_eq(int(act_c.params.get("cost")), 2, "解救消耗应为 2 行动")
	assert_eq(act_c.params.get("card_name"), "科学家", "解救卡牌应为科学家")
	assert_eq(Game.mission_config.lose_condition_components.size(), 1, "任务 1 应挂载 1 个失败组件")
	assert_true(Game.mission_config.lose_condition_components[0] is MissionComponentCardDiscardWatch,
		"失败组件应为 card_discard_watch")
	assert_eq(Game.mission_config.lose_condition_components[0].params.get("on_discard"), "lose",
		"科学家弃置时应判负")
	assert_null(Game.mission_config.mission_script_instance, "任务 1 无专用脚本")


func test_mission_json_mounts_script_via_registry() -> void:
	# 临时注册内嵌脚本，验证 JSON mission_script 声明 → 注册表实例化 → 挂载的通用通道
	MissionScriptRegistry.reset()
	MissionScriptRegistry.register("stub_mission_script", StubMissionScript)
	var mission: MissionData = MissionData.new({"mission_id": 99, "mission_script": "stub_mission_script"})
	Game.mission_config = MissionConfig.new()
	Game._mount_mission_components(mission)
	assert_eq(Game.mission_config.win_condition_components.size(), 0, "无 win_conditions 声明不应挂载胜利组件")
	assert_not_null(Game.mission_config.mission_script_instance, "声明 mission_script 的任务应挂载脚本实例")
	assert_true(Game.mission_config.mission_script_instance is StubMissionScript, "脚本应由注册表按 id 实例化")
	MissionScriptRegistry.reset()


func test_mission_10_json_mounts_collect_and_rally_components() -> void:
	var mission: MissionData = DataManager.get_mission(10)
	assert_not_null(mission, "任务 10 数据应已加载")
	if mission == null:
		return
	Game.mission_config = MissionConfig.new()
	Game._mount_mission_components(mission)
	assert_eq(Game.mission_config.win_condition_components.size(), 2, "任务 10 应挂载 2 个胜利组件")
	var collect: MissionComponent = Game.mission_config.win_condition_components[0]
	assert_true(collect is MissionComponentCollectItems, "第 1 个胜利组件应为 collect_items")
	# JSON 数字解析为 float，逐键转 int 比较避免类型差异
	var items: Dictionary = collect.params.get("items")
	assert_eq(items.size(), 4, "收集清单应含 4 种物品")
	assert_eq(int(items.get("燃料")), 6, "燃料需求应为 6")
	assert_eq(int(items.get("脏毯子")), 3, "脏毯子需求应为 3")
	assert_eq(int(items.get("医疗用品")), 2, "医疗用品需求应为 2")
	assert_eq(int(items.get("多余配件")), 2, "多余配件需求应为 2")
	var rally: MissionComponent = Game.mission_config.win_condition_components[1]
	assert_true(rally is MissionComponentAllPlayersAtBlock, "第 2 个胜利组件应为 all_players_at_block")
	assert_eq(rally.params.get("block_name"), "军事基地", "集结地点应为军事基地")
	assert_eq(rally.params.get("no_monster"), true, "集结地点应要求无怪物")
	assert_eq(Game.mission_config.action_components.size(), 1, "任务 10 应挂载 1 个行动组件")
	var submit: MissionComponent = Game.mission_config.action_components[0]
	assert_true(submit is MissionComponentSubmitItems, "行动组件应为 submit_items")
	assert_eq(submit.params.get("block_name"), "军事基地", "提交地点应为军事基地")
	assert_eq(int(submit.params.get("items", {}).get("燃料")), 6, "提交清单燃料应为 6")
	assert_null(Game.mission_config.mission_script_instance, "任务 10 无专用脚本")


# === 2. 任务 10 组件胜利路径（收集 + 全员集结） ===

func test_mission_10_component_win_path() -> void:
	var mc: MissionConfig = _make_mission_10_config()
	var p1: Player = _make_player("P1")
	p1.hand.append(_make_card("燃料"))
	p1.hand.append(_make_card("燃料"))
	var p2: Player = _make_player("P2")
	p2.hand.append(_make_card("医疗用品"))
	p1.current_block = _make_block("军事基地", 0, 0)
	p2.current_block = _make_block("军事基地", 1, 0)
	_setup_game_env([p1, p2])
	var result: bool = Game.state_machine.check_win_condition()
	assert_true(result, "物品集齐且全员在军事基地应胜利")
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.WIN, "结果应为 WIN")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")
	assert_eq(mc.mission_state.size(), 0, "纯组件任务不应写入 mission_state")


func test_mission_10_fails_when_player_not_at_base() -> void:
	_make_mission_10_config()
	var p1: Player = _make_player("P1")
	p1.hand.append(_make_card("燃料"))
	p1.hand.append(_make_card("燃料"))
	var p2: Player = _make_player("P2")
	p2.hand.append(_make_card("医疗用品"))
	p1.current_block = _make_block("军事基地", 0, 0)
	p2.current_block = _make_block("加油站", 1, 0)
	_setup_game_env([p1, p2])
	assert_false(Game.state_machine.check_win_condition(), "有玩家未到军事基地不应胜利")
	assert_false(Game.state_machine.is_game_over(), "不应进入 GAME_OVER")


func test_mission_10_fails_when_items_insufficient() -> void:
	_make_mission_10_config()
	var p1: Player = _make_player("P1")
	p1.hand.append(_make_card("燃料"))
	var p2: Player = _make_player("P2")
	p2.hand.append(_make_card("医疗用品"))
	p1.current_block = _make_block("军事基地", 0, 0)
	p2.current_block = _make_block("军事基地", 1, 0)
	_setup_game_env([p1, p2])
	assert_false(Game.state_machine.check_win_condition(), "燃料数量不足（1/2）不应胜利")
	assert_false(Game.state_machine.is_game_over(), "不应进入 GAME_OVER")


# === 3. 任务 1 解救 + 护送 + 面包车路径 ===

func test_mission_1_rescue_action_via_wait_player_action() -> void:
	_make_mission_1_config()
	var police: MapBlock = _make_block("警察局", 0, 0)
	var van: MapBlock = _make_block("面包车", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 4
	p.current_block = police
	p.input = CliPlayerInput.new()
	p.input.queue_action({"type": "mission_action", "option_id": "rescue_科学家"})
	_setup_game_env([p], [police, van])
	var options: Array = Game.mission_config.get_action_options(Game, p)
	assert_eq(options.size(), 1, "在警察局且行动足够应出现解救选项")
	assert_eq(options[0]["id"], "rescue_科学家", "选项 id 应为 rescue_科学家")
	await p.wait_player_action()
	var state: Dictionary = Game.mission_config.mission_state
	assert_true(state.get("scientist_rescued"), "执行后应标记 scientist_rescued")
	assert_eq(state.get("scientist_holder"), p, "解救者应为该玩家")
	assert_eq(p.action_count, 2, "解救应消耗 2 点行动（4 → 2）")
	assert_true(p.has_equipment("科学家"), "科学家应装备到玩家装备区")
	assert_eq(Game.mission_config.get_action_options(Game, p).size(), 0, "解救后选项应消失")


func test_mission_1_rescue_then_escort_to_van_wins() -> void:
	_make_mission_1_config()
	var police: MapBlock = _make_block("警察局", 0, 0)
	var van: MapBlock = _make_block("面包车", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 4
	p.current_block = police
	_setup_game_env([p], [police, van])
	var options: Array = Game.mission_config.get_action_options(Game, p)
	assert_eq(options.size(), 1, "应出现解救选项")
	await options[0]["execute"].call()
	assert_true(Game.mission_config.mission_state.get("scientist_rescued"), "解救应完成")
	# 护送：移动到面包车并加满燃料
	p.current_block = van
	van.van_fuel = 4
	assert_true(Game.state_machine.check_win_condition(), "解救+持有者在面包车+燃料足够应胜利")
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.WIN, "结果应为 WIN")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")


func test_mission_1_van_conditions_without_rescue_no_win() -> void:
	_make_mission_1_config()
	var police: MapBlock = _make_block("警察局", 0, 0)
	var van: MapBlock = _make_block("面包车", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 4
	p.current_block = van
	_setup_game_env([p], [police, van])
	van.van_fuel = 4
	assert_false(Game.state_machine.check_win_condition(), "科学家未解救时即使面包车条件满足也不应胜利")
	assert_false(Game.state_machine.is_game_over(), "不应进入 GAME_OVER")


func test_mission_1_rescue_option_hidden_when_conditions_unmet() -> void:
	_make_mission_1_config()
	var police: MapBlock = _make_block("警察局", 0, 0)
	var van: MapBlock = _make_block("面包车", 1, 0)
	var p: Player = _make_player("P")
	p.action_count = 4
	_setup_game_env([p], [police, van])
	p.current_block = van
	assert_eq(Game.mission_config.get_action_options(Game, p).size(), 0, "不在警察局不应出现解救选项")
	p.current_block = police
	p.action_count = 1
	assert_eq(Game.mission_config.get_action_options(Game, p).size(), 0, "行动数不足（1 < 2）不应出现解救选项")


# === 4. 任务脚本通用通道（手动置 mission_state 验证判定链） ===

func test_script_action_options_aggregate_and_execute() -> void:
	var mc: MissionConfig = _make_script_config()
	var p: Player = _make_player("P")
	p.action_count = 2
	_setup_game_env([p])
	var state: Dictionary = mc.mission_state
	assert_true(state.get("stub_setup_done"), "setup_components 应调用脚本 setup 钩子")
	# 选项聚合：脚本选项应合并进 MissionConfig.get_action_options
	state["stub_option_available"] = true
	var options: Array = mc.get_action_options(Game, p)
	assert_eq(options.size(), 1, "脚本应提供行动选项并聚合进 MissionConfig")
	assert_eq(options[0]["id"], "stub_script_action", "选项 id 应为脚本声明值")
	await options[0]["execute"].call()
	assert_true(state.get("stub_action_done"), "执行选项应触发脚本 execute")
	assert_eq(p.action_count, 1, "选项执行应消耗 1 点行动")
	# 判定链：脚本 check_win 为 false 时阻断胜利
	assert_false(Game.state_machine.check_win_condition(), "脚本 check_win 为 false 时不应胜利")
	assert_false(Game.state_machine.is_game_over(), "不应进入 GAME_OVER")
	# 判定链：脚本 check_win 为 true 时参与胜利判定（van_fuel_required=-1 直接胜利）
	state["stub_win"] = true
	assert_true(Game.state_machine.check_win_condition(), "脚本 check_win 为 true 时应胜利")
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.WIN, "结果应为 WIN")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")


func test_script_check_lose_has_priority_over_win() -> void:
	var mc: MissionConfig = _make_script_config()
	var p: Player = _make_player("P")
	_setup_game_env([p])
	var state: Dictionary = mc.mission_state
	# 同时满足脚本胜利条件与失败条件
	state["stub_win"] = true
	state["stub_lose"] = true
	var result: bool = Game.state_machine.check_win_condition()
	assert_true(result, "脚本失败条件满足应终止游戏")
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.LOSE, "失败应优先于胜利")
	assert_eq(Game.game_result, "lose", "Game.game_result 应为 lose")


# === 5. EventBus 全链路（地块触发 → 脚本 on_event） ===

func test_event_bus_chain_forwards_to_mission_script() -> void:
	var mc: MissionConfig = _make_script_config()
	var p: Player = _make_player("P")
	var marked: MapBlock = _make_block("坠毁点", 0, 0)
	marked.add_objective_mark({"mark_id": "mark_1"})
	p.current_block = marked
	_setup_game_env([p], [marked])
	var state: Dictionary = mc.mission_state
	# 地块 → EventBus → Game → mission_config.on_event → 脚本
	await marked.trigger_objective_marks(p)
	assert_true(await _wait_until(func(): return state.get("stub_mark_reached", false)), "objective_mark_triggered 应转发到脚本 on_event")
	assert_eq(state.get("stub_last_event"), "objective_mark_triggered", "事件名应正确转发")
