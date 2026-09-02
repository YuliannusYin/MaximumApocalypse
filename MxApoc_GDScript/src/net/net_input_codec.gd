class_name NetInputCodec
extends RefCounted

## 输入 RPC 编解码：客机端选择 ↔ 主机端对象。
## 客机把行动选择/目标/卡牌编码为 net_id / 坐标 / 技能英文名，
## 主机端据此还原为真实对象引用。


# === 目标编码（choose_target 的目标列表） ===

static func encode_target(target) -> Dictionary:
	if target is Player:
		return {"t": "player", "id": target.net_id}
	if target is Monster:
		return {"t": "monster", "id": target.net_id}
	if target is MapBlock:
		return {"t": "block", "x": int(target.coordinate.get("x", 0)), "y": int(target.coordinate.get("y", 0))}
	if target is Equipment:
		if target.equipment_card != null:
			return {"t": "card", "id": target.equipment_card.net_id}
	if target is Card:
		return {"t": "card", "id": target.net_id}
	if target is Pile:
		return {"t": "pile", "key": ""}
	return {"t": "raw", "value": str(target)}


static func decode_target(game, td: Dictionary) -> Variant:
	match str(td.get("t", "")):
		"player":
			return NetRegistry.get_obj(int(td.get("id", 0)))
		"monster":
			return NetRegistry.get_obj(int(td.get("id", 0)))
		"block":
			var tx := int(td.get("x", -999))
			var ty := int(td.get("y", -999))
			for b in game.map_area:
				if b != null and int(b.coordinate.get("x", -999)) == tx and int(b.coordinate.get("y", -999)) == ty:
					return b
			return null
		"card":
			return NetRegistry.get_obj(int(td.get("id", 0)))
		"pile":
			return _pile_by_key(game, str(td.get("key", "")))
		_:
			return null


# === 行动选择编码 ===

## 客机：把行动选择里的对象引用替换为 ID。
static func encode_action_choice(choice: Dictionary) -> Dictionary:
	var c := choice.duplicate()
	match str(c.get("type", "")):
		"move":
			var t: Variant = c.get("target", null)
			if t is MapBlock:
				c["target"] = {"x": int(t.coordinate.get("x", 0)), "y": int(t.coordinate.get("y", 0))}
		"skill":
			var s: Variant = c.get("skill", null)
			if s is Skill:
				c["skill"] = s.english_name
		"card":
			var card: Variant = c.get("card", null)
			if card is Card:
				c["card"] = card.net_id
	return c


## 主机：把 ID 还原为对象引用（供 dispatch_player_action 消费）。
static func decode_action_choice(player, choice: Dictionary) -> Dictionary:
	var out := choice.duplicate()
	match str(choice.get("type", "")):
		"move":
			var t: Variant = choice.get("target", null)
			if t is Dictionary:
				out["target"] = _block_by_coord(t)
		"skill":
			var en := str(choice.get("skill", ""))
			out["skill"] = _skill_by_english_name(player, en)
		"card":
			out["card"] = NetRegistry.get_obj(int(choice.get("card", 0)))
	return out


# === 选项编码（choose） ===

## 把选项数组转为可序列化标签数组，客机据此展示。
static func serialize_options(options: Array) -> Array:
	var out: Array = []
	for i in range(options.size()):
		var label := ""
		var opt: Variant = options[i]
		if opt is Dictionary:
			label = str(opt.get("label", opt.get("id", str(opt))))
		else:
			label = str(opt)
		out.append({"idx": i, "label": label})
	return out


# === 内部辅助 ===

static func _skill_by_english_name(player, en: String) -> Variant:
	if player == null or en == "":
		return null
	for s in player.skills:
		if s is Skill and s.english_name == en:
			return s
	return null


static func _block_by_coord(td: Dictionary) -> Variant:
	var tx := int(td.get("x", -999))
	var ty := int(td.get("y", -999))
	for b in Game.map_area:
		if b != null and int(b.coordinate.get("x", -999)) == tx and int(b.coordinate.get("y", -999)) == ty:
			return b
	return null


static func _pile_by_key(game, key: String) -> Variant:
	match key:
		"game_deck":
			return null
		"red": return game.red_scavenge_pile
		"green": return game.green_scavenge_pile
		"blue": return game.blue_scavenge_pile
		"discard": return game.scavenge_discard_pile
	return null
