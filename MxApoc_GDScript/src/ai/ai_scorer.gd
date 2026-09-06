class_name AiScorer
extends RefCounted

## 无名杀式贪心评分：attitude / order / useful / effect。
## damage/heal 的 effect.target 为幅度（正数）；评分器按态度决定正负。

const AiMissionHintsScript = preload("res://src/ai/ai_mission_hints.gd")

const ATT_SELF := 2.0
const ATT_ALLY := 1.5
const ATT_ENEMY := -2.0

var hints = AiMissionHintsScript.new()


func attitude(from: Variant, to: Variant) -> float:
	if to == null:
		return 0.0
	if from != null and to == from:
		return ATT_SELF
	if to.has_method("is_player") and to.is_player():
		return ATT_ALLY
	if to.has_method("is_monster") and to.is_monster():
		return ATT_ENEMY
	return 0.0


func read_ai(obj: Variant) -> Dictionary:
	if obj == null:
		return {}
	var raw: Variant = obj.get("ai") if obj.get("ai") != null else {}
	return raw if raw is Dictionary else {}


func ai_order(obj: Variant) -> float:
	return float(read_ai(obj).get("order", 0))


func ai_useful(obj: Variant) -> float:
	return float(read_ai(obj).get("useful", 0))


func ai_tags(obj: Variant) -> Array:
	var tags: Variant = read_ai(obj).get("tags", [])
	return tags if tags is Array else []


func has_tag(obj: Variant, tag: String) -> bool:
	return ai_tags(obj).has(tag)


func useful(player: Variant, card: Variant) -> float:
	if card == null:
		return 0.0
	var value: float = ai_useful(card)
	if value == 0.0:
		var skill: Variant = _primary_play_skill(card)
		if skill != null:
			value = ai_useful(skill)
	if hints.is_needed_card(card, _game_of(player)):
		value += 6.0
	return value


func effect(player: Variant, obj: Variant, target: Variant) -> float:
	if obj == null:
		return 0.0
	if obj.get("ai_result") is Callable and obj.ai_result.is_valid():
		var event: Dictionary = {"player": player, "target": target}
		return float(obj.ai_result.call(player, target, event, Game))
	var effect_dict: Variant = read_ai(obj).get("effect", {})
	var player_part: float = 0.0
	var target_part: float = 0.0
	if effect_dict is Dictionary:
		player_part = float(effect_dict.get("player", 0))
		target_part = float(effect_dict.get("target", 0))
	var att: float = attitude(player, target)
	if has_tag(obj, "damage"):
		return player_part + (-att) * absf(target_part) + _damage_bonus(player, target)
	if has_tag(obj, "heal"):
		return player_part + att * absf(target_part) + _heal_bonus(player, target)
	return player_part + att * target_part


func check_item(player: Variant, obj: Variant, item: Variant) -> float:
	if obj != null and obj.get("ai_check") is Callable and obj.ai_check.is_valid():
		var event: Dictionary = {"player": player, "target": item}
		return float(obj.ai_check.call(player, item, event, Game))
	if item != null and item.has_method("is_monster") and item.is_monster():
		return _monster_threat(item)
	if item != null and item.get("card_type") != null:
		return useful(player, item)
	if item != null and item.has_method("is_map_block") and item.is_map_block():
		return score_block(player, item)
	if item != null and item.has_method("is_player") and item.is_player():
		return attitude(player, item)
	return 0.0


func score_action(player: Variant, action: Dictionary) -> float:
	var action_type: String = str(action.get("type", ""))
	match action_type:
		"card":
			return _score_card_action(player, action.get("card"))
		"skill":
			return _score_skill_action(player, action.get("skill"))
		"move":
			return _score_move(player, action.get("target"))
		"pile_draw":
			return _score_pile_draw(player, str(action.get("pile_key", "")))
		_:
			return 0.0


func score_block(player: Variant, block: Variant) -> float:
	if block == null or not is_instance_valid(block):
		return -99.0
	var score: float = 0.0
	var dist: int = 99
	var current: Variant = player.get_current_block() if player != null and player.has_method("get_current_block") else null
	if current != null and is_instance_valid(current) and current.has_method("distance_to"):
		dist = current.distance_to(block)
	var obj_dist: int = hints.nearest_objective_distance(player)
	if current != null and is_instance_valid(current) and current.has_method("distance_to"):
		var after: int = block.distance_to(_nearest_objective_block(player)) if _nearest_objective_block(player) != null else obj_dist
		score += float(obj_dist - after) * 2.0
	if block.has_method("has_objective_mark") and block.has_objective_mark():
		score += 3.0
	if block.has_method("count_monster_mark") and block.count_monster_mark() > 0:
		score -= 1.5
	if dist == 0:
		score += 0.0
	return score


func _score_card_action(player: Variant, card: Variant) -> float:
	if card == null or not is_instance_valid(card):
		return -99.0
	var skill: Variant = _primary_play_skill(card)
	var base: float = ai_order(card)
	if base == 0.0 and skill != null:
		base = ai_order(skill)
	if str(card.get("card_type")) == "equipment":
		base += 0.5 * useful(player, card)
		if _equipment_full(player) and not _has_same_name_equipped(player, card):
			base -= 4.0
		return base
	if skill != null:
		base += _best_target_effect(player, skill)
		base += _situational_skill_bonus(player, skill)
	else:
		base += 0.25 * useful(player, card)
	return base


