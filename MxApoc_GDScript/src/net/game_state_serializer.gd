class_name GameStateSerializer
extends RefCounted

## 主机权威模式下的全量状态序列化与客户端视图还原。
## 主机端 serialize()：把 Game 权威状态（地图/玩家/手牌/装备/怪物区/牌堆/回合）序列化为字典。
## 客机端 apply_to_view()：原位更新视图模型（保持 Player/MapBlock/Card/Monster 实例不变，
## 使 UI 的 get_instance_id() 映射不失效），随后由调用方触发 EventBus 信号全量刷新。
## 客机视图模型只用于渲染与输入编码，不执行任何模拟逻辑。


## 创建快照上下文（跨帧缓存 net_id -> 对象映射）。
static func make_context() -> Dictionary:
	return {
		"cards": {},     # net_id -> Card
		"monsters": {},  # net_id -> Monster
		"blocks": {},    # net_id -> MapBlock
		"players": {},   # net_id -> Player
		"initialized": false,
	}


# === 序列化（主机） ===

static func serialize(game) -> Dictionary:
	var state := {}
	state["mission_id"] = game.current_mission.mission_id if game.current_mission != null else -1
	state["mission_fuel"] = game.mission_config.van_fuel_required if game.mission_config != null else -1
	state["objective_mark_total"] = game.mission_config.initial_objective_mark_count if game.mission_config != null else 0
	state["mission_state"] = game.mission_config.mission_state if game.mission_config != null else {}
	state["turn_number"] = game.state_machine.turn_number if game.state_machine != null else 0
	state["game_state"] = game.state_machine.current_state if game.state_machine != null else 0
	state["game_result"] = game.state_machine.game_result if game.state_machine != null else -1
	var cur: Variant = game.get_current_player()
	state["current_player_seat"] = cur.seat_number if cur != null else -1

	state["map_width"] = game.map_width
	state["map_height"] = game.map_height
	var blocks: Array = []
	for block in game.map_area:
		if block != null and is_instance_valid(block):
			blocks.append(_serialize_block(block))
	state["blocks"] = blocks

	var players: Array = []
	for player in game.players:
		if player != null and is_instance_valid(player):
			players.append(_serialize_player(player))
	state["players"] = players

	state["piles"] = {
		"monster": _serialize_pile(game.monster_pile),
		"red": _serialize_pile(game.red_scavenge_pile),
		"green": _serialize_pile(game.green_scavenge_pile),
		"blue": _serialize_pile(game.blue_scavenge_pile),
		"discard": _serialize_pile(game.scavenge_discard_pile),
	}
	# 事件日志（供客机事件日志面板渲染）
	state["log"] = game.log_list.duplicate(true)
	return state


static func _serialize_pile(pile) -> Array:
	var out: Array = []
	if pile != null:
		for card in pile.cards:
			out.append(_serialize_card(card))
	return out


static func _serialize_block(block) -> Dictionary:
	return {
		"net_id": block.net_id,
		"block_name": block.block_name,
		"coordinate": block.coordinate,
		"revealed": block.revealed,
		"monster_marks": block.monster_marks,
		"block_state": block.block_state,
		"van_fuel": block.van_fuel,
		"objective_marks": _serialize_objective_marks(block.objective_marks),
		"scavenge_colors": Array(block.scavenge_colors),
		"monster_spawn_value": block.monster_spawn_value,
	}


static func _serialize_player(player) -> Dictionary:
	return {
		"net_id": player.net_id,
		"seat_number": player.seat_number,
		"player_name": player.player_name,
		"hp": player.hp,
		"max_hp": player.max_hp,
		"hunger": player.hunger,
		"action_count": player.action_count,
		"max_action_count": player.max_action_count,
		"in_phase": player.in_phase,
		"current_block": player.current_block.net_id if player.current_block != null else 0,
		"role": _serialize_role(player.role_card),
		"hand": _serialize_cards(player.hand),
		"equipment": _serialize_equipment(player.equipment_zone),
		"monster_zone": _serialize_monsters(player.monster_zone),
		"deck": _serialize_cards(player.game_deck.cards if player.game_deck != null else []),
		"discard": _serialize_cards(player.game_discard_pile.cards if player.game_discard_pile != null else []),
		"skills": _serialize_skills(player.skills),
		"marks": _serialize_marks(player.marks.values()),
	}


