class_name MissionComponentAllPlayersAtBlock
extends MissionComponent

## 全员抵达地块胜利条件组件。
## 组件 id：all_players_at_block；类别：win_condition（胜利条件）。
## params：
## - block_name: String——目标地块名（如 "面包车"）
## 判定：所有存活玩家的 current_block 非空且地块名匹配才胜利；无存活玩家返回 false。

func check_win(game: Game) -> bool:
	if game == null or not is_instance_valid(game):
		return false
	var alive_players: Array = game.get_alive_players()
	if alive_players.is_empty():
		return false
	var block_name: String = params.get("block_name", "")
	for player in alive_players:
		if player == null or not is_instance_valid(player):
			return false
		if player.current_block == null or not is_instance_valid(player.current_block):
			return false
		if player.current_block.block_name != block_name:
			return false
	return true
