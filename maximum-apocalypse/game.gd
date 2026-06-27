extends Node2D

@onready var map_board: Node2D = $MapBoard
@onready var ui_manager: CanvasLayer = $UIManager
@onready var game_loop: Node = $GameLoopManager
@onready var rule_engine: Node = $RuleEngine

func _ready() -> void:
	print("[Game] 游戏场景初始化...")

	# 检查是否有选中的关卡和角色
	if not GameState.selected_mission:
		push_error("[Game] 错误：未选择关卡！")
		return

	if GameState.selected_character_ids.is_empty():
		push_error("[Game] 错误：未选择角色！")
		return

	# 初始化游戏状态
	setup_game_state()

	# 初始化玩家（根据选择的角色）
	setup_players_from_selection()

	# 初始化地图（根据关卡配置）
	await get_tree().create_timer(0.5).timeout
	if map_board and map_board.has_method("initialize_map_from_mission"):
		map_board.initialize_map_from_mission(GameState.selected_mission)

		# 重新查找起始地块位置（地图已创建）
		var starting_pos = find_tile_by_id(GameState.selected_mission.starting_tile_id)
		if starting_pos != Vector2i(-99, -99):
			# 更新所有玩家位置到起始地块
			for player_id in GameState.players.keys():
				GameState.players[player_id].position = starting_pos
			print("[Game] 所有玩家位置已更新到起始地块: " + str(starting_pos))

		# 显示玩家位置
		map_board.update_player_positions()

	# 加载拾荒牌堆（根据关卡配置）
	setup_scavenge_decks()

	# 启动游戏循环 - 增加延迟确保所有节点初始化完成
	await get_tree().create_timer(1.5).timeout
	if game_loop:
		game_loop.start_game()
	else:
		push_error("[Game] GameLoopManager节点未找到！")

func setup_game_state() -> void:
	var mission = GameState.selected_mission

	# GameState是autoload单例，需要手动重置所有状态
	GameState.players.clear()
	GameState.map_grid.clear()
	GameState.current_turn = 1
	GameState.active_player_id = ""
	GameState.current_phase = Enums.GamePhase.SPAWN
	GameState.game_status = Enums.GameStatus.PLAYING
	GameState.available_monster_tokens = 30
	GameState.monster_deck.clear()
	GameState.monster_discard_pile.clear()
	GameState.scavenge_decks = {
		Enums.ScavengeColor.RED: [],
		Enums.ScavengeColor.GREEN: [],
		Enums.ScavengeColor.BLUE: []
	}
	GameState.scavenge_discard_pile.clear()
	GameState.required_fuel = mission.required_van_fuel
	GameState.current_fuel_in_van = 0

	print("[Game] 游戏状态已初始化：关卡=" + mission.mission_name + "，需要燃料=" + str(GameState.required_fuel))

func setup_players_from_selection() -> void:
	var mission = GameState.selected_mission

	# 找到起始地块的位置
	var starting_tile_pos = find_tile_by_id(mission.starting_tile_id)

	if starting_tile_pos == Vector2i(-99, -99):
		push_error("[Game] 错误：未找到起始地块 " + mission.starting_tile_id)
		starting_tile_pos = Vector2i(0, 0)  # 默认位置

	print("[Game] 起始地块位置: " + str(starting_tile_pos))

	# 为每个选中的角色创建玩家
	for i in range(GameState.selected_character_ids.size()):
		var character_id = GameState.selected_character_ids[i]
		var player_data = load_character_data(character_id)

		if not player_data:
			push_error("[Game] 错误：无法加载角色数据 " + character_id)
			continue

		# 创建玩家实例（复制角色数据）
		var player_id = "player_" + str(i + 1)
		var player = {
			"id": player_id,
			"character_name": player_data.character_name,
			"max_hp": player_data.max_hp,
			"current_hp": player_data.max_hp,  # 初始满血
			"hunger_level": player_data.hunger_level,  # 使用角色初始饥饿度
			"is_starving": player_data.is_starving,
			"starving_damage_stage": player_data.starving_damage_stage,
			"position": starting_tile_pos,
			"base_stealth": player_data.base_stealth,
			"starving_stealth": player_data.starving_stealth,
			"action_points": player_data.action_points,
			"poison_tokens": player_data.poison_tokens,
			"is_stunned": player_data.is_stunned,
			"hand": [],
			"equipment_zone": [],
			"deck": [],  # 初始化为空，稍后填充角色卡
			"discard_pile": []
		}

		GameState.players[player_id] = player

		# 加载角色卡到牌库
		load_character_cards_to_deck(player_id, character_id)

		print("[Game] 玩家已创建: " + player_id + " (" + player_data.character_name + ")，位置=" + str(starting_tile_pos))

	# 设置第一个玩家为当前活跃玩家
	if not GameState.players.is_empty():
		GameState.active_player_id = GameState.players.keys()[0]

