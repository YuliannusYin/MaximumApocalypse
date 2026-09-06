class_name AiMissionHints
extends RefCounted

## 从任务组件参数推导行进目标与应保留的物资族名。
## 不写死 13 个剧本：行动点用 ai_should_travel；物资读 params.card_name / items。


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


func nearest_travel_block(player: Variant, game: Variant = null) -> Variant:
	if player == null or not is_instance_valid(player):
		return null
	var current: Variant = player.get_current_block() if player.has_method("get_current_block") else player.get("current_block")
	if current == null or not is_instance_valid(current) or not current.has_method("distance_to"):
		return null
	var best: Variant = null
	var best_d: int = 99
	for block in travel_destination_blocks(player, game):
		if block == null or not is_instance_valid(block) or not current.has_method("distance_to"):
			continue
		var d: int = current.distance_to(block)
		if d < best_d:
			best_d = d
			best = block
	return best


func nearest_objective_distance(player: Variant, game: Variant = null) -> int:
	if player == null or not is_instance_valid(player):
		return 99
	var current: Variant = player.get_current_block() if player.has_method("get_current_block") else player.get("current_block")
	if current == null or not is_instance_valid(current) or not current.has_method("distance_to"):
		return 99
	var dest: Variant = nearest_travel_block(player, game)
	if dest == null or not is_instance_valid(dest):
		return 99
	return current.distance_to(dest)


func is_needed_card(card: Variant, game: Variant = null) -> bool:
	if card == null:
		return false
	var card_name: String = str(card.get("card_name"))
	for family in needed_item_families(game):
		if matches_item_family(card_name, family):
			return true
	return false


func matches_item_family(card_name: String, item_name: String) -> bool:
	return card_name == item_name or card_name.begins_with(item_name + "（")


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
