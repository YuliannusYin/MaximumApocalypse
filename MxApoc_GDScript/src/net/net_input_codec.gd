class_name NetInputCodec
extends RefCounted

## 输入候选和响应的稳定 ID 编解码，禁止把运行时对象直接放进 RPC。

static func encode(value: Variant) -> Variant:
	if value == null or value is bool or value is int or value is float or value is String:
		return value
	if value is Array:
		var rows: Array = []
		for item in value:
			rows.append(encode(item))
		return rows
	if value is Dictionary:
		var result := {}
		for key in value:
			result[String(key)] = encode(value[key])
		return result
	var net_id := _entity_net_id(value)
	if value is MonsterCard:
		return {
			"__kind": "monster_card",
			"net_id": net_id,
			"id": _string_property(value, "english_name"),
			"card_name": _string_property(value, "card_name"),
			"card_type": _string_property(value, "card_type"),
			"source": _string_property(value, "source"),
			"monster_type": _string_property(value, "monster_type"),
			"monster_level": _string_property(value, "monster_level"),
			"max_hp": int(value.get("max_hp")),
			"damage_value": int(value.get("damage_value")),
			"range": _string_property(value, "range"),
		}
	if value is Monster:
		var holder: Variant = value.get("attack_target")
		var holder_seat := int(holder.get("seat_number")) \
			if holder != null and is_instance_valid(holder) else -1
		var zone_index := -1
		if holder != null and is_instance_valid(holder) and "monster_zone" in holder:
			zone_index = holder.monster_zone.find(value)
		return {
			"__kind": "monster",
			"net_id": net_id,
			"id": _string_property(value, "english_name"),
			"monster_name": _string_property(value, "monster_name"),
			"monster_type": _string_property(value, "monster_type"),
			"monster_level": _string_property(value, "monster_level"),
			"hp": int(value.get("hp")),
			"max_hp": int(value.get("max_hp")),
			"damage_value": int(value.get("damage_value")),
			"range": _string_property(value, "range"),
			"stunned": bool(value.get("stunned")),
			"holder_seat": holder_seat,
			"zone_index": zone_index,
		}
	if value is Equipment:
		var owner: Variant = value.get("equipped_player")
		var owner_seat := int(owner.get("seat_number")) \
			if owner != null and is_instance_valid(owner) else -1
		var equipment_index := -1
		if owner != null and is_instance_valid(owner) and "equipment_zone" in owner:
			equipment_index = owner.equipment_zone.find(value)
		return {
			"__kind": "equipment",
			"net_id": net_id,
			"id": _string_property(value, "english_name"),
			"card_name": _string_property(value, "card_name"),
			"card_type": _string_property(value, "card_type"),
			"source": _string_property(value, "source"),
			"size": int(value.get("size")),
			"range": _string_property(value, "range"),
			"charge_type": _string_property(value, "charge_type"),
			"charge_max": int(value.get("charge_max")),
			"charge_current": int(value.get("charge_current")),
			"weapon": bool(value.get("weapon")),
			"owner_seat": owner_seat,
			"equipment_index": equipment_index,
		}
	if value is Card:
		return {
			"__kind": "card",
			"net_id": net_id,
			"id": _string_property(value, "english_name"),
			"card_name": _string_property(value, "card_name"),
			"card_type": _string_property(value, "card_type"),
			"source": _string_property(value, "source"),
		}
	if value is Skill:
		return {
			"__kind": "skill",
			"id": _string_property(value, "english_name"),
			"skill_name": _string_property(value, "skill_name"),
		}
	if value is Player:
		var role_english_name := ""
		var role_card: Variant = value.get("role_card")
		if role_card != null and is_instance_valid(role_card):
			role_english_name = _string_property(role_card, "english_name")
		return {
			"__kind": "player",
			"net_id": net_id,
			"seat_id": int(value.seat_number),
			"role_english_name": role_english_name,
		}
	if value is MapBlock:
		var coordinate: Dictionary = value.coordinate
		return {
			"__kind": "block",
			"net_id": net_id,
			"x": int(coordinate.get("x", 0)),
			"y": int(coordinate.get("y", 0)),
		}
	if value.has_method("get"):
		var english_name: Variant = value.get("english_name")
		if english_name != null:
			return {"__kind": "entity", "net_id": net_id, "id": String(english_name)}
	return str(value)

