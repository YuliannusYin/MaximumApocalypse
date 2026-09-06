class_name AiMissionHints
extends RefCounted

## 从任务组件参数推导目标地块与应保留的物资族名。
## 不写死 13 个剧本，只读 params.block_name / card_name / items。


func needed_item_families(game: Variant = null) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for component in _all_components(game):
		_collect_item_names(component, names, seen)
	return names


func objective_block_names(game: Variant = null) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for component in _all_components(game):
		if component == null:
			continue
		var params: Dictionary = component.params if "params" in component else {}
		var block_name: String = str(params.get("block_name", ""))
		if block_name != "" and not seen.has(block_name):
			seen[block_name] = true
			names.append(block_name)
	return names


func objective_blocks(game: Variant = null) -> Array:
	var result: Array = []
	if game == null or not is_instance_valid(game):
		game = Game
	if game == null or not is_instance_valid(game) or not game.has_method("get_blocks_by_name"):
		return result
	for block_name in objective_block_names(game):
		var blocks: Array = game.get_blocks_by_name(block_name)
		for block in blocks:
			if block != null and is_instance_valid(block):
				result.append(block)
	return result


func nearest_objective_distance(player: Variant, game: Variant = null) -> int:
	if player == null or not is_instance_valid(player):
		return 99
	var current: Variant = player.get_current_block() if player.has_method("get_current_block") else player.get("current_block")
	if current == null or not is_instance_valid(current):
		return 99
	var best: int = 99
	for block in objective_blocks(game):
		if not current.has_method("distance_to"):
			continue
		var d: int = current.distance_to(block)
		if d < best:
			best = d
	return best


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
