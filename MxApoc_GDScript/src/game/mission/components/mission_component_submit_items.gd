class_name MissionComponentSubmitItems
extends MissionComponent

## 消耗行动提交物资的行动选项组件。
## 组件 id：submit_items；类别：action（行动选项）。
## params：
## - block_name: String——提交地点地块名
## - items: Dictionary{卡名: 数量}——可提交的物资清单（值为任务要求数量，仅键名参与提交判定）
## mission_state 键：
## - submitted_items: Dictionary{卡名: 已提交数量}——累计提交进度（本组件写入，
##   collect_items 的 submit 模式等胜利条件组件读取判定）
## 行动选项仅在玩家位于提交地点、行动数充足且手牌/装备区存在清单内物资时出现；
## 执行后扣减 1 行动，将玩家当前持有的清单内物资全部弃置（每种卡名提交全部持有量）
## 并累计入 submitted_items。装备区中的物资经 discard 的装备分支卸下并弃置。
## 服务任务 10。

## 任务配置引用。setup 时注入，用于读写 mission_state。
var _mission_config: MissionConfig = null

## 游戏实例引用。setup 时注入，供行动技能执行体调用 _do_submit。
var _game: Game = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_game = game
	_mission_config = mission_config


func get_action_options(game: Game, player: Player) -> Array:
	if player == null or not is_instance_valid(player):
		return []
	if _mission_config == null:
		return []
	if player.current_block == null or not is_instance_valid(player.current_block):
		return []
	if player.current_block.block_name != params.get("block_name", ""):
		return []
	if player.get_effective_action_count() < 1:
		return []
	var items: Dictionary = params.get("items", {})
	if items.is_empty():
		return []
	for card_name in items:
		if not _collect_cards(player, card_name).is_empty():
			return [{
				"id": "submit_items",
				"label": "消耗 1 行动提交物资",
				"execute": _do_submit.bind(game, player),
			}]
	return []


## 行动技能声明：进入提交地点时挂载为主动技能（active="action"），
## filter 实时检查行动数与可提交物资（与 get_action_options 条件一致，不含地块匹配项）。
func get_action_skill_decl() -> Variant:
	var decl: Dictionary = {}
	decl["skill_name"] = "提交物资"
	decl["block_match"] = func(block: MapBlock) -> bool:
		return block != null and is_instance_valid(block) and block.block_name == params.get("block_name", "")
	decl["filter"] = func(player: Player) -> bool:
		if player == null or not is_instance_valid(player):
			return false
		if _mission_config == null:
			return false
		if player.get_effective_action_count() < 1:
			return false
		var items: Dictionary = params.get("items", {})
		if items.is_empty():
			return false
		for card_name in items:
			if not _collect_cards(player, card_name).is_empty():
				return true
		return false
	decl["execute"] = func(player: Player) -> void:
		await _do_submit(_game, player)
	decl["confirm"] = func(player: Player) -> String:
		return "确定消耗 1 行动提交物资？"
	return decl


## 收集玩家手牌与装备区中指定卡名的全部卡。
## 装备区实体在前、手牌在后：discard 按名解析优先命中装备区，
## 先弃置装备可避免手牌被误解析为装备区同名实体。
## 物品族匹配：清单通用名（如 "医疗用品"）同时收集变体卡（"医疗用品（便携）" 等），
## 与 collect_items 的族等价计数、Game._find_scavenge_card_variants 的建堆语义一致。
func _collect_cards(player: Player, card_name: String) -> Array:
	var cards: Array = []
	for e in player.equipment_zone:
		if e != null and is_instance_valid(e) and _matches_item_family(e.card_name, card_name):
			cards.append(e)
	for c in player.hand:
		if c != null and is_instance_valid(c) and _matches_item_family(c.card_name, card_name):
			cards.append(c)
	return cards


## 卡名是否属于物品族：精确匹配或变体前缀（"医疗用品" 匹配 "医疗用品（便携）"）。
func _matches_item_family(card_name: String, item_name: String) -> bool:
	return card_name == item_name or card_name.begins_with(item_name + "（")


## 提交执行（协程）：扣减 1 行动，逐卡名弃置全部持有物资并累计提交进度。
func _do_submit(game: Game, player: Player) -> void:
	if game == null or not is_instance_valid(game):
		return
	if player == null or not is_instance_valid(player):
		return
	if _mission_config == null:
		return
	var items: Dictionary = params.get("items", {})
	if items.is_empty():
		return
	# 先收集全部可提交批次，无可提交物资时不消耗行动
	var batches: Dictionary = {}
	for card_name in items:
		var to_discard: Array = _collect_cards(player, card_name)
		if not to_discard.is_empty():
			batches[card_name] = to_discard
	if batches.is_empty():
		return
	if not await player.consume_action_evented(1):
		return
	var submitted: Dictionary = _mission_config.mission_state.get("submitted_items", {}).duplicate()
	var parts: Array = []
	for card_name in batches:
		await player.discard(batches[card_name])
		submitted[card_name] = int(submitted.get(card_name, 0)) + batches[card_name].size()
		parts.append(LogColors.card(card_name) + "×" + str(batches[card_name].size()))
	_mission_config.mission_state["submitted_items"] = submitted
	game.log_message(LogColors.player(player.player_name) + " 提交了物资：" + "、".join(parts))
