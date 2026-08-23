class_name MissionComponentAllBlocksRevealed
extends MissionComponent

## 全地块展示胜利条件组件（服务任务 7）。
## 组件 id：all_blocks_revealed；类别：win_condition（胜利条件）。
## params：无。
## 判定：Game.map_area 中所有存活（is_alive）地块 revealed == true。
## 地图为空或无存活地块时返回 false（防止退化场景误判胜利）。

func check_win(game: Game) -> bool:
	if game == null or not is_instance_valid(game):
		return false
	if game.map_area.is_empty():
		return false
	var alive_count: int = 0
	for block in game.map_area:
		if block == null or not is_instance_valid(block):
			continue
		if not block.is_alive():
			continue
		alive_count += 1
		if not block.revealed:
			return false
	return alive_count > 0
