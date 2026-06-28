# 规则引擎类，负责执行游戏规则和逻辑判定
class_name RuleEngine
extends Node

var ui_manager: UIManager
var current_player_id: String = ""

func _ready() -> void:
	# 等待父节点准备好后获取UIManager
	await get_tree().create_timer(0.2).timeout
	ui_manager = get_parent().get_node("UIManager")

	# 连接UIManager的信号
	ui_manager.dice_rolled.connect(_on_dice_rolled)
	ui_manager.card_drawn.connect(_on_card_drawn)
	ui_manager.turn_ended.connect(_on_turn_ended)
	ui_manager.turn_end_processed.connect(_on_turn_end_processed)
	ui_manager.card_played.connect(_on_card_played)

# === 怪物出生阶段 ===
func execute_monster_spawn(dice_1: int, dice_2: int):
	var X = dice_1 + dice_2
	var state = GameState
	var spawned_count = 0

	for pos in state.map_grid.keys():
		var tile = state.map_grid[pos]
		var tile_data: MapBlockData = tile["data"]

		if tile["is_revealed"] and X == tile_data.spawn_value:
			if tile["monster_tokens"] < 3:
				if state.available_monster_tokens <= 0:
					state.game_status = Enums.GameStatus.DEFEAT
					state.game_over.emit(state.game_status)
					return

				tile["monster_tokens"] += 1
				state.available_monster_tokens -= 1
				spawned_count += 1
				print("[RuleEngine] 在地块 " + str(pos) + " 放置怪物标记")

				# 更新地块的怪物显示
				_update_tile_monster_display(pos, tile["monster_tokens"])
			else:
				var players_on_tile = get_players_at_position(pos)
				for player_id in players_on_tile:
					draw_monster_card_to_player(player_id)
					print("[RuleEngine] 地块已满，玩家 " + player_id + " 抽取怪物卡")

	if spawned_count == 0:
		print("[RuleEngine] 本轮无怪物出生")

	# 更新UI
	ui_manager.update_player_info(current_player_id)
	notify_phase_complete()

# === 抽牌阶段 ===
func execute_draw_card(player_id: String):
	var player = GameState.players[player_id]

	if player.deck.size() == 0:
		print("[RuleEngine] 玩家 " + player_id + " 牌库已空，死亡")
		kill_player(player_id)
		return

	# 从牌库抽取一张卡到手牌
	var drawn_card = player.deck.pop_front()
	player.hand.append(drawn_card)

	print("[RuleEngine] 玩家 " + player_id + " 抽牌: " + drawn_card.template_id)

	# 更新UI
	ui_manager.update_player_info(player_id)
	ui_manager.status_label.text = "已抽取: " + drawn_card.template_id

	notify_phase_complete()

# === 移动玩家 ===
func move_player(player_id: String, target_pos: Vector2i):
	var state = GameState
	var player = state.players[player_id]
	var tile = state.map_grid.get(target_pos)

	if not tile:
		print("[RuleEngine] 非法移动：目标地块不存在")
		return

	if player.action_points <= 0:
		print("[RuleEngine] 没有行动点，无法移动")
		return

	# 检查是否相邻地块（只能移动到相邻位置）
	var current_pos = player.position
	var distance = abs(target_pos.x - current_pos.x) + abs(target_pos.y - current_pos.y)
	if distance > 1:
		print("[RuleEngine] 只能移动到相邻地块")
		ui_manager.status_label.text = "只能移动到相邻地块!"
		return

	player.action_points -= 1
	player.position = target_pos

	if not tile["is_revealed"]:
		tile["is_revealed"] = true
		state.tile_revealed.emit(target_pos)
		print("[RuleEngine] 翻开地块: " + str(target_pos))

	if tile["monster_tokens"] > 0 and not has_engaged_monsters(player_id):
		var base_stealth = player.starving_stealth if player.is_starving else player.base_stealth
		var final_stealth = base_stealth - tile["monster_tokens"]

		var roll = randi_range(1, 6) + randi_range(1, 6)
		print("[RuleEngine] 潜行检定: 骰子=" + str(roll) + " vs 需求=" + str(final_stealth))
		ui_manager.status_label.text = "潜行检定: " + str(roll) + " vs " + str(final_stealth)

		if roll > final_stealth:
			var count = tile["monster_tokens"]
			tile["monster_tokens"] = 0
			state.available_monster_tokens += count

			# 更新地块的怪物显示（清除怪物）
			_update_tile_monster_display(target_pos, 0)

			for i in range(count):
				draw_monster_card_to_player(player_id)
			print("[RuleEngine] 潜行失败，玩家抓取 " + str(count) + " 张怪物卡")

	# 更新UI
	ui_manager.update_player_info(player_id)
	ui_manager.status_label.text = "移动到 (" + str(target_pos.x) + "," + str(target_pos.y) + ")"

	# 更新地图上的玩家显示
	var game_node = get_parent()
	if game_node and game_node.has_node("MapBoard"):
		var map_board = game_node.get_node("MapBoard")
		if map_board.has_method("update_player_positions"):
			map_board.update_player_positions()

