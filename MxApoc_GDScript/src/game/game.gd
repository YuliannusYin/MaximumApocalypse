extends Node

## Game 游戏全局类（autoload）。
## 全局区域 + build_map + destroy_map_block + 状态机委托。
## 设计文档：GameDesignDocus/GameSystem/Game/Game.md

# === 全局区域 ===
var monster_pile: Pile = null
var monster_discard_pile: Pile = null
var red_scavenge_pile: Pile = null
var green_scavenge_pile: Pile = null
var blue_scavenge_pile: Pile = null
var scavenge_discard_pile: Pile = null
var map_area: Array = []
var map_width: int = 0
var map_height: int = 0
var card_resolution_area: Array = []
var players: Array = []

# === 状态机 ===
var state_machine: GameStateMachine = null
var mission_config: MissionConfig = null
var stats_tracker: StatsTracker = null
var coop_death_mode: bool = false
var current_mission: Variant = null  # 可能是 Dictionary 或 Resource，类型不确定
var removed_cards: Array = []
var log_list: Array = []

# === 子技能注册表 ===
# 键为子技能 english_name（全局唯一），值为 SkillData。
# 由 _create_skill_from_data 在编译父技能时按 english_name 自动注册（递归子技能）。
var sub_skill_registry: Dictionary = {}

# === 测试用标记（向后兼容，由 state_machine.game_over 同步设置） ===
var game_over_called: bool = false
var game_result: String = ""


func _ready() -> void:
	state_machine = GameStateMachine.new()
	state_machine.init()
	stats_tracker = StatsTracker.new()
	_wire_mission_event_forwarding()


## 日志输出。方法名避开 GDScript 内置 log()（自然对数）。
func log_message(message: String) -> void:
	log_list.append(message)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.publish_log(message)


## 记录日志消息（log_message 的别名，供 content 代码统一调用）。
func log(message: String) -> void:
	log_message(message)


# === 状态机委托 ===

## 游戏开局流程。委托给 state_machine.start_game()。
func start_game() -> void:
	if state_machine != null and is_instance_valid(state_machine):
		await state_machine.start_game()


## 游戏结束流程。接受 String ("win"/"lose") 并委托给 state_machine.game_over(enum)。
func game_over(result: String) -> void:
	var enum_result: int = GameStateMachine.GameResult.LOSE
	if result == "win":
		enum_result = GameStateMachine.GameResult.WIN
	if state_machine != null and is_instance_valid(state_machine):
		state_machine.game_over(enum_result)
	else:
		game_over_called = true
		game_result = result


## 进入下一玩家回合。委托给 state_machine.next_turn()。
func next_turn() -> void:
	if state_machine != null and is_instance_valid(state_machine):
		await state_machine.next_turn()


## 返回当前回合玩家。委托给 state_machine.get_current_player()。
func get_current_player() -> Variant:
	if state_machine != null and is_instance_valid(state_machine):
		return state_machine.get_current_player()
	return null


## 检查任务特定胜利条件。委托给 mission_config.check_win（三层架构组件/脚本编排）。
func check_mission_win_condition() -> bool:
	if mission_config == null:
		return false
	return mission_config.check_win(self)


# === 任务事件转发（三层架构：EventBus → mission_config.on_event） ===

## 一次性连接 EventBus 信号到任务事件转发处理方法。
## Game 为 autoload，_ready() 仅执行一次，无需断开重连。
func _wire_mission_event_forwarding() -> void:
	if EventBus == null or not is_instance_valid(EventBus):
		return
	EventBus.turn_started.connect(_on_event_turn_started)
	EventBus.turn_ended.connect(_on_event_turn_ended)
	EventBus.player_moved.connect(_on_event_player_moved)
	EventBus.block_revealed.connect(_on_event_block_revealed)
	EventBus.block_destroyed.connect(_on_event_block_destroyed)
	EventBus.monster_died.connect(_on_event_monster_died)
	EventBus.objective_mark_triggered.connect(_on_event_objective_mark_triggered)
	EventBus.equipment_equipped.connect(_on_event_equipment_equipped)


## 转发事件到任务配置（mission_config 为 null 时忽略）。
func _forward_mission_event(event_name: String, event: Dictionary) -> void:
	if mission_config == null:
		return
	mission_config.on_event(self, event_name, event)


