class_name MissionComponentSpawnDiceEffect
extends MissionComponent

## 怪物生成检定外围地块效果触发器组件。
## 组件 id：spawn_dice_effect；类别：trigger（触发器）。
## params：
## - value: int——怪物出生检定命中的投骰点数（如 7）
## - block_name: String（默认 "面包车"）——日志措辞中的参照地块名（地图中心点），可缺省
## 说明：怪物出生检定投出指定点数（monster_spawn_judged 事件 value 命中 params.value）时，
## 对"外围地块"执行天灾扩散效果：
## 1. 存在未展示的外围地块 → 随机选一个置 revealed = true（直接翻转，不触发地块技能）；
## 2. 全部外围地块已展示 → 随机选一个外围地块移除：
##    先让其上所有存活玩家死亡（player.death(null)，fire-and-forget 协程，
##    日志"被崩塌的废墟吞噬"），再调用 game.destroy_map_block(block, self) 摧毁地块。
##    注：destroy_map_block 内部只会把地块上的"存活"玩家弹出到相邻存活地块
##    （无相邻则受 5 点伤害），不会杀死玩家——因此组件必须先杀死其上玩家，
##    玩家死亡后 hp=0 立即生效，destroy_map_block 的 get_players() 不再包含他们，不会重复处理。
## 外围定义：地图边界上的存活地块——coordinate.x == 0 或 x == Game.map_width-1
## 或 coordinate.y == 0 或 y == Game.map_height-1（最外圈一圈）。外围无存活地块时跳过。
## 随机选择：在候选数组上 pick_random()（均匀随机），两个分支各自独立抽取。
## 服务任务 6（核辐射）。

func on_event(game: Game, event_name: String, event: Dictionary) -> void:
	if event_name != "monster_spawn_judged":
		return
	if game == null or not is_instance_valid(game):
		return
	var value: int = int(event.get("value", -1))
	if value != int(params.get("value", -1)):
		return
	# 外围地块 = 地图边界一圈的存活地块；无存活外围时直接跳过
	var outer_blocks: Array = _get_outer_blocks(game)
	if outer_blocks.is_empty():
		return
	var center_name: String = params.get("block_name", "面包车")
	# 分支 1：仍有未展示的外围地块 → 随机揭示一个
	var unrevealed_blocks: Array = []
	for block in outer_blocks:
		if not block.is_revealed():
			unrevealed_blocks.append(block)
	if not unrevealed_blocks.is_empty():
		var target: MapBlock = unrevealed_blocks.pick_random()
		target.revealed = true
		game.log_message("辐射逼近 " + LogColors.block(center_name) + "！外围的 " + LogColors.block(target.block_name) + " 被揭示")
		return
	# 分支 2：全部外围已展示 → 随机移除一个外围地块（先吞噬其上玩家再摧毁）
	var doomed: MapBlock = outer_blocks.pick_random()
	for player in game.players:
		if player == null or not is_instance_valid(player):
			continue
		if not player.is_alive():
			continue
		if player.current_block == doomed:
			game.log_message(LogColors.player(player.player_name) + " 被崩塌的废墟吞噬！")
			player.death(null)
	game.log_message("辐射吞噬 " + LogColors.block(center_name) + " 周边！外围的 " + LogColors.block(doomed.block_name) + " 崩塌了")
	game.destroy_map_block(doomed, self)


## 内部方法：计算外围地块集合。
## 遍历 Game.map_area 中存活（is_alive）的地块，坐标位于地图边界
## （x == 0 或 x == map_width-1 或 y == 0 或 y == map_height-1）者入选。
func _get_outer_blocks(game: Game) -> Array:
	var outer_blocks: Array = []
	for block in game.map_area:
		if block == null or not is_instance_valid(block) or not block.is_alive():
			continue
		var x: int = int(block.coordinate.get("x", 0))
		var y: int = int(block.coordinate.get("y", 0))
		if x == 0 or x == game.map_width - 1 or y == 0 or y == game.map_height - 1:
			outer_blocks.append(block)
	return outer_blocks
