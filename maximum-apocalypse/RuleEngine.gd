# 规则引擎类，负责执行游戏规则和逻辑判定
class_name RuleEngine
extends Node

var ui_manager: UIManager
var effect_manager: EffectManager
var current_player_id: String = ""

func _ready() -> void:
	# 等待父节点准备好后获取UIManager和EffectManager
	await get_tree().create_timer(0.3).timeout
	ui_manager = get_parent().get_node("UIManager")
	effect_manager = get_parent().get_node("EffectManager")
	
	if effect_manager:
		print("[RuleEngine] EffectManager已获取")
	else:
		print("[RuleEngine] 错误：EffectManager未找到！")

	# 连接UIManager的信号
	ui_manager.dice_rolled.connect(_on_dice_rolled)
	ui_manager.card_drawn.connect(_on_card_drawn)
	ui_manager.turn_ended.connect(_on_turn_ended)
	ui_manager.turn_end_processed.connect(_on_turn_end_processed)
	ui_manager.card_played.connect(_on_card_played)
	ui_manager.scavenge_performed.connect(_on_scavenge_performed)

# === 怪物出生阶段 ===
func execute_monster_spawn(dice_1: int, dice_2: int):
	var X = dice_1 + dice_2
	var state = GameState
	var spawned_count = 0

	ui_manager.add_log_message("丢筛子: " + str(dice_1) + " + " + str(dice_2) + " = " + str(X))

	for pos in state.map_grid.keys():
		var tile = state.map_grid[pos]
		var tile_data: MapBlockData = tile["data"]

		if tile["is_revealed"] and X == tile_data.spawn_value:
			if tile["monster_tokens"] < 3:
				if state.available_monster_tokens <= 0:
					state.game_status = Enums.GameStatus.DEFEAT
					state.game_over.emit(state.game_status)
					ui_manager.add_log_message("怪物标记耗尽，游戏失败！")
					return

				tile["monster_tokens"] += 1
				state.available_monster_tokens -= 1
				spawned_count += 1
				print("[RuleEngine] 在地块 " + str(pos) + " 放置怪物标记")
				ui_manager.add_log_message("在(" + str(pos.x) + "," + str(pos.y) + ")刷怪")

				# 更新地块的怪物显示
				_update_tile_monster_display(pos, tile["monster_tokens"])
			else:
				var players_on_tile = get_players_at_position(pos)
				for player_id in players_on_tile:
					draw_monster_card_to_player(player_id)
					print("[RuleEngine] 地块已满，玩家 " + player_id + " 抽取怪物卡")
					ui_manager.add_log_message("地块怪物满，玩家被纠缠")

	if spawned_count == 0:
		print("[RuleEngine] 本轮无怪物出生")
		ui_manager.add_log_message("本轮无怪物出生")

	# 更新UI
	ui_manager.update_player_info(current_player_id)
	notify_phase_complete()

