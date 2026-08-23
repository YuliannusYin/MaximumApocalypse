class_name MissionComponentDestroyCurrentMark
extends MissionComponent

## 花费行动摧毁当前地块任务标记的行动选项组件。
## 组件 id：destroy_current_mark；类别：action（行动选项）。
## params：
## - cost: int（默认 1）——摧毁消耗的行动数
## - require_no_monster: bool（默认 false）——true 时额外要求地块无怪物标记
##   且同地块所有存活玩家的怪物区皆空
## 行动选项仅在玩家所在地块存在未移除的任务标记且行动数充足时出现；
## 执行后扣减行动并移除该地块全部任务标记。
## 服务任务 9/11/12。

func setup(game: Game, mission_config: MissionConfig) -> void:
	if not params.has("cost"):
		params["cost"] = 1
	if not params.has("require_no_monster"):
		params["require_no_monster"] = false


func get_action_options(game: Game, player: Player) -> Array:
	if player == null or not is_instance_valid(player):
		return []
	if player.current_block == null or not is_instance_valid(player.current_block):
		return []
	var block: MapBlock = player.current_block
	if not block.has_objective_mark():
		return []
	var cost: int = int(params.get("cost", 1))
	if player.action_count < cost:
		return []
	if params.get("require_no_monster", false) == true:
		if block.count_monster_mark() > 0:
			return []
		if _count_monsters_on_block(game, block) > 0:
			return []
	return [{
		"id": "destroy_mark",
		"label": "花费 %d 行动摧毁目标" % cost,
		"execute": _do_destroy.bind(game, player),
	}]


## 统计同地块存活玩家怪物区的怪物总数（地块上被纠缠的怪物）。
func _count_monsters_on_block(game: Game, block: MapBlock) -> int:
	var count: int = 0
	if game == null or not is_instance_valid(game):
		return count
	for other in game.players:
		if other == null or not is_instance_valid(other) or not other.is_alive():
			continue
		if other.current_block != block:
			continue
		count += other.monster_zone.size()
	return count


## 摧毁执行：扣减行动并移除地块全部任务标记。
func _do_destroy(game: Game, player: Player) -> void:
	if game == null or not is_instance_valid(game):
		return
	if player == null or not is_instance_valid(player):
		return
	if player.current_block == null or not is_instance_valid(player.current_block):
		return
	var block: MapBlock = player.current_block
	var cost: int = int(params.get("cost", 1))
	player.reduce_action_count(cost)
	block.remove_all_objective_marks()
	game.log_message(LogColors.player(player.player_name) + " 摧毁了 " + LogColors.block(block.block_name) + " 上的任务标记！")
