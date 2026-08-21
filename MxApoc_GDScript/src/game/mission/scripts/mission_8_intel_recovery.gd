class_name Mission8IntelRecovery
extends MissionScript

## 任务 8「情报恢复」专用脚本（三层架构第三层）。
## 规则：第一个到达目标标记地块的玩家抓取首领卡并投一次潜行检定——
## 成功则科学家还活着，可花费 1 个行动解救（装备到面前）；
## 失败则需持有"满是灰尘的日记本"记录科学家弥留信息，否则任务失败。
## 胜利：科学家被解救且持有者位于军事基地，或信息被记录且记录者位于军事基地。
## mission_state 键（与 IdentifierMapping 约定对齐）：
## - intel_attempted：是否已有玩家到达过目标标记（仅第一次到达生效）
## - scientist_available：检定成功，科学家待解救
## - scientist_rescued：科学家已被解救
## - scientist_holder：解救科学家的玩家
## - scientist_info_recorded：科学家弥留信息已被记录
## - info_recorder：记录信息的玩家
## - intel_failed_no_diary：检定失败且无日记本（任务失败标记）

## setup 时注入的任务配置引用，用于读写 mission_state。
var _mission_config: MissionConfig = null


## 初始化：记录任务配置引用并初始化 mission_state 各键默认值。
func setup(game: Game, mission_config: MissionConfig) -> void:
	_mission_config = mission_config
	var state: Dictionary = mission_config.mission_state
	state["intel_attempted"] = false
	state["scientist_available"] = false
	state["scientist_rescued"] = false
	state["scientist_holder"] = null
	state["scientist_info_recorded"] = false
	state["info_recorder"] = null
	state["intel_failed_no_diary"] = false


## 事件回调：仅响应 objective_mark_triggered（第一个到达目标标记的玩家）。
## 含 await（sneak_judge 为协程），事件转发链路以 fire-and-forget 方式调用本方法。
func on_event(game: Game, event_name: String, event: Dictionary) -> void:
	if event_name != "objective_mark_triggered":
		return
	var state: Dictionary = _get_state()
	if state.get("intel_attempted", false):
		return
	state["intel_attempted"] = true
	var player: Variant = event.get("player")
	if player == null or not is_instance_valid(player):
		return
	game.log_message(LogColors.player(player.player_name) + " 到达了目标标记地点！")
	# 抓取首领卡（非协程，直接调用）
	player.draw_boss_card()
	# 潜行检定（协程）
	var success: bool = await player.sneak_judge(event.get("block"))
	if success:
		state["scientist_available"] = true
		game.log_message("潜行检定成功，科学家还活着！可以花费 1 个行动解救他。")
	else:
		if player.has_item("满是灰尘的日记本"):
			state["scientist_info_recorded"] = true
			state["info_recorder"] = player
			game.log_message("潜行检定失败。" + LogColors.player(player.player_name) + " 记下了科学家弥留之际说出的信息。")
		else:
			state["intel_failed_no_diary"] = true
			game.log_message("潜行检定失败，且没有日记本！任务失败……")


## 行动选项：科学家待解救、未被解救且玩家至少有 1 点行动时，提供解救选项。
func get_action_options(game: Game, player: Player) -> Array:
	var state: Dictionary = _get_state()
	if not state.get("scientist_available", false):
		return []
	if state.get("scientist_rescued", false):
		return []
	if player == null or not is_instance_valid(player) or player.action_count < 1:
		return []
	return [{
		"id": "mission_8_rescue_scientist",
		"label": "花费 1 行动解救科学家",
		"execute": _do_rescue.bind(game, player),
	}]


## 解救科学家：创建科学家卡，扣 1 点行动并装备到玩家面前。
func _do_rescue(game: Game, player: Player) -> void:
	var card: Card = game.create_scavenge_card("科学家")
	if card == null:
		game.log_message("未找到科学家卡，无法解救！")
		return
	var state: Dictionary = _get_state()
	player.reduce_action_count(1)
	await player.equip(card)
	state["scientist_rescued"] = true
	state["scientist_holder"] = player
	state["scientist_available"] = false
	game.log_message(LogColors.player(player.player_name) + " 解救了科学家，装备到面前！")


## 胜利：科学家被解救且持有者在军事基地，或信息被记录且记录者在军事基地。
func check_win(game: Game) -> bool:
	var state: Dictionary = _get_state()
	var holder: Variant = state.get("scientist_holder")
	if state.get("scientist_rescued", false) and _is_player_at_block(holder, "军事基地"):
		return true
	var recorder: Variant = state.get("info_recorder")
	if state.get("scientist_info_recorded", false) and _is_player_at_block(recorder, "军事基地"):
		return true
	return false


## 失败：检定失败且无日记本。
func check_lose(game: Game) -> bool:
	return _get_state().get("intel_failed_no_diary", false) == true


## 读取 mission_state。优先 setup 注入的配置，回退到 Game.mission_config。
func _get_state() -> Dictionary:
	if _mission_config != null:
		return _mission_config.mission_state
	if Game != null and is_instance_valid(Game) and Game.mission_config != null:
		return Game.mission_config.mission_state
	return {}


## 判断玩家有效存活且位于指定名称的地块。
func _is_player_at_block(player: Variant, block_name: String) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not player.is_alive():
		return false
	var block: Variant = player.current_block
	if block == null or not is_instance_valid(block):
		return false
	return block.block_name == block_name
