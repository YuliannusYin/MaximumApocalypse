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

## 游戏实例引用。setup 时注入，供行动技能 filter/执行体查询同地块怪物。
var _game: Game = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_game = game
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


## 行动技能声明：进入带任务标记的地块时挂载（block_match 动态匹配 has_objective_mark），
## filter 实时复查标记与怪物条件（与 get_action_options 条件一致，不含地块匹配项）。
func get_action_skill_decl() -> Variant:
	var decl: Dictionary = {}
	decl["skill_name"] = "摧毁目标"
	decl["block_match"] = func(block: MapBlock) -> bool:
		return block != null and is_instance_valid(block) and block.has_objective_mark()
	decl["filter"] = func(player: Player) -> bool:
		if player == null or not is_instance_valid(player):
			return false
		if player.current_block == null or not is_instance_valid(player.current_block):
			return false
		var block: MapBlock = player.current_block
		if not block.has_objective_mark():
			return false
		if player.action_count < int(params.get("cost", 1)):
			return false
		if params.get("require_no_monster", false) == true:
			if _game == null or not is_instance_valid(_game):
				return false
			if block.count_monster_mark() > 0:
				return false
			if _count_monsters_on_block(_game, block) > 0:
				return false
		return true
	decl["execute"] = func(player: Player) -> void:
		await _do_destroy(_game, player)
	decl["confirm"] = func(player: Player) -> String:
		return "确定消耗 %d 行动摧毁此目标？" % int(params.get("cost", 1))
	return decl


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
