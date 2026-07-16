extends GutTest

## 测试 Game.initialize_game() 游戏初始化流程。
## 覆盖：玩家创建、地图构建、牌堆初始化、出生点放置。


func before_each() -> void:
	Game.players.clear()
	Game.map_area.clear()
	Game.monster_pile = null
	Game.monster_discard_pile = null
	Game.scavenge_discard_pile = null
	Game.red_scavenge_pile = null
	Game.green_scavenge_pile = null
	Game.blue_scavenge_pile = null
	Game.mission_config = null
	Game.current_mission = null
	Game.removed_cards.clear()
	Game.log_list.clear()
	Game.game_over_called = false
	Game.game_result = ""
	Game.coop_death_mode = false
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func after_each() -> void:
	Game.players.clear()
	Game.map_area.clear()
	Game.monster_pile = null
	Game.monster_discard_pile = null
	Game.scavenge_discard_pile = null
	Game.red_scavenge_pile = null
	Game.green_scavenge_pile = null
	Game.blue_scavenge_pile = null
	Game.mission_config = null
	Game.current_mission = null


func _make_seats(survivor_names: Array) -> Array:
	var seats: Array = []
	for name in survivor_names:
		var survivor: SurvivorData = DataManager.get_survivor(name)
		seats.append({"type": "human", "survivor": survivor})
	return seats


func test_initialize_game_creates_players() -> void:
	var mission: MissionData = DataManager.get_mission(1)
	assert_not_null(mission, "任务1应存在")
	var seats: Array = _make_seats(["firefighter", "surgeon"])
	Game.initialize_game(mission, {}, seats)
	assert_eq(Game.players.size(), 2, "应创建2个玩家")
	assert_eq(Game.players[0].player_name, "消防员", "玩家1应为消防员")
	assert_eq(Game.players[1].player_name, "外科医生", "玩家2应为外科医生")
	assert_eq(Game.players[0].hp, 32, "消防员初始HP=32")
	assert_eq(Game.players[0].max_hp, 32, "消防员最大HP=32")
	assert_eq(Game.players[0].get_sneak(), 6, "消防员潜行=6")
	assert_eq(Game.players[0].hunger, 1, "初始饥饿=1")


func test_initialize_game_creates_role_card() -> void:
	var mission: MissionData = DataManager.get_mission(1)
	var seats: Array = _make_seats(["firefighter"])
	Game.initialize_game(mission, {}, seats)
	var player: Player = Game.players[0]
	assert_not_null(player.role_card, "应有角色卡")
	assert_eq(player.role_card.role_name, "消防员", "角色名=消防员")
	assert_eq(player.role_card.sneak, 6, "正面潜行=6")
	assert_eq(player.role_card.hunger_sneak, 5, "反面潜行=5")
	assert_true(player.role_card.intrinsic_skills.size() > 0, "应有固有技能")


func test_initialize_game_creates_player_deck() -> void:
	var mission: MissionData = DataManager.get_mission(1)
	var seats: Array = _make_seats(["firefighter"])
	Game.initialize_game(mission, {}, seats)
	var player: Player = Game.players[0]
	assert_not_null(player.game_deck, "应有游戏牌堆")
	assert_true(player.game_deck.size() > 0, "牌堆不应为空")
	assert_not_null(player.game_discard_pile, "应有弃牌堆")


func test_initialize_game_builds_map() -> void:
	var mission: MissionData = DataManager.get_mission(1)
	var seats: Array = _make_seats(["firefighter"])
	Game.initialize_game(mission, {}, seats)
	assert_true(Game.map_area.size() > 0, "地图应有地块")
	assert_eq(Game.map_width, 5, "任务1地图宽度=5")
	assert_eq(Game.map_height, 5, "任务1地图高度=5")
	# 验证有出生点地块（面包车）
	var has_van: bool = false
	for block in Game.map_area:
		if block.block_name == "面包车":
			has_van = true
			break
	assert_true(has_van, "地图应包含面包车地块")


