class_name MissionComponentAddVanFuel
extends MissionComponent

## 消耗行动给面包车添加燃料的行动选项组件。
## 组件 id：add_van_fuel；类别：action（行动选项）。
## params：
## - block_name: String（默认 "面包车"）——添加地点地块名
## - card_name: String（默认 "燃料"）——弃置的燃料卡名
## - count: int（默认 0）——需求桶数；达到后置 van_fueled
## mission_state 键：
## - van_fuel: int——已添加燃料累计
## - van_fueled: bool——是否达到 count（state_flag 胜利条件读取）
## 一次行动将手牌与装备区中全部燃料弃置并累计；已满额后不再出现技能。

var _mission_config: MissionConfig = null
var _game: Game = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_game = game
	_mission_config = mission_config
	if not params.has("block_name"):
		params["block_name"] = "面包车"
	if not params.has("card_name"):
		params["card_name"] = "燃料"
	if not params.has("count"):
		params["count"] = 0
	if _mission_config == null:
		return
	if not _mission_config.mission_state.has("van_fuel"):
		_mission_config.mission_state["van_fuel"] = 0
	if not _mission_config.mission_state.has("van_fueled"):
		_mission_config.mission_state["van_fueled"] = false


func get_action_options(game: Game, player: Player) -> Array:
	if player == null or not is_instance_valid(player):
		return []
	if _mission_config == null:
		return []
	if _mission_config.mission_state.get("van_fueled", false) == true:
		return []
	if player.current_block == null or not is_instance_valid(player.current_block):
		return []
	if player.current_block.block_name != params.get("block_name", "面包车"):
		return []
	if player.get_effective_action_count() < 1:
		return []
	if _collect_cards(player).is_empty():
		return []
	return [{
		"id": "add_van_fuel",
		"label": "消耗 1 行动添加燃料",
		"execute": _do_add_fuel.bind(game, player),
	}]


func get_action_skill_decl() -> Variant:
	var decl: Dictionary = {}
	decl["skill_name"] = "添加燃料"
	decl["block_match"] = func(block: MapBlock) -> bool:
		return block != null and is_instance_valid(block) and block.block_name == params.get("block_name", "面包车")
	decl["filter"] = func(player: Player) -> bool:
		if player == null or not is_instance_valid(player):
			return false
		if _mission_config == null:
			return false
		if _mission_config.mission_state.get("van_fueled", false) == true:
			return false
		if player.get_effective_action_count() < 1:
			return false
		return not _collect_cards(player).is_empty()
	decl["execute"] = func(player: Player) -> void:
		await _do_add_fuel(_game, player)
	decl["confirm"] = func(player: Player) -> String:
		return "确定消耗 1 行动添加燃料？"
	decl["ai"] = _mission_action_ai()
	return decl


func ai_should_travel(player: Player) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var config: MissionConfig = _mission_config
	if config == null and Game != null and is_instance_valid(Game):
		config = Game.mission_config
	if config != null and config.mission_state.get("van_fueled", false) == true:
		return false
	return not _collect_cards(player).is_empty()


func _collect_cards(player: Player) -> Array:
	var card_name: String = params.get("card_name", "燃料")
	var cards: Array = []
	for e in player.equipment_zone:
		if e != null and is_instance_valid(e) and _matches_item_family(e.card_name, card_name):
			cards.append(e)
	for c in player.hand:
		if c != null and is_instance_valid(c) and _matches_item_family(c.card_name, card_name):
			cards.append(c)
	return cards


func _matches_item_family(card_name: String, item_name: String) -> bool:
	return card_name == item_name or card_name.begins_with(item_name + "（")


func _do_add_fuel(game: Game, player: Player) -> void:
	if game == null or not is_instance_valid(game):
		return
	if player == null or not is_instance_valid(player):
		return
	if _mission_config == null:
		return
	if _mission_config.mission_state.get("van_fueled", false) == true:
		return
	var to_discard: Array = _collect_cards(player)
	if to_discard.is_empty():
		return
	if not await player.consume_action_evented(1):
		return
	await player.discard(to_discard)
	var added: int = to_discard.size()
	var count: int = int(params.get("count", 0))
	var total: int = int(_mission_config.mission_state.get("van_fuel", 0)) + added
	_mission_config.mission_state["van_fuel"] = total
	if count > 0 and total >= count:
		_mission_config.mission_state["van_fueled"] = true
		game.log_message(LogColors.player(player.player_name) + " 给面包车加满了燃料！（" + str(total) + "/" + str(count) + "）")
	else:
		game.log_message(LogColors.player(player.player_name) + " 给面包车添加了燃料（" + str(total) + "/" + str(count) + "）")