func _on_event_turn_started(player: Variant) -> void:
	_forward_mission_event("turn_started", {"player": player})


func _on_event_turn_ended(player: Variant) -> void:
	_forward_mission_event("turn_ended", {"player": player})


func _on_event_player_moved(player: Variant, source_block: Variant, target_block: Variant) -> void:
	_forward_mission_event("player_moved", {"player": player, "source_block": source_block, "target_block": target_block})


func _on_event_block_revealed(block: Variant, player: Variant) -> void:
	_forward_mission_event("block_revealed", {"block": block, "player": player})


func _on_event_block_destroyed(block: Variant, source: Variant) -> void:
	_forward_mission_event("block_destroyed", {"block": block, "source": source})


func _on_event_monster_died(monster: Variant, source: Variant) -> void:
	_forward_mission_event("monster_died", {"monster": monster, "source": source})


func _on_event_objective_mark_triggered(player: Variant, block: Variant, mark: Variant) -> void:
	_forward_mission_event("objective_mark_triggered", {"player": player, "block": block, "mark": mark})


func _on_event_equipment_equipped(player: Variant, card: Variant) -> void:
	_forward_mission_event("equipment_equipped", {"player": player, "card": card})


# === 地图管理 ===

## 通过坐标查询存活的地块。
func get_block_by_coord(x: int, y: int) -> MapBlock:
	for block in map_area:
		if block != null and is_instance_valid(block) and block.is_alive():
			if block.coordinate["x"] == x and block.coordinate["y"] == y:
				return block
	return null


## 按名字查询所有同名的存活地块。
func get_blocks_by_name(block_name: String) -> Array:
	var result: Array = []
	for block in map_area:
		if block != null and is_instance_valid(block) and block.is_alive():
			if block.block_name == block_name:
				result.append(block)
	return result


## 返回地块的四向相邻存活地块。
func get_adjacent_alive_blocks(block: MapBlock) -> Array:
	return block.get_adjacent_blocks()


## 根据任务包配置构建游戏地图。
## 编码：-1=无地块 / 0=出生点 / 1=随机地块 / 2=结束点 / 3=标记地块
func build_map(mission_config_arg: Variant) -> void:
	map_area.clear()
	map_width = 0
	map_height = 0
	if mission_config_arg == null:
		return
	var map_template: Variant = _config_get(mission_config_arg, "map_template")
	if map_template == null or map_template.is_empty():
		return
	map_height = map_template.size()
	map_width = map_template[0].size()
	var spawn_name: String = _config_get(mission_config_arg, "spawn_block_name", "")
	var end_name: String = _config_get(mission_config_arg, "end_block_name", "")
	# 统计出生点（code 0）和结束点（code 2）格子数，这些格子直接使用 spawn_name/end_name，
	# 不从随机池中抽取，因此需从 map_block_config 的计数中扣除，否则同名地块会重复出现在地图上
	var spawn_cell_count: int = 0
	var end_cell_count: int = 0
	for y in map_height:
		for x in map_width:
			var code0: int = map_template[y][x]
			if code0 == 0:
				spawn_cell_count += 1
			elif code0 == 2:
				end_cell_count += 1
	var block_pool: Array = []
	var block_config: Variant = _config_get(mission_config_arg, "map_block_config")
	if block_config != null:
		for entry in block_config:
			var block_name: String = _config_get(entry, "block_name", "")
			var count: int = _config_get(entry, "count", 0)
			if block_name == spawn_name:
				count -= spawn_cell_count
			elif block_name == end_name:
				count -= end_cell_count
			var block_def: MapBlockData = DataManager.get_map_block_def_by_name(block_name)
			if block_def != null and block_def.variants.size() > 0:
				var variant_indices: Array = []
				for i in block_def.variants.size():
					variant_indices.append(i)
				variant_indices.shuffle()
				for i in max(0, count):
					block_pool.append({"block_name": block_name, "variant_index": variant_indices[i % variant_indices.size()]})
			else:
				for i in max(0, count):
					block_pool.append({"block_name": block_name, "variant_index": -1})
	for y in map_height:
		for x in map_width:
			var code: int = map_template[y][x]
			if code == -1:
				continue
			var block_name: String = ""
			var block: MapBlock = null
			var variant_index: int = -1
			if code == 0:
				block_name = spawn_name
				var spawn_def: MapBlockData = DataManager.get_map_block_def_by_name(spawn_name)
				if spawn_def != null and spawn_def.variants.size() > 0:
					variant_index = randi() % spawn_def.variants.size()
			elif code == 1:
				if block_pool.is_empty():
					continue
				var idx: int = randi() % block_pool.size()
				var entry: Dictionary = block_pool.pop_at(idx)
				block_name = entry["block_name"]
				variant_index = entry.get("variant_index", -1)
			elif code == 2:
				block_name = end_name
				var end_def: MapBlockData = DataManager.get_map_block_def_by_name(end_name)
				if end_def != null and end_def.variants.size() > 0:
					variant_index = randi() % end_def.variants.size()
			elif code == 3:
				if block_pool.is_empty():
					continue
				var idx3: int = randi() % block_pool.size()
				var entry3: Dictionary = block_pool.pop_at(idx3)
				block_name = entry3["block_name"]
				variant_index = entry3.get("variant_index", -1)
			block = _create_map_block(block_name, variant_index)
			if block == null:
				continue
			block.set_coordinate(x, y)
			if code == 0 or code == 2 or code == 3:
				block.revealed = true
			if code == 3:
				var marks: Variant = _config_get(mission_config_arg, "objective_marks")
				if marks != null and not marks.is_empty():
					var mark: Variant = marks.pop_front()
					block.add_objective_mark(mark)
					var initial_marks: int = _config_get(mark, "initial_monster_marks", 0)
					if initial_marks > 0:
						block.add_monster_mark(initial_marks)
			map_area.append(block)


