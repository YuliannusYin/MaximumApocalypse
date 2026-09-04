class_name MissionComponentRescueJudgeWin
extends MissionComponent

## 消耗行动解救并潜行检定决胜的行动选项组件。
## 组件 id：rescue_judge_win；类别：action（行动选项）。
## params：
## - card_name: String（默认 "满是灰尘的日记本"）——检定失败时豁免所需的情报卡名
## mission_state 键：
## - rescue_judge_done: bool——是否已执行过解救检定（setup 时缺省 false）
## 行动选项仅在玩家所在地块存在任务标记、未执行过检定且行动数充足时出现；
## 执行后扣减 1 行动并执行潜行检定：成功直接胜利；失败时持有情报卡仍胜利，
## 否则直接失败。服务任务 8（配 action_win_only 组件防误判）。

## 任务配置引用。setup 时注入，用于读写 mission_state。
var _mission_config: MissionConfig = null

## 游戏实例引用。setup 时注入，供行动技能执行体调用 _do_rescue。
var _game: Game = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_game = game
	_mission_config = mission_config
	if not params.has("card_name"):
		params["card_name"] = "满是灰尘的日记本"
	if _mission_config == null:
		return
	if not _mission_config.mission_state.has("rescue_judge_done"):
		_mission_config.mission_state["rescue_judge_done"] = false


func get_action_options(game: Game, player: Player) -> Array:
	if player == null or not is_instance_valid(player):
		return []
	if _mission_config == null:
		return []
	if _mission_config.mission_state.get("rescue_judge_done", false) == true:
		return []
	if player.current_block == null or not is_instance_valid(player.current_block):
		return []
	if not player.current_block.has_objective_mark():
		return []
	if player.get_effective_action_count() < 1:
		return []
	return [{
		"id": "rescue_judge_win",
		"label": "消耗 1 行动解救科学家",
		"execute": _do_rescue.bind(game, player),
	}]


## 行动技能声明：进入带任务标记的地块时挂载（block_match 动态匹配 has_objective_mark），
## filter 实时复查检定状态、地块标记与行动数（与 get_action_options 条件一致，不含地块匹配项）。
func get_action_skill_decl() -> Variant:
	var decl: Dictionary = {}
	decl["skill_name"] = "解救科学家"
	decl["block_match"] = func(block: MapBlock) -> bool:
		return block != null and is_instance_valid(block) and block.has_objective_mark()
	decl["filter"] = func(player: Player) -> bool:
		if player == null or not is_instance_valid(player):
			return false
		if _mission_config == null:
			return false
		if _mission_config.mission_state.get("rescue_judge_done", false) == true:
			return false
		if player.current_block == null or not is_instance_valid(player.current_block):
			return false
		if not player.current_block.has_objective_mark():
			return false
		return player.get_effective_action_count() >= 1
	decl["execute"] = func(player: Player) -> void:
		await _do_rescue(_game, player)
	decl["confirm"] = func(player: Player) -> String:
		return "确定消耗 1 行动解救科学家？"
	return decl


## 解救执行（协程）：扣减 1 行动、执行潜行检定并按结果判定胜负。
## 成功 → 胜利；失败但持有情报卡 → 胜利；失败且无情报卡 → 失败。
func _do_rescue(game: Game, player: Player) -> void:
	if game == null or not is_instance_valid(game):
		return
	if player == null or not is_instance_valid(player):
		return
	if _mission_config == null:
		return
	if not await player.consume_action_evented(1):
		return
	_mission_config.mission_state["rescue_judge_done"] = true
	game.log_message(LogColors.player(player.player_name) + " 执行潜行检定……")
	var success: bool = await player.sneak_judge(player.current_block)
	if success:
		game.log_message("潜行检定成功！科学家还活着！")
		game.game_over("win")
		return
	if player.has_item(params.get("card_name", "满是灰尘的日记本")):
		game.log_message("潜行检定失败，但记下了科学家弥留之际的信息！")
		game.game_over("win")
	else:
		game.log_message("潜行检定失败且没有日记本……")
		game.game_over("lose")