# === 出牌 ===
func play_card(player_id: String, card_index: int):
	var player = GameState.players[player_id]

	if card_index < 0 or card_index >= player.hand.size():
		print("[RuleEngine] 非法卡牌索引")
		return

	if player.action_points <= 0:
		print("[RuleEngine] 没有行动点，无法出牌")
		ui_manager.status_label.text = "没有行动点!"
		return

	var card = player.hand[card_index]

	# 如果是怪物卡，不能直接打出，需要战斗
	if card.template_id.contains("monster"):
		ui_manager.status_label.text = "怪物卡需要战斗才能清除!"
		return

	# 打出卡牌（从手牌移到弃牌堆）
	player.hand.remove_at(card_index)
	player.discard_pile.append(card)
	player.action_points -= 1

	print("[RuleEngine] 玩家 " + player_id + " 出牌: " + card.template_id)

	# 更新UI
	ui_manager.update_player_info(player_id)
	ui_manager.status_label.text = "已打出: " + card.template_id

# === 回合结束阶段（饥饿+怪物攻击） ===
func execute_turn_end(player_id: String):
	print("[RuleEngine] 开始回合结束处理...")

	# 1. 饥饿结算
	execute_hunger(player_id)
	if _is_game_over():
		return

	# 2. 怪物攻击
	execute_monster_attack(player_id)
	if _is_game_over():
		return

	# 更新UI
	ui_manager.update_player_info(player_id)
	ui_manager.status_label.text = "回合结束处理完成"

	notify_phase_complete()

# === 饥饿结算 ===
func execute_hunger(player_id: String):
	var player = GameState.players[player_id]

	player.hunger_level += 1
	print("[RuleEngine] 玩家 " + player_id + " 饥饿度增加到 " + str(player.hunger_level))
	ui_manager.status_label.text = "饥饿度: " + str(player.hunger_level)

	if player.hunger_level >= 6:
		if not player.is_starving:
			player.is_starving = true
			player.starving_damage_stage = 1
			print("[RuleEngine] 玩家 " + player_id + " 进入饥饿状态")
			ui_manager.status_label.text = "进入饥饿状态!"

		var dmg = player.starving_damage_stage * 2
		apply_damage_to_player(player_id, dmg, "饥饿")
		ui_manager.status_label.text = "饥饿伤害: " + str(dmg)

		player.starving_damage_stage += 1

# === 怪物攻击 ===
func execute_monster_attack(player_id: String):
	var monsters = get_monsters_engaged_with(player_id)

	if monsters.is_empty():
		print("[RuleEngine] 玩家 " + player_id + " 没有纠缠的怪物")
		ui_manager.status_label.text = "没有纠缠的怪物"
		return

	for monster_id in monsters:
		var monster_damage = 2
		apply_damage_to_player(player_id, monster_damage, "怪物攻击")
		ui_manager.status_label.text = "怪物攻击: " + str(monster_damage) + " 点伤害"

		if _is_game_over():
			return

# === UI信号响应 ===
signal spawn_phase_complete
signal draw_phase_complete
signal action_phase_complete
signal turn_end_phase_complete

func _on_dice_rolled(d1: int, d2: int) -> void:
	execute_monster_spawn(d1, d2)

func _on_card_drawn(player_id: String) -> void:
	execute_draw_card(player_id)

func _on_turn_ended(player_id: String) -> void:
	ui_manager.end_turn_button.visible = false
	ui_manager.status_label.text = "行动阶段结束"
	action_phase_complete.emit()

func _on_turn_end_processed(player_id: String) -> void:
	execute_turn_end(player_id)

func _on_card_played(player_id: String, card_index: int) -> void:
	play_card(player_id, card_index)

# === 地图点击响应 ===
func on_tile_clicked(player_id: String, tile_pos: Vector2i) -> void:
	# 只在行动阶段可以移动
	if GameState.current_phase != Enums.GamePhase.ACTION:
		ui_manager.status_label.text = "只能在行动阶段移动!"
		return

	move_player(player_id, tile_pos)