## 内部方法：从 Dictionary 或 Object 安全读取字段。
func _config_get(config: Variant, field: String, default: Variant = null) -> Variant:
	if config == null:
		return default
	if config is Dictionary:
		return config.get(field, default)
	var value: Variant = config.get(field)
	return value if value != null else default


## 内部方法：根据地块名创建 MapBlock 实例。从 DataManager 加载完整地块数据。
func _create_map_block(block_name: String, variant_index: int = -1) -> MapBlock:
	var block: MapBlock = MapBlock.new()
	block.block_name = block_name
	var block_def: MapBlockData = DataManager.get_map_block_def_by_name(block_name)
	if block_def != null:
		if variant_index >= 0 and variant_index < block_def.variants.size():
			var variant: Dictionary = block_def.variants[variant_index]
			block.scavenge_colors = PackedStringArray(variant.get("scavenge_colors", []))
			block.monster_spawn_value = int(variant.get("monster_spawn_value", 0))
		else:
			block.scavenge_colors = PackedStringArray(block_def.scavenge_colors)
			block.monster_spawn_value = block_def.monster_spawn_value
		for skill_data in block_def.skills:
			var skill: Skill = _create_skill_from_data(skill_data)
			block.add_skill(skill)
	return block


## 摧毁地块流程。6 节点：before → 玩家弹出 → 怪物标记清零 → on → 状态变更 → after。
func destroy_map_block(block: MapBlock, source: Variant) -> bool:
	if block == null or not is_instance_valid(block):
		return false
	var event: Dictionary = EventSystem.create_destroy_block_event(source, block)
	# 1. 摧毁地块前（取消点）
	for player in players:
		if player != null and is_instance_valid(player):
			await player.trigger("before_destroy_block", event)
	if EventSystem.is_cancelled(event):
		return false
	# 2. 处理地块上的玩家（弹出到相邻存活地块）
	var players_on_block: Array = block.get_players()
	for player in players_on_block:
		var adjacent: Array = block.get_adjacent_blocks()
		if adjacent.is_empty():
			log_message(LogColors.player(player.player_name) + " 无处可逃，受到 5 点伤害")
			player.damage(5, null, "block_destroy")
		else:
			var target: MapBlock = await player.choose_map_block(adjacent)
			if target == null:
				target = adjacent[0]
			if block.has_method("_clear_skills_for_player"):
				block._clear_skills_for_player(player)
			player.current_block = target
			if target.has_method("_acquire_skills_for_player"):
				target._acquire_skills_for_player(player)
			if not target.is_revealed():
				await target.reveal(true, player)
	# 3. 消灭地块上的所有怪物标记
	block.monster_marks = 0
	# 4. 摧毁地块时（系统结算）
	for player in players:
		if player != null and is_instance_valid(player):
			await player.trigger("on_destroy_block", event)
	# 5. 地块状态变更，从地图区域移除
	block.block_state = "destroyed"
	map_area.erase(block)
	log_message(LogColors.block(block.block_name) + " 被摧毁了")
	# 6. 摧毁地块后（通知）
	for player in players:
		if player != null and is_instance_valid(player):
			await player.trigger("after_destroy_block", event)
	return true


