# RuleEngine.gd 中
func execute_monster_spawn(dice_1: int, dice_2: int):
	var X = dice_1 + dice_2
	var state = GameState # 引入全局状态
	
	for pos in state.map_grid.keys():
		var tile = state.map_grid[pos]
		# 假设 tile_data 是预先加载的 MapTileData 资源
		var tile_data: MapTileData = tile["data"] 
		
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
