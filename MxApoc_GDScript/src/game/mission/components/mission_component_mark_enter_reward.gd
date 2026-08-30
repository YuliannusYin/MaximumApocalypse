class_name MissionComponentMarkEnterReward
extends MissionComponent

## 任务标记抵达奖励触发器组件。
## 组件 id：mark_enter_reward；类别：trigger（触发器）。
## params：
## - rewards: Dictionary{mark_id: {cards: Dictionary{卡牌名: 数量}, draw_boss: bool}}——
##   按目标标记 id 声明抵达奖励，如 {"mark_1": {"cards": {"燃料": 2}, "draw_boss": true}}
## 说明：玩家抵达带目标标记的地块、objective_mark_triggered 事件触发时，
## 按 mark.get("mark_id") 匹配 rewards 发放奖励：
## - cards：逐张生成拾荒卡（game.create_scavenge_card）进入玩家手牌（player.gain，
##   与引擎摸牌入手机行为一致，手牌满时经 try_add_card_to_hand 弹窗弃牌腾位）；
##   卡牌不存在时跳过该张并记录日志。
## - draw_boss：玩家额外抓取一张首领卡（player.draw_boss_card）。
## 同一标记由引擎 trigger_objective_marks 保证仅触发一次，组件无需去重。
## 服务任务 5（日记本 + 首领）/ 任务 10（三种不同奖励标记）。

func on_event(game: Game, event_name: String, event: Dictionary) -> void:
	if event_name != "objective_mark_triggered":
		return
	if game == null or not is_instance_valid(game):
		return
	var rewards: Dictionary = params.get("rewards", {})
	if rewards.is_empty():
		return
	var player: Variant = event.get("player")
	if player == null or not is_instance_valid(player):
		return
	var mark: Variant = event.get("mark")
	if mark == null or not (mark is Dictionary):
		return
	var mark_id: String = str(mark.get("mark_id", ""))
	if not rewards.has(mark_id):
		return
	var reward: Dictionary = rewards[mark_id]
	# 1. 卡牌奖励：逐张生成拾荒卡进入玩家手牌
	var cards: Dictionary = reward.get("cards", {})
	var gained_names: Array = []
	for card_name in cards:
		var count: int = int(cards[card_name])
		for i in count:
			var card: Card = game.create_scavenge_card(card_name)
			if card == null:
				game.log_message("未找到奖励拾荒卡：" + LogColors.card(card_name) + "，跳过")
				continue
			await player.gain(card)
			gained_names.append(card_name)
	# 2. 首领奖励：抓取一张首领卡
	var draw_boss: bool = reward.get("draw_boss", false) == true
	# 3. 记录奖励内容日志
	var reward_text: String = ""
	if not gained_names.is_empty():
		var card_counts: Dictionary = {}
		for card_name in gained_names:
			card_counts[card_name] = card_counts.get(card_name, 0) + 1
		var parts: Array = []
		for card_name in card_counts:
			parts.append(LogColors.card(card_name) + " ×" + str(card_counts[card_name]))
		reward_text += "获得 " + "、".join(parts)
	if draw_boss:
		if reward_text != "":
			reward_text += "，并"
		reward_text += "抓取一张首领牌"
	if reward_text != "":
		game.log_message(LogColors.player(player.player_name) + " 触发任务标记奖励：" + reward_text)
	if draw_boss:
		player.draw_boss_card()