# === 玩家管理 ===

func get_all_players() -> Array:
	return players


func get_alive_players() -> Array:
	var result: Array = []
	for player in players:
		if player != null and is_instance_valid(player) and player.is_alive():
			result.append(player)
	return result


func all_players_dead() -> bool:
	for player in players:
		if player != null and is_instance_valid(player) and player.is_alive():
			return false
	return true


## 返回地块上的所有目标（玩家 + 怪物），用于猎枪/氧气罐的溅射。
## 怪物随其纠缠玩家所在地块判定位置（怪物存于 player.monster_zone）。
func get_target(block: MapBlock) -> Array:
	if block == null or not is_instance_valid(block):
		return []
	var targets: Array = []
	for player in players:
		if player == null or not is_instance_valid(player):
			continue
		if player.get_current_block() == block:
			targets.append(player)
			if "monster_zone" in player:
				for monster in player.monster_zone:
					if monster != null and is_instance_valid(monster):
						targets.append(monster)
	return targets


# === 卡牌管理 ===

## 将卡牌移出游戏（区别于进入弃牌堆）。
func remove_card(card: Card, silent: bool = false) -> void:
	removed_cards.append(card)
	if not silent:
		log_message(LogColors.card(card.card_name) + " 被移出游戏")


## 获取指定颜色的拾荒牌堆。
func get_scavenge_pile(color: String) -> Pile:
	match color:
		"red":
			return red_scavenge_pile
		"green":
			return green_scavenge_pile
		"blue":
			return blue_scavenge_pile
	return null


## 返回玩家面前纠缠的怪物列表。
func get_engaged_monsters(player: Variant) -> Array:
	if player == null or not is_instance_valid(player):
		return []
	if "monster_zone" in player:
		return player.monster_zone
	return []


## 从玩家指定区域随机返回一张牌；无牌返回 null。
## 装备区持有 Equipment 实体，返回时映射为来源 EquipmentCard，保持"返回卡"语义。
func get_random_card(player: Variant, areas: Array) -> Variant:
	if player == null or not is_instance_valid(player):
		return null
	var all_cards: Array = []
	for area in areas:
		if area == "hand" and "hand" in player:
			all_cards.append_array(player.hand)
		elif area == "equipment" and "equipment_zone" in player:
			for e in player.equipment_zone:
				if e != null and is_instance_valid(e) and e.get("equipment_card") != null:
					all_cards.append(e.equipment_card)
	if all_cards.is_empty():
		return null
	return all_cards[randi() % all_cards.size()]


## 根据卡牌名创建拾荒卡实例。
## 遍历所有拾荒包数据（red/green/blue/gray），按 card_name 精确匹配 ScavengeCardData，
## 找到时调用 _create_scavenge_card_from_data 创建实例并返回；未找到返回 null 并记录日志。
func create_scavenge_card(card_name: String) -> Card:
	for color in ["red", "green", "blue", "gray"]:
		var pile_data: Array = DataManager.get_scavenge_pile(color)
		for card_data in pile_data:
			if card_data.card_name == card_name:
				return _create_scavenge_card_from_data(card_data, color)
	log_message("未找到拾荒卡：" + LogColors.card(card_name))
	return null


## 从指定牌堆中查找并返回第一张匹配名称的卡牌；未找到返回 null。
## pile 可为 Pile 或 Array；运行时卡牌以 card.card_name 标识。
func get_card(card_english_name: String, pile: Variant) -> Card:
	if pile == null:
		return null
	var cards: Array
	if pile is Array:
		cards = pile
	elif pile is Pile:
		cards = pile.cards
	else:
		return null
	for card in cards:
		if card == null or not is_instance_valid(card):
			continue
		if card.card_name == card_english_name or card.english_name == card_english_name:
			return card
	return null


# === 游戏初始化 ===

