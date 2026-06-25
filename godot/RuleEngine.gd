extends Node
@onready var map_board = $MapBoard
@onready var ui_manager = $UIManager


# RuleEngine.gd 中
func execute_monster_spawn(dice_1: int, dice_2: int):
	var X = dice_1 + dice_2
	var state = GameState # 引入全局状态
	
	for pos in state.map_grid.keys():
		var tile = state.map_grid[pos]
		# 假设 tile_data 是预先加载的 MapBlockData 资源
		var tile_data: MapBlockData = tile["data"] 
		
		if tile["is_revealed"] and X in tile_data.spawn_values:
			if tile["monster_tokens"] < 3:
				# 配件流失校验
				if state.available_monster_tokens <= 0:
					state.game_status = Enums.GameStatus.DEFEAT
					state.game_over.emit(state.game_status)
					return
				
				tile["monster_tokens"] += 1
				state.available_monster_tokens -= 1
			else:
				# 标记满了，该地块所有玩家抓一张怪物卡
				var players_on_tile = get_players_at_position(pos)
				for player in players_on_tile:
					draw_monster_card_to_player(player.id)

# RuleEngine.gd 中
func move_player(player_id: String, target_pos: Vector2i):
	var state = GameState
	var player: PlayerState = state.players[player_id]
	var tile = state.map_grid.get(target_pos)
	
	if not tile: return # 非法边界
	
	# 1. 扣除行动点
	player.action_points -= 1
	player.position = target_pos
	
	# 2. 翻开迷雾
	if not tile["is_revealed"]:
		tile["is_revealed"] = true
		state.tile_revealed.emit(target_pos) # 发射信号通知视图层播放翻牌动画
		trigger_tile_effect(target_pos, Enums.TriggerTime.ON_REVEAL, player_id)
		
	trigger_tile_effect(target_pos, Enums.TriggerTime.ON_ENTER, player_id)
	
	# 3. 潜行检定
	if tile["monster_tokens"] > 0 and not has_engaged_monsters(player_id):
		var base_stealth = player.starving_stealth if player.is_starving else player.base_stealth
		var final_stealth = base_stealth - tile["monster_tokens"]
		
		# Godot 随机数生成
		var roll = randi_range(1, 6) + randi_range(1, 6)
		if roll > final_stealth:
			# 检定失败
			var count = tile["monster_tokens"]
			tile["monster_tokens"] = 0
			state.available_monster_tokens += count # 退回标记
			
			for i in range(count):
				draw_monster_card_to_player(player_id)


func _process_spawn_phase():
	# 1. 摇两个六面骰
	var d1 = randi_range(1, 6)
	var d2 = randi_range(1, 6)
	
	# 2. 通知 UI 表现层显示摇骰子动画
	ui_manager.play_dice_animation(d1, d2)
	await ui_manager.dice_animation_finished # 等待 UI 播完动画
	
	# 3. 运行规则引擎计算：放置标记或让玩家抓怪物卡
	rule_engine.execute_monster_spawn(d1, d2)
	
	# 4. 给玩家短暂的视觉停留时间（例如0.5秒看清哪里出了怪）
	await get_tree().create_timer(0.5).timeout
	

func _process_draw_phase(player_id: String):
	var player = GameState.players[player_id]
	
	# 规则检查：牌库是否空了
	if player.deck.size() == 0:
		rule_engine.kill_player(player_id)
		return
		
	# 规则执行：摸牌
	var drawn_card = player.deck.pop_front()
	player.hand.append(drawn_card)
	
	# 通知 UI 播放摸牌动效
	ui_manager.play_draw_card_anim(player_id, drawn_card)
	await ui_manager.draw_card_anim_finished
	
	
# 一个类内部的异步信号催化剂
signal action_phase_finished

func _process_action_phase(player_id: String):
	var player = GameState.players[player_id]
	player.action_points = 4 # 重置行动点
	
	# 允许 UI 响应玩家的操作点击（移动、攻击、拾荒、点卡牌）
	ui_manager.enable_player_controls(player_id)
	
	# 【核心挂起】代码会在这里死死卡住，直到玩家把 4 点行动点用完，
	# 或者在 UI 上点击了 "结束行动阶段" 按钮触发了此信号。
	await action_phase_finished
	
	# 禁用 UI 响应，防止玩家在非行动阶段乱点
	ui_manager.disable_player_controls()

# 这个函数由 UI 界面上的“结束回合”按钮点击时调用
func _on_ui_end_turn_button_pressed():
	action_phase_finished.emit()
	
func _process_hunger_phase(player_id: String):
	var player = GameState.players[player_id]
	
	# 饥饿度自增
	player.hunger_level += 1
	
	if player.hunger_level >= 6:
		if not player.is_starving:
			# 第一次进入饥饿：角色卡翻面
			player.is_starving = true
			player.starving_damage_stage = 1 # 进入承受2点伤害阶段
			ui_manager.show_character_flip_anim(player_id)
			await ui_manager.flip_anim_finished
		
		# 根据伤害阶段扣血 (2, 4, 6, 8)
		var dmg = player.starving_damage_stage * 2
		rule_engine.apply_damage_to_player(player_id, dmg, true) # true 代表无视护甲/不可避免
		
		# 晋升到下一个更痛的伤害阶段
		player.starving_damage_stage += 1
		
		# 飘字提示玩家饿肚子掉血
		ui_manager.show_damage_floating_text(player_id, dmg, "饥饿!")
		await get_tree().create_timer(0.8).timeout


func _process_monster_attack_phase(player_id: String):
	# 获取所有正在纠缠该玩家的运行时怪物
	var monsters = rule_engine.get_monsters_engaged_with(player_id)
	
	for monster in monsters:
		# 结算伤害
		rule_engine.apply_damage_to_player(player_id, monster.damage, false)
		
		# 播放怪物咬人/攻击动画
		ui_manager.play_monster_attack_anim(monster.id, player_id)
		await ui_manager.monster_attack_anim_finished
		
		# 每次怪物咬完，检查一下玩家有没有暴毙，死了就不用被后面的怪咬了
		if _is_game_over(): return
		
# 顺时针轮转玩家
func _switch_to_next_player():
	var keys = GameState.players.keys()
	var current_index = keys.find(GameState.active_player_id)
	var next_index = (current_index + 1) % keys.size()
	GameState.active_player_id = keys[next_index]
	
	# 如果轮了一圈回到第一个人，回合总计数 +1
	if next_index == 0:
		GameState.current_turn += 1

# 判定游戏是否结束
func _is_game_over() -> bool:
	# 每次关键伤害或事件后调用
	if GameState.game_status != Enums.GameStatus.PLAYING:
		return true
	return false

# 处理输赢结局
func _handle_game_over():
	if GameState.game_status == Enums.GameStatus.VICTORY:
		ui_manager.show_victory_screen()
	elif GameState.game_status == Enums.GameStatus.DEFEAT:
		ui_manager.show_defeat_screen()
