extends Node2D

@onready var map_board: Node2D = $MapBoard
@onready var ui_manager: CanvasLayer = $UIManager
@onready var game_loop: Node = $GameLoopManager
@onready var rule_engine: Node = $RuleEngine
@onready var effect_manager: Node = $EffectManager

func _ready() -> void:
	print("[Game] 游戏场景初始化...")

	# 设置窗口大小以适配UI布局
	DisplayServer.window_set_size(Vector2i(1300, 900))
	
	# 等待所有子节点准备完成
	await get_tree().create_timer(0.3).timeout

	# 检查是否有选中的关卡和角色
	if not GameState.selected_mission:
		push_error("[Game] 错误：未选择关卡！")
		return

	if GameState.selected_character_ids.is_empty():
		push_error("[Game] 错误：未选择角色！")
		return

	# 初始化效果管理器（必须在setup_game_state之前）
	if effect_manager and effect_manager.has_method("initialize"):
		effect_manager.initialize(rule_engine, ui_manager, map_board)
		print("[Game] EffectManager已初始化")

	# 初始化游戏状态
	setup_game_state()

	# 初始化玩家（根据选择的角色）
	setup_players_from_selection()

	# 初始化地图（根据关卡配置）
	await get_tree().create_timer(0.5).timeout
	if map_board and map_board.has_method("initialize_map_from_mission"):
		var starting_pos = map_board.initialize_map_from_mission(GameState.selected_mission)

		# 使用返回的起始地块位置更新所有玩家位置
		if starting_pos != Vector2i(-99, -99):
			for player_id in GameState.players.keys():
				GameState.players[player_id].position = starting_pos
			print("[Game] 所有玩家位置已更新到起始地块: " + str(starting_pos))
		else:
			push_error("[Game] 错误：未找到起始地块！")

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

	# 加载怪物牌库（根据关卡怪物类型）
	setup_monster_deck()

