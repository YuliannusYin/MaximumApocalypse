class_name MissionComponentCollectItems
extends MissionComponent

## 收集物品胜利条件组件。
## 组件 id：collect_items；类别：win_condition（胜利条件）。
## params：
## - items: Dictionary{卡牌名: 数量}——需要收集的物品及数量，如 {"燃料": 4, "弹药（少量）": 2}
## - mode: String（默认 "hold"）——判定模式：
##   - "hold"：全队随身携带计数（所有存活玩家的手牌 + 装备区）
##   - "submit"：判定 mission_state["submitted_items"]（Dictionary{卡牌名: int}）中
##     每种卡名的已提交计数 >= 要求数量，与玩家随身持有无关。
##     键名 "submitted_items" 由 submit_items 行动组件维护，本组件只读。
## 说明：引擎无面包车卡牌存储，"hold" 模式下"收集" = 全队随身携带，
## 每种卡名的持有总数达到要求数量即满足该项；全部满足才判定胜利。

## 任务配置引用。setup 时注入，submit 模式用于读取 mission_state。
var _mission_config: MissionConfig = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_mission_config = mission_config


func check_win(game: Game) -> bool:
	var items: Dictionary = params.get("items", {})
	if items.is_empty():
		return true
	if params.get("mode", "hold") == "submit":
		return _check_submit(items)
	if game == null or not is_instance_valid(game):
		return false
	var alive_players: Array = game.get_alive_players()
	for card_name in items:
		var required: int = int(items[card_name])
		var count: int = 0
		for player in alive_players:
			if player == null or not is_instance_valid(player):
				continue
			for card in player.hand:
				if card != null and is_instance_valid(card) and _matches_item_family(card.card_name, card_name):
					count += 1
			for card in player.equipment_zone:
				if card != null and is_instance_valid(card) and _matches_item_family(card.card_name, card_name):
					count += 1
		if count < required:
			return false
	return true


## 卡名是否属于物品族：精确匹配或变体前缀（"医疗用品" 匹配 "医疗用品（便携）"）。
## 任务 JSON 的 items 使用通用名，而拾荒牌堆中的实体卡为变体名
## （建堆时由 Game._find_scavenge_card_variants 按前缀展开），两者按族等价计数。
func _matches_item_family(card_name: String, item_name: String) -> bool:
	return card_name == item_name or card_name.begins_with(item_name + "（")


## submit 模式判定：mission_state["submitted_items"] 中每种卡名计数 >= 要求数量。
func _check_submit(items: Dictionary) -> bool:
	if _mission_config == null:
		return false
	var submitted: Dictionary = _mission_config.mission_state.get("submitted_items", {})
	for card_name in items:
		var required: int = int(items[card_name])
		if int(submitted.get(card_name, 0)) < required:
			return false
	return true
