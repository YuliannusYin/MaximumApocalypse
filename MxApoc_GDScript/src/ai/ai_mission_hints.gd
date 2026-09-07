class_name AiMissionHints
extends RefCounted

## 从任务组件参数推导行进目标与应保留的物资族名。
## 不写死 13 个剧本：行动点用 ai_should_travel；物资读 params.card_name / items。
## 行进三层：可执行行动点 → 仍缺的采集拾荒格 → 胜利集结。


func needed_item_families(game: Variant = null) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for component in _all_components(game):
		_collect_item_names(component, names, seen)
	return names


func travel_destination_blocks(player: Variant, game: Variant = null) -> Array:
	var result: Array = []
	game = _resolve_game(game)
	if game == null:
		return result
	var config: Variant = game.get("mission_config")
	if config == null or not is_instance_valid(config):
		return result
	var seen: Dictionary = {}
	for component in config.action_components:
		if not _action_wants_travel(component, player):
			continue
		var params: Dictionary = component.params if "params" in component else {}
		var block_name: String = str(params.get("block_name", ""))
		if block_name != "":
			_append_named_blocks(game, block_name, result, seen)
		else:
			_append_marked_blocks(game, result, seen)
	if not result.is_empty():
		return result
	var gather: Array = gather_destination_blocks(player, game)
	if not gather.is_empty():
		return gather
	for component in config.win_condition_components:
		if component == null or not is_instance_valid(component):
			continue
		if component.has_method("check_win") and component.check_win(game):
			continue
		var params: Dictionary = component.params if "params" in component else {}
		var block_name: String = str(params.get("block_name", ""))
		if block_name == "":
			continue
		var card_name: String = str(params.get("card_name", ""))
		if card_name != "":
			if player == null or not is_instance_valid(player) or not player.has_method("has_equipment"):
				continue
			if not player.has_equipment(card_name):
				continue
		_append_named_blocks(game, block_name, result, seen)
	return result


func gather_destination_blocks(_player: Variant, game: Variant = null) -> Array:
	var result: Array = []
	game = _resolve_game(game)
	if game == null:
		return result
	var families: PackedStringArray = still_needed_gather_families(game)
	if families.is_empty():
		return result
	var best_colors: PackedStringArray = _best_gather_colors(game, families)
	if best_colors.is_empty():
		return result
	var seen: Dictionary = {}
	if game.get("map_area") == null:
		return result
	for block in game.map_area:
		if block == null or not is_instance_valid(block):
			continue
		if block.has_method("is_alive") and not block.is_alive():
			continue
		if _block_has_color(block, best_colors):
			_append_unique_block(block, result, seen)
	return result


func remaining_needed_count(family: String, game: Variant = null) -> int:
	return _remaining_needed(family, _resolve_game(game))


func still_needed_gather_families(game: Variant = null) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	game = _resolve_game(game)
	for family in _gather_family_requirements(game):
		if _remaining_needed(str(family), game) <= 0:
			continue
		if seen.has(family):
			continue
		seen[family] = true
		names.append(str(family))
	return names


func nearest_travel_block(player: Variant, game: Variant = null) -> Variant:
	if player == null or not is_instance_valid(player):
		return null
	var current: Variant = player.get_current_block() if player.has_method("get_current_block") else player.get("current_block")
	if current == null or not is_instance_valid(current):
		return null
	var best: Variant = null
	var best_d: int = 99
	for block in travel_destination_blocks(player, game):
		if block == null or not is_instance_valid(block):
			continue
		var d: int = path_distance(current, block)
		if d < best_d:
			best_d = d
			best = block
	return best


func nearest_objective_distance(player: Variant, game: Variant = null) -> int:
	if player == null or not is_instance_valid(player):
		return 99
	var current: Variant = player.get_current_block() if player.has_method("get_current_block") else player.get("current_block")
	if current == null or not is_instance_valid(current):
		return 99
	var dest: Variant = nearest_travel_block(player, game)
	if dest == null or not is_instance_valid(dest):
		return 99
	return path_distance(current, dest)


## 行进用图距离：沿邻格绕空洞 / 摧毁格。无邻接表时退回曼哈顿。
func path_distance(from_block: Variant, to_block: Variant) -> int:
	if from_block == null or to_block == null:
		return 99
	if not is_instance_valid(from_block) or not is_instance_valid(to_block):
		return 99
	if from_block.has_method("path_distance_to"):
		return int(from_block.path_distance_to(to_block))
	if from_block.has_method("distance_to"):
		return int(from_block.distance_to(to_block))
	return 99


func is_needed_card(card: Variant, game: Variant = null) -> bool:
	if card == null:
		return false
	var card_name: String = str(card.get("card_name"))
	for family in needed_item_families(game):
		if matches_item_family(card_name, family):
			return true
	return false