static func _serialize_role(role) -> Dictionary:
	if role == null:
		return {}
	return {
		"english_name": role.english_name,
		"role_name": role.role_name,
		"is_front_side": role.is_front_side,
		"equipment_capacity": role.equipment_capacity,
	}


static func _serialize_cards(cards: Array) -> Array:
	var out: Array = []
	for card in cards:
		out.append(_serialize_card(card))
	return out


## 装备区存的是 Equipment 实体（引用来源 EquipmentCard），按来源卡序列化。
static func _serialize_equipment(zone: Array) -> Array:
	var out: Array = []
	for eq in zone:
		if eq != null and eq.equipment_card != null:
			out.append(_serialize_card(eq.equipment_card))
	return out


static func _serialize_monsters(zone: Array) -> Array:
	var out: Array = []
	for monster in zone:
		out.append(_serialize_monster(monster))
	return out


static func _serialize_monster(monster) -> Dictionary:
	return {
		"net_id": monster.net_id,
		"monster_name": monster.monster_name,
		"monster_type": monster.monster_type,
		"english_name": monster.english_name,
		"monster_level": monster.monster_level,
		"hp": monster.hp,
		"max_hp": monster.max_hp,
		"damage_value": monster.damage_value,
		"range": monster.range,
		"stunned": monster.stunned,
		"attack_target": monster.attack_target.seat_number if monster.attack_target != null else -1,
		"monster_card": _serialize_card(monster.monster_card),
		"skills": _serialize_skills(monster.skills),
		"marks": _serialize_marks(monster.marks.values()),
	}


## 卡牌全量显示数据（静态 + 运行时填充物/标记）。
static func _serialize_card(card) -> Dictionary:
	return {
		"net_id": card.net_id,
		"card_name": card.card_name,
		"english_name": card.english_name,
		"card_type": card.card_type,
		"card_subtype": str(_card_get(card, "card_subtype", "")),
		"source": card.source,
		"size": int(_card_get(card, "size", 0)),
		"range": str(_card_get(card, "range", "none")),
		"charge_type": str(_card_get(card, "charge_type", "")),
		"charge_max": int(_card_get(card, "charge_max", 0)),
		"charge_current": int(_card_get(card, "charge_current", 0)),
		"color": str(_card_get(card, "color", "")),
		"scavenge_type": str(_card_get(card, "scavenge_type", "")),
		"monster_type": str(_card_get(card, "monster_type", "")),
		"monster_level": str(_card_get(card, "monster_level", "normal")),
		"max_hp": int(_card_get(card, "max_hp", 0)),
		"damage_value": int(_card_get(card, "damage_value", 0)),
		"is_boss": bool(_card_get(card, "is_boss", false)),
		"skills": _serialize_skills(card.skills),
		"marks": _serialize_marks(card.marks.values()),
	}


## Object.get(prop) 单参；此处补默认值。
static func _card_get(card, prop: String, default: Variant) -> Variant:
	var v: Variant = card.get(prop)
	return v if v != null else default


static func _serialize_skills(skills: Array) -> Array:
	var out: Array = []
	for s in skills:
		out.append({
			"english_name": s.english_name,
			"skill_name": s.skill_name,
			"skill_description": s.skill_description,
			"skill_type": s.skill_type,
			"active": s.active,
			"used_count": s.used_count,
		})
	return out


static func _serialize_marks(marks: Array) -> Array:
	var out: Array = []
	for mark in marks:
		if mark == null:
			continue
		if mark is Dictionary:
			# 地块目标标记（objective_marks）以 Dictionary 存储，按键读取。
			out.append({
				"name": str(mark.get("name", "")),
				"mark_text": str(mark.get("mark_text", "")),
				"mark_content": str(mark.get("mark_content", "")),
				"visible": bool(mark.get("visible", true)),
				"count": int(mark.get("count", 1)),
				"items": mark.get("items", []),
			})
		else:
			out.append({
				"name": str(mark.get("name")),
				"mark_text": str(mark.get("mark_text")),
				"mark_content": str(mark.get("mark_content")),
				"visible": bool(mark.get("visible")),
				"count": int(mark.get("count")),
				"items": mark.get("items"),
			})
	return out