func load_character_data(character_id: String) -> PlayerData:
	var character_path = "res://data/characters/" + character_id + ".tres"

	if ResourceLoader.exists(character_path):
		var res = load(character_path)
		if res is PlayerData:
			return res

	return null

func find_tile_by_id(tile_id: String) -> Vector2i:
	# 在地图中查找指定ID的地块位置
	for pos in GameState.map_grid.keys():
		var tile = GameState.map_grid[pos]
		if tile["template_id"] == tile_id:
			return pos

	return Vector2i(-99, -99)  # 未找到

func load_character_cards_to_deck(player_id: String, character_id: String) -> void:
	# 加载角色专属卡牌到玩家牌库（正确路径）
	var cards_folder = "res://data/cards/characterCards/" + character_id + "/"
	var player = GameState.players[player_id]

	print("[Game] 正在加载角色卡牌: " + character_id)

	var dir = DirAccess.open(cards_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var clean_name = file_name.replace(".remap", "")
				var full_path = cards_folder + clean_name
				var res = load(full_path)
				if res is CharacterCardData:
					# 创建卡牌实例并添加到牌库
					var card = CardRuntime.new("char_card_" + str(randi()), res.id)
					player.deck.append(card)
					print("[Game]   加载卡牌: " + res.id)
			file_name = dir.get_next()

	# 如果没有找到角色卡，添加默认测试卡
	if player.deck.is_empty():
		print("[Game] 警告：角色 " + character_id + " 没有找到卡牌，使用默认牌库")
		for i in range(10):
			var card = CardRuntime.new("default_card_" + str(i), "default_action")
			player.deck.append(card)
	else:
		print("[Game] 玩家 " + player_id + " 牌库加载完成（" + str(player.deck.size()) + "张）")

	# === 开局抽4张牌作为初始手牌 ===
	for i in range(4):
		if player.deck.size() > 0:
			var drawn_card = player.deck.pop_front()
			player.hand.append(drawn_card)

	print("[Game] 玩家 " + player_id + " 开局手牌: " + str(player.hand.size()) + "张")

func setup_scavenge_decks() -> void:
	var mission = GameState.selected_mission

	# 加载红色拾荒牌堆
	for card_id in mission.red_scavenge_pool.keys():
		var count = mission.red_scavenge_pool[card_id]
		for i in range(count):
			var card = CardRuntime.new("scavenge_red_" + str(randi()), card_id)
			GameState.scavenge_decks[Enums.ScavengeColor.RED].append(card)

	# 加载绿色拾荒牌堆
	for card_id in mission.green_scavenge_pool.keys():
		var count = mission.green_scavenge_pool[card_id]
		for i in range(count):
			var card = CardRuntime.new("scavenge_green_" + str(randi()), card_id)
			GameState.scavenge_decks[Enums.ScavengeColor.GREEN].append(card)

	# 加载蓝色拾荒牌堆
	for card_id in mission.blue_scavenge_pool.keys():
		var count = mission.blue_scavenge_pool[card_id]
		for i in range(count):
			var card = CardRuntime.new("scavenge_blue_" + str(randi()), card_id)
			GameState.scavenge_decks[Enums.ScavengeColor.BLUE].append(card)

	print("[Game] 拾荒牌堆已加载：红=" + str(GameState.scavenge_decks[Enums.ScavengeColor.RED].size()) +
		  "，绿=" + str(GameState.scavenge_decks[Enums.ScavengeColor.GREEN].size()) +
		  "，蓝=" + str(GameState.scavenge_decks[Enums.ScavengeColor.BLUE].size()))