static func decode(value: Variant, game: Variant = null) -> Variant:
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(decode(item, game))
		return result
	if not value is Dictionary:
		return value
	var kind := String(value.get("__kind", ""))
	if kind == "":
		var result_dict := {}
		for key in value:
			result_dict[key] = decode(value[key], game)
		return result_dict
	if game == null:
		return value
	# 活对象只返回引用，禁止把 payload 的 hp 等战斗字段写回去。
	var net_id := int(value.get("net_id", 0))
	if net_id > 0:
		var live: Variant = GameStateSerializer.find_by_net_id(game, net_id)
		if live != null:
			return live
	match kind:
		"monster":
			var holder_seat := int(value.get("holder_seat", -1))
			var zone_index := int(value.get("zone_index", -1))
			if holder_seat >= 0 and zone_index >= 0:
				for player in game.players:
					if int(player.seat_number) == holder_seat \
							and "monster_zone" in player \
							and zone_index < player.monster_zone.size():
						return player.monster_zone[zone_index]
			var monster := Monster.new()
			_apply_monster_payload(monster, value)
			return monster
		"equipment":
			var owner_seat := int(value.get("owner_seat", -1))
			var equipment_index := int(value.get("equipment_index", -1))
			if owner_seat >= 0 and equipment_index >= 0:
				for player in game.players:
					if int(player.seat_number) == owner_seat \
							and "equipment_zone" in player \
							and equipment_index < player.equipment_zone.size():
						return player.equipment_zone[equipment_index]
			var equipment := Equipment.new()
			equipment.english_name = String(value.get("id", ""))
			equipment.equipment_name = String(value.get("card_name", ""))
			equipment.card_name = equipment.equipment_name
			equipment.card_type = String(value.get("card_type", "equipment"))
			equipment.source = String(value.get("source", ""))
			equipment.size = int(value.get("size", 0))
			equipment.range = String(value.get("range", "none"))
			equipment.charge_type = String(value.get("charge_type", ""))
			equipment.charge_max = int(value.get("charge_max", 0))
			equipment.weapon = bool(value.get("weapon", false))
			equipment.in_equipment_area = true
			return equipment
		"monster_card":
			var monster_card := MonsterCard.new()
			monster_card.english_name = String(value.get("id", ""))
			monster_card.card_name = String(value.get("card_name", ""))
			monster_card.card_type = String(value.get("card_type", "monster"))
			monster_card.source = String(value.get("source", "monster"))
			monster_card.monster_type = String(value.get("monster_type", ""))
			monster_card.monster_level = String(value.get("monster_level", "normal"))
			monster_card.max_hp = int(value.get("max_hp", 0))
			monster_card.damage_value = int(value.get("damage_value", 0))
			monster_card.range = String(value.get("range", "none"))
			return monster_card
		"player":
			for player in game.players:
				if int(player.seat_number) == int(value.get("seat_id", -1)):
					return player
		"block":
			return game.get_block_by_coord(int(value.get("x", 0)), int(value.get("y", 0)))
		"card":
			return resolve_card(value, game)
		"skill":
			return resolve_skill(value, game)
		"entity":
			return value
	return value

## 将网络卡牌描述解析为客机/房主已有的完整卡牌实例。
## 优先复用现有实体，找不到时从静态牌组数据重建技能，避免普通 Card 丢失 skills。
static func resolve_card(value: Dictionary, game: Variant) -> Variant:
	if game == null:
		return null
	var net_id := int(value.get("net_id", 0))
	if net_id > 0:
		var live: Variant = GameStateSerializer.find_by_net_id(game, net_id)
		if live != null:
			return live
	var card_id := String(value.get("id", value.get("english_name", "")))
	for player in game.players:
		if player == null or not is_instance_valid(player):
			continue
		for card in player.hand:
			if card != null and is_instance_valid(card) \
					and String(card.get("english_name")) == card_id:
				return card
		for equipment in player.equipment_zone:
			var source: Variant = equipment.get("equipment_card") \
				if equipment != null and equipment.has_method("get") else null
			if source != null and is_instance_valid(source) \
					and String(source.get("english_name")) == card_id:
				return source
		for pile in [player.game_deck, player.game_discard_pile]:
			if pile == null:
				continue
			for card in pile.cards:
				if card != null and is_instance_valid(card) \
						and String(card.get("english_name")) == card_id:
					return card
	if game.get("scavenge_discard_pile") != null:
		var scavenge_discard: Variant = game.scavenge_discard_pile
		if scavenge_discard != null and "cards" in scavenge_discard:
			for card in scavenge_discard.cards:
				if card != null and is_instance_valid(card) \
						and String(card.get("english_name")) == card_id:
					return card
	return create_card_from_payload(value, game)


