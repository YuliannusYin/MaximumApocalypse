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
	result.stats = _serialize_stats(game)
	return result


## 按 net_id 原位更新 game。ctx: Dictionary[int, Object]，调用方持有并跨快照复用。
static func apply(game: Variant, snapshot: Dictionary, ctx: Dictionary) -> void:
	if game == null or snapshot.is_empty():
		return
	_ensure_mission(game, snapshot)
	var previous_blocks: Dictionary = _current_blocks_by_player(game)
	var rebuilt_blocks: Dictionary = _apply_map(game, snapshot.get("map", []), ctx)
	for row in snapshot.get("players", []):
		if not row is Dictionary:
			continue
		var player: Variant = _ensure_player(game, row, ctx)
		if player == null:
			continue
		player.hp = int(row.get("hp", player.hp))
		player.max_hp = int(row.get("max_hp", player.max_hp))
		player.hunger = int(row.get("hunger", player.hunger))
		if row.has("in_phase"):
			player.in_phase = String(row.get("in_phase", player.in_phase))
		if row.has("action_count"):
			player.action_count = int(row.get("action_count", player.action_count))
		if row.has("max_action_count"):
			player.max_action_count = int(row.get("max_action_count", player.max_action_count))
		player.hand = _apply_card_list(player.hand if "hand" in player else [],
			row.get("hand", []), ctx, game)
		_apply_discard_pile(player, row.get("discard", null), ctx, game)
		_apply_equipment_zone(player, row.get("equipment", []), ctx, game)
		if row.has("game_deck"):
			player.game_deck = _resize_unrevealed_pile(player.game_deck, int(row.get("game_deck", 0)))
		player.monster_zone = _apply_monster_list(
			player.monster_zone if "monster_zone" in player else [],
			row.get("monsters", []), ctx, player)
		var block_id: Dictionary = row.get("current_block", {})
		if not block_id.is_empty() and game.has_method("get_block_by_coord"):
			player.current_block = game.get_block_by_coord(
				int(block_id.get("x", 0)), int(block_id.get("y", 0)))
		elif not block_id.is_empty():
			player.current_block = _block_at(game, int(block_id.get("x", 0)),
				int(block_id.get("y", 0)))
	if game.get("state_machine") != null:
		var machine: Variant = game.state_machine
		var state_data: Dictionary = snapshot.get("state_machine", {})
		if state_data.has("state"):
			machine.current_state = int(state_data.get("state", machine.current_state))
		if state_data.has("turn_number"):
			machine.turn_number = int(state_data.get("turn_number", machine.turn_number))
		if state_data.has("game_result"):
			machine.game_result = int(state_data.get("game_result", machine.game_result))
		var current_seat := int(state_data.get("current_player_seat", -1))
		machine.current_player = _player_by_seat(game, current_seat) \
			if current_seat >= 0 else null
		var last_seat := int(state_data.get("last_player_seat", -1))
		if last_seat >= 0 and "last_player" in machine:
			machine.last_player = _player_by_seat(game, last_seat)
		if int(machine.current_state) == GameStateMachine.GameState.GAME_OVER:
			game.game_over_called = true
			if int(machine.game_result) == GameStateMachine.GameResult.WIN:
				game.game_result = "win"
			elif int(machine.game_result) == GameStateMachine.GameResult.LOSE:
				game.game_result = "lose"
	_apply_unrevealed_piles(game, snapshot.get("piles", {}))
	_apply_scavenge_discard(game, snapshot.get("piles", {}), ctx)
	_apply_mission(game, snapshot)
	_apply_stats(game, snapshot)
	_sync_location_skills(game, previous_blocks, rebuilt_blocks)
	_prune_ctx(ctx, snapshot)


