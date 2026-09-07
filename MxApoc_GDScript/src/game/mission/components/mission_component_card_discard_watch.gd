class_name MissionComponentCardDiscardWatch
extends MissionComponent

## 指定卡被弃置/持有者死亡监视触发器组件。
## 组件 id：card_discard_watch；类别：trigger（触发器，兼失败条件）。
## params：
## - card_name: String——监视的卡牌名（如 "科学家"）
## - on_discard: String——弃置时的处理模式："destroy"（销毁，移出游戏）/"lose"（任务失败）
## - on_death: String——持有指定卡的玩家死亡时的处理模式："lose"（任务失败）
## mission_state 键：
## - card_discard_failed: bool——on_discard 为 "lose" 时置 true
## - card_death_failed: bool——on_death 为 "lose" 且持有者死亡时置 true
## 说明：card_discarded 事件命中监视卡名时按模式处理：
## - "destroy"：将卡从其所在弃牌堆移除并调用 game.remove_card 移出游戏
##   （card_discarded 事件发出时卡已被 player.discard 放入弃牌堆，需先移出再销毁）；
## - "lose"：置 card_discard_failed = true，后续 check_lose 判定任务失败。
## player_died 事件中，若死亡玩家持有指定卡，则按 on_death 处理。

## 任务配置引用。setup 时注入，用于读写 mission_state。
var _mission_config: MissionConfig = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_mission_config = mission_config


func on_event(game: Game, event_name: String, event: Dictionary) -> void:
	if event_name == "player_died":
		_handle_player_death(game, event)
		return
	if event_name != "card_discarded":
		return
	if game == null or not is_instance_valid(game):
		return
	var card: Variant = event.get("card")
	if card == null or not is_instance_valid(card):
		return
	if card.card_name != params.get("card_name", ""):
		return
	var player: Variant = event.get("player")
	match params.get("on_discard", "destroy"):
		"destroy":
			_remove_from_discard_pile(game, player, card)
			game.remove_card(card, true)
			game.log_message(LogColors.card(card.card_name) + " 被弃置并销毁")
		"lose":
			if _mission_config != null:
				_mission_config.mission_state["card_discard_failed"] = true
			game.log_message("警告：" + LogColors.card(card.card_name) + " 被弃置，任务失败！")


func check_lose(game: Game) -> bool:
	if _mission_config == null:
		return false
	return _mission_config.mission_state.get("card_discard_failed", false) == true \
		or _mission_config.mission_state.get("card_death_failed", false) == true


func _handle_player_death(game: Game, event: Dictionary) -> void:
	if params.get("on_death", "") != "lose":
		return
	var player: Variant = event.get("player")
	if player == null or not is_instance_valid(player):
		return
	var card_name: String = params.get("card_name", "")
	if not player.has_method("has_item") or not player.has_item(card_name):
		return
	if _mission_config != null:
		_mission_config.mission_state["card_death_failed"] = true
	if game != null and is_instance_valid(game):
		game.log_message("警告：" + LogColors.player(player.player_name) + " 死亡时携带" + LogColors.card(card_name) + "，任务失败！")


## 内部方法：将卡从其所在弃牌堆移除。
## 与 player.discard 的去向一致：source == "scavenge" 进全局拾荒弃牌堆，否则进玩家游戏弃牌堆。
func _remove_from_discard_pile(game: Game, player: Variant, card: Card) -> void:
	if card.source == "scavenge":
		if game.scavenge_discard_pile != null:
			game.scavenge_discard_pile.cards.erase(card)
	elif player != null and is_instance_valid(player) and player.game_discard_pile != null:
		player.game_discard_pile.cards.erase(card)