## 游戏初始化：从 RoomState 创建玩家、构建地图、初始化牌堆。
## 在 start_game() 前调用。mission 为 null 时随机抽取一个任务。
func initialize_game(mission: MissionData, variants: Dictionary, seats: Array) -> void:
	# 1. 确定任务
	if mission == null:
		var all_missions: Array = DataManager.get_all_missions()
		if all_missions.is_empty():
			push_error("Game.initialize_game: 无可用任务")
			return
		mission = all_missions[randi() % all_missions.size()]
	current_mission = mission

	# 2. 设置任务配置
	mission_config = MissionConfig.new()
	mission_config.van_fuel_required = int(mission.van_fuel_required) if mission.van_fuel_required != null else -1
	mission_config.mission_state = {}
	_mount_mission_components(mission)
	mission_config.setup_components(self)

	# 3. 创建玩家
	players.clear()
	for i in range(seats.size()):
		var seat: Dictionary = seats[i]
		if seat.type == "empty" or seat.type == "ai":
			continue
		var survivor: SurvivorData = seat.survivor
		if survivor == null:
			continue
		var player: Player = Player.new()
		player.seat_number = i
		player.player_name = survivor.character_name
		player.max_hp = survivor.max_hp
		player.hp = survivor.initial_hp
		player.hunger = 1
		player.role_card = _create_role_card_from_survivor(survivor)
		player.game_deck = _create_player_deck(survivor)
		player.game_discard_pile = Pile.new()
		# 挂载通用主动技能
		for skill_data in DataManager.get_common_skills():
			player.add_skill(_create_skill_from_data(skill_data))
		# 挂载角色固有技能
		if player.role_card != null:
			for skill in player.role_card.intrinsic_skills:
				player.add_skill(skill)
		players.append(player)

	# 4. 构建地图
	var map_config: Dictionary = _build_map_config(mission)
	build_map(map_config)

	# 5. 将玩家放到出生点
	var spawn_block: MapBlock = _find_spawn_block(mission)
	if spawn_block != null:
		for player in players:
			player.current_block = spawn_block

	# 6. 初始化全局牌堆
	_init_global_piles(mission)

	# 7. 初始化状态机
	if state_machine != null and is_instance_valid(state_machine):
		state_machine.init()


## 内部方法：按任务数据声明挂载任务组件与脚本实例（三层架构第二/三层）。
## win_conditions / lose_conditions / triggers / actions 逐项经注册表实例化，
## 未知 id 由注册表 push_error 并返回 null，此处跳过不挂载。
func _mount_mission_components(mission: MissionData) -> void:
	if mission_config == null:
		return
	mission_config.win_condition_components.clear()
	mission_config.lose_condition_components.clear()
	mission_config.trigger_components.clear()
	mission_config.action_components.clear()
	mission_config.mission_script_instance = null
	for cfg in mission.win_conditions:
		var win_component: MissionComponent = MissionComponentRegistry.create(cfg.get("component", ""), cfg.get("params", {}))
		if win_component != null:
			mission_config.win_condition_components.append(win_component)
	for cfg in mission.lose_conditions:
		var lose_component: MissionComponent = MissionComponentRegistry.create(cfg.get("component", ""), cfg.get("params", {}))
		if lose_component != null:
			mission_config.lose_condition_components.append(lose_component)
	for cfg in mission.triggers:
		var trigger_component: MissionComponent = MissionComponentRegistry.create(cfg.get("component", ""), cfg.get("params", {}))
		if trigger_component != null:
			mission_config.trigger_components.append(trigger_component)
	for cfg in mission.actions:
		var action_component: MissionComponent = MissionComponentRegistry.create(cfg.get("component", ""), cfg.get("params", {}))
		if action_component != null:
			mission_config.action_components.append(action_component)
	if mission.mission_script != "":
		mission_config.mission_script_instance = MissionScriptRegistry.create(mission.mission_script)