func _score_skill_action(player: Variant, skill: Variant) -> float:
	if skill == null or not is_instance_valid(skill):
		return -99.0
	var base: float = ai_order(skill)
	if has_tag(skill, "mission") or str(skill.get("skill_type")) == "任务":
		base = maxf(base, 12.0)
		base += 4.0
	base += _best_target_effect(player, skill)
	base += _situational_skill_bonus(player, skill)
	return base


func _score_move(player: Variant, block: Variant) -> float:
	var score: float = 4.0 + score_block(player, block)
	if player != null and player.monster_zone != null and player.monster_zone.size() > 0:
		score -= 5.0
	if player != null and player.get_effective_action_count() <= 1:
		score -= 1.0
	return score


func _score_pile_draw(player: Variant, pile_key: String) -> float:
	var score: float = 3.5
	if player != null and player.hand != null and player.hand.size() >= 8:
		score -= 2.0
	if pile_key != "game_deck":
		score += 0.5
	if player != null and player.hunger >= 4:
		score += 1.0
	return score


func _best_target_effect(player: Variant, skill: Variant) -> float:
	if player == null or not player.has_method("get_skill_valid_targets"):
		return effect(player, skill, player)
	var select_n: int = int(skill.get("select_target")) if skill.get("select_target") != null else 0
	if select_n == 0 and str(skill.get("target_type")) == "":
		return effect(player, skill, player)
	var targets: Array = player.get_skill_valid_targets(skill)
	if targets.is_empty():
		return 0.0
	if select_n < 0:
		var total: float = 0.0
		for t in targets:
			total += effect(player, skill, t)
		return total
	var best: float = -99.0
	for t in targets:
		var s: float = effect(player, skill, t)
		if s > best:
			best = s
	return best if best > -99.0 else 0.0


func _situational_skill_bonus(player: Variant, skill: Variant) -> float:
	var bonus: float = 0.0
	if has_tag(skill, "heal"):
		bonus += _heal_urgency(player) * 4.0
	if has_tag(skill, "food") and player != null and int(player.get("hunger")) >= 4:
		bonus += 5.0
	if has_tag(skill, "ammo") and _has_underfilled_weapon(player, "ammo"):
		bonus += 4.0
	if has_tag(skill, "fuel") and _has_underfilled_weapon(player, "fuel"):
		bonus += 3.0
	if has_tag(skill, "damage") and player != null and player.monster_zone != null and player.monster_zone.size() > 0:
		bonus += 3.0
	return bonus


func _damage_bonus(player: Variant, target: Variant) -> float:
	if target == null or not (target.has_method("is_monster") and target.is_monster()):
		return 0.0
	var bonus: float = _monster_threat(target)
	if player != null and player.monster_zone != null and player.monster_zone.has(target):
		bonus += 2.0
	return bonus


func _heal_bonus(player: Variant, target: Variant) -> float:
	return _heal_urgency(target if target != null else player)


func _heal_urgency(who: Variant) -> float:
	if who == null or not who.has_method("get_hp"):
		return 0.0
	var hp: int = who.get_hp()
	var max_hp: int = who.get_max_hp() if who.has_method("get_max_hp") else 0
	if max_hp <= 0:
		return 0.0
	return 1.0 - float(hp) / float(max_hp)


func _monster_threat(monster: Variant) -> float:
	if monster == null:
		return 0.0
	var threat: float = float(monster.get("damage_value"))
	threat += float(monster.get("hp")) * 0.15
	if str(monster.get("monster_level")) == "boss":
		threat += 4.0
	elif str(monster.get("monster_level")) == "elite":
		threat += 2.0
	return threat


func _primary_play_skill(card: Variant) -> Variant:
	if card == null or not card.has_method("get_all_skills"):
		return null
	for skill in card.get_all_skills():
		if skill != null and str(skill.get("active")) == "action":
			return skill
	return null


func _equipment_full(player: Variant) -> bool:
	if player == null or player.equipment_zone == null:
		return false
	var cap: int = 4
	if player.role_card != null and is_instance_valid(player.role_card):
		cap = int(player.role_card.equipment_capacity)
	return player.equipment_zone.size() >= cap


func _has_same_name_equipped(player: Variant, card: Variant) -> bool:
	if player == null or card == null:
		return false
	for e in player.equipment_zone:
		if e != null and e.card_name == card.card_name:
			return true
	return false


func _has_underfilled_weapon(player: Variant, charge_type: String) -> bool:
	if player == null:
		return false
	for e in player.equipment_zone:
		if e == null:
			continue
		if str(e.get("charge_type")) != charge_type:
			continue
		if int(e.get("charge_current")) < int(e.get("charge_max")):
			return true
	return false


func _nearest_objective_block(player: Variant) -> Variant:
	var current: Variant = player.get_current_block() if player != null and player.has_method("get_current_block") else null
	if current == null:
		return null
	var best: Variant = null
	var best_d: int = 99
	for block in hints.objective_blocks(_game_of(player)):
		var d: int = current.distance_to(block)
		if d < best_d:
			best_d = d
			best = block
	return best


func _game_of(_player: Variant) -> Variant:
	return Game