# === 抽牌阶段 ===
func execute_draw_card(player_id: String):
	var player = GameState.players[player_id]

	# 牌库空时，将弃牌堆洗回牌库
	if player.deck.size() == 0:
		if player.discard_pile.size() > 0:
			player.deck = player.discard_pile.duplicate()
			player.deck.shuffle()
			player.discard_pile.clear()
			print("[RuleEngine] 玩家 " + player_id + " 牌库已空，将弃牌堆洗回牌库")
			ui_manager.add_log_message("玩家牌库洗牌")
		else:
			print("[RuleEngine] 玩家 " + player_id + " 牌库已空，死亡")
			ui_manager.add_log_message("牌库已空，玩家死亡")
			kill_player(player_id)
			return

	# 从牌库抽取一张卡到手牌
	var drawn_card = player.deck.pop_front()
	player.hand.append(drawn_card)

	print("[RuleEngine] 玩家 " + player_id + " 抽牌: " + drawn_card.template_id)
	ui_manager.add_log_message("抽到: " + drawn_card.card_name)

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
		ui_manager.add_log_message("移动失败：地块不存在")
		return

	if player.action_points <= 0:
		print("[RuleEngine] 没有行动点，无法移动")
		ui_manager.add_log_message("移动失败：无行动点")
		return

	# 检查是否相邻地块（只能移动到相邻位置）
	var current_pos = player.position
	var distance = abs(target_pos.x - current_pos.x) + abs(target_pos.y - current_pos.y)
	if distance > 1:
		print("[RuleEngine] 只能移动到相邻地块")
		ui_manager.status_label.text = "只能移动到相邻地块!"
		ui_manager.add_log_message("移动失败：只能移动相邻地块")
		return

	player.action_points -= 1
	player.position = target_pos
	ui_manager.add_log_message("移动到(" + str(target_pos.x) + "," + str(target_pos.y) + ") AP-1")

	if not tile["is_revealed"]:
		tile["is_revealed"] = true
		state.tile_revealed.emit(target_pos)
		print("[RuleEngine] 翻开地块: " + str(target_pos))
		ui_manager.add_log_message("翻开地块")

	if tile["monster_tokens"] > 0 and not has_engaged_monsters(player_id):
		var base_stealth = player.starving_stealth if player.is_starving else player.base_stealth
		var final_stealth = base_stealth - tile["monster_tokens"]

		var roll = randi_range(1, 6) + randi_range(1, 6)
		print("[RuleEngine] 潜行检定: 骰子=" + str(roll) + " vs 需求=" + str(final_stealth))
		ui_manager.status_label.text = "潜行检定: " + str(roll) + " vs " + str(final_stealth)
		ui_manager.add_log_message("潜行检定: " + str(roll) + " vs " + str(final_stealth))

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

	# 更新拾荒按钮状态（检查新地块是否有拾荒标记）
	if GameState.current_phase == Enums.GamePhase.ACTION:
		ui_manager.show_phase_buttons(Enums.GamePhase.ACTION, player_id)

	# 更新地图上的玩家显示
	var game_node = get_parent()
	if game_node and game_node.has_node("MapBoard"):
		var map_board = game_node.get_node("MapBoard")
		if map_board.has_method("update_player_positions"):
			map_board.update_player_positions()

# === 出牌 ===
func play_card(player_id: String, card_index: int):
	var player = GameState.players[player_id]

	print("[RuleEngine] === 出牌流程开始 ===")
	print("[RuleEngine] 玩家: " + player_id + ", 卡牌索引: " + str(card_index))
	print("[RuleEngine] 手牌数量: " + str(player.hand.size()))

	if card_index < 0 or card_index >= player.hand.size():
		print("[RuleEngine] 非法卡牌索引")
		return

	if player.action_points <= 0:
		print("[RuleEngine] 没有行动点，无法出牌")
		ui_manager.status_label.text = "没有行动点!"
		return

	var card = player.hand[card_index]
	print("[RuleEngine] 卡牌信息: template_id=" + card.template_id + ", name=" + card.card_name)
	ui_manager.add_log_message("尝试出牌: " + card.card_name)

	# 如果是怪物卡，不能直接打出，需要战斗
	if card.template_id.contains("monster"):
		ui_manager.status_label.text = "怪物卡需要战斗才能清除!"
		ui_manager.add_log_message("怪物卡需要战斗清除")
		return

	# 加载卡牌数据以获取效果脚本ID
	print("[RuleEngine] 尝试加载卡牌数据...")
	var card_data = _load_card_data(card.template_id)
	
	if card_data:
		print("[RuleEngine] 卡牌数据已加载: " + str(card_data))
		if card_data is ScavengeCardData:
			print("[RuleEngine]  - effect_script_id: " + card_data.effect_script_id)
			print("[RuleEngine]  - card_type: " + str(card_data.card_type))
	else:
		print("[RuleEngine] 错误：卡牌数据加载失败")

	# 检查是否是装备牌
	var is_equipment = false
	var is_weapon = false
	if card_data is ScavengeCardData:
		is_equipment = (card_data.card_type == Enums.ScavengeCardType.EQUIPMENT)
	elif card_data is CharacterCardData:
		is_equipment = (card_data.card_type == Enums.CharacterCard.EQUIPMENT)
		is_weapon = (card_data.max_ammo > 0)

	if is_equipment:
		# 装备牌：不执行攻击效果，直接装备到装备栏
		# 检查是否已有同种装备（顶掉旧的）+ 槽位上限
		var equip_ok = _equip_to_player(player_id, card_index, card_data)
		if not equip_ok:
			return  # 装备失败，不消耗行动点
	else:
		# 非装备牌：执行效果 → 弃牌
		if card_data and effect_manager:
			var success = effect_manager.execute_effect(card_data, player_id, card)
			if not success:
				ui_manager.status_label.text = "效果执行失败!"
				return
		player.hand.remove_at(card_index)
		player.discard_pile.append(card)
		print("[RuleEngine] 玩家 " + player_id + " 出牌: " + card.card_name)
		ui_manager.add_log_message("打出: " + card.card_name + " AP-1")

	player.action_points -= 1

	# 更新UI
	ui_manager.update_player_info(player_id)
	ui_manager.status_label.text = "已打出: " + card.card_name
	print("[RuleEngine] === 出牌流程结束 ===")

