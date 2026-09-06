class_name LegalActions
extends RefCounted

## 从规则层枚举行动阶段可选项。与 HUD 点选无关。


static func enumerate(player: Variant) -> Array:
	var actions: Array = []
	if player == null or not is_instance_valid(player):
		return actions
	if player.has_method("is_alive") and not player.is_alive():
		return actions
	_append_cards(player, actions)
	_append_skills(player, actions)
	_append_moves(player, actions)
	_append_pile_draws(player, actions)
	return actions


static func _append_cards(player: Variant, actions: Array) -> void:
	if not player.has_method("is_card_usable"):
		return
	for card in player.hand:
		if card != null and is_instance_valid(card) and player.is_card_usable(card):
			actions.append({"type": "card", "card": card})


static func _append_skills(player: Variant, actions: Array) -> void:
	if not player.has_method("can_use_active_skill"):
		return
	for skill in player.skills:
		if skill != null and is_instance_valid(skill) and player.can_use_active_skill(skill):
			actions.append({"type": "skill", "skill": skill})


static func _append_moves(player: Variant, actions: Array) -> void:
	if player.get_effective_action_count() <= 0:
		return
	var current: Variant = player.get_current_block() if player.has_method("get_current_block") else null
	if current == null or not is_instance_valid(current) or not current.has_method("get_adjacent_blocks"):
		return
	for block in current.get_adjacent_blocks():
		if block != null and is_instance_valid(block):
			actions.append({"type": "move", "target": block})


static func _append_pile_draws(player: Variant, actions: Array) -> void:
	if player.get_effective_action_count() <= 0:
		return
	if Game == null or not is_instance_valid(Game):
		return
	if player.game_deck != null and is_instance_valid(player.game_deck) and not player.game_deck.is_empty():
		actions.append({"type": "pile_draw", "pile_key": "game_deck"})
	for pair in [["red_scavenge", Game.red_scavenge_pile], ["green_scavenge", Game.green_scavenge_pile], ["blue_scavenge", Game.blue_scavenge_pile]]:
		var pile: Variant = pair[1]
		if pile != null and is_instance_valid(pile) and not pile.is_empty():
			actions.append({"type": "pile_draw", "pile_key": pair[0]})