## 不复用场上实例，从静态数据或 payload 新建卡牌（快照重建用，避免与手牌别名）。
static func create_card_from_payload(value: Dictionary, game: Variant) -> Variant:
	var card_id := String(value.get("id", value.get("english_name", "")))
	var source_name := String(value.get("source", ""))
	var card_type := String(value.get("card_type", ""))
	if game != null and DataManager != null and is_instance_valid(DataManager):
		if source_name == "game":
			for survivor in DataManager.get_all_survivors():
				for raw_card in survivor.deck:
					if raw_card is Dictionary \
							and String(raw_card.get("english_name", "")) == card_id:
						var game_card: Variant = game.call(
							"_create_game_card_from_dict", raw_card)
						if game_card != null and is_instance_valid(game_card):
							var payload_net_id := int(value.get("net_id", 0))
							if payload_net_id > 0:
								game_card.net_id = payload_net_id
							return game_card
		elif source_name == "scavenge":
			for color in ["red", "green", "blue", "gray"]:
				for card_data in DataManager.get_scavenge_pile(color):
					if String(card_data.get("english_name")) != card_id:
						continue
					var scavenge_card: Variant = game.call(
						"_create_scavenge_card_from_data", card_data, color)
					if scavenge_card != null and is_instance_valid(scavenge_card):
						var payload_net_id := int(value.get("net_id", 0))
						if payload_net_id > 0:
							scavenge_card.net_id = payload_net_id
						return scavenge_card
	var card: Card
	if card_type == "equipment":
		card = EquipmentCard.new()
	else:
		card = Card.new()
	card.english_name = card_id
	card.card_name = String(value.get("card_name", card_id))
	card.card_type = card_type
	card.source = source_name
	var payload_net_id := int(value.get("net_id", 0))
	if payload_net_id > 0:
		card.net_id = payload_net_id
	return card


static func apply_monster_payload(monster: Variant, value: Dictionary) -> void:
	_apply_monster_payload(monster, value)


static func _apply_monster_payload(monster: Variant, value: Dictionary) -> void:
	if monster == null:
		return
	var payload_net_id := int(value.get("net_id", 0))
	if payload_net_id > 0:
		monster.net_id = payload_net_id
	var english_name := String(value.get("id", value.get("english_name", "")))
	if not english_name.is_empty():
		monster.english_name = english_name
	var monster_name := String(value.get("monster_name", ""))
	if monster_name.is_empty():
		monster_name = String(value.get("card_name", ""))
	if not monster_name.is_empty():
		monster.monster_name = monster_name
	var monster_type := String(value.get("monster_type", ""))
	if not monster_type.is_empty():
		monster.monster_type = monster_type
	var monster_level := String(value.get("monster_level", ""))
	if not monster_level.is_empty():
		monster.monster_level = monster_level
	if value.has("max_hp"):
		monster.max_hp = int(value.get("max_hp", monster.max_hp))
	if value.has("hp"):
		monster.hp = int(value.get("hp", monster.hp))
	elif value.has("max_hp"):
		monster.hp = int(value.get("max_hp", 0))
	if value.has("damage_value"):
		monster.damage_value = int(value.get("damage_value", monster.damage_value))
	if value.has("range"):
		monster.range = String(value.get("range", monster.range))
	if value.has("stunned"):
		monster.stunned = bool(value.get("stunned"))


## 将网络技能描述解析回房主/客机已经创建的真实 Skill 实例。
## 技能的 content/filter 等 Callable 不通过网络传输，始终使用本地编译版本。
static func resolve_skill(value: Dictionary, game: Variant) -> Variant:
	if game == null:
		return null
	var skill_id := String(value.get("id", ""))
	for player in game.players:
		if player == null or not is_instance_valid(player):
			continue
		var found: Variant = _find_skill_in_array(player.get("skills"), skill_id)
		if found != null:
			return found
	return null

static func _find_skill_in_array(skills: Variant, skill_id: String) -> Variant:
	if not skills is Array:
		return null
	for skill in skills:
		if skill == null or not is_instance_valid(skill) or not skill is Skill:
			continue
		if String(skill.get("english_name")) == skill_id:
			return skill
		var nested: Variant = _find_skill_in_array(skill.get("sub_skills").values(), skill_id)
		if nested != null:
			return nested
	return null

static func _entity_net_id(value: Variant) -> int:
	if value == null or not value.has_method("get"):
		return 0
	var raw: Variant = value.get("net_id")
	return int(raw) if raw != null else 0


static func _string_property(value: Variant, property_name: String) -> String:
	if value == null or not value.has_method("get"):
		return ""
	var property_value: Variant = value.get(property_name)
	return "" if property_value == null else str(property_value)