# 加载卡牌数据
func _load_card_data(template_id: String) -> Resource:
	print("[RuleEngine] _load_card_data 尝试加载: " + template_id)
	
	# 尝试从拾荒卡文件夹加载
	var scavenge_folders = ["red", "green", "blue", "gray"]
	for folder in scavenge_folders:
		var path = "res://data/cards/scavengeCards/" + folder + "/" + template_id + ".tres"
		print("[RuleEngine]   检查路径: " + path)
		if ResourceLoader.exists(path):
			print("[RuleEngine]   找到资源！加载中...")
			var res = load(path)
			print("[RuleEngine]   加载成功: " + str(res))
			return res
		else:
			print("[RuleEngine]   路径不存在")

	# 尝试从角色卡文件夹加载（需要扫描子文件夹）
	var char_folders = ["cowboy", "firefighter", "hunter", "mechanic", "surgeon", "veteran"]
	for folder in char_folders:
		var path = "res://data/cards/characterCards/" + folder + "/" + template_id + ".tres"
		print("[RuleEngine]   检查路径: " + path)
		if ResourceLoader.exists(path):
			print("[RuleEngine]   找到角色卡资源！")
			return load(path)

	print("[RuleEngine] 未找到卡牌数据: " + template_id)
	return null

# === 拾荒 ===
func execute_scavenge(player_id: String):
	var player = GameState.players[player_id]

	if player.action_points <= 0:
		print("[RuleEngine] 没有行动点，无法拾荒")
		ui_manager.status_label.text = "没有行动点!"
		ui_manager.add_log_message("拾荒失败：无行动点")
		return

	# 检查地块是否有拾荒颜色标记
	var player_pos = player.position
	if not GameState.map_grid.has(player_pos):
		print("[RuleEngine] 玩家位置无效")
		ui_manager.add_log_message("拾荒失败：位置无效")
		return

	var tile = GameState.map_grid[player_pos]
	var tile_data: MapBlockData = tile["data"]
	var scavenge_colors = tile_data.scavenge_colors

	if scavenge_colors.size() == 0:
		print("[RuleEngine] 当前地块没有拾荒标记")
		ui_manager.status_label.text = "当前地块没有拾荒标记!"
		ui_manager.add_log_message("拾荒失败：地块无标记")
		return

	# 如果只有一个拾荒颜色，直接抓牌
	if scavenge_colors.size() == 1:
		var color = scavenge_colors[0]
		ui_manager.add_log_message("拾荒: " + Enums.ScavengeColor.keys()[color] + "牌")
		_draw_scavenge_card(player_id, color)
	# 如果有多个拾荒颜色，随机选择一个（简化处理，实际应该让玩家选择）
	else:
		var color = scavenge_colors[randi() % scavenge_colors.size()]
		print("[RuleEngine] 多色地块，随机选择: " + Enums.ScavengeColor.keys()[color])
		ui_manager.add_log_message("多色地块，随机: " + Enums.ScavengeColor.keys()[color])
		_draw_scavenge_card(player_id, color)

