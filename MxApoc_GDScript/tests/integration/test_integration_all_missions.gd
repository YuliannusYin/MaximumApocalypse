extends GutTest

## 集成测试：全部 13 个任务的关键路径（已批准 spec implement-all-13-missions Task 8）。
## A 部分（挂载验证）：真实任务 JSON 经 Game.initialize_game 全流程挂载，
##   断言 mission_config 各组件数组（win/lose/trigger/action）的实例类型与数量，
##   对照 data/missions/mission_*.json 实际配置；setup_components 已随 initialize_game 调用，
##   对会写 mission_state 的组件（kill_monsters / defuse_bomb / turn_countdown /
##   repair_van / rescue_judge_win）断言初始化副作用。
## B 部分（关键路径）：逐任务胜利/失败路径。优先手动搭建
##   （_mount_mission 轻量挂载真实 JSON 组件 + 手动构造玩家/地块），
##   仅开局装备（setup_equip_card）与 no_initial_monster_draw 类验证走真实 initialize_game。
## 判定链（回合结束 check_win_condition）：先 lose（任一组件 true）→ game_over(LOSE)；
##   再 win（全部组件 true）→ van_fuel_required<0 直接 WIN，否则面包车判定
##   （燃料 + 全员上车 + 无怪无标记）。潜行检定分支用 stealth=12（必成功）/0（必失败）控制。


# === 辅助方法 ===

