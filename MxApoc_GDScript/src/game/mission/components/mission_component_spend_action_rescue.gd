class_name MissionComponentSpendActionRescue
extends MissionComponent

## 花费行动解救（如科学家）行动选项组件。
## 组件 id：spend_action_rescue；类别：action（行动选项）。
## params：
## - block_name: String——解救地点地块名
## - cost: int（默认 2）——解救消耗的行动数
## - card_name: String（默认 "科学家"）——解救获得的拾荒卡名
## - rescued_key: String（默认 "scientist_rescued"）——mission_state 中标记已获救的键
## - holder_key: String（默认 "scientist_holder"）——mission_state 中持有者玩家引用的键
## 行动选项仅在玩家位于解救地点、行动数充足且尚未解救时出现；
## 执行后扣减行动、将解救的拾荒卡装备到玩家装备区，并写入 rescued_key / holder_key
## 记录解救状态（供行动选项隐藏等任务逻辑使用）。
## 胜利判定由 escort_equipment_at_block 直接查找装备区持有者完成。

## 任务配置引用。setup 时注入，用于读写 mission_state。
var _mission_config: MissionConfig = null

## 游戏实例引用。setup 时注入，供行动技能执行体调用 _do_rescue。
var _game: Game = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_game = game
	_mission_config = mission_config
	if not params.has("cost"):
		params["cost"] = 2
	if not params.has("card_name"):
		params["card_name"] = "科学家"
	if not params.has("rescued_key"):
		params["rescued_key"] = "scientist_rescued"
	if not params.has("holder_key"):
		params["holder_key"] = "scientist_holder"


func get_action_options(game: Game, player: Player) -> Array:
	if player == null or not is_instance_valid(player):
		return []
	if _mission_config == null:
		return []
	if _mission_config.mission_state.get(params.get("rescued_key", "scientist_rescued"), false) == true:
		return []
	if player.current_block == null or not is_instance_valid(player.current_block):
		return []
	if player.current_block.block_name != params.get("block_name", ""):
		return []
	var cost: int = int(params.get("cost", 2))
	if player.get_effective_action_count() < cost:
		return []
	var card_name: String = params.get("card_name", "科学家")
	return [{
		"id": "rescue_" + card_name,
		"label": "花费 %d 行动解救%s" % [cost, card_name],
		"execute": _do_rescue.bind(game, player),
	}]


## 行动技能声明：进入解救地点时挂载为主动技能（active="action"），
## 复用地块技能管线（技能栏显示、filter 灰化、confirm 确认门、use_active_skill 执行）。
## 闭包捕获组件实例：挂载后调用时读取最新的 mission_state 与 params。
func get_action_skill_decl() -> Variant:
	var decl: Dictionary = {}
	decl["skill_name"] = params.get("skill_name", "解救科学家")
	decl["block_match"] = func(block: MapBlock) -> bool:
		return block != null and is_instance_valid(block) and block.block_name == params.get("block_name", "")
	decl["filter"] = func(player: Player) -> bool:
		if player == null or not is_instance_valid(player):
			return false
		if _mission_config == null:
			return false
		if _mission_config.mission_state.get(params.get("rescued_key", "scientist_rescued"), false) == true:
			return false
		return player.get_effective_action_count() >= int(params.get("cost", 2))
	decl["execute"] = func(player: Player) -> void:
		await _do_rescue(_game, player)
	decl["confirm"] = func(player: Player) -> String:
		return "确定花费 %d 行动解救%s？" % [int(params.get("cost", 2)), params.get("card_name", "科学家")]
	return decl


## 解救执行（协程）：创建拾荒卡并装备到玩家面前，写入 mission_state。
## 拾荒卡不存在时不消耗行动直接返回。
func _do_rescue(game: Game, player: Player) -> void:
	if game == null or not is_instance_valid(game):
		return
	if player == null or not is_instance_valid(player):
		return
	if _mission_config == null:
		return
	var card_name: String = params.get("card_name", "科学家")
	var cost: int = int(params.get("cost", 2))
	var card: Card = game.create_scavenge_card(card_name)
	if card == null:
		game.log_message("未找到拾荒卡：" + card_name + "，无法解救")
		return
	if not await player.consume_action_evented(cost):
		return
	await player.equip(card)
	_mission_config.mission_state[params.get("rescued_key", "scientist_rescued")] = true
	_mission_config.mission_state[params.get("holder_key", "scientist_holder")] = player
	game.log_message(LogColors.player(player.player_name) + " 解救了" + card_name + "，装备到面前！")