func _draw_scavenge_card(player_id: String, color: Enums.ScavengeColor) -> void:
	var player = GameState.players[player_id]
	var deck = GameState.scavenge_decks.get(color)

	if not deck or deck.size() == 0:
		print("[RuleEngine] " + Enums.ScavengeColor.keys()[color] + "拾荒牌堆已空")
		ui_manager.status_label.text = Enums.ScavengeColor.keys()[color] + "拾荒牌堆已空!"
		ui_manager.add_log_message(Enums.ScavengeColor.keys()[color] + "牌堆已空")
		return

	# 从牌堆抓取一张卡（CardRuntime实例）
	var drawn_card: CardRuntime = deck.pop_front()

	print("[RuleEngine] 玩家 " + player_id + " 拾荒: " + drawn_card.card_name + " (" + Enums.ScavengeColor.keys()[color] + ")")
	ui_manager.add_log_message("拾到: " + drawn_card.card_name)

	# 加载卡牌数据以检查是否需要触发抽牌效果
	var card_data = _load_card_data(drawn_card.template_id)

	# 检查是否是gray牌（抽到时触发效果）
	if card_data and card_data is ScavengeCardData:
		if card_data.color == Enums.ScavengeCardColor.GRAY:
			# 执行抽牌效果（如"一无所获"立即弃掉，"伏击"抽怪物卡）
			if effect_manager:
				var success = effect_manager.execute_effect(card_data, player_id, drawn_card)
				if success:
					print("[RuleEngine] Gray牌效果已触发")
					# 效果执行后，卡牌可能已被弃掉或处理，不加入手牌
					player.action_points -= 1
					ui_manager.update_player_info(player_id)
					ui_manager.status_label.text = "拾荒触发效果: " + drawn_card.card_name
					return
			# 如果效果执行失败，正常加入手牌
			player.hand.append(drawn_card)
		else:
			# 正常加入手牌
			player.hand.append(drawn_card)
	else:
		# 未知卡牌类型，正常加入手牌
		player.hand.append(drawn_card)

	player.action_points -= 1

	# 更新UI
	ui_manager.update_player_info(player_id)
	ui_manager.status_label.text = "拾荒获得: " + drawn_card.card_name

	# 更新拾荒按钮状态（如果行动点耗尽或牌堆空）
	if player.action_points <= 0 or deck.size() == 0:
		ui_manager.scavenge_button.visible = false

# === 回合结束阶段（饥饿+怪物攻击） ===
func execute_turn_end(player_id: String):
	print("[RuleEngine] 开始回合结束处理...")
	ui_manager.add_log_message("--- 回合结束结算 ---")

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
	ui_manager.add_log_message("回合结束完成")

	notify_phase_complete()

# === 饥饿结算 ===
func execute_hunger(player_id: String):
	var player = GameState.players[player_id]

	player.hunger_level += 1
	print("[RuleEngine] 玩家 " + player_id + " 饥饿度增加到 " + str(player.hunger_level))
	ui_manager.status_label.text = "饥饿度: " + str(player.hunger_level)
	ui_manager.add_log_message("饥饿度+1 → " + str(player.hunger_level))

	if player.hunger_level >= 6:
		if not player.is_starving:
			player.is_starving = true
			player.starving_damage_stage = 1
			print("[RuleEngine] 玩家 " + player_id + " 进入饥饿状态")
			ui_manager.status_label.text = "进入饥饿状态!"
			ui_manager.add_log_message("进入饥饿状态!")

		var dmg = player.starving_damage_stage * 2
		apply_damage_to_player(player_id, dmg, "饥饿")
		ui_manager.status_label.text = "饥饿伤害: " + str(dmg)
		ui_manager.add_log_message("饥饿伤害: " + str(dmg))

		player.starving_damage_stage += 1

# === 怪物攻击 ===
func execute_monster_attack(player_id: String):
	var monsters = get_monsters_engaged_with(player_id)

	if monsters.is_empty():
		print("[RuleEngine] 玩家 " + player_id + " 没有纠缠的怪物")
		ui_manager.status_label.text = "没有纠缠的怪物"
		ui_manager.add_log_message("无纠缠怪物")
		return

	ui_manager.add_log_message("怪物攻击：" + str(monsters.size()) + "只")

	for monster_id in monsters:
		var monster_damage = 2
		apply_damage_to_player(player_id, monster_damage, "怪物攻击")
		ui_manager.status_label.text = "怪物攻击: " + str(monster_damage) + " 点伤害"
		ui_manager.add_log_message("怪物造成" + str(monster_damage) + "伤害")

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