# === 辅助函数 ===
func notify_phase_complete() -> void:
	await get_tree().create_timer(0.5).timeout
	# 根据当前阶段发出完成信号
	match GameState.current_phase:
		Enums.GamePhase.SPAWN:
			spawn_phase_complete.emit()
		Enums.GamePhase.DRAW:
			draw_phase_complete.emit()
		Enums.GamePhase.ACTION:
			action_phase_complete.emit()
		Enums.GamePhase.MONSTER_ATTACK:
			turn_end_phase_complete.emit()

func set_current_player(player_id: String) -> void:
	current_player_id = player_id

# === 游戏状态检查 ===
func _is_game_over() -> bool:
	return GameState.game_status != Enums.GameStatus.PLAYING

func _handle_game_over():
	if GameState.game_status == Enums.GameStatus.VICTORY:
		ui_manager.show_victory_screen()
		print("[RuleEngine] 游戏胜利！")
	elif GameState.game_status == Enums.GameStatus.DEFEAT:
		ui_manager.show_defeat_screen()
		print("[RuleEngine] 游戏失败！")

func _switch_to_next_player():
	var keys = GameState.players.keys()

	if keys.is_empty():
		GameState.game_status = Enums.GameStatus.DEFEAT
		GameState.game_over.emit(GameState.game_status)
		print("[RuleEngine] 所有玩家已死亡，游戏结束")
		return

	var current_index = keys.find(GameState.active_player_id)
	var next_index = (current_index + 1) % keys.size()
	GameState.active_player_id = keys[next_index]

	if next_index == 0:
		GameState.current_turn += 1
		ui_manager.update_turn_display(GameState.current_turn)
		print("[RuleEngine] 进入回合 " + str(GameState.current_turn))

# === 数据查询函数 ===
func get_players_at_position(pos: Vector2i) -> Array[String]:
	var result: Array[String] = []
	for player_id in GameState.players.keys():
		var player = GameState.players[player_id]
		if player.position == pos:
			result.append(player_id)
	return result

func has_engaged_monsters(player_id: String) -> bool:
	var player = GameState.players[player_id]
	for card in player.hand:
		if card.template_id.contains("monster"):
			return true
	return false

func get_monsters_engaged_with(player_id: String) -> Array[String]:
	var result: Array[String] = []
	var player = GameState.players[player_id]

	for card in player.hand:
		if card.template_id.contains("monster"):
			result.append(card.instance_id)
	return result

func draw_monster_card_to_player(player_id: String):
	var player = GameState.players[player_id]
	var monster_id = "monster_" + str(randi() % 10 + 1)
	var new_monster = CardRuntime.new("monster_instance_" + str(randi()), monster_id)
	player.hand.append(new_monster)
	print("[RuleEngine] 玩家 " + player_id + " 抽取怪物卡: " + monster_id)

func apply_damage_to_player(player_id: String, damage: int, reason: String):
	var player = GameState.players[player_id]
	player.current_hp -= damage
	print("[RuleEngine] 玩家 " + player_id + " 受到 " + str(damage) + " 点伤害 (" + reason + ")，剩余生命=" + str(player.current_hp))

	if player.current_hp <= 0:
		kill_player(player_id)

func kill_player(player_id: String):
	print("[RuleEngine] 玩家 " + player_id + " 死亡")
	GameState.players.erase(player_id)

	if GameState.players.is_empty():
		GameState.game_status = Enums.GameStatus.DEFEAT
		GameState.game_over.emit(GameState.game_status)

func check_victory_conditions():
	if GameState.current_fuel_in_van >= GameState.required_fuel:
		var all_players_at_van = true
		for player_id in GameState.players.keys():
			var player = GameState.players[player_id]
			var tile = GameState.map_grid.get(player.position)
			if tile and tile["template_id"] != "van":
				all_players_at_van = false

		if all_players_at_van:
			GameState.game_status = Enums.GameStatus.VICTORY
			GameState.game_over.emit(GameState.game_status)

# === 更新地块怪物显示 ===
func _update_tile_monster_display(pos: Vector2i, count: int) -> void:
	var game_node = get_parent()
	if game_node and game_node.has_node("MapBoard"):
		var map_board = game_node.get_node("MapBoard")
		if map_board.has_method("update_tile_monster_count"):
			map_board.update_tile_monster_count(pos, count)