## 内部方法：从 MissionData 构建 build_map() 所需的配置字典。
func _build_map_config(mission: MissionData) -> Dictionary:
	var config: Dictionary = {}
	config["map_template"] = mission.map_layout
	# map_blocks_config 在 MissionData 中是 Dictionary{name: count}，build_map 需要 Array{name, count}
	var block_config: Array = []
	for block_name in mission.map_blocks_config:
		block_config.append({"block_name": block_name, "count": mission.map_blocks_config[block_name]})
	config["map_block_config"] = block_config
	# 从 map_legend 提取 spawn_block_name 和 end_block_name
	config["spawn_block_name"] = ""
	config["end_block_name"] = ""
	if mission.map_legend.has("0") and mission.map_legend["0"] is Dictionary:
		config["spawn_block_name"] = mission.map_legend["0"].get("block_name", "")
	if mission.map_legend.has("2") and mission.map_legend["2"] is Dictionary:
		config["end_block_name"] = mission.map_legend["2"].get("block_name", "")
	# objective_marks 需要 copy，因为 build_map 会 pop_front 消费
	config["objective_marks"] = mission.objective_marks.duplicate(true)
	return config


## 内部方法：查找任务的出生点地块。
func _find_spawn_block(mission: MissionData) -> MapBlock:
	var spawn_name: String = ""
	if mission.map_legend.has("0") and mission.map_legend["0"] is Dictionary:
		spawn_name = mission.map_legend["0"].get("block_name", "")
	if spawn_name == "":
		return null
	for block in map_area:
		if block != null and is_instance_valid(block) and block.block_name == spawn_name:
			return block
	return null


## 内部方法：初始化全局牌堆（怪物牌堆 + 拾荒牌堆 + 弃牌堆）。
func _init_global_piles(mission: MissionData) -> void:
	# 怪物牌堆
	monster_pile = Pile.new()
	monster_discard_pile = Pile.new()
	var monster_pack: Array = DataManager.get_monster_pack(mission.monster_pack_type)
	for card_data in monster_pack:
		for i in card_data.count:
			var mc: MonsterCard = _create_monster_card_from_data(card_data, mission.monster_pack_type)
			monster_pile.add(mc)
	monster_pile.shuffle()

	# 拾荒牌堆
	scavenge_discard_pile = Pile.new()
	for color in ["red", "green", "blue"]:
		var pile: Pile = Pile.new()
		var card_entries: Array = mission.scavenge_config.get(color, [])
		for entry in card_entries:
			var card_name: String = entry.get("card_name", "")
			var count: int = int(entry.get("count", 0))
			var variants: Array = _find_scavenge_card_variants(card_name)
			if variants.is_empty():
				log_message("警告：拾荒卡未找到 - " + color + "/" + LogColors.card(card_name))
				continue
			for i in count:
				var card_data: ScavengeCardData = variants[i % variants.size()]
				var card: ScavengeCard = _create_scavenge_card_from_data(card_data, color)
				pile.add(card)
		pile.shuffle()
		match color:
			"red":
				red_scavenge_pile = pile
			"green":
				green_scavenge_pile = pile
			"blue":
				blue_scavenge_pile = pile


## 内部方法：按名称在所有颜色的拾荒卡数据中查找匹配项。
## 先精确匹配，若无则前缀匹配（如 "食物" 匹配 "食物（微量）"）。
## 返回所有匹配的 ScavengeCardData 数组（可能跨色）。
func _find_scavenge_card_variants(card_name: String) -> Array:
	var exact_matches: Array = []
	var prefix_matches: Array = []
	for color in ["red", "green", "blue", "gray"]:
		var pile_data: Array = DataManager.get_scavenge_pile(color)
		for card_data in pile_data:
			if card_data.card_name == card_name:
				exact_matches.append(card_data)
			elif card_data.card_name.begins_with(card_name + "（"):
				prefix_matches.append(card_data)
	if not exact_matches.is_empty():
		return exact_matches
	return prefix_matches


# === 工厂方法 ===

