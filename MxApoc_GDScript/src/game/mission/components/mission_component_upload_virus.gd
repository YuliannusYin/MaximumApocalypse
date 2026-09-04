class_name MissionComponentUploadVirus
extends MissionComponent

## 消耗行动上传病毒的直接胜利行动选项组件。
## 组件 id：upload_virus；类别：action（行动选项）。
## params：
## - block_name: String（默认 "坠毁点"）——上传地点地块名
## - equipment: String（默认 "科学家"）——上传所需的装备名（须在玩家装备区）
## 行动选项仅在玩家位于上传地点、装备区持有指定装备、行动数充足
## 且场上存活地块已无任何未移除的任务标记时出现；
## 执行后扣减 1 行动并直接判定胜利（game_over("win")）。
## 服务任务 9。

## 游戏实例引用。setup 时注入，供行动技能 filter 扫描场上标记与执行体调用 _do_upload。
var _game: Game = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_game = game
	if not params.has("block_name"):
		params["block_name"] = "坠毁点"
	if not params.has("equipment"):
		params["equipment"] = "科学家"


func get_action_options(game: Game, player: Player) -> Array:
	if player == null or not is_instance_valid(player):
		return []
	if player.current_block == null or not is_instance_valid(player.current_block):
		return []
	if player.current_block.block_name != params.get("block_name", "坠毁点"):
		return []
	if not player.has_equipment(params.get("equipment", "科学家")):
		return []
	if player.get_effective_action_count() < 1:
		return []
	if _any_objective_mark_on_map(game):
		return []
	return [{
		"id": "upload_virus",
		"label": "消耗 1 行动上传病毒",
		"execute": _do_upload.bind(game, player),
	}]


## 行动技能声明：进入上传地点时挂载为主动技能（active="action"），
## filter 实时检查装备持有、行动数与场上任务标记清空状态
## （与 get_action_options 条件一致，不含地块匹配项）。
func get_action_skill_decl() -> Variant:
	var decl: Dictionary = {}
	decl["skill_name"] = "上传病毒"
	decl["block_match"] = func(block: MapBlock) -> bool:
		return block != null and is_instance_valid(block) and block.block_name == params.get("block_name", "坠毁点")
	decl["filter"] = func(player: Player) -> bool:
		if player == null or not is_instance_valid(player):
			return false
		if not player.has_equipment(params.get("equipment", "科学家")):
			return false
		if player.get_effective_action_count() < 1:
			return false
		if _game == null or not is_instance_valid(_game):
			return false
		if _any_objective_mark_on_map(_game):
			return false
		return true
	decl["execute"] = func(player: Player) -> void:
		await _do_upload(_game, player)
	decl["confirm"] = func(player: Player) -> String:
		return "确定消耗 1 行动上传病毒？"
	return decl


## 场上存活地块是否存在未移除的任务标记。
func _any_objective_mark_on_map(game: Game) -> bool:
	if game == null or not is_instance_valid(game):
		return false
	if game.map_area == null:
		return false
	for block in game.map_area:
		if block == null or not is_instance_valid(block):
			continue
		if not block.is_alive():
			continue
		if block.has_objective_mark():
			return true
	return false


## 上传执行：扣减 1 行动并直接判定胜利。
func _do_upload(game: Game, player: Player) -> void:
	if game == null or not is_instance_valid(game):
		return
	if player == null or not is_instance_valid(player):
		return
	if not await player.consume_action_evented(1):
		return
	game.log_message(LogColors.player(player.player_name) + " 上传了病毒！")
	await game.game_over("win")