static func find_by_net_id(game: Variant, net_id: int) -> Variant:
	if game == null or net_id <= 0:
		return null
	for player in game.players:
		if player == null:
			continue
		if int(player.get("net_id")) == net_id:
			return player
		for card in player.hand if "hand" in player else []:
			if card != null and int(card.get("net_id")) == net_id:
				return card
		for equipment in player.equipment_zone if "equipment_zone" in player else []:
			if equipment != null and int(equipment.get("net_id")) == net_id:
				return equipment
			var source: Variant = equipment.get("equipment_card") \
				if equipment != null and equipment.has_method("get") else null
			if source != null and int(source.get("net_id")) == net_id:
				return source
		for monster in player.monster_zone if "monster_zone" in player else []:
			if monster != null and int(monster.get("net_id")) == net_id:
				return monster
		for pile in [player.get("game_deck") if player.has_method("get") else null,
				player.get("game_discard_pile") if player.has_method("get") else null]:
			if pile == null or not "cards" in pile:
				continue
			for card in pile.cards:
				if card != null and int(card.get("net_id")) == net_id:
					return card
	for block in game.map_area if "map_area" in game else []:
		if block != null and int(block.get("net_id")) == net_id:
			return block
	if game.get("scavenge_discard_pile") != null:
		var pile: Variant = game.scavenge_discard_pile
		if pile != null and "cards" in pile:
			for card in pile.cards:
				if card != null and int(card.get("net_id")) == net_id:
					return card
	return null


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
			equipment.append(_serialize_equipment(item))
	return {
		"net_id": _entity_net_id(player),
		"seat_number": int(player.seat_number),
		"player_name": str(player.player_name),
		"hp": int(player.hp),
		"max_hp": int(player.max_hp),
		"hunger": int(player.hunger),
		"in_phase": str(player.in_phase) if "in_phase" in player else "idle",
		"action_count": int(player.action_count) if "action_count" in player else 0,
		"max_action_count": int(player.max_action_count),
		"is_ai": bool(player.is_ai),
		"alive": bool(player.is_alive()) if player.has_method("is_alive") else true,
		"current_block": _block_id(player.current_block),
		"hand": hand,
		"equipment": equipment,
		"discard": _serialize_pile_cards(player.game_discard_pile if "game_discard_pile" in player else null),
		"game_deck": _pile_size(player.game_deck if "game_deck" in player else null),
		"monsters": _serialize_array(player.monster_zone if "monster_zone" in player else []),
	}


static func _serialize_stats(game: Variant) -> Dictionary:
	if game == null:
		return {}
	var tracker: Variant = game.get("stats_tracker")
	if tracker == null or not tracker.has_method("to_network_dict"):
		return {}
	var players: Array = game.players if "players" in game else []
	return tracker.to_network_dict(players)


static func _apply_stats(game: Variant, snapshot: Dictionary) -> void:
	if not snapshot.has("stats"):
		return
	var tracker: Variant = game.get("stats_tracker") if game != null else null
	if tracker == null or not tracker.has_method("apply_network_snapshot"):
		return
	var stats_data: Variant = snapshot.get("stats", {})
	if not (stats_data is Dictionary):
		return
	var players: Array = game.players if "players" in game else []
	tracker.apply_network_snapshot(players, stats_data)


static func _serialize_block(block: Variant) -> Dictionary:
	if block == null:
		return {}
	var coordinate: Dictionary = block.coordinate if "coordinate" in block else {}
	var scavenge_colors: Array = []
	if "scavenge_colors" in block:
		for color in block.scavenge_colors:
			scavenge_colors.append(str(color))
	return {
		"net_id": _entity_net_id(block),
		"block_name": str(block.block_name),
		"x": int(coordinate.get("x", 0)),
		"y": int(coordinate.get("y", 0)),
		"state": str(block.block_state),
		"revealed": bool(block.revealed),
		"monster_marks": int(block.monster_marks),
		"objective_marks": _serialize_array(block.objective_marks),
		"scavenge_colors": scavenge_colors,
		"monster_spawn_value": int(block.monster_spawn_value) if "monster_spawn_value" in block else 0,
	}

