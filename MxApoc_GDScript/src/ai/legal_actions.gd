class_name LegalActions
extends RefCounted

## 从规则层枚举行动阶段可选项。与 HUD 点选无关。


static func enumerate(player: Variant, allowed_types: Variant = null) -> Array:
	var actions: Array = []
	if player == null or not is_instance_valid(player):
		return actions
	if player.has_method("is_alive") and not player.is_alive():
		return actions
	if _is_type_allowed(player, "card", allowed_types):
		_append_cards(player, actions)
	if _is_type_allowed(player, "skill", allowed_types):
		_append_skills(player, actions)
	if _is_type_allowed(player, "move", allowed_types):
		_append_moves(player, actions)
	if _is_type_allowed(player, "pile_draw", allowed_types):
		_append_pile_draws(player, actions)
	return actions


static func _is_type_allowed(player: Variant, action_type: String, allowed_override: Variant) -> bool:
	if allowed_override is Array and not allowed_override.is_empty() and not allowed_override.has(action_type):
		return false
	if player != null and player.has_method("is_action_type_allowed"):
		return player.is_action_type_allowed(action_type)
	return true


static func _append_cards(player: Variant, actions: Array) -> void:
	if not player.has_method("is_card_usable"):
		return
	for card in player.hand:
		if card == null or not is_instance_valid(card) or not player.is_card_usable(card):
			continue
		if _should_skip_damage_action(player, _primary_play_skill(card)):
			continue
		if _should_skip_reveal_action(player, _primary_play_skill(card)):
			continue
		actions.append({"type": "card", "card": card})


static func _append_skills(player: Variant, actions: Array) -> void:
	if not player.has_method("can_use_active_skill"):
		return
	for skill in player.skills:
		if skill == null or not is_instance_valid(skill) or not player.can_use_active_skill(skill):
			continue
		if _should_skip_damage_action(player, skill):
			continue
		if _should_skip_reveal_action(player, skill):
			continue
		actions.append({"type": "skill", "skill": skill})


static func _append_moves(player: Variant, actions: Array) -> void:
	if player.get_effective_action_count() <= 0:
		return
	if player.monster_zone != null and player.monster_zone.size() > 0:
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
	var allowed: Dictionary = _allowed_scavenge_colors(player)
	for pair in [["red", "red_scavenge", Game.red_scavenge_pile], ["green", "green_scavenge", Game.green_scavenge_pile], ["blue", "blue_scavenge", Game.blue_scavenge_pile]]:
		if not allowed.has(pair[0]):
			continue
		var pile: Variant = pair[2]
		if pile != null and is_instance_valid(pile) and not pile.is_empty():
			actions.append({"type": "pile_draw", "pile_key": pair[1]})


static func _allowed_scavenge_colors(player: Variant) -> Dictionary:
	var allowed: Dictionary = {}
	var current: Variant = player.get_current_block() if player.has_method("get_current_block") else player.get("current_block")
	if current == null or not is_instance_valid(current):
		return allowed
	var raw: Variant = current.get("scavenge_colors")
	if raw is PackedStringArray or raw is Array:
		for color in raw:
			allowed[str(color)] = true
	return allowed


static func _should_skip_reveal_action(player: Variant, skill: Variant) -> bool:
	if skill == null or not _is_reveal_skill(skill):
		return false
	var current: Variant = player.get_current_block() if player != null and player.has_method("get_current_block") else null
	if current == null or not is_instance_valid(current):
		return true
	var range_str: String = str(skill.get("range")) if skill.get("range") != null else ""
	if range_str == "":
		range_str = "long"
	if current.has_method("has_unrevealed_block_in_range"):
		return not current.has_unrevealed_block_in_range(range_str)
	return true


static func _is_reveal_skill(skill: Variant) -> bool:
	if skill == null:
		return false
	var raw: Variant = skill.get("ai") if skill.get("ai") != null else {}
	if raw is Dictionary:
		var tags: Variant = raw.get("tags", [])
		if tags is Array and tags.has("reveal"):
			return true
	var english_name: String = str(skill.get("english_name"))
	return english_name == "binoculars"


static func _should_skip_damage_action(player: Variant, skill: Variant) -> bool:
	if skill == null or not _is_damage_skill(skill):
		return false
	if str(skill.get("target_type")) == "equipment":
		return not _has_monster_in_weapon_range(player, skill)
	if player == null or not player.has_method("get_skill_valid_targets"):
		return false
	for target in player.get_skill_valid_targets(skill):
		if not _is_player_like(target):
			return false
	return true


static func _has_monster_in_weapon_range(player: Variant, skill: Variant) -> bool:
	if player == null:
		return false
	if player.monster_zone != null and player.monster_zone.size() > 0:
		return true
	var range_str: String = str(skill.get("range")) if skill != null else ""
	if range_str == "":
		range_str = "long"
	var current: Variant = player.get_current_block() if player.has_method("get_current_block") else null
	if current == null or not is_instance_valid(current):
		return false
	if current.has_method("get_players"):
		for ally in current.get_players():
			if _ally_has_monster(ally, player):
				return true
	if current.has_method("get_players_in_range"):
		for ally in current.get_players_in_range(range_str):
			if _ally_has_monster(ally, player):
				return true
	return false


static func _ally_has_monster(ally: Variant, self_player: Variant) -> bool:
	if ally == null or ally == self_player:
		return false
	if ally.get("monster_zone") == null:
		return false
	return ally.monster_zone.size() > 0


static func _is_damage_skill(skill: Variant) -> bool:
	var raw: Variant = skill.get("ai") if skill.get("ai") != null else {}
	if not (raw is Dictionary):
		return false
	var tags: Variant = raw.get("tags", [])
	if tags is Array and tags.has("damage"):
		return true
	if tags is Array and (tags.has("heal") or tags.has("food")):
		return false
	var effect_dict: Variant = raw.get("effect", {})
	return effect_dict is Dictionary and float(effect_dict.get("target", 0)) > 0.0 and tags is Array and tags.has("weapon")


static func _is_player_like(target: Variant) -> bool:
	return target != null and is_instance_valid(target) and target.has_method("is_player") and target.is_player()


static func _primary_play_skill(card: Variant) -> Variant:
	if card == null or not card.has_method("get_all_skills"):
		return null
	for skill in card.get_all_skills():
		if skill != null and str(skill.get("active")) == "action":
			return skill
	return null