## 从 SkillData 创建 Skill 实例。
func _create_skill_from_data(skill_data: SkillData) -> Skill:
	var skill: Skill = Skill.new()
	skill.skill_name = skill_data.skill_name
	skill.english_name = skill_data.english_name
	skill.skill_description = skill_data.skill_description
	skill.active = skill_data.active
	skill.trigger = skill_data.trigger
	skill.skill_type = skill_data.skill_type
	skill.forced = skill_data.forced
	skill.position = skill_data.position
	skill.select_card = skill_data.select_card
	skill.select_target = skill_data.select_target
	skill.select_target_min = skill_data.select_target_min
	skill.usable = skill_data.usable
	skill.filter_target_range = skill_data.filter_target_range
	skill.range = skill_data.range
	skill.target_type = skill_data.target_type
	skill.filter = CodeExecutor.compile_filter(skill_data.filter)
	skill.content = CodeExecutor.compile_content(skill_data.content)
	skill.filter_target = CodeExecutor.compile_filter_target(skill_data.filter_target)
	skill.filter_card = CodeExecutor.compile_filter_card(skill_data.filter_card)
	skill.confirm_prompt = CodeExecutor.compile_confirm_prompt(skill_data.confirm_prompt)
	skill.defer_action_cost = skill_data.defer_action_cost
	skill.window_prompt = skill_data.window_prompt
	# 递归编译子技能
	for sub_key in skill_data.sub_skills.keys():
		var sub_skill_data: SkillData = skill_data.sub_skills[sub_key]
		var sub_skill: Skill = _create_skill_from_data(sub_skill_data)
		skill.sub_skills[sub_key] = sub_skill
		# 注册到全局 sub_skill_registry（按 english_name）
		if sub_skill_data.english_name != "":
			sub_skill_registry[sub_skill_data.english_name] = sub_skill_data
	return skill


## 从全局子技能注册表查询 SkillData。
## 子技能由 _create_skill_from_data 在编译父技能时按 english_name 注册。
## 不存在时返回 null。
func get_sub_skill_data(english_name: String) -> SkillData:
	return sub_skill_registry.get(english_name, null)


## 从 SurvivorData 创建 RoleCard 实例。
func _create_role_card_from_survivor(survivor: SurvivorData) -> RoleCard:
	var rc: RoleCard = RoleCard.new()
	rc.role_name = survivor.character_name
	rc.english_name = survivor.english_name
	rc.max_hp = survivor.max_hp
	rc.initial_hp = survivor.initial_hp
	rc.sneak = survivor.stealth
	rc.hunger_sneak = survivor.hunger_stealth
	rc.equipment_capacity = survivor.equipment_slot
	rc.hand_size_limit = survivor.hand_size_limit
	for skill_data in survivor.intrinsic_skills:
		rc.intrinsic_skills.append(_create_skill_from_data(skill_data))
	return rc


## 从 SurvivorData 创建玩家游戏牌堆。
func _create_player_deck(survivor: SurvivorData) -> Pile:
	var pile: Pile = Pile.new()
	for card_dict in survivor.deck:
		var count: int = int(card_dict.get("count", 1))
		for i in count:
			var card: Card = _create_game_card_from_dict(card_dict)
			if card != null:
				pile.add(card)
	pile.shuffle()
	return pile


## 从 survivor deck 字典创建游戏卡牌实例。
func _create_game_card_from_dict(card_dict: Dictionary) -> Card:
	var card_type: String = card_dict.get("card_type", "")
	var card: Card = null
	if card_type == "equipment":
		card = EquipmentCard.new()
		(card as EquipmentCard).charge_type = card_dict.get("charge_type", "")
		(card as EquipmentCard).charge_max = int(card_dict.get("charge_max", 0))
		(card as EquipmentCard).charge_current = int(card_dict.get("charge_initial", 0))
		(card as EquipmentCard).size = int(card_dict.get("size", 1))
		var range_str: String = card_dict.get("range", "none")
		(card as EquipmentCard).range = range_str
		(card as EquipmentCard).card_subtype = "equipment"
	elif card_type == "action":
		card = SurvivorGameCard.new()
		(card as SurvivorGameCard).card_subtype = "action"
		var range_str2: String = card_dict.get("range", "none")
		(card as SurvivorGameCard).range = range_str2
	else:
		card = SurvivorGameCard.new()
		(card as SurvivorGameCard).card_subtype = card_type
	card.card_name = card_dict.get("card_name", "")
	card.english_name = card_dict.get("english_name", "")
	card.card_type = card_type
	card.source = "game"
	# 加载技能
	var raw_skills: Array = card_dict.get("skills", [])
	for raw in raw_skills:
		if raw is Dictionary:
			var skill_data: SkillData = SkillData.new(raw)
			card.add_skill(_create_skill_from_data(skill_data))
	return card