## 手牌或装备区持有尚未提交满额的任务物资（持有者应去交付，而不是继续采）。
func player_holds_needed_item(player: Variant, game: Variant = null) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	game = _resolve_game(game)
	for family in needed_item_families(game):
		var required: int = _required_count(str(family), game)
		if required <= 0:
			continue
		if _submitted_count(str(family), game) >= required:
			continue
		if _player_held_count(player, str(family)) > 0:
			return true
	return false


func pile_has_food(pile_key: String, game: Variant = null) -> bool:
	var color: String = _color_of_pile_key(pile_key)
	if color == "":
		return false
	game = _resolve_game(game)
	if game == null or not game.has_method("get_scavenge_pile"):
		return false
	var pile: Variant = game.get_scavenge_pile(color)
	if pile == null or not is_instance_valid(pile) or pile.get("cards") == null:
		return false
	for card in pile.cards:
		if card == null:
			continue
		if matches_item_family(str(card.get("card_name")), "食物"):
			return true
	return false


func matches_item_family(card_name: String, item_name: String) -> bool:
	return card_name == item_name or card_name.begins_with(item_name + "（")


func is_staying_to_gather(player: Variant, game: Variant = null) -> bool:
	if nearest_objective_distance(player, game) != 0:
		return false
	return current_block_has_needed_scavenge(player, game)


func current_block_has_needed_scavenge(player: Variant, game: Variant = null) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var current: Variant = player.get_current_block() if player.has_method("get_current_block") else player.get("current_block")
	return block_has_needed_scavenge(current, game)


func block_has_needed_scavenge(block: Variant, game: Variant = null) -> bool:
	if block == null or not is_instance_valid(block):
		return false
	game = _resolve_game(game)
	var families: PackedStringArray = still_needed_gather_families(game)
	if families.is_empty():
		return false
	var colors: PackedStringArray = _block_colors(block)
	for color in colors:
		if _pile_needed_count(game, str(color), families) > 0:
			return true
	return false


func pile_has_needed_items(pile_key: String, game: Variant = null) -> bool:
	var color: String = _color_of_pile_key(pile_key)
	if color == "":
		return false
	game = _resolve_game(game)
	var families: PackedStringArray = still_needed_gather_families(game)
	if families.is_empty():
		return false
	return _pile_needed_count(game, color, families) > 0


func _all_components(game: Variant) -> Array:
	var result: Array = []
	if game == null or not is_instance_valid(game):
		game = Game
	if game == null or not is_instance_valid(game):
		return result
	var config: Variant = game.get("mission_config")
	if config == null or not is_instance_valid(config):
		return result
	result.append_array(config.win_condition_components)
	result.append_array(config.lose_condition_components)
	result.append_array(config.trigger_components)
	result.append_array(config.action_components)
	return result


func _collect_item_names(component: Variant, names: PackedStringArray, seen: Dictionary) -> void:
	if component == null:
		return
	var params: Dictionary = component.params if "params" in component else {}
	var card_name: String = str(params.get("card_name", ""))
	if card_name != "" and not seen.has(card_name):
		seen[card_name] = true
		names.append(card_name)
	var items: Variant = params.get("items", {})
	if items is Dictionary:
		for key in items.keys():
			var family: String = str(key)
			if family != "" and not seen.has(family):
				seen[family] = true
				names.append(family)


func _gather_family_requirements(game: Variant) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	if game == null or not is_instance_valid(game):
		return names
	var config: Variant = game.get("mission_config")
	if config == null or not is_instance_valid(config):
		return names
	var components: Array = []
	components.append_array(config.action_components)
	components.append_array(config.win_condition_components)
	for component in components:
		if component == null:
			continue
		var params: Dictionary = component.params if "params" in component else {}
		var items: Variant = params.get("items", {})
		if items is Dictionary:
			for key in items.keys():
				if int(items[key]) <= 0:
					continue
				var family: String = str(key)
				if family != "" and not seen.has(family):
					seen[family] = true
					names.append(family)
		var card_name: String = str(params.get("card_name", ""))
		if card_name != "" and int(params.get("count", 0)) > 0 and not seen.has(card_name):
			seen[card_name] = true
			names.append(card_name)
	return names


func _required_count(family: String, game: Variant) -> int:
	var required: int = 0
	if game == null or not is_instance_valid(game):
		return 0
	var config: Variant = game.get("mission_config")
	if config == null or not is_instance_valid(config):
		return 0
	var components: Array = []
	components.append_array(config.action_components)
	components.append_array(config.win_condition_components)
	for component in components:
		if component == null:
			continue
		var params: Dictionary = component.params if "params" in component else {}
		var items: Variant = params.get("items", {})
		if items is Dictionary:
			for key in items.keys():
				if matches_item_family(str(key), family) or matches_item_family(family, str(key)):
					required = maxi(required, int(items[key]))
		var card_name: String = str(params.get("card_name", ""))
		if card_name != "" and matches_item_family(card_name, family):
			required = maxi(required, int(params.get("count", 0)))
	return required