func _on_scavenge_performed(player_id: String) -> void:
	execute_scavenge(player_id)

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
	return player.monster_zone.size() > 0

func get_monsters_engaged_with(player_id: String) -> Array[String]:
	var result: Array[String] = []
	var player = GameState.players[player_id]

	for card in player.monster_zone:
		result.append(card.instance_id)
	return result

func draw_monster_card_to_player(player_id: String):
	var player = GameState.players[player_id]

	# 检查怪物牌库是否为空
	if GameState.monster_deck.size() == 0:
		# 如果弃牌堆不为空，洗回牌库
		if GameState.monster_discard_pile.size() > 0:
			GameState.monster_deck = GameState.monster_discard_pile.duplicate()
			GameState.monster_deck.shuffle()
			GameState.monster_discard_pile.clear()
			print("[RuleEngine] 怪物牌库已空，将弃牌堆洗回牌库")
			ui_manager.add_log_message("怪物牌库洗牌")
		else:
			print("[RuleEngine] 怪物牌库和弃牌堆都已空，无法抽取怪物卡")
			ui_manager.add_log_message("怪物牌库已空")
			return

	# 从牌库顶部抽取一张怪物卡
	var monster_data: MonsterData = GameState.monster_deck.pop_front()
	var instance_id = "monster_" + monster_data.id + "_" + str(randi() % 10000)

	# 创建怪物卡实例放入玩家纠缠怪物区（monster_zone），而不是手牌
	var new_monster = CardRuntime.new(instance_id, monster_data.id, monster_data.monster_name, 0, monster_data.max_hp)
	player.monster_zone.append(new_monster)

	print("[RuleEngine] 玩家 " + player_id + " 抽取怪物卡: " + monster_data.monster_name + " (ID: " + monster_data.id + ", HP: " + str(monster_data.max_hp) + ")")
	ui_manager.add_log_message("被怪物纠缠: " + monster_data.monster_name)

	# 更新UI显示
	ui_manager.update_monster_display(player_id)

func apply_damage_to_player(player_id: String, damage: int, reason: String):
	var player = GameState.players[player_id]

	# 检查装备区减伤效果
	var damage_reduction = 0
	for equipment in player.equipment_zone:
		var card_data = _load_card_data(equipment.template_id)
		if card_data is CharacterCardData:
			var eid = card_data.effect_script_id
			if eid == "reduce_damage_by_1" or eid == "reduce_all_damage_by_1":
				damage_reduction += 1
			elif eid == "heal_veteran_dog_2_reduce_veteran_damage_1":
				damage_reduction += 1
			elif eid == "damage_reduction_2_uses_3":
				# 防弹背心：减伤2，使用次数存在current_ammo中
				if equipment.current_ammo > 0:
					damage_reduction += 2
					equipment.current_ammo -= 1
					if equipment.current_ammo <= 0:
						# 用完移到弃牌堆
						player.equipment_zone.erase(equipment)
						player.discard_pile.append(equipment)
					ui_manager.add_log_message("防弹背心减伤2（剩余" + str(equipment.current_ammo) + "次）")

	var actual_damage = max(0, damage - damage_reduction)
	if damage_reduction > 0:
		print("[RuleEngine] 减伤" + str(damage_reduction) + "，实际伤害=" + str(actual_damage))
		ui_manager.add_log_message("减伤" + str(damage_reduction) + "，实际受到" + str(actual_damage) + "伤害")

	player.current_hp -= actual_damage
	print("[RuleEngine] 玩家 " + player_id + " 受到 " + str(actual_damage) + " 点伤害 (" + reason + ")，剩余生命=" + str(player.current_hp))

	if player.current_hp <= 0:
		kill_player(player_id)

	ui_manager.update_player_info(player_id)
	ui_manager.update_equipment_display(player_id)