func test_initialize_game_map_blocks_have_data() -> void:
	var mission: MissionData = DataManager.get_mission(1)
	var seats: Array = _make_seats(["firefighter"])
	Game.initialize_game(mission, {}, seats)
	# 验证地块有完整的 MapBlockData（非空 block_name 的地块应有 scavenge_colors 或 monster_spawn_value）
	var has_spawn_value: bool = false
	for block in Game.map_area:
		if block.monster_spawn_value > 0:
			has_spawn_value = true
			break
	assert_true(has_spawn_value, "至少一个地块应有怪物生成值")


func test_initialize_game_places_players_on_spawn() -> void:
	var mission: MissionData = DataManager.get_mission(1)
	var seats: Array = _make_seats(["firefighter", "surgeon"])
	Game.initialize_game(mission, {}, seats)
	var spawn_block: MapBlock = null
	for block in Game.map_area:
		if block.block_name == "面包车":
			spawn_block = block
			break
	assert_not_null(spawn_block, "应找到出生点")
	for player in Game.players:
		assert_eq(player.current_block, spawn_block, "玩家应在出生点")
	assert_true(spawn_block.is_revealed(), "出生点应已翻开")


func test_initialize_game_init_monster_pile() -> void:
	var mission: MissionData = DataManager.get_mission(1)
	var seats: Array = _make_seats(["firefighter"])
	Game.initialize_game(mission, {}, seats)
	assert_not_null(Game.monster_pile, "应有怪物牌堆")
	assert_true(Game.monster_pile.size() > 0, "怪物牌堆不应为空")
	assert_not_null(Game.monster_discard_pile, "应有怪物弃牌堆")


func test_initialize_game_init_scavenge_piles() -> void:
	var mission: MissionData = DataManager.get_mission(1)
	var seats: Array = _make_seats(["firefighter"])
	Game.initialize_game(mission, {}, seats)
	assert_not_null(Game.red_scavenge_pile, "应有红色拾荒牌堆")
	assert_not_null(Game.green_scavenge_pile, "应有绿色拾荒牌堆")
	assert_not_null(Game.blue_scavenge_pile, "应有蓝色拾荒牌堆")
	assert_not_null(Game.scavenge_discard_pile, "应有拾荒弃牌堆")


func test_initialize_game_sets_mission_config() -> void:
	var mission: MissionData = DataManager.get_mission(1)
	var seats: Array = _make_seats(["firefighter"])
	Game.initialize_game(mission, {}, seats)
	assert_not_null(Game.mission_config, "应有任务配置")
	assert_eq(Game.mission_config.van_fuel_required, 4, "任务1燃料需求=4")
	assert_not_null(Game.current_mission, "应记录当前任务")


func test_initialize_game_null_mission_picks_random() -> void:
	var seats: Array = _make_seats(["firefighter"])
	Game.initialize_game(null, {}, seats)
	assert_not_null(Game.current_mission, "null任务应随机抽取一个")
	assert_not_null(Game.mission_config, "应有任务配置")


func test_initialize_game_skips_empty_seats() -> void:
	var mission: MissionData = DataManager.get_mission(1)
	var seats: Array = [
		{"type": "human", "survivor": DataManager.get_survivor("firefighter")},
		{"type": "empty", "survivor": null},
		{"type": "ai", "survivor": DataManager.get_survivor("surgeon")},
	]
	Game.initialize_game(mission, {}, seats)
	assert_eq(Game.players.size(), 1, "应跳过empty和ai座位，只创建1个玩家")
	assert_eq(Game.players[0].player_name, "消防员", "唯一玩家应为消防员")


func test_initialize_game_state_machine_initialized() -> void:
	var mission: MissionData = DataManager.get_mission(1)
	var seats: Array = _make_seats(["firefighter"])
	Game.initialize_game(mission, {}, seats)
	assert_eq(Game.state_machine.get_game_state(), GameStateMachine.GameState.WAITING, "状态应为WAITING")
