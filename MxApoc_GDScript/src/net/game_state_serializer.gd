class_name GameStateSerializer
extends RefCounted

## 将房主运行时状态转换为可传输快照。
## 这是合作视图版本：所有玩家手牌都包含在快照中。

static func snapshot(game: Variant) -> Dictionary:
	if game == null:
		return {}
	var result := {
		"match_id": NetSession.registry.match_id if NetSession != null else "",
		"server_sequence": NetSession.registry.server_sequence if NetSession != null else 0,
		"mission_id": _mission_id(game.current_mission),
		"players": [],
		"map": [],
		"piles": _serialize_piles(game),
		"state_machine": _serialize_state_machine(game.state_machine),
		"mission_state": _serialize_mission(game.mission_config),
	}
	for player in game.players:
		result.players.append(_serialize_player(player))
	for block in game.map_area:
		result.map.append(_serialize_block(block))
	return result

static func _serialize_player(player: Variant) -> Dictionary:
	if player == null:
		return {}
	var hand: Array = []
	if "hand" in player:
		for card in player.hand:
			hand.append(_serialize_card(card))
	var equipment: Array = []
	if "equipment_zone" in player:
		for item in player.equipment_zone:
			var card: Variant = item
			if item is Equipment and item.equipment_card != null:
				card = item.equipment_card
			equipment.append(_serialize_card(card))
	return {
		"seat_number": int(player.seat_number),
		"player_name": str(player.player_name),
		"hp": int(player.hp),
		"max_hp": int(player.max_hp),
		"hunger": int(player.hunger),
		"in_phase": str(player.in_phase) if "in_phase" in player else "idle",
		"action_count": int(player.get_action_count())
			if player.has_method("get_action_count") else int(player.action_count),
		"max_action_count": int(player.max_action_count),
		"is_ai": bool(player.is_ai),
		"alive": bool(player.is_alive()) if player.has_method("is_alive") else true,
		"current_block": _block_id(player.current_block),
		"hand": hand,
		"equipment": equipment,
		"monsters": _serialize_array(player.monster_zone if "monster_zone" in player else []),
	}

static func _serialize_block(block: Variant) -> Dictionary:
	if block == null:
		return {}
	var coordinate: Dictionary = block.coordinate if "coordinate" in block else {}
	return {
		"block_name": str(block.block_name),
		"x": int(coordinate.get("x", 0)),
		"y": int(coordinate.get("y", 0)),
		"state": str(block.block_state),
		"revealed": bool(block.revealed),
		"monster_marks": int(block.monster_marks),
		"objective_marks": _serialize_array(block.objective_marks),
	}

static func _serialize_card(card: Variant) -> Dictionary:
	if card == null:
		return {}
	var result := {
		"english_name": _string_property(card, "english_name"),
		"card_name": _string_property(card, "card_name"),
		"card_type": _string_property(card, "card_type"),
		"source": _string_property(card, "source"),
	}
	for property_name in ["card_subtype", "size", "range", "color", "charge_type",
			"charge_max", "charge_current", "weapon"]:
		var value: Variant = card.get(property_name) if card.has_method("get") else null
		if value != null:
			result[property_name] = value
	return result

static func _serialize_array(items: Array) -> Array:
	var result: Array = []
	for item in items:
		if item is Dictionary:
			result.append(item.duplicate(true))
		elif item != null:
			var row: Dictionary = {}
			if item.has_method("get"):
				row["english_name"] = _string_property(item, "english_name")
				row["card_name"] = _string_property(item, "card_name")
				row["monster_type"] = _string_property(item, "monster_type")
				row["monster_level"] = _string_property(item, "monster_level")
				row["hp"] = int(item.get("hp")) if item.get("hp") != null else 0
				row["max_hp"] = int(item.get("max_hp")) if item.get("max_hp") != null else 0
			result.append(row)
	return result

static func _serialize_piles(game: Variant) -> Dictionary:
	return {
		"monster": _pile_size(game.monster_pile),
		"monster_discard": _pile_size(game.monster_discard_pile),
		"red": _pile_size(game.red_scavenge_pile),
		"green": _pile_size(game.green_scavenge_pile),
		"blue": _pile_size(game.blue_scavenge_pile),
		"scavenge_discard": _pile_size(game.scavenge_discard_pile),
	}

static func _pile_size(pile: Variant) -> int:
	return pile.cards.size() if pile != null and "cards" in pile else 0

static func _serialize_state_machine(machine: Variant) -> Dictionary:
	if machine == null:
		return {}
	var current_player: Variant = machine.current_player \
		if "current_player" in machine else null
	return {
		"state": int(machine.current_state) if "current_state" in machine else 0,
		"current_player_seat": int(current_player.seat_number)
			if current_player != null and "seat_number" in current_player else -1,
		"turn_number": int(machine.turn_number) if "turn_number" in machine else 0,
		"game_result": int(machine.game_result) if "game_result" in machine else -1,
	}

static func _serialize_mission(config: Variant) -> Dictionary:
	if config == null:
		return {}
	return {"mission_state": config.mission_state.duplicate(true) if "mission_state" in config else {}}

static func _mission_id(mission: Variant) -> int:
	return int(mission.mission_id) if mission != null and "mission_id" in mission else -1

static func _block_id(block: Variant) -> Dictionary:
	if block == null:
		return {}
	var coordinate: Dictionary = block.coordinate if "coordinate" in block else {}
	return {"x": int(coordinate.get("x", 0)), "y": int(coordinate.get("y", 0))}

static func _string_property(value: Variant, property_name: String) -> String:
	if value == null or not value.has_method("get"):
		return ""
	var property_value: Variant = value.get(property_name)
	return "" if property_value == null else str(property_value)
