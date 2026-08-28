class_name MissionComponentSetupEquipCard
extends MissionComponent

## 开局装备拾荒卡触发器组件。
## 组件 id：setup_equip_card；类别：trigger（触发器）。
## params：
## - card_name: String——开局装备到第一名玩家面前的拾荒卡名（如 "科学家"）
## 说明：任务开始 setup 时，若玩家列表非空，取第一个存活玩家（players[0]），
## 生成指定拾荒卡并装备到其装备区。equip 为协程，此处 fire-and-forget 直接调用
## 不 await（GDScript 4 直接调用即开始执行，装备流程后续节点自行推进）；
## 拾荒卡不存在时不装备。服务任务 3 / 任务 9（科学家初始装备）。

func setup(game: Game, mission_config: MissionConfig) -> void:
	if game == null or not is_instance_valid(game):
		return
	if game.players.is_empty():
		return
	var player: Variant = game.players[0]
	if player == null or not is_instance_valid(player) or not player.is_alive():
		return
	var card: Card = game.create_scavenge_card(params.get("card_name", ""))
	if card == null:
		return
	game.log_message(LogColors.player(player.player_name) + " 开局装备了 " + LogColors.card(card.card_name))
	player.equip(card)