static func _serialize_card(card: Variant) -> Dictionary:
	if card == null:
		return {}
	var result := {
		"net_id": _entity_net_id(card),
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


static func _serialize_equipment(item: Variant) -> Dictionary:
	if item == null:
		return {}
	var card: Variant = item
	if item is Equipment and item.equipment_card != null:
		card = item.equipment_card
	var result := _serialize_card(card)
	if item is Equipment:
		result["net_id"] = _entity_net_id(item)
		if item.equipment_card != null:
			result["equipment_card"] = _serialize_card(item.equipment_card)
		for property_name in ["charge_current", "charge_max", "charge_type", "size",
				"range", "weapon"]:
			var value: Variant = item.get(property_name) if item.has_method("get") else null
			if value != null:
				result[property_name] = value
	return result

static func _serialize_array(items: Array) -> Array:
	var result: Array = []
	for item in items:
		if item is Dictionary:
			result.append(item.duplicate(true))
		elif item != null:
			var row: Dictionary = {
				"net_id": _entity_net_id(item),
			}
			if item.has_method("get"):
				row["english_name"] = _string_property(item, "english_name")
				var monster_name := _string_property(item, "monster_name")
				row["monster_name"] = monster_name
				row["card_name"] = _string_property(item, "card_name")
				if String(row["card_name"]) == "" and not monster_name.is_empty():
					row["card_name"] = monster_name
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
		"scavenge_discard_cards": _serialize_pile_cards(game.scavenge_discard_pile),
	}


static func _serialize_pile_cards(pile: Variant) -> Array:
	var result: Array = []
	if pile == null or not "cards" in pile:
		return result
	for card in pile.cards:
		result.append(_serialize_card(card))
	return result

static func _pile_size(pile: Variant) -> int:
	return pile.cards.size() if pile != null and "cards" in pile else 0