## 从 ScavengeCardData 创建 ScavengeCard 实例。
func _create_scavenge_card_from_data(card_data: ScavengeCardData, color: String) -> ScavengeCard:
	var card: ScavengeCard = ScavengeCard.new()
	card.card_name = card_data.card_name
	card.english_name = card_data.english_name
	card.card_type = card_data.card_type
	card.color = color
	card.source = "scavenge"
	if card_data.card_type == "equipment":
		card.scavenge_type = "equipment"
		card.card_subtype = "equipment"
	else:
		card.scavenge_type = "consumable"
		card.card_subtype = "action"
	# EquipmentCard 继承字段：从数据填充装备相关属性（含射程 range）。
	# 非装备类拾荒卡（食物/弹药/医疗用品等）的 charge 字段保持默认 0/空，无害。
	card.size = card_data.size
	card.range = card_data.range
	card.charge_type = card_data.charge_type
	card.charge_max = card_data.charge_max
	card.charge_current = card_data.charge_initial
	for skill_data in card_data.skills:
		card.add_skill(_create_skill_from_data(skill_data))
	return card


## 从 MonsterCardData 创建 MonsterCard 实例。
func _create_monster_card_from_data(card_data: MonsterCardData, monster_type: String) -> MonsterCard:
	var card: MonsterCard = MonsterCard.new()
	card.card_name = card_data.monster_name
	card.card_type = "monster"
	card.source = "monster"
	card.monster_type = monster_type
	card.monster_level = card_data.monster_level
	card.max_hp = card_data.max_hp
	card.damage_value = card_data.attack_damage
	card.range = card_data.range
	for skill_data in card_data.skills:
		card.add_skill(_create_skill_from_data(skill_data))
	return card


## 返回场上所有弃牌堆中的装备牌列表。
func get_all_discard_pile_equipments() -> Array:
	var result: Array = []
	for player in players:
		if player == null or not is_instance_valid(player):
			continue
		var pile: Variant = player.get("game_discard_pile")
		if pile != null and pile.has_method("get_all"):
			for card in pile.get_all():
				if card != null and card is EquipmentCard:
					result.append(card)
	if scavenge_discard_pile != null and scavenge_discard_pile.has_method("get_all"):
		for card in scavenge_discard_pile.get_all():
			if card != null and card is EquipmentCard:
				result.append(card)
	return result


## 场上所有弃牌堆中是否至少有 1 张装备牌。
func has_equipment_in_discard_piles() -> bool:
	for player in players:
		if player == null or not is_instance_valid(player):
			continue
		var pile: Variant = player.get("game_discard_pile")
		if pile != null and pile.has_method("get_all"):
			for card in pile.get_all():
				if card != null and card is EquipmentCard:
					return true
	if scavenge_discard_pile != null and scavenge_discard_pile.has_method("get_all"):
		for card in scavenge_discard_pile.get_all():
			if card != null and card is EquipmentCard:
				return true
	return false


## 从场上所有弃牌堆中移除指定卡牌，返回来源 Pile。未找到返回 null。
func take_card_from_discard_piles(card: Card) -> Pile:
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		var pile: Variant = p.get("game_discard_pile")
		if pile != null and pile.has_method("get_all"):
			if card in pile.cards:
				pile.cards.erase(card)
				return pile
	if scavenge_discard_pile != null and card in scavenge_discard_pile.cards:
		scavenge_discard_pile.cards.erase(card)
		return scavenge_discard_pile
	return null


## 判断场上是否有拾荒牌（红/绿/蓝拾荒牌堆任一非空）。
func has_scavenge_cards() -> bool:
	for color in ["red", "green", "blue"]:
		var pile: Pile = get_scavenge_pile(color)
		if pile != null and not pile.is_empty():
			return true
	return false


## 返回从 source 朝 target 方向的相邻存活地块。
func get_step_toward(source: MapBlock, target: MapBlock) -> MapBlock:
	if source == null or target == null:
		return null
	var dx: int = target.coordinate["x"] - source.coordinate["x"]
	var dy: int = target.coordinate["y"] - source.coordinate["y"]
	if dx != 0:
		var step_x: int = source.coordinate["x"] + (1 if dx > 0 else -1)
		var candidate: MapBlock = get_block_by_coord(step_x, source.coordinate["y"])
		if candidate != null:
			return candidate
	if dy != 0:
		var step_y: int = source.coordinate["y"] + (1 if dy > 0 else -1)
		var candidate: MapBlock = get_block_by_coord(source.coordinate["x"], step_y)
		if candidate != null:
			return candidate
	if dx == 0 and dy == 0:
		return target
	return null