func _make_player(player_name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = player_name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_card(card_name: String = "test_card", card_type: String = "action") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.card_type = card_type
	c.source = "game"
	return c


func _make_block(block_name: String = "B", x: int = 0, y: int = 0, revealed: bool = true) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = block_name
	b.set_coordinate(x, y)
	b.revealed = revealed
	return b


func _make_monster_card(card_name: String = "test_monster", level: String = "normal") -> MonsterCard:
	var c: MonsterCard = MonsterCard.new()
	c.card_name = card_name
	c.card_type = "monster"
	c.source = "monster"
	c.monster_type = "zombie"
	c.monster_level = level
	c.max_hp = 3
	c.damage_value = 2
	c.range = "none"
	return c


func _make_monster(monster_name: String) -> Monster:
	return _make_monster_card(monster_name).instantiate(null)


func _clear_game() -> void:
	Game.players = []
	Game.map_area = []
	Game.map_width = 0
	Game.map_height = 0
	Game.monster_pile = null
	Game.monster_discard_pile = null
	Game.scavenge_discard_pile = null
	Game.red_scavenge_pile = null
	Game.green_scavenge_pile = null
	Game.blue_scavenge_pile = null
	Game.mission_config = null
	Game.current_mission = null
	Game.removed_cards = []
	Game.game_over_called = false
	Game.game_result = ""
	Game.coop_death_mode = false
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


## 轻量挂载：真实任务 JSON 组件 → MissionConfig（补齐 van_fuel_required / 旗标解析，
## 与 initialize_game 一致），并执行 setup_components（此时玩家列表为空，
## setup_equip_card 等依赖玩家的组件安全跳过）。B 部分手动搭建用例的主力入口。
func _mount_mission(mission_id: int) -> MissionConfig:
	var mission: MissionData = DataManager.get_mission(mission_id)
	if mission == null:
		assert_not_null(mission, "任务 %d 数据应已加载" % mission_id)
		return null
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = int(mission.van_fuel_required) if mission.van_fuel_required != null else -1
	mc.no_initial_monster_draw = mission.no_initial_monster_draw
	Game.mission_config = mc
	Game._mount_mission_components(mission)
	mc.setup_components(Game)
	return mc


## 真实全流程初始化：initialize_game（创建玩家 / 构建地图 / 初始化牌堆 / 挂载并
## setup 组件），用于 A 部分挂载验证与 B 部分开局装备类路径。
func _init_real_mission(mission_id: int) -> MissionConfig:
	var mission: MissionData = DataManager.get_mission(mission_id)
	if mission == null:
		assert_not_null(mission, "任务 %d 数据应已加载" % mission_id)
		return null
	var seats: Array = [{"type": "human", "survivor": DataManager.get_survivor("firefighter")}]
	Game.initialize_game(mission, {}, seats)
	return Game.mission_config


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


## 轮询等待条件成立（fire-and-forget 协程时序兜底），超时返回最后一次求值。
func _wait_until(condition: Callable, timeout_sec: float = 2.0) -> bool:
	var waited: float = 0.0
	while waited < timeout_sec:
		if condition.call():
			return true
		await get_tree().create_timer(0.02).timeout
		waited += 0.02
	return condition.call()


## 等待开局装备协程（setup_equip_card 的 equip 为 fire-and-forget）完成。
func _wait_for_equipment(p: Player, card_name: String) -> bool:
	var waited: int = 0
	while not p.has_equipment(card_name) and waited < 50:
		await Engine.get_main_loop().process_frame
		waited += 1
	return p.has_equipment(card_name)


## 按名称查找当前地图地块。
func _find_block(block_name: String) -> MapBlock:
	for block in Game.map_area:
		if block != null and is_instance_valid(block) and block.block_name == block_name:
			return block
	return null


## 统计玩家手牌中属于指定物品族的卡牌数（精确或变体前缀，与引擎族匹配语义一致）。
func _count_in_hand(p: Player, card_name: String) -> int:
	var count: int = 0
	for c in p.hand:
		if c == null or not is_instance_valid(c):
			continue
		if c.card_name == card_name or c.card_name.begins_with(card_name + "（"):
			count += 1
	return count


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()
	# 冲刷开局装备等 fire-and-forget 协程，避免事件残留跨用例
	for i in 3:
		await Engine.get_main_loop().process_frame


# ============================================================
# A 部分：真实 JSON → initialize_game 挂载验证（13 个任务）
# ============================================================

func test_mount_mission_0_tutorial_no_components() -> void:
	var mc: MissionConfig = _init_real_mission(0)
	if mc == null:
		return
	assert_eq(mc.van_fuel_required, 4, "任务 0 面包车燃料需求应为 4")
	assert_eq(mc.win_condition_components.size(), 0, "任务 0 应无胜利组件")
	assert_eq(mc.lose_condition_components.size(), 0, "任务 0 应无失败组件")
	assert_eq(mc.trigger_components.size(), 0, "任务 0 应无触发器组件")
	assert_eq(mc.action_components.size(), 0, "任务 0 应无行动组件")
	assert_null(mc.mission_script_instance, "任务 0 无专用脚本")
	assert_eq(mc.initial_objective_mark_count, 0, "任务 0 无任务标记")


func test_mount_mission_1_rescue_scientist_components() -> void:
	var mc: MissionConfig = _init_real_mission(1)
	if mc == null:
		return
	assert_eq(mc.van_fuel_required, 4, "任务 1 面包车燃料需求应为 4")
	assert_eq(mc.win_condition_components.size(), 1, "任务 1 应挂载 1 个胜利组件")
	assert_true(mc.win_condition_components[0] is MissionComponentEscortEquipmentAtBlock,
		"胜利组件应为 escort_equipment_at_block")
	assert_eq(mc.win_condition_components[0].params.get("card_name"), "科学家", "护送卡牌应为科学家")
	assert_eq(mc.win_condition_components[0].params.get("block_name"), "面包车", "护送目标应为面包车")
	assert_eq(mc.action_components.size(), 1, "任务 1 应挂载 1 个行动组件")
	assert_true(mc.action_components[0] is MissionComponentSpendActionRescue,
		"行动组件应为 spend_action_rescue")
	assert_eq(int(mc.action_components[0].params.get("cost")), 2, "解救消耗应为 2 行动")
	assert_eq(mc.trigger_components.size(), 2, "任务 1 应挂载 2 个触发器")
	assert_true(mc.trigger_components[0] is MissionComponentFirstEnterDrawBoss,
		"触发器 1 应为 first_enter_draw_boss")
	assert_eq(mc.trigger_components[0].params.get("block_name"), "警察局", "首次进入地块应为警察局")
	assert_true(mc.trigger_components[1] is MissionComponentCardDiscardWatch,
		"触发器 2 应为 card_discard_watch")
	assert_eq(mc.trigger_components[1].params.get("on_discard"), "lose", "科学家弃置时应判负")
	assert_eq(mc.lose_condition_components.size(), 1, "任务 1 应挂载 1 个失败组件")
	assert_true(mc.lose_condition_components[0] is MissionComponentCardDiscardWatch,
		"失败组件应为 card_discard_watch")
	assert_eq(mc.lose_condition_components[0].params.get("on_discard"), "lose", "科学家弃置时应判负")


func test_mount_mission_2_collect_samples_components() -> void:
	var mc: MissionConfig = _init_real_mission(2)
	if mc == null:
		return
	assert_eq(mc.van_fuel_required, 4, "任务 2 面包车燃料需求应为 4")
	assert_eq(mc.win_condition_components.size(), 1, "任务 2 应挂载 1 个胜利组件")
	assert_true(mc.win_condition_components[0] is MissionComponentKillMonsters,
		"胜利组件应为 kill_monsters")
	var counts: Dictionary = mc.win_condition_components[0].params.get("counts")
	assert_eq(counts.size(), 4, "击杀清单应含 4 种僵尸")
	assert_eq(int(counts.get("僵尸步行者")), 2, "僵尸步行者需求应为 2")
	assert_eq(int(counts.get("僵尸喷吐者")), 2, "僵尸喷吐者需求应为 2")
	assert_eq(int(counts.get("僵尸狗")), 2, "僵尸狗需求应为 2")
	assert_eq(int(counts.get("僵尸士兵")), 2, "僵尸士兵需求应为 2")
	assert_eq(mc.trigger_components.size(), 1, "任务 2 应挂载 1 个触发器（击杀计数）")
	assert_true(mc.trigger_components[0] is MissionComponentKillMonsters,
		"触发器应为 kill_monsters（接收 monster_died 计数）")
	assert_eq(mc.action_components.size(), 0, "任务 2 无行动组件")
	assert_eq(mc.lose_condition_components.size(), 0, "任务 2 无失败组件")
	# setup_components 已执行：kill_counts 应初始化为空字典
	assert_eq(mc.mission_state.get("kill_counts"), {}, "setup 后 kill_counts 应初始化为空字典")


func test_mount_mission_3_develop_cure_components() -> void:
	var mc: MissionConfig = _init_real_mission(3)
	if mc == null:
		return
	assert_eq(mc.van_fuel_required, -1, "任务 3 不通过面包车胜利（van_fuel_required=null → -1）")
	assert_eq(mc.win_condition_components.size(), 2, "任务 3 应挂载 2 个胜利组件")
	assert_true(mc.win_condition_components[0] is MissionComponentCollectItems,
		"胜利组件 1 应为 collect_items")
	assert_eq(mc.win_condition_components[0].params.get("mode"), "submit", "收集判定应为提交模式")
	var items: Dictionary = mc.win_condition_components[0].params.get("items")
	assert_eq(int(items.get("医疗用品")), 2, "医疗用品需求应为 2")
	assert_eq(int(items.get("解毒剂")), 3, "解毒剂需求应为 3")
	assert_true(mc.win_condition_components[1] is MissionComponentEscortEquipmentAtBlock,
		"胜利组件 2 应为 escort_equipment_at_block")
	assert_eq(mc.win_condition_components[1].params.get("block_name"), "医院", "护送目标应为医院")
	assert_eq(mc.lose_condition_components.size(), 1, "任务 3 应挂载 1 个失败组件")
	assert_true(mc.lose_condition_components[0] is MissionComponentCardDiscardWatch,
		"失败组件应为 card_discard_watch")
	assert_eq(mc.lose_condition_components[0].params.get("on_discard"), "lose", "科学家弃置时应判负")
	assert_eq(mc.trigger_components.size(), 2, "任务 3 应挂载 2 个触发器")
	assert_true(mc.trigger_components[0] is MissionComponentSetupEquipCard,
		"触发器 1 应为 setup_equip_card")
	assert_eq(mc.trigger_components[0].params.get("card_name"), "科学家", "开局应装备科学家")
	assert_true(mc.trigger_components[1] is MissionComponentCardDiscardWatch, "触发器 2 应为 card_discard_watch")
	assert_eq(mc.action_components.size(), 1, "任务 3 应挂载 1 个行动组件")
	assert_true(mc.action_components[0] is MissionComponentSubmitItems,
		"行动组件应为 submit_items")
	assert_eq(mc.action_components[0].params.get("block_name"), "医院", "提交地点应为医院")
	var submit_items: Dictionary = mc.action_components[0].params.get("items")
	assert_eq(int(submit_items.get("医疗用品")), 2, "提交清单医疗用品应为 2")
	assert_eq(int(submit_items.get("解毒剂")), 3, "提交清单解毒剂应为 3")


func test_mount_mission_4_nuclear_winter_components() -> void:
	var mc: MissionConfig = _init_real_mission(4)
	if mc == null:
		return
	assert_eq(mc.van_fuel_required, -1, "任务 4 不通过面包车胜利")
	assert_eq(mc.win_condition_components.size(), 2, "任务 4 应挂载 2 个胜利组件")
	assert_true(mc.win_condition_components[0] is MissionComponentCollectItems,
		"胜利组件 1 应为 collect_items")
	var items: Dictionary = mc.win_condition_components[0].params.get("items")
	assert_eq(int(items.get("燃料")), 3, "燃料需求应为 3")
	assert_eq(int(items.get("脏毯子")), 2, "脏毯子需求应为 2")
	assert_eq(int(items.get("老报纸")), 2, "老报纸需求应为 2")
	assert_true(mc.win_condition_components[1] is MissionComponentAllPlayersAtBlock,
		"胜利组件 2 应为 all_players_at_block")
	assert_eq(mc.win_condition_components[1].params.get("block_name"), "避难所", "集结地点应为避难所")
	assert_eq(mc.win_condition_components[1].params.get("no_monster"), true, "避难所应要求无怪物")
	assert_eq(mc.trigger_components.size(), 0, "任务 4 无触发器")
	assert_eq(mc.action_components.size(), 0, "任务 4 无行动组件")
	assert_eq(mc.lose_condition_components.size(), 0, "任务 4 无失败组件")


func test_mount_mission_5_defuse_bomb_components() -> void:
	var mc: MissionConfig = _init_real_mission(5)
	if mc == null:
		return
	assert_eq(mc.van_fuel_required, 3, "任务 5 面包车燃料需求应为 3")
	assert_eq(mc.win_condition_components.size(), 1, "任务 5 应挂载 1 个胜利组件")
	assert_true(mc.win_condition_components[0] is MissionComponentStateFlag,
		"胜利组件应为 state_flag")
	assert_eq(mc.win_condition_components[0].params.get("key"), "bomb_defused", "胜利旗标应为 bomb_defused")
	assert_eq(mc.action_components.size(), 1, "任务 5 应挂载 1 个行动组件")
	assert_true(mc.action_components[0] is MissionComponentDefuseBomb, "行动组件应为 defuse_bomb")
	assert_eq(mc.action_components[0].params.get("block_name"), "电厂", "炸弹应在电厂")
	assert_eq(int(mc.action_components[0].params.get("cost")), 2, "解除消耗应为 2 行动")
	assert_eq(mc.trigger_components.size(), 2, "任务 5 应挂载 2 个触发器")
	assert_true(mc.trigger_components[0] is MissionComponentMarkEnterReward,
		"触发器 1 应为 mark_enter_reward")
	assert_true(mc.trigger_components[0].params.get("rewards", {}).has("mark_1"), "奖励表应含 mark_1")
	assert_true(mc.trigger_components[1] is MissionComponentTurnCountdown,
		"触发器 2 应为 turn_countdown")
	assert_eq(int(mc.trigger_components[1].params.get("rounds")), 3, "倒计时应为 3 轮")
	assert_eq(mc.trigger_components[1].params.get("expire_kill_outside"), "面包车", "归零应击杀车外玩家")
	assert_eq(mc.lose_condition_components.size(), 0, "任务 5 无失败组件")
	assert_eq(mc.initial_objective_mark_count, 1, "任务 5 开局应有 1 个任务标记")
	# setup_components 已执行：倒计时与炸弹状态键应初始化
	assert_eq(mc.mission_state.get("bomb_defused"), false, "setup 后 bomb_defused 应为 false")
	assert_eq(mc.mission_state.get("countdown_active"), false, "setup 后倒计时应未激活")
	assert_eq(int(mc.mission_state.get("countdown_remaining")), 0, "setup 后剩余轮数应为 0")


func test_mount_mission_6_nuclear_radiation_components() -> void:
	var mc: MissionConfig = _init_real_mission(6)
	if mc == null:
		return
	assert_eq(mc.van_fuel_required, 3, "任务 6 面包车燃料需求应为 3")
	assert_eq(mc.win_condition_components.size(), 1, "任务 6 应挂载 1 个胜利组件")
	assert_true(mc.win_condition_components[0] is MissionComponentStateFlag,
		"胜利组件应为 state_flag")
	assert_eq(mc.win_condition_components[0].params.get("key"), "van_repaired", "胜利旗标应为 van_repaired")
	assert_eq(mc.action_components.size(), 1, "任务 6 应挂载 1 个行动组件")
	assert_true(mc.action_components[0] is MissionComponentRepairVan, "行动组件应为 repair_van")
	assert_eq(int(mc.action_components[0].params.get("times")), 3, "修满应需 3 次维修")
	assert_eq(mc.trigger_components.size(), 1, "任务 6 应挂载 1 个触发器")
	assert_true(mc.trigger_components[0] is MissionComponentSpawnDiceEffect,
		"触发器应为 spawn_dice_effect")
	assert_eq(int(mc.trigger_components[0].params.get("value")), 7, "天灾触发点数应为 7")
	assert_eq(mc.lose_condition_components.size(), 0, "任务 6 无失败组件")
	# setup_components 已执行：维修进度键应初始化
	assert_eq(int(mc.mission_state.get("van_repair_count")), 0, "setup 后维修进度应为 0")
	assert_eq(mc.mission_state.get("van_repaired"), false, "setup 后 van_repaired 应为 false")


func test_mount_mission_7_scout_alien_zone_components() -> void:
	var mc: MissionConfig = _init_real_mission(7)
	if mc == null:
		return
	assert_eq(mc.van_fuel_required, 4, "任务 7 面包车燃料需求应为 4")
	assert_eq(mc.win_condition_components.size(), 1, "任务 7 应挂载 1 个胜利组件")
	assert_true(mc.win_condition_components[0] is MissionComponentAllBlocksRevealed,
		"胜利组件应为 all_blocks_revealed")
	assert_eq(mc.trigger_components.size(), 1, "任务 7 应挂载 1 个触发器")
	assert_true(mc.trigger_components[0] is MissionComponentRevealMarkDrawBoss,
		"触发器应为 reveal_mark_draw_boss")
	assert_eq(mc.action_components.size(), 0, "任务 7 无行动组件")
	assert_eq(mc.lose_condition_components.size(), 0, "任务 7 无失败组件")
	assert_eq(mc.initial_objective_mark_count, 1, "任务 7 开局应有 1 个任务标记")


func test_mount_mission_8_intelligence_recovery_components() -> void:
	var mc: MissionConfig = _init_real_mission(8)
	if mc == null:
		return
	assert_eq(mc.van_fuel_required, -1, "任务 8 不通过面包车胜利")
	assert_eq(mc.win_condition_components.size(), 1, "任务 8 应挂载 1 个胜利组件")
	assert_true(mc.win_condition_components[0] is MissionComponentActionWinOnly,
		"胜利组件应为 action_win_only（防止空真误判）")
	assert_eq(mc.action_components.size(), 1, "任务 8 应挂载 1 个行动组件")
	assert_true(mc.action_components[0] is MissionComponentRescueJudgeWin,
		"行动组件应为 rescue_judge_win")
	assert_eq(mc.trigger_components.size(), 0, "任务 8 无触发器")
	assert_eq(mc.lose_condition_components.size(), 0, "任务 8 无失败组件")
	assert_eq(mc.initial_objective_mark_count, 1, "任务 8 开局应有 1 个任务标记")
	# setup_components 已执行：检定标记键应初始化
	assert_eq(mc.mission_state.get("rescue_judge_done"), false, "setup 后 rescue_judge_done 应为 false")


func test_mount_mission_9_human_counterattack_components() -> void:
	var mc: MissionConfig = _init_real_mission(9)
	if mc == null:
		return
	assert_eq(mc.van_fuel_required, -1, "任务 9 不通过面包车胜利")
	assert_eq(mc.win_condition_components.size(), 1, "任务 9 应挂载 1 个胜利组件")
	assert_true(mc.win_condition_components[0] is MissionComponentActionWinOnly,
		"胜利组件应为 action_win_only")
	assert_eq(mc.lose_condition_components.size(), 1, "任务 9 应挂载 1 个失败组件")
	assert_true(mc.lose_condition_components[0] is MissionComponentCardDiscardWatch,
		"失败组件应为 card_discard_watch")
	assert_eq(mc.lose_condition_components[0].params.get("on_discard"), "lose", "科学家弃置时应判负")
	assert_eq(mc.action_components.size(), 2, "任务 9 应挂载 2 个行动组件")
	assert_true(mc.action_components[0] is MissionComponentDestroyCurrentMark,
		"行动组件 1 应为 destroy_current_mark")
	assert_eq(mc.action_components[0].params.get("require_no_monster"), false,
		"摧毁发射器不应要求无怪物（需先清怪物标记是标记地块自身的约束）")
	assert_true(mc.action_components[1] is MissionComponentUploadVirus,
		"行动组件 2 应为 upload_virus")
	assert_eq(mc.action_components[1].params.get("block_name"), "坠毁点", "上传地点应为坠毁点")
	assert_eq(mc.trigger_components.size(), 2, "任务 9 应挂载 2 个触发器")
	assert_true(mc.trigger_components[0] is MissionComponentSetupEquipCard,
		"触发器 1 应为 setup_equip_card")
	assert_true(mc.trigger_components[1] is MissionComponentCardDiscardWatch, "触发器 2 应为 card_discard_watch")
	assert_eq(mc.initial_objective_mark_count, 2, "任务 9 开局应有 2 个任务标记（两座发射器）")


func test_mount_mission_10_transport_components() -> void:
	var mc: MissionConfig = _init_real_mission(10)
	if mc == null:
		return
	assert_eq(mc.van_fuel_required, -1, "任务 10 不通过面包车胜利")
	assert_eq(mc.win_condition_components.size(), 2, "任务 10 应挂载 2 个胜利组件")
	assert_true(mc.win_condition_components[0] is MissionComponentCollectItems,
		"胜利组件 1 应为 collect_items")
	assert_eq(mc.win_condition_components[0].params.get("mode"), "submit", "收集判定应为 submit 模式")
	var items: Dictionary = mc.win_condition_components[0].params.get("items")
	assert_eq(int(items.get("燃料")), 6, "燃料需求应为 6")
	assert_eq(int(items.get("脏毯子")), 3, "脏毯子需求应为 3")
	assert_eq(int(items.get("医疗用品")), 2, "医疗用品需求应为 2")
	assert_eq(int(items.get("多余配件")), 2, "多余配件需求应为 2")
	assert_true(mc.win_condition_components[1] is MissionComponentAllPlayersAtBlock,
		"胜利组件 2 应为 all_players_at_block")
	assert_eq(mc.win_condition_components[1].params.get("block_name"), "军事基地", "集结地点应为军事基地")
	assert_eq(mc.action_components.size(), 1, "任务 10 应挂载 1 个行动组件")
	assert_true(mc.action_components[0] is MissionComponentSubmitItems, "行动组件应为 submit_items")
	assert_eq(mc.trigger_components.size(), 1, "任务 10 应挂载 1 个触发器")
	assert_true(mc.trigger_components[0] is MissionComponentMarkEnterReward,
		"触发器应为 mark_enter_reward")
	var rewards: Dictionary = mc.trigger_components[0].params.get("rewards")
	assert_eq(rewards.size(), 3, "奖励表应含 3 种标记")
	assert_eq(mc.lose_condition_components.size(), 0, "任务 10 无失败组件")
	assert_eq(mc.initial_objective_mark_count, 3, "任务 10 开局应有 3 个任务标记")


func test_mount_mission_11_defend_base_components() -> void:
	var mc: MissionConfig = _init_real_mission(11)
	if mc == null:
		return
	assert_eq(mc.van_fuel_required, -1, "任务 11 不通过面包车胜利")
	assert_true(mc.no_initial_monster_draw, "任务 11 应声明 no_initial_monster_draw")
	assert_eq(mc.win_condition_components.size(), 2, "任务 11 应挂载 2 个胜利组件")
	assert_true(mc.win_condition_components[0] is MissionComponentObjectiveMarksCleared,
		"胜利组件 1 应为 objective_marks_cleared")
	assert_eq(int(mc.win_condition_components[0].params.get("count")), 3, "需移除 3 个任务标记")
	assert_true(mc.win_condition_components[1] is MissionComponentAllPlayersAtBlock,
		"胜利组件 2 应为 all_players_at_block")
	assert_eq(mc.win_condition_components[1].params.get("block_name"), "军事基地", "集结地点应为军事基地")
	assert_eq(mc.action_components.size(), 1, "任务 11 应挂载 1 个行动组件")
	assert_true(mc.action_components[0] is MissionComponentDestroyCurrentMark,
		"行动组件应为 destroy_current_mark")
	assert_eq(mc.action_components[0].params.get("require_no_monster"), true,
		"摧毁应要求地块无怪物")
	assert_eq(mc.trigger_components.size(), 0, "任务 11 无触发器")
	assert_eq(mc.lose_condition_components.size(), 0, "任务 11 无失败组件")
	assert_eq(mc.initial_objective_mark_count, 3, "任务 11 开局应有 3 个任务标记")


func test_mount_mission_12_burn_the_robots_components() -> void:
	var mc: MissionConfig = _init_real_mission(12)
	if mc == null:
		return
	assert_eq(mc.van_fuel_required, 3, "任务 12 面包车燃料需求应为 3")
	assert_eq(mc.win_condition_components.size(), 1, "任务 12 应挂载 1 个胜利组件")
	assert_true(mc.win_condition_components[0] is MissionComponentObjectiveMarksCleared,
		"胜利组件应为 objective_marks_cleared")
	assert_eq(int(mc.win_condition_components[0].params.get("count")), 3, "需移除 3 个任务标记")
	assert_eq(mc.action_components.size(), 1, "任务 12 应挂载 1 个行动组件")
	assert_true(mc.action_components[0] is MissionComponentDestroyCurrentMark,
		"行动组件应为 destroy_current_mark")
	assert_eq(mc.action_components[0].params.get("require_no_monster"), true,
		"摧毁应要求地块无怪物")
	assert_eq(mc.trigger_components.size(), 0, "任务 12 无触发器")
	assert_eq(mc.lose_condition_components.size(), 0, "任务 12 无失败组件")
	assert_eq(mc.initial_objective_mark_count, 3, "任务 12 开局应有 3 个任务标记")


# ============================================================
# B 部分：关键路径（手动搭建为主）
# ============================================================

# === 任务 0：教程 —— 面包车燃料引擎路径（回归） ===

func test_mission_0_van_fuel_engine_win_path() -> void:
	_mount_mission(0)
	var van: MapBlock = _make_block("面包车", 0, 0)
	var other: MapBlock = _make_block("加油站", 1, 0)
	var p: Player = _make_player("P")
	p.current_block = van
	_setup_game_env([p], [van, other])
	assert_false(Game.state_machine.check_win_condition(), "燃料 0/4 不应胜利")
	van.van_fuel = 4
	p.current_block = other
	assert_false(Game.state_machine.check_win_condition(), "玩家不在面包车不应胜利")
	p.current_block = van
	assert_true(Game.state_machine.check_win_condition(), "玩家在面包车+燃料4+无怪应胜利")
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.WIN, "结果应为 WIN")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")