func _submitted_count(family: String, game: Variant) -> int:
	if game == null or not is_instance_valid(game):
		return 0
	var config: Variant = game.get("mission_config")
	if config == null or not is_instance_valid(config):
		return 0
	var state: Dictionary = config.mission_state if "mission_state" in config else {}
	if state.get("van_fueled", false) == true:
		for component in config.action_components:
			if component == null:
				continue
			var params: Dictionary = component.params if "params" in component else {}
			if matches_item_family(str(params.get("card_name", "")), family) and int(params.get("count", 0)) > 0:
				return _required_count(family, game)
	var van_fuel: int = int(state.get("van_fuel", 0))
	if van_fuel > 0:
		for component in config.action_components:
			if component == null:
				continue
			var params: Dictionary = component.params if "params" in component else {}
			if matches_item_family(str(params.get("card_name", "")), family) and int(params.get("count", 0)) > 0:
				return van_fuel
	var submitted: Variant = state.get("submitted_items", {})
	if submitted is Dictionary:
		var total: int = 0
		for key in submitted.keys():
			if matches_item_family(str(key), family) or matches_item_family(family, str(key)):
				total += int(submitted[key])
		return total
	return 0


func _party_held_count(family: String, game: Variant) -> int:
	var total: int = 0
	if game == null or not is_instance_valid(game):
		return 0
	var players: Array = game.get_alive_players() if game.has_method("get_alive_players") else game.get("players")
	if not (players is Array):
		return 0
	for player in players:
		total += _player_held_count(player, family)
	return total


func _player_held_count(player: Variant, family: String) -> int:
	if player == null or not is_instance_valid(player):
		return 0
	var n: int = 0
	if player.get("hand") != null:
		for card in player.hand:
			if card != null and matches_item_family(str(card.get("card_name")), family):
				n += 1
	if player.get("equipment_zone") != null:
		for card in player.equipment_zone:
			if card != null and matches_item_family(str(card.get("card_name")), family):
				n += 1
	return n


func _remaining_needed(family: String, game: Variant) -> int:
	var required: int = _required_count(family, game)
	if required <= 0:
		return 0
	return maxi(0, required - _submitted_count(family, game) - _party_held_count(family, game))


func _best_gather_colors(game: Variant, families: PackedStringArray) -> PackedStringArray:
	var best: PackedStringArray = PackedStringArray()
	var best_n: int = 0
	for color in ["red", "green", "blue"]:
		var n: int = _pile_needed_count(game, color, families)
		if n > best_n:
			best_n = n
			best = PackedStringArray([color])
		elif n > 0 and n == best_n:
			best.append(color)
	return best


func _pile_needed_count(game: Variant, color: String, families: PackedStringArray) -> int:
	if game == null or not game.has_method("get_scavenge_pile"):
		return 0
	var pile: Variant = game.get_scavenge_pile(color)
	if pile == null or not is_instance_valid(pile) or pile.get("cards") == null:
		return 0
	var n: int = 0
	for card in pile.cards:
		if card == null:
			continue
		var card_name: String = str(card.get("card_name"))
		for family in families:
			if matches_item_family(card_name, str(family)):
				n += 1
				break
	return n


func _block_colors(block: Variant) -> PackedStringArray:
	if block == null:
		return PackedStringArray()
	var raw: Variant = block.get("scavenge_colors")
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		var out: PackedStringArray = PackedStringArray()
		for c in raw:
			out.append(str(c))
		return out
	return PackedStringArray()


func _block_has_color(block: Variant, colors: PackedStringArray) -> bool:
	var have: PackedStringArray = _block_colors(block)
	for color in colors:
		if have.has(color):
			return true
	return false


func _color_of_pile_key(pile_key: String) -> String:
	match pile_key:
		"red_scavenge":
			return "red"
		"green_scavenge":
			return "green"
		"blue_scavenge":
			return "blue"
		_:
			return ""


func _resolve_game(game: Variant) -> Variant:
	if game == null or not is_instance_valid(game):
		game = Game
	if game == null or not is_instance_valid(game):
		return null
	return game


func _action_wants_travel(component: Variant, player: Variant) -> bool:
	if component == null or not is_instance_valid(component):
		return false
	if not component.has_method("ai_should_travel"):
		return false
	return component.ai_should_travel(player)


func _append_named_blocks(game: Variant, block_name: String, result: Array, seen: Dictionary) -> void:
	if game == null or not game.has_method("get_blocks_by_name"):
		return
	for block in game.get_blocks_by_name(block_name):
		_append_unique_block(block, result, seen)


func _append_marked_blocks(game: Variant, result: Array, seen: Dictionary) -> void:
	if game == null or game.get("map_area") == null:
		return
	for block in game.map_area:
		if block == null or not is_instance_valid(block):
			continue
		if block.has_method("is_alive") and not block.is_alive():
			continue
		if block.has_method("has_objective_mark") and block.has_objective_mark():
			_append_unique_block(block, result, seen)


func _append_unique_block(block: Variant, result: Array, seen: Dictionary) -> void:
	if block == null or not is_instance_valid(block):
		return
	var key: int = block.get_instance_id()
	if seen.has(key):
		return
	seen[key] = true
	result.append(block)