static func _serialize_state_machine(machine: Variant) -> Dictionary:
	if machine == null:
		return {}
	var current_player: Variant = machine.current_player \
		if "current_player" in machine else null
	var last_player: Variant = machine.last_player if "last_player" in machine else null
	return {
		"state": int(machine.current_state) if "current_state" in machine else 0,
		"current_player_seat": int(current_player.seat_number)
			if current_player != null and "seat_number" in current_player else -1,
		"last_player_seat": int(last_player.seat_number)
			if last_player != null and "seat_number" in last_player else -1,
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


static func _entity_net_id(value: Variant) -> int:
	if value == null or not value.has_method("get"):
		return 0
	var raw: Variant = value.get("net_id")
	return int(raw) if raw != null else 0


static func _stamp(entity: Variant, net_id: int, ctx: Dictionary) -> void:
	if entity == null or net_id <= 0:
		return
	entity.net_id = net_id
	ctx[net_id] = entity


static func _player_by_seat(game: Variant, seat_number: int) -> Variant:
	if game == null or seat_number < 0:
		return null
	for player in game.players:
		if player != null and int(player.seat_number) == seat_number:
			return player
	return null


static func _ensure_player(game: Variant, row: Dictionary, ctx: Dictionary) -> Variant:
	var net_id := int(row.get("net_id", 0))
	var seat_number := int(row.get("seat_number", -1))
	var player: Variant = ctx.get(net_id, null) if net_id > 0 else null
	if player == null:
		player = _player_by_seat(game, seat_number)
	if player == null:
		player = Player.new()
		player.seat_number = seat_number
		player.game_deck = Pile.new()
		player.game_discard_pile = Pile.new()
		_hydrate_view_player(game, player, row)
		if game.get("players") == null:
			game.players = []
		game.players.append(player)
	_stamp(player, net_id, ctx)
	return player


static func _hydrate_view_player(game: Variant, player: Variant, row: Dictionary) -> void:
	if player == null:
		return
	player.player_name = String(row.get("player_name", player.player_name))
	player.is_ai = bool(row.get("is_ai", player.is_ai))
	if game == null or not game.has_method("hydrate_view_player"):
		return
	var survivor: Variant = _survivor_for_seat(int(row.get("seat_number", -1)))
	if survivor != null:
		game.hydrate_view_player(player, survivor)


static func _survivor_for_seat(seat_number: int) -> Variant:
	if seat_number < 0:
		return null
	if RoomState != null and seat_number < RoomState.seats.size():
		var seat: Dictionary = RoomState.seats[seat_number]
		var survivor: Variant = seat.get("survivor", null)
		if survivor != null:
			return survivor
	if NetSession == null or seat_number >= NetSession.registry.seats.size():
		return null
	var survivor_id := String(NetSession.registry.seats[seat_number].get("survivor_id", ""))
	if survivor_id.is_empty() or DataManager == null:
		return null
	return DataManager.get_survivor(survivor_id)


static func _ensure_mission(game: Variant, snapshot: Dictionary) -> void:
	if game == null:
		return
	var mission_id := int(snapshot.get("mission_id", -1))
	if mission_id < 0:
		return
	if game.get("current_mission") != null and _mission_id(game.current_mission) == mission_id:
		return
	if DataManager == null:
		return
	var mission: Variant = DataManager.get_mission(mission_id)
	if mission == null:
		return
	game.current_mission = mission
	if game.get("mission_config") == null:
		game.mission_config = MissionConfig.new()
		game.mission_config.no_initial_monster_draw = mission.no_initial_monster_draw
		game.mission_config.mission_state = {}
		if game.has_method("_mount_mission_components"):
			game._mount_mission_components(mission)
		_setup_mission_components_for_world(game)


## 权威/客机本机 Game 全量 setup；房主 ViewGame 只 setup 行动组件，避免触发器吃权威 EventBus。
static func _setup_mission_components_for_world(game: Variant) -> void:
	if game == null:
		return
	var config: Variant = game.mission_config if "mission_config" in game else null
	if config == null:
		return
	if game == Game:
		if config.has_method("setup_components"):
			config.setup_components(game)
		return
	if config.has_method("setup_action_components"):
		config.setup_action_components(game)


static func _apply_unrevealed_piles(game: Variant, piles: Variant) -> void:
	if game == null or not piles is Dictionary:
		return
	var data: Dictionary = piles
	if data.has("monster"):
		game.monster_pile = _resize_unrevealed_pile(game.monster_pile, int(data.get("monster", 0)))
	if data.has("monster_discard"):
		game.monster_discard_pile = _resize_unrevealed_pile(
			game.monster_discard_pile, int(data.get("monster_discard", 0)))
	if data.has("red"):
		game.red_scavenge_pile = _resize_unrevealed_pile(game.red_scavenge_pile, int(data.get("red", 0)))
	if data.has("green"):
		game.green_scavenge_pile = _resize_unrevealed_pile(
			game.green_scavenge_pile, int(data.get("green", 0)))
	if data.has("blue"):
		game.blue_scavenge_pile = _resize_unrevealed_pile(game.blue_scavenge_pile, int(data.get("blue", 0)))


static func _resize_unrevealed_pile(pile: Variant, count: int) -> Variant:
	if count < 0:
		return pile
	if pile == null:
		pile = Pile.new()
	var cards: Array = pile.cards if "cards" in pile else []
	while cards.size() > count:
		cards.pop_back()
	while cards.size() < count:
		cards.append(Card.new())
	pile.cards = cards
	return pile


static func _block_at(game: Variant, x: int, y: int) -> Variant:
	if game == null:
		return null
	for block in game.map_area:
		if block == null:
			continue
		var coordinate: Dictionary = block.get("coordinate") if block.has_method("get") else {}
		if int(coordinate.get("x", 0)) == x and int(coordinate.get("y", 0)) == y:
			return block
	return null


static func _apply_map(game: Variant, raw_map: Variant, ctx: Dictionary) -> Dictionary:
	var rebuilt_blocks: Dictionary = {}
	if not raw_map is Array or raw_map.is_empty():
		return rebuilt_blocks
	var mirrored_map: Array = []
	for row in raw_map:
		if not row is Dictionary:
			continue
		var net_id := int(row.get("net_id", 0))
		var x := int(row.get("x", 0))
		var y := int(row.get("y", 0))
		var block_name := String(row.get("block_name", ""))
		var block: Variant = ctx.get(net_id, null) if net_id > 0 else null
		if block == null:
			block = _block_at(game, x, y)
		var created := false
		if block == null and game.has_method("_create_map_block"):
			block = game.call("_create_map_block", block_name)
			created = true
		if block == null:
			continue
		_stamp(block, net_id, ctx)
		if not created and _block_skills_stale(block, block_name):
			_detach_block_skills_from_players(game, block)
			_rebuild_block_skills(game, block, block_name)
			rebuilt_blocks[block] = true
		block.block_name = block_name if not block_name.is_empty() \
			else String(block.block_name)
		if block.has_method("set_coordinate"):
			block.set_coordinate(x, y)
		block.revealed = bool(row.get("revealed", block.revealed))
		if row.has("state"):
			block.block_state = String(row.get("state", block.block_state))
		block.monster_marks = int(row.get("monster_marks", block.monster_marks))
		if row.has("objective_marks"):
			block.objective_marks = row.get("objective_marks", block.objective_marks)
		if row.has("scavenge_colors"):
			var colors: Variant = row.get("scavenge_colors", [])
			if colors is PackedStringArray:
				block.scavenge_colors = colors
			elif colors is Array:
				block.scavenge_colors = PackedStringArray(colors)
		if row.has("monster_spawn_value"):
			block.monster_spawn_value = int(row.get("monster_spawn_value", block.monster_spawn_value))
		mirrored_map.append(block)
	if mirrored_map.is_empty():
		return rebuilt_blocks
	game.map_area = mirrored_map
	game.map_height = 0
	game.map_width = 0
	for block in mirrored_map:
		var coordinate: Dictionary = block.get("coordinate")
		game.map_width = maxi(int(game.map_width), int(coordinate.get("x", 0)) + 1)
		game.map_height = maxi(int(game.map_height), int(coordinate.get("y", 0)) + 1)
	return rebuilt_blocks


static func _apply_card_list(existing: Array, rows: Variant, ctx: Dictionary, game: Variant) -> Array:
	var result: Array = []
	if not rows is Array:
		return result
	var claimed: Dictionary = {}
	for row in rows:
		if not row is Dictionary:
			continue
		var card: Variant = _resolve_card(existing, row, ctx, game, claimed)
		if card == null:
			continue
		_copy_card_properties(card, row)
		result.append(card)
	return result


static func _resolve_card(existing: Array, row: Dictionary, ctx: Dictionary,
		game: Variant, claimed: Dictionary) -> Variant:
	var net_id := int(row.get("net_id", 0))
	var card: Variant = ctx.get(net_id, null) if net_id > 0 else null
	if card == null:
		card = _take_unused_by_name(existing, row, claimed)
	if card == null:
		card = NetInputCodec.create_card_from_payload({
			"id": String(row.get("english_name", "")),
			"english_name": String(row.get("english_name", "")),
			"card_name": String(row.get("card_name", "")),
			"card_type": String(row.get("card_type", "")),
			"source": String(row.get("source", "")),
			"net_id": net_id,
		}, game)
	if card == null:
		return null
	_stamp(card, net_id, ctx)
	if net_id > 0:
		claimed[net_id] = true
	return card


static func _take_unused_by_name(existing: Array, row: Dictionary, claimed: Dictionary) -> Variant:
	var english_name := String(row.get("english_name", ""))
	if english_name.is_empty():
		return null
	for item in existing:
		if item == null:
			continue
		var item_id := _entity_net_id(item)
		if item_id > 0 and claimed.has(item_id):
			continue
		if String(item.get("english_name")) != english_name:
			continue
		if item_id > 0:
			claimed[item_id] = true
		return item
	return null


static func _copy_card_properties(card: Variant, row: Dictionary) -> void:
	if card == null:
		return
	for property_name in ["card_subtype", "size", "range", "color", "charge_type",
			"charge_max", "charge_current", "weapon"]:
		if row.has(property_name) and card.has_method("set"):
			card.set(property_name, row[property_name])
	if row.has("english_name"):
		card.english_name = String(row.get("english_name", card.english_name))
	if row.has("card_name"):
		card.card_name = String(row.get("card_name", card.card_name))
	if row.has("card_type"):
		card.card_type = String(row.get("card_type", card.card_type))
	if row.has("source"):
		card.source = String(row.get("source", card.source))


static func _apply_discard_pile(player: Variant, raw_cards: Variant, ctx: Dictionary, game: Variant) -> void:
	if player == null or not raw_cards is Array:
		return
	if player.game_discard_pile == null:
		player.game_discard_pile = Pile.new()
	var existing: Array = player.game_discard_pile.cards if "cards" in player.game_discard_pile else []
	player.game_discard_pile.cards = _apply_card_list(existing, raw_cards, ctx, game)


static func _apply_scavenge_discard(game: Variant, piles: Variant, ctx: Dictionary) -> void:
	if not piles is Dictionary or not piles.has("scavenge_discard_cards"):
		return
	if game.scavenge_discard_pile == null:
		game.scavenge_discard_pile = Pile.new()
	var existing: Array = game.scavenge_discard_pile.cards \
		if "cards" in game.scavenge_discard_pile else []
	game.scavenge_discard_pile.cards = _apply_card_list(
		existing, piles.get("scavenge_discard_cards", []), ctx, game)


static func _apply_equipment_zone(player: Variant, rows: Variant, ctx: Dictionary, game: Variant) -> void:
	if player == null:
		return
	var previous: Array = player.equipment_zone.duplicate() if "equipment_zone" in player else []
	var previous_set: Dictionary = {}
	for item in previous:
		if item != null:
			previous_set[item] = true
	var new_zone: Array = []
	if rows is Array:
		for row in rows:
			if not row is Dictionary:
				continue
			var equipment: Variant = _resolve_equipment(player, previous, row, ctx, game)
			if equipment == null:
				continue
			new_zone.append(equipment)
	for old_equipment in previous:
		if old_equipment == null or new_zone.has(old_equipment):
			continue
		if old_equipment.has_method("get_all_skills"):
			for old_skill in old_equipment.get_all_skills():
				if old_skill != null and is_instance_valid(old_skill):
					player.remove_skill(old_skill)
	for equipment in new_zone:
		if previous_set.has(equipment):
			continue
		if equipment != null and equipment.has_method("get_all_skills"):
			for equipment_skill in equipment.get_all_skills():
				if equipment_skill != null and is_instance_valid(equipment_skill):
					player.add_skill(equipment_skill)
	player.equipment_zone = new_zone


static func _resolve_equipment(player: Variant, existing: Array, row: Dictionary,
		ctx: Dictionary, game: Variant) -> Variant:
	var net_id := int(row.get("net_id", 0))
	var equipment: Variant = ctx.get(net_id, null) if net_id > 0 else null
	if equipment != null and equipment is Equipment:
		_copy_card_properties(equipment, row)
		_stamp(equipment, net_id, ctx)
		var card_row: Variant = row.get("equipment_card", {})
		if card_row is Dictionary and equipment.equipment_card != null:
			_stamp(equipment.equipment_card, int(card_row.get("net_id", 0)), ctx)
			_copy_card_properties(equipment.equipment_card, card_row)
		return equipment
	var claimed := {}
	equipment = _take_unused_by_name(existing, row, claimed)
	if equipment != null:
		_stamp(equipment, net_id, ctx)
		_copy_card_properties(equipment, row)
		return equipment
	var card_payload: Dictionary = row.get("equipment_card", row)
	if not card_payload is Dictionary:
		card_payload = row
	var source_card: Variant = NetInputCodec.create_card_from_payload({
		"id": String(card_payload.get("english_name", row.get("english_name", ""))),
		"english_name": String(card_payload.get("english_name", row.get("english_name", ""))),
		"card_name": String(card_payload.get("card_name", row.get("card_name", ""))),
		"card_type": String(card_payload.get("card_type", "equipment")),
		"source": String(card_payload.get("source", row.get("source", ""))),
		"net_id": int(card_payload.get("net_id", 0)),
	}, game)
	if source_card is EquipmentCard and is_instance_valid(source_card):
		_copy_card_properties(source_card, card_payload if card_payload is Dictionary else row)
		_stamp(source_card, int(card_payload.get("net_id", 0)), ctx)
		var full_equipment: Equipment = source_card.instantiate(player)
		if row.has("charge_current"):
			full_equipment.charge_current = int(row.get("charge_current", full_equipment.charge_current))
		full_equipment.in_equipment_area = true
		_stamp(full_equipment, net_id, ctx)
		return full_equipment
	var fallback := Equipment.new()
	fallback.english_name = String(row.get("english_name", ""))
	fallback.card_name = String(row.get("card_name", fallback.english_name))
	fallback.equipment_name = fallback.card_name
	fallback.source = String(row.get("source", ""))
	_copy_card_properties(fallback, row)
	fallback.equipped_player = player
	fallback.in_equipment_area = true
	_stamp(fallback, net_id, ctx)
	return fallback


static func _current_blocks_by_player(game: Variant) -> Dictionary:
	var previous_blocks: Dictionary = {}
	if game == null:
		return previous_blocks
	for player in game.players if "players" in game else []:
		if player != null:
			previous_blocks[player] = player.current_block if "current_block" in player else null
	return previous_blocks


static func _apply_mission(game: Variant, snapshot: Dictionary) -> void:
	if game == null:
		return
	var config: Variant = game.mission_config if "mission_config" in game else null
	if config == null:
		return
	var packed: Variant = snapshot.get("mission_state", {})
	if not packed is Dictionary or packed.is_empty():
		return
	var state: Variant = packed.get("mission_state", packed)
	if state is Dictionary:
		config.mission_state = state.duplicate(true)


static func _block_skills_stale(block: Variant, block_name: String) -> bool:
	if block == null or block_name.is_empty():
		return false
	if String(block.block_name) != block_name:
		return true
	if DataManager == null:
		return false
	var block_def: Variant = DataManager.get_map_block_def_by_name(block_name)
	if block_def == null:
		return false
	var expected: Array = block_def.skills if "skills" in block_def else []
	var actual: Array = block.skills if "skills" in block else []
	if expected.size() != actual.size():
		return true
	for i in range(expected.size()):
		var expected_name := String(expected[i].skill_name) if expected[i] != null else ""
		var actual_skill: Variant = actual[i]
		var actual_name := ""
		if actual_skill != null and actual_skill.has_method("get"):
			actual_name = String(actual_skill.get("skill_name"))
		if expected_name != actual_name:
			return true
	return false


static func _detach_block_skills_from_players(game: Variant, block: Variant) -> void:
	if game == null or block == null or not block.has_method("_clear_skills_for_player"):
		return
	for player in game.players if "players" in game else []:
		if player != null:
			block._clear_skills_for_player(player)


static func _rebuild_block_skills(game: Variant, block: Variant, block_name: String) -> void:
	if block == null or not block.has_method("remove_skill"):
		return
	for skill in block.skills.duplicate() if "skills" in block else []:
		if skill != null:
			block.remove_skill(skill)
	if game == null or not game.has_method("_create_skill_from_data"):
		return
	if DataManager == null:
		return
	var block_def: Variant = DataManager.get_map_block_def_by_name(block_name)
	if block_def == null:
		return
	for skill_data in block_def.skills:
		var skill: Variant = game.call("_create_skill_from_data", skill_data)
		if skill != null and block.has_method("add_skill"):
			block.add_skill(skill)


static func _sync_location_skills(game: Variant, previous_blocks: Dictionary,
		rebuilt_blocks: Dictionary) -> void:
	if game == null:
		return
	var mission_config: Variant = game.mission_config if "mission_config" in game else null
	for player in game.players if "players" in game else []:
		if player == null:
			continue
		var previous: Variant = previous_blocks.get(player, null)
		var current: Variant = player.current_block if "current_block" in player else null
		var block_changed: bool = previous != current
		var current_rebuilt: bool = current != null and rebuilt_blocks.has(current)
		if not block_changed and not current_rebuilt:
			if current != null and mission_config != null \
					and mission_config.has_method("mount_action_skills") \
					and not _has_mission_action_skill(player) \
					and _block_matches_any_action(mission_config, current):
				mission_config.mount_action_skills(player, current)
			continue
		if previous != null and previous != current and previous.has_method("_clear_skills_for_player"):
			previous._clear_skills_for_player(player)
		if current != null and current.has_method("_acquire_skills_for_player"):
			current._acquire_skills_for_player(player)
		if mission_config != null and mission_config.has_method("mount_action_skills"):
			mission_config.mount_action_skills(player, current)


static func _has_mission_action_skill(player: Variant) -> bool:
	if player == null or not "skills" in player:
		return false
	for skill in player.skills:
		if skill != null and String(skill.get("english_name")).begins_with("mission_action_"):
			return true
	return false


static func _block_matches_any_action(mission_config: Variant, block: Variant) -> bool:
	if mission_config == null or block == null or not "action_components" in mission_config:
		return false
	for component in mission_config.action_components:
		if component == null or not component.has_method("get_action_skill_decl"):
			continue
		var decl: Variant = component.get_action_skill_decl()
		if not decl is Dictionary:
			continue
		var block_match: Callable = decl.get("block_match", Callable())
		if block_match.is_valid() and bool(block_match.call(block)):
			return true
	return false


static func _apply_monster_list(existing: Array, rows: Variant, ctx: Dictionary,
		owner: Variant) -> Array:
	var result: Array = []
	if not rows is Array:
		return result
	var claimed: Dictionary = {}
	for row in rows:
		if not row is Dictionary:
			continue
		var net_id := int(row.get("net_id", 0))
		var monster: Variant = ctx.get(net_id, null) if net_id > 0 else null
		if monster == null:
			monster = _take_unused_by_name(existing, row, claimed)
		if monster == null:
			monster = Monster.new()
			monster.attack_target = owner
		NetInputCodec.apply_monster_payload(monster, row)
		monster.attack_target = owner
		_stamp(monster, net_id, ctx)
		if net_id > 0:
			claimed[net_id] = true
		result.append(monster)
	return result


static func _prune_ctx(ctx: Dictionary, snapshot: Dictionary) -> void:
	var live: Dictionary = {}
	_collect_snapshot_ids(snapshot, live)
	var stale: Array = []
	for net_id in ctx.keys():
		if not live.has(int(net_id)):
			stale.append(net_id)
	for net_id in stale:
		ctx.erase(net_id)


static func _collect_snapshot_ids(value: Variant, live: Dictionary) -> void:
	if value is Dictionary:
		var net_id := int(value.get("net_id", 0))
		if net_id > 0:
			live[net_id] = true
		for key in value:
			_collect_snapshot_ids(value[key], live)
	elif value is Array:
		for item in value:
			_collect_snapshot_ids(item, live)
