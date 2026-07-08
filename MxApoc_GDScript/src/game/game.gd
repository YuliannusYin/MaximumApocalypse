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
var coop_death_mode: bool = false
var current_mission: Variant = null  # 可能是 Dictionary 或 Resource，类型不确定
var removed_cards: Array = []
var log_list: Array = []

# === 测试用标记（向后兼容，由 state_machine.game_over 同步设置） ===
var game_over_called: bool = false
var game_result: String = ""


func _ready() -> void:
	state_machine = GameStateMachine.new()
	state_machine.init()


## 日志输出。方法名避开 GDScript 内置 log()（自然对数）。
func log_message(message: String) -> void:
	log_list.append(message)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.publish_log(message)


# === 状态机委托 ===

## 游戏开局流程。委托给 state_machine.start_game()。
func start_game() -> void:
	if state_machine != null and is_instance_valid(state_machine):
		state_machine.start_game()


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
		state_machine.next_turn()


## 返回当前回合玩家。委托给 state_machine.get_current_player()。
func get_current_player() -> Variant:
	if state_machine != null and is_instance_valid(state_machine):
		return state_machine.get_current_player()
	return null


## 检查任务特定胜利条件。委托给 mission_config.check_win_condition。
func check_mission_win_condition() -> bool:
	if mission_config == null:
		return false
	if mission_config.check_win_condition.is_valid():
		return mission_config.check_win_condition.call()
	return false


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
	var block_pool: Array = []
	var block_config: Variant = _config_get(mission_config_arg, "map_block_config")
	if block_config != null:
		for entry in block_config:
			var block_name: String = _config_get(entry, "block_name", "")
			var count: int = _config_get(entry, "count", 0)
			for i in count:
				block_pool.append(block_name)
	var spawn_name: String = _config_get(mission_config_arg, "spawn_block_name", "")
	var end_name: String = _config_get(mission_config_arg, "end_block_name", "")
	for y in map_height:
		for x in map_width:
			var code: int = map_template[y][x]
			if code == -1:
				continue
			var block_name: String = ""
			var block: MapBlock = null
			if code == 0:
				block_name = spawn_name
			elif code == 1:
				if block_pool.is_empty():
					continue
				var idx: int = randi() % block_pool.size()
				block_name = block_pool.pop_at(idx)
			elif code == 2:
				block_name = end_name
			elif code == 3:
				if block_pool.is_empty():
					continue
				var idx3: int = randi() % block_pool.size()
				block_name = block_pool.pop_at(idx3)
			block = _create_map_block(block_name)
			if block == null:
				continue
			block.set_coordinate(x, y)
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


## 内部方法：根据地块名创建 MapBlock 实例。
func _create_map_block(block_name: String) -> MapBlock:
	var block: MapBlock = MapBlock.new()
	block.block_name = block_name
	return block


## 摧毁地块流程。6 节点：before → 玩家弹出 → 怪物标记清零 → on → 状态变更 → after。
func destroy_map_block(block: MapBlock, source: Variant) -> bool:
	if block == null or not is_instance_valid(block):
		return false
	var event: Dictionary = EventSystem.create_destroy_block_event(source, block)
	# 1. 摧毁地块前（取消点）
	for player in players:
		if player != null and is_instance_valid(player):
			player.trigger("before_destroy_block", event)
	if EventSystem.is_cancelled(event):
		return false
	# 2. 处理地块上的玩家（弹出到相邻存活地块）
	var players_on_block: Array = block.get_players()
	for player in players_on_block:
		var adjacent: Array = block.get_adjacent_blocks()
		if adjacent.is_empty():
			log_message(player.player_name + " 无处可逃，受到 5 点伤害")
			player.damage(5, null, "block_destroy")
		else:
			var target: MapBlock = player.choose_map_block(adjacent)
			if target == null:
				target = adjacent[0]
			if block.has_method("_clear_skills_for_player"):
				block._clear_skills_for_player(player)
			player.current_block = target
			if target.has_method("_acquire_skills_for_player"):
				target._acquire_skills_for_player(player)
			if not target.is_revealed():
				target.reveal(true, player)
	# 3. 消灭地块上的所有怪物标记
	block.monster_marks = 0
	# 4. 摧毁地块时（系统结算）
	for player in players:
		if player != null and is_instance_valid(player):
			player.trigger("on_destroy_block", event)
	# 5. 地块状态变更，从地图区域移除
	block.block_state = "destroyed"
	map_area.erase(block)
	# 6. 摧毁地块后（通知）
	for player in players:
		if player != null and is_instance_valid(player):
			player.trigger("after_destroy_block", event)
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


# === 卡牌管理 ===

## 将卡牌移出游戏（区别于进入弃牌堆）。
func remove_card(card: Card) -> void:
	removed_cards.append(card)


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


## 根据卡牌名创建拾荒卡实例（stub，需 ScavengePacks 数据加载后完整实现）。
func create_scavenge_card(card_name: String) -> Card:
	log_message("create_scavenge_card stub: " + card_name)
	return null


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
