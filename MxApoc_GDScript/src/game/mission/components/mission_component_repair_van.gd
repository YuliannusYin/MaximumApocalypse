class_name MissionComponentRepairVan
extends MissionComponent

## 消耗行动维修面包车的行动选项组件。
## 组件 id：repair_van；类别：action（行动选项）。
## params：
## - block_name: String（默认 "面包车"）——维修地点地块名
## - card_name: String（默认 "多余配件"）——每次维修弃置的配件卡名
## - times: int（默认 3）——修满所需的维修次数
## mission_state 键：
## - van_repair_count: int——已完成维修次数（setup 时缺省 0）
## - van_repaired: bool——是否修满（setup 时缺省 false，state_flag 类胜利条件组件读取）
## 行动选项仅在玩家位于面包车地块、持有配件（手牌或装备区）、行动数充足
## 且未修满时出现；执行后扣减 1 行动、弃置 1 张配件并累计维修进度，
## 达到 times 次后置 van_repaired = true。
## 服务任务 6。

## 任务配置引用。setup 时注入，用于读写 mission_state。
var _mission_config: MissionConfig = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_mission_config = mission_config
	if not params.has("block_name"):
		params["block_name"] = "面包车"
	if not params.has("card_name"):
		params["card_name"] = "多余配件"
	if not params.has("times"):
		params["times"] = 3
	if _mission_config == null:
		return
	if not _mission_config.mission_state.has("van_repair_count"):
		_mission_config.mission_state["van_repair_count"] = 0
	if not _mission_config.mission_state.has("van_repaired"):
		_mission_config.mission_state["van_repaired"] = false


func get_action_options(game: Game, player: Player) -> Array:
	if player == null or not is_instance_valid(player):
		return []
	if _mission_config == null:
		return []
	if _mission_config.mission_state.get("van_repaired", false) == true:
		return []
	if player.current_block == null or not is_instance_valid(player.current_block):
		return []
	if player.current_block.block_name != params.get("block_name", "面包车"):
		return []
	if not player.has_item(params.get("card_name", "多余配件")):
		return []
	if player.action_count < 1:
		return []
	return [{
		"id": "repair_van",
		"label": "消耗 1 行动维修面包车（弃置 1 张%s）" % params.get("card_name", "多余配件"),
		"execute": _do_repair.bind(game, player),
	}]


## 维修执行（协程）：扣减 1 行动、弃置 1 张配件并累计维修进度。
## 配件不足时不消耗行动直接返回。
func _do_repair(game: Game, player: Player) -> void:
	if game == null or not is_instance_valid(game):
		return
	if player == null or not is_instance_valid(player):
		return
	if _mission_config == null:
		return
	var card_name: String = params.get("card_name", "多余配件")
	var times: int = int(params.get("times", 3))
	# 收集 1 张配件：装备区实体在前（discard 按名解析优先命中装备区），手牌在后
	var card_to_discard: Variant = null
	for e in player.equipment_zone:
		if e != null and is_instance_valid(e) and e.card_name == card_name:
			card_to_discard = e
			break
	if card_to_discard == null:
		for c in player.hand:
			if c != null and is_instance_valid(c) and c.card_name == card_name:
				card_to_discard = c
				break
	if card_to_discard == null:
		return
	player.reduce_action_count(1)
	await player.discard(card_to_discard)
	var count: int = int(_mission_config.mission_state.get("van_repair_count", 0)) + 1
	_mission_config.mission_state["van_repair_count"] = count
	if count >= times:
		_mission_config.mission_state["van_repaired"] = true
		game.log_message(LogColors.player(player.player_name) + " 修好了面包车！（" + str(count) + "/" + str(times) + "）")
	else:
		game.log_message(LogColors.player(player.player_name) + " 维修了面包车（" + str(count) + "/" + str(times) + "）")