# === 任务 1：解救科学家 —— 解救 → 护送 → 面包车；科学家弃置判负 ===

func test_mission_1_rescue_via_input_then_van_win() -> void:
	_mount_mission(1)
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
	# CliPlayerInput 队列注入 → wait_player_action → mission_action 执行链
	await p.wait_player_action()
	var state: Dictionary = Game.mission_config.mission_state
	assert_true(state.get("scientist_rescued"), "执行后应标记 scientist_rescued")
	assert_eq(p.action_count, 2, "解救应消耗 2 点行动（4 → 2）")
	assert_true(p.has_equipment("科学家"), "科学家应装备到玩家装备区")
	assert_eq(Game.mission_config.get_action_options(Game, p).size(), 0, "解救后选项应消失")
	# 护送：到面包车 + 燃料 4 → WIN
	p.current_block = van
	van.van_fuel = 4
	assert_true(Game.state_machine.check_win_condition(), "解救+持有者在面包车+燃料4应胜利")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")


func test_mission_1_scientist_discard_loses() -> void:
	_mount_mission(1)
	var p: Player = _make_player("P")
	_setup_game_env([p])
	# 模拟解救后的科学家（真实拾荒卡）
	var card: Card = Game.create_scavenge_card("科学家")
	assert_not_null(card, "科学家拾荒卡应可创建")
	p.hand.append(card)
	await p.equip(card)
	assert_true(p.has_equipment("科学家"), "科学家应已装备")
	# 弃置装备区科学家 → card_discarded → card_discard_watch lose 分支（触发器+失败组件双声明链路）
	await p.discard(p.equipment_zone[0])
	assert_eq(p.equipment_zone.size(), 0, "弃置后装备区应无科学家")
	assert_eq(Game.scavenge_discard_pile.size(), 1, "科学家应留在拾荒弃牌堆（不再销毁）")
	assert_eq(Game.removed_cards.size(), 0, "科学家不应被移出游戏")
	assert_eq(Game.mission_config.mission_state.get("card_discard_failed"), true,
		"科学家弃置应置 card_discard_failed")
	assert_true(Game.state_machine.check_win_condition(), "失败条件满足应终止游戏")
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.LOSE, "结果应为 LOSE")
	assert_eq(Game.game_result, "lose", "Game.game_result 应为 lose")