# 对纠缠怪物造成伤害
func apply_damage_to_monster(player_id: String, monster_instance_id: String, damage: int) -> bool:
	var player = GameState.players[player_id]

	# 检查装备区增伤效果
	var damage_bonus = 0
	for equipment in player.equipment_zone:
		var card_data = _load_card_data(equipment.template_id)
		if card_data is CharacterCardData:
			var eid = card_data.effect_script_id
			if eid == "heal_3_on_equip_increase_damage_1":
				damage_bonus += 1
	var actual_damage = damage + damage_bonus

	for i in range(player.monster_zone.size()):
		var monster = player.monster_zone[i]
		if monster.instance_id == monster_instance_id:
			monster.current_hp -= actual_damage
			print("[RuleEngine] 怪物 " + monster.card_name + " 受到 " + str(actual_damage) + " 点伤害，剩余HP=" + str(monster.current_hp))
			ui_manager.add_log_message("对 " + monster.card_name + " 造成 " + str(actual_damage) + " 伤害")

			if monster.current_hp <= 0:
				# 怪物死亡，移到弃牌堆
				player.monster_zone.remove_at(i)
				GameState.monster_discard_pile.append(_get_monster_data_by_id(monster.template_id))
				print("[RuleEngine] 怪物 " + monster.card_name + " 被消灭")
				ui_manager.add_log_message("消灭: " + monster.card_name)

			ui_manager.update_monster_display(player_id)
			return true

	print("[RuleEngine] 未找到目标怪物: " + monster_instance_id)
	return false

# 根据ID获取怪物数据（从牌库/弃牌堆查找）
func _get_monster_data_by_id(monster_id: String) -> MonsterData:
	# 先在弃牌堆找
	for data in GameState.monster_discard_pile:
		if data.id == monster_id:
			return data
	# 在牌库找
	for data in GameState.monster_deck:
		if data.id == monster_id:
			return data
	# 创建一个空数据返回
	return null

# 获取第一个纠缠怪物（简化目标选择）
func get_first_monster(player_id: String) -> CardRuntime:
	var player = GameState.players[player_id]
	if player.monster_zone.size() > 0:
		return player.monster_zone[0]
	return null

# === 装备系统 ===

# 获取玩家当前装备栏槽位上限（基础+背包加成）
func get_player_equipment_slots(player_id: String) -> int:
	var player = GameState.players[player_id]
	var slots = player.base_equipment_slots
	# 检查背包被动+1格
	for equipment in player.equipment_zone:
		var card_data = _load_card_data(equipment.template_id)
		if card_data is CharacterCardData and card_data.effect_script_id == "increase_equipment_slots_1":
			slots += 1
		elif card_data is ScavengeCardData and card_data.effect_script_id == "increase_equipment_slots_1":
			slots += 1
	return slots

# 获取装备卡的槽位花费
func _get_equipment_cost(card_data: Resource) -> int:
	if card_data is CharacterCardData:
		return card_data.equipment_cost
	elif card_data is ScavengeCardData:
		return card_data.equipment_slot
	return 0

# 装备卡牌到玩家装备栏（顶掉同种旧装备，检查槽位上限）
func _equip_to_player(player_id: String, card_index: int, card_data: Resource) -> bool:
	var player = GameState.players[player_id]
	var card = player.hand[card_index]

	var new_cost = _get_equipment_cost(card_data)

	# 检查是否已有同种装备（template_id相同）
	for i in range(player.equipment_zone.size()):
		var existing = player.equipment_zone[i]
		if existing.template_id == card.template_id:
			# 顶掉旧装备（移到弃牌堆）
			player.discard_pile.append(existing)
			print("[RuleEngine] 顶掉旧装备: " + existing.card_name)
			ui_manager.add_log_message("替换装备: " + existing.card_name)
			# 装备新卡
			player.equipment_zone[i] = card
			# 如果是武器，初始化弹药
			if card_data is CharacterCardData and card_data.max_ammo > 0:
				card.current_ammo = card_data.max_ammo
			elif card_data is ScavengeCardData:
				card.current_ammo = 0
			player.hand.remove_at(card_index)
			print("[RuleEngine] 装备: " + card.card_name)
			ui_manager.add_log_message("装备: " + card.card_name)
			ui_manager.update_player_info(player_id)
			ui_manager.update_equipment_display(player_id)
			# 触发装备时效果
			_trigger_on_equip(player_id, card, card_data)
			return true

	# 没有同种装备，检查槽位上限
	var current_used = 0
	for equipment in player.equipment_zone:
		var ed = _load_card_data(equipment.template_id)
		current_used += _get_equipment_cost(ed)
	var max_slots = get_player_equipment_slots(player_id)
	if current_used + new_cost > max_slots:
		print("[RuleEngine] 装备栏槽位不足: " + str(current_used) + "/" + str(max_slots) + "，新增需" + str(new_cost))
		ui_manager.add_log_message("装备栏槽位不足（" + str(current_used) + "/" + str(max_slots) + "），无法装备 " + card.card_name)
		ui_manager.status_label.text = "装备栏已满!"
		return false

	# 装备新卡
	if card_data is CharacterCardData and card_data.max_ammo != 0:
		card.current_ammo = card_data.max_ammo
	player.equipment_zone.append(card)
	player.hand.remove_at(card_index)
	print("[RuleEngine] 装备: " + card.card_name)
	ui_manager.add_log_message("装备: " + card.card_name)
	ui_manager.update_player_info(player_id)
	ui_manager.update_equipment_display(player_id)
	# 触发装备时效果
	_trigger_on_equip(player_id, card, card_data)
	return true