## 地块目标标记以 Dictionary 存储（mark_id/mark_description/remove_condition 等纯数据字段），
## 直接浅拷贝序列化，避免经 Mark 对象 schema 丢失目标标记专属字段。
## 客机端仍以 Dictionary 还原，`has_objective_mark`/弹窗等 `mark.get("removed", false)` 调用不受影响。
static func _serialize_objective_marks(marks: Array) -> Array:
	var out: Array = []
	for mark in marks:
		if mark == null:
			continue
		if mark is Dictionary:
			out.append(mark.duplicate())
		else:
			out.append({
				"mark_id": mark.get("mark_id"),
				"mark_description": mark.get("mark_description"),
			})
	return out


# === 反序列化（客机：原位更新视图模型） ===

static func apply_to_view(game, state: Dictionary, ctx: Dictionary) -> void:
	if not bool(ctx.get("initialized", false)):
		_build_initial_view(game, state, ctx)
		ctx["initialized"] = true

	if state.has("mission_id") and int(state.get("mission_id", -1)) >= 0:
		var mission: Variant = DataManager.get_mission(int(state["mission_id"]))
		if mission != null:
			game.current_mission = mission
	if game.mission_config != null:
		game.mission_config.van_fuel_required = int(state.get("mission_fuel", -1))
		game.mission_config.initial_objective_mark_count = int(state.get("objective_mark_total", 0))
		game.mission_config.mission_state = state.get("mission_state", {})

	for bd in state.get("blocks", []):
		var block: Variant = ctx.blocks.get(int(bd.get("net_id", 0)))
		if block != null:
			_apply_block(block, bd)

	for pd in state.get("players", []):
		var player: Variant = ctx.players.get(int(pd.get("net_id", 0)))
		if player != null:
			_apply_player(game, player, pd, ctx)

	# 牌堆内容（原位重建，缓存卡对象）
	var piles: Dictionary = state.get("piles", {})
	_set_pile(game.monster_pile, piles.get("monster", []), ctx)
	_set_pile(game.red_scavenge_pile, piles.get("red", []), ctx)
	_set_pile(game.green_scavenge_pile, piles.get("green", []), ctx)
	_set_pile(game.blue_scavenge_pile, piles.get("blue", []), ctx)
	_set_pile(game.scavenge_discard_pile, piles.get("discard", []), ctx)

	# 当前玩家 / 回合 / 状态
	if game.state_machine != null:
		var cur_seat := int(state.get("current_player_seat", -1))
		game.state_machine.current_player = _find_player_by_seat(game.players, cur_seat)
		game.state_machine.turn_number = int(state.get("turn_number", 0))
		game.state_machine.current_state = int(state.get("game_state", 0))
		game.state_machine.game_result = int(state.get("game_result", -1))


static func _build_initial_view(game, state: Dictionary, ctx: Dictionary) -> void:
	# 地图块
	var blocks: Array = state.get("blocks", [])
	game.map_area.clear()
	for bd in blocks:
		var block := MapBlock.new()
		block.net_id = int(bd.get("net_id", 0))
		game.map_area.append(block)
		ctx.blocks[block.net_id] = block
	game.map_width = int(state.get("map_width", 0))
	game.map_height = int(state.get("map_height", 0))

	# 玩家
	var players: Array = state.get("players", [])
	game.players.clear()
	for pd in players:
		var player := Player.new()
		player.net_id = int(pd.get("net_id", 0))
		player.input = CliPlayerInput.new()
		player.game_deck = Pile.new()
		player.game_discard_pile = Pile.new()
		game.players.append(player)
		ctx.players[player.net_id] = player

	# 全局牌堆（仅容器，内容由 _set_pile 填充）
	game.monster_pile = Pile.new()
	game.red_scavenge_pile = Pile.new()
	game.green_scavenge_pile = Pile.new()
	game.blue_scavenge_pile = Pile.new()
	game.scavenge_discard_pile = Pile.new()


static func _apply_block(block: MapBlock, bd: Dictionary) -> void:
	block.block_name = str(bd.get("block_name", block.block_name))
	block.coordinate = bd.get("coordinate", block.coordinate)
	block.revealed = bool(bd.get("revealed", block.revealed))
	block.monster_marks = int(bd.get("monster_marks", block.monster_marks))
	block.block_state = str(bd.get("block_state", block.block_state))
	block.van_fuel = int(bd.get("van_fuel", block.van_fuel))
	block.scavenge_colors = PackedStringArray(bd.get("scavenge_colors", []))
	block.monster_spawn_value = int(bd.get("monster_spawn_value", block.monster_spawn_value))
	block.objective_marks.clear()
	for md in bd.get("objective_marks", []):
		if md is Dictionary:
			# 目标标记在主机侧为 Dictionary，客机视图保持 Dictionary 结构
			block.objective_marks.append(md.duplicate())
		else:
			block.objective_marks.append(_mark_from_dict(md))


