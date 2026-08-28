class_name MissionComponentAllPlayersAtBlock
extends MissionComponent

## 全员抵达地块胜利条件组件。
## 组件 id：all_players_at_block；类别：win_condition（胜利条件）。
## params：
## - block_name: String——目标地块名（如 "面包车"）
## - no_monster: bool（默认 false）——true 时目标地块须同时满足无怪物标记、
##   且地块上玩家的怪物卡总数为 0（引擎怪物在玩家面前，即 player.monster_zone）
## 判定：所有存活玩家的 current_block 非空且地块名匹配才胜利；无存活玩家返回 false。
## no_monster=true 时额外判定目标地块无怪：目标地块取存活玩家所在同名地块（任取一块），
## 玩家可能分布在多个同名地块实例上，任一实例有怪物标记、任一存活玩家面前有怪均视为未清空。

func check_win(game: Game) -> bool:
	if game == null or not is_instance_valid(game):
		return false
	var alive_players: Array = game.get_alive_players()
	if alive_players.is_empty():
		return false
	var block_name: String = params.get("block_name", "")
	var no_monster: bool = params.get("no_monster", false) == true
	var checked_blocks: Array = []
	for player in alive_players:
		if player == null or not is_instance_valid(player):
			return false
		if player.current_block == null or not is_instance_valid(player.current_block):
			return false
		if player.current_block.block_name != block_name:
			return false
		if no_monster:
			# 目标地块无怪物标记（count_monster_mark，见 map_block.gd）
			if not checked_blocks.has(player.current_block):
				checked_blocks.append(player.current_block)
				if player.current_block.count_monster_mark() > 0:
					return false
			# 地块上玩家的怪物卡总数为 0（怪物在玩家面前 monster_zone）
			if player.monster_zone.size() > 0:
				return false
	return true