# === 任务 2：收集样本 —— monster_died 事件链计数 → 面包车 ===

func test_mission_2_kill_monsters_event_chain_then_van_win() -> void:
	var mc: MissionConfig = _mount_mission(2)
	var van: MapBlock = _make_block("面包车", 0, 0)
	var p: Player = _make_player("P")
	p.current_block = van
	_setup_game_env([p], [van])
	# EventBus 全链路：monster_died → Game → mission_config.on_event → kill_monsters 计数
	EventBus.monster_died.emit(_make_monster("僵尸潜伏者"), null)
	EventBus.monster_died.emit(_make_monster("僵尸潜伏者"), null)
	assert_false(mc.win_condition_components[0].check_win(Game), "非目标怪物击杀不应计入")
	var kill_counts: Dictionary = mc.mission_state.get("kill_counts", {})
	assert_false(kill_counts.has("僵尸潜伏者"), "kill_counts 不应记录非目标怪物")
	# 目标怪物：四种僵尸各 2 次
	for monster_name: String in ["僵尸步行者", "僵尸喷吐者", "僵尸狗", "僵尸士兵"]:
		for i in 2:
			EventBus.monster_died.emit(_make_monster(monster_name), null)
	kill_counts = mc.mission_state.get("kill_counts", {})
	assert_eq(int(kill_counts.get("僵尸步行者", 0)), 2, "僵尸步行者应累计 2 次")
	assert_eq(int(kill_counts.get("僵尸喷吐者", 0)), 2, "僵尸喷吐者应累计 2 次")
	assert_eq(int(kill_counts.get("僵尸狗", 0)), 2, "僵尸狗应累计 2 次")
	assert_eq(int(kill_counts.get("僵尸士兵", 0)), 2, "僵尸士兵应累计 2 次")
	assert_true(mc.win_condition_components[0].check_win(Game), "四种僵尸各杀 2 只应满足胜利组件")
	# 叠加面包车判定：燃料不足 → 不胜；加满 → WIN
	assert_false(Game.state_machine.check_win_condition(), "燃料 0/4 不应胜利")
	van.van_fuel = 4
	assert_true(Game.state_machine.check_win_condition(), "击杀达标+面包车条件应胜利")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")