static func _apply_player(game, player: Player, pd: Dictionary, ctx: Dictionary) -> void:
	player.seat_number = int(pd.get("seat_number", player.seat_number))
	player.player_name = str(pd.get("player_name", player.player_name))
	player.hp = int(pd.get("hp", player.hp))
	player.max_hp = int(pd.get("max_hp", player.max_hp))
	player.hunger = int(pd.get("hunger", player.hunger))
	player.action_count = int(pd.get("action_count", player.action_count))
	player.max_action_count = int(pd.get("max_action_count", player.max_action_count))
	player.in_phase = str(pd.get("in_phase", player.in_phase))
	var block_id := int(pd.get("current_block", 0))
	player.current_block = ctx.blocks.get(block_id, null)
	# 角色卡
	var role_dict: Dictionary = pd.get("role", {})
	player.role_card = _role_from_dict(role_dict, player.role_card)
	# 手牌 / 装备区 / 怪物区
	player.hand = _cards_from_dicts(pd.get("hand", []), ctx)
	player.equipment_zone = _equipment_from_dicts(pd.get("equipment", []), ctx)
	player.monster_zone = _monsters_from_dicts(game, pd.get("monster_zone", []), ctx, player)
	# 个人牌堆内容
	if player.game_deck != null:
		player.game_deck.cards = _cards_from_dicts(pd.get("deck", []), ctx)
	if player.game_discard_pile != null:
		player.game_discard_pile.cards = _cards_from_dicts(pd.get("discard", []), ctx)
	# 技能（显示 + choose_target 定位）
	_apply_skills(player, pd.get("skills", []))
	# 标记
	player.marks.clear()
	for md in pd.get("marks", []):
		player.marks[md.get("name", "")] = _mark_from_dict(md)


static func _role_from_dict(rd: Dictionary, existing) -> RoleCard:
	if rd.is_empty():
		return existing
	var role: RoleCard = existing if existing != null else RoleCard.new()
	role.english_name = str(rd.get("english_name", role.english_name))
	role.role_name = str(rd.get("role_name", role.role_name))
	role.is_front_side = bool(rd.get("is_front_side", role.is_front_side))
	role.equipment_capacity = int(rd.get("equipment_capacity", role.equipment_capacity))
	return role


static func _cards_from_dicts(dicts: Array, ctx: Dictionary) -> Array:
	var out: Array = []
	for cd in dicts:
		out.append(_ensure_card(cd, ctx))
	return out


## 装备区：由来源卡数据构造 Equipment 视图模型。
static func _equipment_from_dicts(dicts: Array, ctx: Dictionary) -> Array:
	var out: Array = []
	for cd in dicts:
		var eq := Equipment.new()
		var card: Card = _ensure_card(cd, ctx)
		eq.equipment_card = card
		eq.equipment_name = card.card_name
		eq.card_name = card.card_name
		eq.english_name = card.english_name
		eq.card_type = card.card_type
		eq.card_subtype = str(_card_get(card, "card_subtype", ""))
		eq.source = card.source
		eq.size = int(_card_get(card, "size", 0))
		eq.range = str(_card_get(card, "range", "none"))
		eq.charge_type = str(_card_get(card, "charge_type", ""))
		eq.charge_max = int(_card_get(card, "charge_max", 0))
		eq.in_equipment_area = true
		out.append(eq)
	return out


static func _monsters_from_dicts(game, dicts: Array, ctx: Dictionary, owner) -> Array:
	var out: Array = []
	for md in dicts:
		var nid := int(md.get("net_id", 0))
		var monster: Monster
		if ctx.monsters.has(nid):
			monster = ctx.monsters[nid]
		else:
			monster = Monster.new()
			monster.net_id = nid
			ctx.monsters[nid] = monster
		monster.monster_name = str(md.get("monster_name", ""))
		monster.monster_type = str(md.get("monster_type", ""))
		monster.english_name = str(md.get("english_name", ""))
		monster.monster_level = str(md.get("monster_level", "normal"))
		monster.hp = int(md.get("hp", 0))
		monster.max_hp = int(md.get("max_hp", 0))
		monster.damage_value = int(md.get("damage_value", 0))
		monster.range = str(md.get("range", "none"))
		monster.stunned = bool(md.get("stunned", false))
		monster.attack_target = _find_player_by_seat(game.players, int(md.get("attack_target", -1)))
		monster.monster_card = _ensure_card(md.get("monster_card", {}), ctx) as MonsterCard
		_apply_skills(monster, md.get("skills", []))
		monster.marks.clear()
		for mk in md.get("marks", []):
			monster.marks[mk.get("name", "")] = _mark_from_dict(mk)
		out.append(monster)
	return out


