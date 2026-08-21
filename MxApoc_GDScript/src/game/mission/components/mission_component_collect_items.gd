class_name MissionComponentCollectItems
extends MissionComponent

## 收集物品胜利条件组件。
## 组件 id：collect_items；类别：win_condition（胜利条件）。
## params：
## - items: Dictionary{卡牌名: 数量}——需要收集的物品及数量，如 {"燃料": 4, "弹药（少量）": 2}
## 说明：引擎无面包车卡牌存储，"收集" = 全队随身携带（所有存活玩家的手牌 + 装备区），
## 每种卡名的持有总数达到要求数量即满足该项；全部满足才判定胜利。

func check_win(game: Game) -> bool:
	var items: Dictionary = params.get("items", {})
	if items.is_empty():
		return true
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
				if card != null and is_instance_valid(card) and card.card_name == card_name:
					count += 1
			for card in player.equipment_zone:
				if card != null and is_instance_valid(card) and card.card_name == card_name:
					count += 1
		if count < required:
			return false
	return true