# === 任务 3：研制解药 —— 开局装备科学家 → 医院提交物资 → 医院；科学家弃置判负 ===

func test_mission_3_setup_equip_submit_and_hospital_win() -> void:
	_init_real_mission(3)
	var p: Player = Game.players[0]
	assert_not_null(p, "应已创建玩家")
	# setup_equip_card 开局装备协程推进
	assert_true(await _wait_for_equipment(p, "科学家"), "开局应将科学家装备进第一名玩家装备区")
	# 手牌备齐提交清单：医疗用品×2 + 解毒剂×3（精确卡名直接匹配提交清单）
	p.hand.append(_make_card("医疗用品"))
	p.hand.append(_make_card("医疗用品"))
	for i in 3:
		p.hand.append(_make_card("解毒剂"))
	# 持有者到医院
	var hospital: MapBlock = _find_block("医院")
	assert_not_null(hospital, "任务 3 地图应包含医院")
	p.current_block = hospital
	p.action_count = 2
	Game.state_machine.transition_to(GameStateMachine.GameState.PLAYING)
	# 随身持有不再直接判胜（collect_items 提交模式）：须经医院提交物资
	assert_false(Game.state_machine.check_win_condition(), "仅持有未提交不应胜利")
	var options: Array = Game.mission_config.get_action_options(Game, p)
	assert_eq(options.size(), 1, "在医院持有清单物资应出现提交选项")
	assert_eq(options[0]["id"], "submit_items", "选项 id 应为 submit_items")
	await options[0]["execute"].call()
	assert_eq(p.hand.size(), 0, "清单内物资应全部提交（弃置）")
	assert_eq(p.action_count, 1, "提交应消耗 1 点行动（2 → 1）")
	var submitted: Dictionary = Game.mission_config.mission_state.get("submitted_items", {})
	assert_eq(int(submitted.get("医疗用品", 0)), 2, "医疗用品应提交 2 张")
	assert_eq(int(submitted.get("解毒剂", 0)), 3, "解毒剂应提交 3 张")
	# collect_items submit 模式达标 + 科学家持有者在医院 → WIN
	assert_true(Game.state_machine.check_win_condition(), "提交达标+科学家在医院应胜利")
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.WIN, "结果应为 WIN")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")


func test_mission_3_progress_panel_submitted_count_lines() -> void:
	var mc: MissionConfig = _mount_mission(3)
	var panel: MissionProgressPanel = MissionProgressPanel.new()
	autofree(panel)
	var mission: MissionData = DataManager.get_mission(3)
	# 部分提交：医疗用品 1/2，解毒剂 0/3 → 进度行按 submitted_count 求值
	mc.mission_state["submitted_items"] = {"医疗用品": 1}
	var lines: Array = panel.build_lines_from(mission.progress_conditions)
	assert_eq(lines.size(), 3, "任务 3 进度面板应显示 3 行")
	assert_eq(lines[0], "1. 提交医疗用品(1/2)", "部分提交的医疗用品行应显示 (1/2)")
	assert_eq(lines[1], "2. 提交解毒剂(0/3)", "未提交的解毒剂行应显示 (0/3)")


func test_mission_3_lose_when_scientist_discarded() -> void:
	_init_real_mission(3)
	var p: Player = Game.players[0]
	assert_true(await _wait_for_equipment(p, "科学家"), "开局应装备科学家")
	# 弃置装备区科学家 → card_discarded → card_discard_watch lose 分支
	await p.discard(p.equipment_zone[0])
	assert_eq(Game.mission_config.mission_state.get("card_discard_failed"), true,
		"科学家弃置应置 card_discard_failed")
	Game.state_machine.transition_to(GameStateMachine.GameState.PLAYING)
	assert_true(Game.state_machine.check_win_condition(), "失败条件满足应终止游戏")
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.LOSE, "结果应为 LOSE")
	assert_eq(Game.game_result, "lose", "Game.game_result 应为 lose")


# === 任务 4：核冬天 —— 物资 + 全员避难所 ===

func test_mission_4_supplies_and_shelter_win() -> void:
	_mount_mission(4)
	var shelter: MapBlock = _make_block("避难所", 0, 0)
	var p1: Player = _make_player("P1")
	var p2: Player = _make_player("P2")
	p1.current_block = shelter
	p2.current_block = shelter
	# 物资分散在两名玩家：燃料3 + 脏毯子2 + 老报纸2
	for i in 3:
		p1.hand.append(_make_card("燃料"))
	for i in 2:
		p1.hand.append(_make_card("脏毯子"))
	for i in 2:
		p2.hand.append(_make_card("老报纸"))
	_setup_game_env([p1, p2], [shelter])
	assert_true(Game.state_machine.check_win_condition(), "物资达标+全员避难所无怪应胜利")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")


func test_mission_4_monster_at_shelter_blocks_win() -> void:
	_mount_mission(4)
	var shelter: MapBlock = _make_block("避难所", 0, 0)
	var p: Player = _make_player("P")
	p.current_block = shelter
	for i in 3:
		p.hand.append(_make_card("燃料"))
	for i in 2:
		p.hand.append(_make_card("脏毯子"))
	for i in 2:
		p.hand.append(_make_card("老报纸"))
	_setup_game_env([p], [shelter])
	# 避难所有怪物标记 → 不胜
	shelter.add_monster_mark(1)
	assert_false(Game.state_machine.check_win_condition(), "避难所有怪物标记不应胜利")
	assert_false(Game.state_machine.is_game_over(), "不应进入 GAME_OVER")
	# 清标记但玩家面前有怪 → 不胜
	shelter.remove_all_monster_marks()
	p.monster_zone.append(_make_monster("变异老鼠"))
	assert_false(Game.state_machine.check_win_condition(), "避难所玩家面前有怪物不应胜利")


# === 任务 5：拆除炸弹 —— 标记奖励 → 解除 → 倒计时 → 撤离 ===

func test_mission_5_mark_enter_reward_diary_and_boss() -> void:
	_mount_mission(5)
	var p: Player = _make_player("P")
	var marked: MapBlock = _make_block("废墟", 0, 0)
	marked.add_objective_mark({"mark_id": "mark_1"})
	p.current_block = marked
	_setup_game_env([p], [marked])
	# 怪物牌堆备 1 张首领卡供 draw_boss
	Game.monster_pile.add(_make_monster_card("首领变异体", "boss"))
	# 进入标记地块 → objective_mark_triggered → mark_enter_reward
	await marked.trigger_objective_marks(p)
	assert_eq(_count_in_hand(p, "满是灰尘的日记本"), 1, "应获得满是灰尘的日记本")
	assert_eq(p.monster_zone.size(), 1, "应抓取一张首领牌")
	assert_eq(p.monster_zone[0].monster_name, "首领变异体", "抓取的应为首领卡")