## 获取（或创建并缓存）指定 net_id 的卡牌视图模型，并按字典更新字段。
static func _ensure_card(cd: Dictionary, ctx: Dictionary) -> Card:
	var nid := int(cd.get("net_id", 0))
	var card: Card
	if ctx.cards.has(nid):
		card = ctx.cards[nid]
	else:
		card = _new_card_from_dict(cd)
		card.net_id = nid
		ctx.cards[nid] = card
	_apply_card(card, cd)
	return card


static func _new_card_from_dict(cd: Dictionary) -> Card:
	var ctype := str(cd.get("card_type", ""))
	var source := str(cd.get("source", ""))
	var card: Card
	if source == "monster":
		card = MonsterCard.new()
	elif ctype == "equipment":
		card = EquipmentCard.new()
	elif source == "scavenge":
		card = ScavengeCard.new()
	else:
		card = SurvivorGameCard.new()
	return card


static func _apply_card(card: Card, cd: Dictionary) -> void:
	card.net_id = int(cd.get("net_id", card.net_id))
	card.card_name = str(cd.get("card_name", card.card_name))
	card.english_name = str(cd.get("english_name", card.english_name))
	card.card_type = str(cd.get("card_type", card.card_type))
	card.source = str(cd.get("source", card.source))
	card.set("card_subtype", str(cd.get("card_subtype", "")))
	card.set("size", int(cd.get("size", 0)))
	card.set("range", str(cd.get("range", "none")))
	card.set("charge_type", str(cd.get("charge_type", "")))
	card.set("charge_max", int(cd.get("charge_max", 0)))
	card.set("charge_current", int(cd.get("charge_current", 0)))
	card.set("color", str(cd.get("color", "")))
	card.set("scavenge_type", str(cd.get("scavenge_type", "")))
	card.set("monster_type", str(cd.get("monster_type", "")))
	card.set("monster_level", str(cd.get("monster_level", "normal")))
	card.set("max_hp", int(cd.get("max_hp", 0)))
	card.set("damage_value", int(cd.get("damage_value", 0)))
	card.set("is_boss", bool(cd.get("is_boss", false)))
	_apply_skills(card, cd.get("skills", []))
	card.marks.clear()
	for mk in cd.get("marks", []):
		card.marks[mk.get("name", "")] = _mark_from_dict(mk)


static func _apply_skills(target, skill_dicts: Array) -> void:
	var existing: Dictionary = {}
	for s in target.skills:
		existing[s.english_name] = s
	target.skills.clear()
	for sd in skill_dicts:
		var en := str(sd.get("english_name", ""))
		var skill: Skill = existing.get(en, null)
		if skill == null:
			skill = Skill.new()
		skill.english_name = en
		skill.skill_name = str(sd.get("skill_name", ""))
		skill.skill_description = str(sd.get("skill_description", ""))
		skill.skill_type = str(sd.get("skill_type", ""))
		skill.active = str(sd.get("active", ""))
		skill.used_count = int(sd.get("used_count", 0))
		target.skills.append(skill)


static func _mark_from_dict(md: Dictionary) -> Mark:
	var mark := Mark.new()
	mark.name = str(md.get("name", ""))
	mark.mark_text = str(md.get("mark_text", ""))
	mark.mark_content = str(md.get("mark_content", ""))
	mark.visible = bool(md.get("visible", true))
	mark.count = int(md.get("count", 1))
	mark.items = md.get("items", [])
	return mark


static func _set_pile(pile, card_dicts: Array, ctx: Dictionary) -> void:
	if pile == null:
		return
	pile.cards.clear()
	for cd in card_dicts:
		pile.cards.append(_ensure_card(cd, ctx))


static func _find_player_by_seat(players: Array, seat: int) -> Variant:
	if seat < 0:
		return null
	for p in players:
		if p != null and p.seat_number == seat:
			return p
	return null