func setup_monster_deck() -> void:
	var mission = GameState.selected_mission
	var monster_type = mission.monster_type

	# 根据怪物类型确定文件夹路径
	var pack_folder: String
	var pack_name: String
	match monster_type:
		Enums.MonsterPack.ZOMBIE:
			pack_folder = "zombie"
			pack_name = "僵尸"
		Enums.MonsterPack.MUTANT:
			pack_folder = "mutant"
			pack_name = "突变体"
		Enums.MonsterPack.ALIEN:
			pack_folder = "alien"
			pack_name = "外星人"
		Enums.MonsterPack.ROBOT:
			pack_folder = "robot"
			pack_name = "机器人"
		_:
			push_error("[Game] 错误：未知怪物类型 " + str(monster_type))
			return

	var path = "res://data/monsters/" + pack_folder + "/"
	print("[Game] 正在加载" + pack_name + "怪物包...")

	# 扫描文件夹，加载所有怪物卡
	var dir = DirAccess.open(path)
	if not dir:
		push_error("[Game] 错误：无法打开怪物包文件夹 " + path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var total_monsters = 0

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path = path + file_name.replace(".remap", "")
			var res = load(full_path)
			if res is MonsterData:
				# 根据count字段添加相应数量的怪物实例
				var count = res.count
				for i in range(count):
					GameState.monster_deck.append(res)
				total_monsters += count
				print("[Game]   加载: " + res.monster_name + " x" + str(count))
		file_name = dir.get_next()

	dir.list_dir_end()

	# 打乱怪物牌库
	GameState.monster_deck.shuffle()

	print("[Game] " + pack_name + "怪物包已加载完成，共 " + str(total_monsters) + " 张怪物卡，牌库已打乱")

func setup_players_from_selection() -> void:
	var mission = GameState.selected_mission

	# 为每个选中的角色创建玩家
	for i in range(GameState.selected_character_ids.size()):
		var character_id = GameState.selected_character_ids[i]
		var player_data = load_character_data(character_id)

		if not player_data:
			push_error("[Game] 错误：无法加载角色数据 " + character_id)
			continue

		# 创建玩家实例（使用PlayerState类）
		# 注意：位置将在地图初始化后设置
		var player_id = "player_" + str(i + 1)
		var player = PlayerState.new()
		player.id = player_id
		player.character_name = player_data.character_name
		player.max_hp = player_data.max_hp
		player.current_hp = player_data.max_hp  # 初始满血
		player.hunger_level = player_data.hunger_level
		player.is_starving = player_data.is_starving
		player.starving_damage_stage = player_data.starving_damage_stage
		player.position = Vector2i(-99, -99)  # 临时位置，等地图初始化后更新
		player.base_stealth = player_data.base_stealth
		player.starving_stealth = player_data.starving_stealth
		player.action_points = player_data.action_points
		player.poison_tokens = player_data.poison_tokens
		player.is_stunned = player_data.is_stunned

		GameState.players[player_id] = player

		# 加载角色卡到牌库
		load_character_cards_to_deck(player_id, character_id)

		print("[Game] 玩家已创建: " + player_id + " (" + player_data.character_name + ")")

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
					# 根据deck_quantity创建多张卡牌实例
					var quantity = res.deck_quantity if res.deck_quantity > 0 else 1
					for j in range(quantity):
						var card = CardRuntime.new("char_card_" + str(randi()) + "_" + str(j), res.id, res.card_name)
						player.deck.append(card)
					print("[Game]   加载卡牌: " + res.card_name + " x" + str(quantity))
			file_name = dir.get_next()

	# 如果没有找到角色卡，添加默认测试卡
	if player.deck.is_empty():
		print("[Game] 警告：角色 " + character_id + " 没有找到卡牌，使用默认牌库")
		for i in range(10):
			var card = CardRuntime.new("default_card_" + str(i), "default_action")
			player.deck.append(card)
	else:
		# 洗牌
		player.deck.shuffle()
		print("[Game] 玩家 " + player_id + " 牌库加载完成并洗牌（" + str(player.deck.size()) + "张）")

	# === 开局抽4张牌作为初始手牌 ===
	for i in range(4):
		if player.deck.size() > 0:
			var drawn_card = player.deck.pop_front()
			player.hand.append(drawn_card)

	print("[Game] 玩家 " + player_id + " 开局手牌: " + str(player.hand.size()) + "张")

func setup_scavenge_decks() -> void:
	var mission = GameState.selected_mission

	# 预先扫描所有拾荒卡文件夹，建立ID映射和类别映射
	var scavenge_card_map = _build_scavenge_card_map()

	# 加载红色拾荒牌堆
	for card_id in mission.red_scavenge_pool.keys():
		var count = mission.red_scavenge_pool[card_id]
		_load_scavenge_card_to_deck(card_id, count, Enums.ScavengeColor.RED, scavenge_card_map)

	# 加载绿色拾荒牌堆
	for card_id in mission.green_scavenge_pool.keys():
		var count = mission.green_scavenge_pool[card_id]
		_load_scavenge_card_to_deck(card_id, count, Enums.ScavengeColor.GREEN, scavenge_card_map)

	# 加载蓝色拾荒牌堆
	for card_id in mission.blue_scavenge_pool.keys():
		var count = mission.blue_scavenge_pool[card_id]
		_load_scavenge_card_to_deck(card_id, count, Enums.ScavengeColor.BLUE, scavenge_card_map)

	print("[Game] 拾荒牌堆已加载：红=" + str(GameState.scavenge_decks[Enums.ScavengeColor.RED].size()) +
		  "，绿=" + str(GameState.scavenge_decks[Enums.ScavengeColor.GREEN].size()) +
		  "，蓝=" + str(GameState.scavenge_decks[Enums.ScavengeColor.BLUE].size()))

	# 洗牌
	GameState.scavenge_decks[Enums.ScavengeColor.RED].shuffle()
	GameState.scavenge_decks[Enums.ScavengeColor.GREEN].shuffle()
	GameState.scavenge_decks[Enums.ScavengeColor.BLUE].shuffle()
	print("[Game] 拾荒牌堆已洗牌")

# 扫描所有拾荒卡文件夹，建立精确ID映射和类别ID映射
func _build_scavenge_card_map() -> Dictionary:
	# 精确ID映射：id -> {path, data}
	var exact_map: Dictionary = {}
	# 类别ID映射：category_prefix -> [list of variants]
	var category_map: Dictionary = {}

	# 类别ID前缀定义（任务配置中使用的类别名 -> 对应的拾荒卡ID前缀）
	var category_prefixes = {
		"food": "food_",
		"ammo": "ammo_",
		"medical_supplies": "medical_",
		"fuel": "",  # fuel没有变体，精确匹配
		"nothing": "",  # nothing没有变体
		"spare_parts": "",  # spare_parts没有变体
		"flashlight": "",
		"binoculars": "",
		"pistol": "",
		"walkie_talkie": "",
		"backpack": "",
		"bulletproof_vest": "",
		"dynamite": "",
		"antidote": ""
	}

	var folders = ["red", "green", "blue", "gray"]

	for folder in folders:
		var path = "res://data/cards/scavengeCards/" + folder + "/"
		var dir = DirAccess.open(path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".tres"):
					var full_path = path + file_name.replace(".remap", "")
					var res = load(full_path)
					if res is ScavengeCardData:
						# 精确ID映射
						exact_map[res.id] = {"path": full_path, "data": res}

						# 类别ID映射：检查ID是否属于某个类别
						for category in category_prefixes.keys():
							var prefix = category_prefixes[category]
							if prefix != "" and res.id.begins_with(prefix):
								if not category_map.has(category):
									category_map[category] = []
								category_map[category].append(res)
								break
				file_name = dir.get_next()

	return {"exact": exact_map, "category": category_map}

# 根据ID加载拾荒卡到指定颜色的牌堆（支持类别ID随机变体）
func _load_scavenge_card_to_deck(card_id: String, count: int, color: Enums.ScavengeColor, card_map: Dictionary) -> void:
	var exact_map = card_map["exact"]
	var category_map = card_map["category"]

	# 检查是否是精确ID
	if exact_map.has(card_id):
		var card_info = exact_map[card_id]
		var res: ScavengeCardData = card_info["data"]
		for i in range(count):
			var card = CardRuntime.new("scavenge_" + str(randi()), res.id, res.card_name)
			GameState.scavenge_decks[color].append(card)
		print("[Game]   加载拾荒卡: " + res.card_name + " x" + str(count) + " -> " + Enums.ScavengeColor.keys()[color] + "牌堆")
		return

	# 检查是否是类别ID（需要从变体中随机选择）
	if category_map.has(card_id):
		var variants = category_map[card_id]
		for i in range(count):
			var res: ScavengeCardData = variants[randi() % variants.size()]
			var card = CardRuntime.new("scavenge_" + str(randi()), res.id, res.card_name)
			GameState.scavenge_decks[color].append(card)
		print("[Game]   加载拾荒卡(随机变体): " + card_id + " x" + str(count) + " -> " + Enums.ScavengeColor.keys()[color] + "牌堆")
		return

	print("[Game] 警告：拾荒卡ID不存在: " + card_id)