func test_mission_5_defuse_countdown_kill_outside_win() -> void:
	var mc: MissionConfig = _mount_mission(5)
	var van: MapBlock = _make_block("面包车", 0, 0)
	var plant: MapBlock = _make_block("电厂", 1, 0)
	var p_in: Player = _make_player("车内", 10)
	var p_out: Player = _make_player("车外", 10)
	p_in.current_block = van
	p_out.current_block = plant
	_setup_game_env([p_in, p_out], [van, plant])
	# 持日记本在电厂解除炸弹
	p_out.action_count = 4
	p_out.hand.append(Game.create_scavenge_card("满是灰尘的日记本"))
	var options: Array = Game.mission_config.get_action_options(Game, p_out)
	assert_eq(options.size(), 1, "在电厂持日记本应出现解除选项")
	assert_eq(options[0]["id"], "defuse_bomb", "选项 id 应为 defuse_bomb")
	await options[0]["execute"].call()
	assert_eq(mc.mission_state.get("bomb_defused"), true, "解除后应标记 bomb_defused")
	assert_eq(mc.mission_state.get("countdown_activate"), true, "解除后应写入倒计时激活标记")
	assert_eq(p_out.action_count, 2, "解除应消耗 2 点行动（4 → 2）")
	assert_false(Game.state_machine.check_win_condition(), "燃料 0/3 不应胜利")
	# 倒计时激活：下一个转发事件消费 countdown_activate 标记
	Game.mission_config.on_event(Game, "turn_ended", {"player": p_out})
	assert_eq(mc.mission_state.get("countdown_active"), true, "倒计时应已激活")
	assert_eq(int(mc.mission_state.get("countdown_remaining")), 3, "激活后剩余轮数应为 3")
	assert_false(mc.mission_state.has("countdown_activate"), "激活后标记键应被清除")
	# 3 轮归零：turn_started 事件 + 轮数递增（首个事件仅记录基准）
	Game.state_machine.turn_number = 1
	Game.mission_config.on_event(Game, "turn_started", {"player": p_in})
	for tn in [2, 3, 4]:
		Game.state_machine.turn_number = tn
		Game.mission_config.on_event(Game, "turn_started", {"player": p_in})
	assert_eq(int(mc.mission_state.get("countdown_remaining")), 0, "3 轮后倒计时应归零")
	assert_eq(mc.mission_state.get("countdown_expired"), true, "倒计时应标记归零")
	# 归零击杀车外玩家，车内存活
	assert_false(p_out.is_alive(), "车外玩家应被倒计时击杀")
	assert_true(p_in.is_alive(), "车内玩家应存活")
	# 车内玩家 + 燃料 3 → WIN
	van.van_fuel = 3
	assert_true(Game.state_machine.check_win_condition(), "炸弹解除+车内玩家+燃料3应胜利")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")


# === 任务 6：核辐射 —— 维修面包车；投骰 7 天灾 ===

func test_mission_6_repair_three_times_van_win() -> void:
	var mc: MissionConfig = _mount_mission(6)
	var van: MapBlock = _make_block("面包车", 0, 0)
	var p: Player = _make_player("P")
	p.action_count = 9
	p.current_block = van
	for i in 3:
		p.hand.append(_make_card("多余配件"))
	_setup_game_env([p], [van])
	var component: MissionComponent = mc.action_components[0]
	for i in 3:
		var options: Array = component.get_action_options(Game, p)
		assert_eq(options.size(), 1, "第 %d 次维修前应出现选项" % (i + 1))
		await options[0]["execute"].call()
	assert_eq(int(mc.mission_state.get("van_repair_count")), 3, "三次维修后进度应为 3")
	assert_eq(mc.mission_state.get("van_repaired"), true, "三次维修后应标记修满")
	assert_eq(p.hand.size(), 0, "三次维修应共弃置 3 张配件")
	assert_eq(p.action_count, 6, "三次维修应共消耗 3 点行动（9 → 6）")
	assert_eq(component.get_action_options(Game, p).size(), 0, "修满后不应再出现维修选项")
	# 修满 + 燃料 3 + 全员面包车 → WIN
	van.van_fuel = 3
	assert_true(Game.state_machine.check_win_condition(), "修满+燃料3+全员面包车应胜利")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")


func test_mission_6_spawn_dice_reveals_outer_block() -> void:
	_mount_mission(6)
	# 3x3 地图：中心已展示，外围 8 块未展示
	var blocks: Array = []
	for y in 3:
		for x in 3:
			var is_center: bool = x == 1 and y == 1
			blocks.append(_make_block("地块_%d_%d" % [x, y], x, y, is_center))
	Game.map_width = 3
	Game.map_height = 3
	var p: Player = _make_player("P")
	p.current_block = blocks[4]
	_setup_game_env([p], blocks)
	Game.map_width = 3
	Game.map_height = 3
	# 非命中点数不应有效果
	EventBus.monster_spawn_judged.emit(p, 3)
	assert_eq(_count_revealed(blocks), 1, "投出 3 不应触发天灾")
	# 命中点数 7：揭示一个外围地块（EventBus → Game → spawn_dice_effect 全链路）
	EventBus.monster_spawn_judged.emit(p, 7)
	assert_eq(_count_revealed(blocks), 2, "投出 7 应揭示一个外围地块")


func test_mission_6_spawn_dice_destroys_outer_and_kills() -> void:
	_mount_mission(6)
	# 3x1 地图：3 块全为外围（y==0==map_height-1），全部已展示，各站 1 名玩家
	var blocks: Array = [
		_make_block("地块A", 0, 0),
		_make_block("地块B", 1, 0),
		_make_block("地块C", 2, 0),
	]
	var players: Array = []
	for i in blocks.size():
		var p: Player = _make_player("P%d" % i)
		p.current_block = blocks[i]
		players.append(p)
	# 传副本避免别名：destroy_map_block 会从 Game.map_area erase，
	# 若直接传 blocks 本体，本地数组会被同步删除导致断言失真
	_setup_game_env(players, blocks.duplicate())
	Game.map_width = 3
	Game.map_height = 1
	# 外围全部已展示 → 再投 7 进入移除分支：随机移除一个外围地块并杀死其上玩家
	EventBus.monster_spawn_judged.emit(players[0], 7)
	var settled: bool = await _wait_until(func():
		var dead: int = 0
		for p in players:
			if not p.is_alive():
				dead += 1
		return dead == 1 and Game.map_area.size() == 2)
	assert_true(settled, "应移除一个外围地块并杀死其上一名玩家")
	var destroyed: Array = []
	for b in blocks:
		if b.block_state == "destroyed":
			destroyed.append(b)
	assert_eq(destroyed.size(), 1, "应恰有一个外围地块被摧毁")
	assert_false(Game.map_area.has(destroyed[0]), "被摧毁地块应已移出地图")
	var dead_players: Array = []
	for p in players:
		if not p.is_alive():
			dead_players.append(p)
	assert_eq(dead_players.size(), 1, "应恰有一名玩家死亡")
	assert_eq(dead_players[0].current_block, destroyed[0], "死亡玩家应在被摧毁地块上")


func _count_revealed(blocks: Array) -> int:
	var count: int = 0
	for b in blocks:
		if b.is_revealed():
			count += 1
	return count


# === 任务 7：侦查外星人地区 —— 全展示 + 面包车；展示标记地块抓首领 ===