# 装备时触发的效果（如恢复HP等）
func _trigger_on_equip(player_id: String, card: CardRuntime, card_data: Resource) -> void:
	if effect_manager == null:
		return
	var eid = ""
	if card_data is CharacterCardData:
		eid = card_data.effect_script_id
	elif card_data is ScavengeCardData:
		eid = card_data.effect_script_id
	# 这些效果需要装备时触发
	if eid == "heal_veteran_dog_2_reduce_veteran_damage_1" or eid == "heal_3_on_equip_increase_damage_1":
		effect_manager.execute_effect(card_data, player_id, card)

# 玩家主动弃掉装备区的装备（用于触发弃牌效果）
func discard_equipment(player_id: String, equipment_index: int) -> bool:
	var player = GameState.players[player_id]
	if equipment_index < 0 or equipment_index >= player.equipment_zone.size():
		return false

	var equipment = player.equipment_zone[equipment_index]
	player.equipment_zone.remove_at(equipment_index)

	# 判断是否拾荒卡
	var card_data = _load_card_data(equipment.template_id)
	if card_data is ScavengeCardData:
		# 拾荒卡放到拾荒弃牌堆
		var color = card_data.color
		if GameState.has("scavenge_discard_piles") and GameState.scavenge_discard_piles.has(color):
			GameState.scavenge_discard_piles[color].append(equipment)
		else:
			player.discard_pile.append(equipment)
	else:
		player.discard_pile.append(equipment)

	print("[RuleEngine] 弃掉装备: " + equipment.card_name)
	ui_manager.add_log_message("弃掉装备: " + equipment.card_name)
	ui_manager.update_player_info(player_id)
	ui_manager.update_equipment_display(player_id)
	return true

# 使用武器攻击（消耗1弹药+1行动点，执行武器效果）
func use_weapon_attack(player_id: String, equipment_index: int) -> bool:
	var player = GameState.players[player_id]

	if equipment_index < 0 or equipment_index >= player.equipment_zone.size():
		return false

	var weapon = player.equipment_zone[equipment_index]

	# 检查行动点
	if player.action_points <= 0:
		ui_manager.status_label.text = "没有行动点!"
		return false

	# 检查弹药（-1表示无限弹药，不需要检查）
	if weapon.current_ammo == 0:
		ui_manager.status_label.text = "弹药不足!"
		ui_manager.add_log_message(weapon.card_name + " 弹药不足")
		return false

	# 加载卡牌数据
	var card_data = _load_card_data(weapon.template_id)
	if card_data == null or effect_manager == null:
		return false

	# 消耗弹药（-1表示无限弹药，不消耗）
	if weapon.current_ammo > 0:
		weapon.current_ammo -= 1

	# 执行武器效果
	var success = effect_manager.execute_effect(card_data, player_id, weapon)
	if not success:
		# 效果失败，退还弹药
		weapon.current_ammo += 1
		return false

	# 消耗行动点
	player.action_points -= 1

	ui_manager.add_log_message("使用 " + weapon.card_name + " 攻击 (剩余弹药:" + str(weapon.current_ammo) + ")")
	ui_manager.update_player_info(player_id)
	return true

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