func test_mission_7_all_blocks_revealed_van_win() -> void:
	_mount_mission(7)
	var wild: MapBlock = _make_block("旷野", 0, 0, false)
	var van: MapBlock = _make_block("面包车", 1, 0)
	var p: Player = _make_player("P")
	p.current_block = van
	_setup_game_env([p], [wild, van])
	van.van_fuel = 4
	assert_false(Game.state_machine.check_win_condition(), "有未展示地块不应胜利")
	wild.revealed = true
	assert_true(Game.state_machine.check_win_condition(), "全部地块展示+面包车条件应胜利")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")


func test_mission_7_reveal_marked_block_draws_boss() -> void:
	_mount_mission(7)
	var p: Player = _make_player("P")
	var marked: MapBlock = _make_block("坠毁点", 0, 0, false)
	marked.add_objective_mark({"mark_id": "mark_1"})
	p.current_block = marked
	_setup_game_env([p], [marked])
	Game.monster_pile.add(_make_monster_card("首领外星人", "boss"))
	# 展示带标记地块 → block_revealed → reveal_mark_draw_boss → 抓首领
	await marked.reveal(false, p)
	assert_eq(p.monster_zone.size(), 1, "展示带任务标记地块的玩家应抓取首领牌")
	assert_eq(p.monster_zone[0].monster_level, "boss", "抓取的应为首领级怪物")


# === 任务 8：情报恢复 —— 潜行检定决胜 ===

func test_mission_8_action_win_only_prevents_vacuous_win() -> void:
	_mount_mission(8)
	var p: Player = _make_player("P")
	_setup_game_env([p])
	assert_false(Game.state_machine.check_win_condition(),
		"action_win_only 组件应防止开局空真胜利")
	assert_false(Game.state_machine.is_game_over(), "不应进入 GAME_OVER")


func test_mission_8_rescue_judge_success_wins() -> void:
	var mc: MissionConfig = _mount_mission(8)
	var p: Player = _make_player("P")
	p.stealth = 12  # 两骰和 2~12 恒 ≤ 12，检定必成功
	p.action_count = 2
	var block: MapBlock = _make_block("实验室", 0, 0)
	block.add_objective_mark({"mark_id": "mark_1"})
	p.current_block = block
	_setup_game_env([p], [block])
	var options: Array = Game.mission_config.get_action_options(Game, p)
	assert_eq(options.size(), 1, "在标记地块应出现解救选项")
	await options[0]["execute"].call()
	assert_eq(p.action_count, 1, "解救检定应消耗 1 点行动（2 → 1）")
	assert_eq(mc.mission_state.get("rescue_judge_done"), true, "执行后应标记 rescue_judge_done")
	assert_true(Game.game_over_called, "检定成功应触发游戏结束")
	assert_eq(Game.game_result, "win", "潜行检定成功应判定胜利")


func test_mission_8_rescue_judge_fail_with_diary_wins() -> void:
	_mount_mission(8)
	var p: Player = _make_player("P")
	p.stealth = 0  # 两骰和恒 ≥ 2 > 0，检定必失败
	p.action_count = 2
	p.hand.append(_make_card("满是灰尘的日记本"))
	var block: MapBlock = _make_block("实验室", 0, 0)
	block.add_objective_mark({"mark_id": "mark_1"})
	p.current_block = block
	_setup_game_env([p], [block])
	await Game.mission_config.get_action_options(Game, p)[0]["execute"].call()
	assert_true(Game.game_over_called, "检定失败持日记本应触发游戏结束")
	assert_eq(Game.game_result, "win", "检定失败但持有日记本仍应胜利")


func test_mission_8_rescue_judge_fail_without_diary_loses() -> void:
	_mount_mission(8)
	var p: Player = _make_player("P")
	p.stealth = 0  # 检定必失败且无日记本
	p.action_count = 2
	var block: MapBlock = _make_block("实验室", 0, 0)
	block.add_objective_mark({"mark_id": "mark_1"})
	p.current_block = block
	_setup_game_env([p], [block])
	await Game.mission_config.get_action_options(Game, p)[0]["execute"].call()
	assert_true(Game.game_over_called, "检定失败无日记本应触发游戏结束")
	assert_eq(Game.game_result, "lose", "检定失败且无日记本应判定失败")


# === 任务 9：人类反击 —— 摧毁发射器 → 上传病毒；科学家弃置判负 ===

func test_mission_9_destroy_marks_and_upload_virus_win() -> void:
	_init_real_mission(9)
	var p: Player = Game.players[0]
	assert_not_null(p, "应已创建玩家")
	assert_true(await _wait_for_equipment(p, "科学家"), "开局应将科学家装备进第一名玩家")
	p.action_count = 10
	# 两个带任务标记的发射器地块
	var marked_blocks: Array = []
	for block in Game.map_area:
		if block != null and is_instance_valid(block) and block.has_objective_mark():
			marked_blocks.append(block)
	assert_eq(marked_blocks.size(), 2, "任务 9 地图应有 2 个任务标记地块")
	# 摧毁第一个发射器（require_no_monster=false，怪物标记不阻断）
	p.current_block = marked_blocks[0]
	var options: Array = Game.mission_config.get_action_options(Game, p)
	assert_eq(options.size(), 1, "标记未清空前在标记地块应仅有摧毁选项")
	assert_eq(options[0]["id"], "destroy_mark", "选项 id 应为 destroy_mark")
	await options[0]["execute"].call()
	assert_false(marked_blocks[0].has_objective_mark(), "第一个发射器标记应被移除")
	# 摧毁第二个发射器
	p.current_block = marked_blocks[1]
	options = Game.mission_config.get_action_options(Game, p)
	assert_eq(options.size(), 1, "仍剩标记时在标记地块应仅有摧毁选项")
	await options[0]["execute"].call()
	assert_false(marked_blocks[1].has_objective_mark(), "第二个发射器标记应被移除")
	# 场上无标记 + 装备科学家 + 在坠毁点 → 上传病毒选项出现并直接胜利
	var crash: MapBlock = _find_block("坠毁点")
	assert_not_null(crash, "任务 9 地图应包含坠毁点")
	p.current_block = crash
	options = Game.mission_config.get_action_options(Game, p)
	assert_eq(options.size(), 1, "条件齐备时应仅出现上传选项")
	assert_eq(options[0]["id"], "upload_virus", "选项 id 应为 upload_virus")
	await options[0]["execute"].call()
	assert_true(Game.game_over_called, "上传病毒应触发游戏结束")
	assert_eq(Game.game_result, "win", "上传病毒应判定胜利")


func test_mission_9_lose_when_scientist_discarded() -> void:
	_init_real_mission(9)
	var p: Player = Game.players[0]
	assert_true(await _wait_for_equipment(p, "科学家"), "开局应装备科学家")
	await p.discard(p.equipment_zone[0])
	assert_eq(Game.mission_config.mission_state.get("card_discard_failed"), true,
		"科学家弃置应置 card_discard_failed")
	Game.state_machine.transition_to(GameStateMachine.GameState.PLAYING)
	assert_true(Game.state_machine.check_win_condition(), "失败条件满足应终止游戏")
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.LOSE, "结果应为 LOSE")
	assert_eq(Game.game_result, "lose", "Game.game_result 应为 lose")


# === 任务 10：运输 —— 三标记奖励 → 提交物资 → 集结 ===

func test_mission_10_three_mark_rewards() -> void:
	_mount_mission(10)
	var p: Player = _make_player("P")
	_setup_game_env([p])
	Game.monster_pile.add(_make_monster_card("首领机器人", "boss"))
	# 三个标记地块分别触发不同奖励
	for mark_id: String in ["mark_1", "mark_2", "mark_3"]:
		var b: MapBlock = _make_block("标记地_" + mark_id, 0, 0)
		b.add_objective_mark({"mark_id": mark_id})
		p.current_block = b
		await b.trigger_objective_marks(p)
	# mark_1：多余配件×3 + 医疗用品×2；mark_2：脏毯子×3 + 首领牌；mark_3：燃料×2 + 医疗用品×1
	assert_eq(_count_in_hand(p, "多余配件"), 3, "mark_1 应给 3 个多余配件")
	assert_eq(_count_in_hand(p, "医疗用品"), 3, "mark_1+mark_3 应共给 3 个医疗用品")
	assert_eq(_count_in_hand(p, "脏毯子"), 3, "mark_2 应给 3 个脏毯子")
	assert_eq(_count_in_hand(p, "燃料"), 2, "mark_3 应给 2 个燃料")
	assert_eq(p.monster_zone.size(), 1, "mark_2 应抓取一张首领牌")


func test_mission_10_submit_items_rally_win() -> void:
	var mc: MissionConfig = _mount_mission(10)
	var base: MapBlock = _make_block("军事基地", 0, 0)
	var p: Player = _make_player("P")
	p.action_count = 2
	p.current_block = base
	# 手牌备齐提交清单：燃料6 脏毯子3 医疗用品2 多余配件2
	for i in 6:
		p.hand.append(_make_card("燃料"))
	for i in 3:
		p.hand.append(_make_card("脏毯子"))
	for i in 2:
		p.hand.append(_make_card("医疗用品"))
	for i in 2:
		p.hand.append(_make_card("多余配件"))
	_setup_game_env([p], [base])
	assert_false(Game.state_machine.check_win_condition(), "未提交物资不应胜利")
	var options: Array = Game.mission_config.get_action_options(Game, p)
	assert_eq(options.size(), 1, "在军事基地持有清单物资应出现提交选项")
	assert_eq(options[0]["id"], "submit_items", "选项 id 应为 submit_items")
	await options[0]["execute"].call()
	assert_eq(p.hand.size(), 0, "清单内物资应全部提交（弃置）")
	assert_eq(p.action_count, 1, "提交应消耗 1 点行动（2 → 1）")
	var submitted: Dictionary = mc.mission_state.get("submitted_items", {})
	assert_eq(int(submitted.get("燃料", 0)), 6, "燃料应提交 6 张")
	assert_eq(int(submitted.get("脏毯子", 0)), 3, "脏毯子应提交 3 张")
	assert_eq(int(submitted.get("医疗用品", 0)), 2, "医疗用品应提交 2 张")
	assert_eq(int(submitted.get("多余配件", 0)), 2, "多余配件应提交 2 张")
	# collect_items submit 模式达标 + 全员军事基地无怪 → WIN
	assert_true(Game.state_machine.check_win_condition(), "提交达标+全员军事基地无怪应胜利")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")


# === 任务 11：保护基地 —— 不抓初始怪物；清怪后摧毁标记；集结 ===

func test_mission_11_no_initial_monster_draw_flag() -> void:
	var mc: MissionConfig = _init_real_mission(11)
	if mc == null:
		return
	assert_true(mc.no_initial_monster_draw, "任务 11 应声明 no_initial_monster_draw")
	assert_eq(mc.van_fuel_required, -1, "任务 11 不通过面包车胜利")
	# 3 个标记地块各带 3 个怪物标记（destroy_current_mark require_no_monster 的门槛）
	var marked_blocks: Array = []
	for block in Game.map_area:
		if block != null and is_instance_valid(block) and block.has_objective_mark():
			marked_blocks.append(block)
	assert_eq(marked_blocks.size(), 3, "任务 11 地图应有 3 个任务标记地块")
	for block in marked_blocks:
		assert_eq(block.count_monster_mark(), 3, "每个机器人攻击部队应带 3 个怪物标记")
	# 初始怪物牌抓取发生在 start_game（跳过行为由单测覆盖）；此处验证旗标传递与开局怪物区为空
	for p in Game.players:
		assert_eq(p.monster_zone.size(), 0, "初始化后玩家怪物区应为空")


func test_mission_11_destroy_option_requires_no_monster() -> void:
	_mount_mission(11)
	var p: Player = _make_player("P")
	p.action_count = 3
	var block: MapBlock = _make_block("巡逻区", 0, 0)
	block.add_objective_mark({"mark_id": "mark_1"})
	block.add_monster_mark(3)
	p.current_block = block
	_setup_game_env([p], [block])
	assert_eq(Game.mission_config.get_action_options(Game, p).size(), 0,
		"地块有怪物标记时不应出现摧毁选项")
	# 清除怪物标记后选项出现
	block.remove_all_monster_marks()
	assert_eq(Game.mission_config.get_action_options(Game, p).size(), 1,
		"清除怪物标记后应出现摧毁选项")
	# 同地块其他玩家被怪物纠缠时选项消失
	var p2: Player = _make_player("P2")
	p2.current_block = block
	p2.monster_zone.append(_make_monster("巡逻机器人"))
	Game.players.append(p2)
	assert_eq(Game.mission_config.get_action_options(Game, p).size(), 0,
		"同地块玩家怪物区有怪时不应出现摧毁选项")


func test_mission_11_destroy_three_marks_rally_win() -> void:
	var mc: MissionConfig = _mount_mission(11)
	mc.initial_objective_mark_count = 3
	var base: MapBlock = _make_block("军事基地", 0, 0)
	var p: Player = _make_player("P")
	p.action_count = 9
	_setup_game_env([p], [base])
	var marked_blocks: Array = []
	for i in 3:
		var b: MapBlock = _make_block("攻击部队_%d" % i, 1, i)
		b.add_objective_mark({"mark_id": "mark_%d" % (i + 1)})
		marked_blocks.append(b)
		Game.map_area.append(b)
	# 依次摧毁 3 个标记（require_no_monster=true，标记地块无怪物标记）
	for b in marked_blocks:
		p.current_block = b
		var options: Array = Game.mission_config.get_action_options(Game, p)
		assert_eq(options.size(), 1, "在标记地块应出现摧毁选项")
		await options[0]["execute"].call()
		assert_false(b.has_objective_mark(), "任务标记应被移除")
	# 标记清零但玩家未回军事基地 → 不胜
	assert_false(Game.state_machine.check_win_condition(), "未全员抵达军事基地不应胜利")
	p.current_block = base
	assert_true(Game.state_machine.check_win_condition(), "标记清零+全员军事基地无怪应胜利")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")


# === 任务 12：烧死那群机器人 —— 摧毁 3 目标 → 面包车 ===

func test_mission_12_destroy_marks_van_win() -> void:
	var mc: MissionConfig = _mount_mission(12)
	mc.initial_objective_mark_count = 3
	var van: MapBlock = _make_block("面包车", 0, 0)
	var p: Player = _make_player("P")
	p.action_count = 9
	p.current_block = van
	_setup_game_env([p], [van])
	var marked_blocks: Array = []
	for i in 3:
		var b: MapBlock = _make_block("目标_%d" % i, 1, i + 1)
		b.add_objective_mark({"mark_id": "mark_%d" % (i + 1)})
		marked_blocks.append(b)
		Game.map_area.append(b)
	van.van_fuel = 3
	# 摧毁 2 个目标 → 未达标
	for i in 2:
		p.current_block = marked_blocks[i]
		await Game.mission_config.get_action_options(Game, p)[0]["execute"].call()
	assert_false(Game.state_machine.check_win_condition(), "仅移除 2/3 个标记不应胜利")
	# 摧毁第 3 个 → 达标；玩家返回面包车 → WIN
	p.current_block = marked_blocks[2]
	await Game.mission_config.get_action_options(Game, p)[0]["execute"].call()
	assert_true(mc.win_condition_components[0].check_win(Game), "移除 3/3 个标记应满足胜利组件")
	p.current_block = van
	assert_true(Game.state_machine.check_win_condition(), "标记清零+燃料3+全员面包车应胜利")
	assert_eq(Game.game_result, "win", "Game.game_result 应为 win")
