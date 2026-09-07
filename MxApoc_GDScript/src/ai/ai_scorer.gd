class_name AiScorer
extends RefCounted

## 无名杀式贪心评分：attitude / order / useful / effect。
## damage/heal 的 effect.target 为幅度（正数）；评分器按态度决定正负。

const AiMissionHintsScript = preload("res://src/ai/ai_mission_hints.gd")
const LegalActionsScript = preload("res://src/ai/legal_actions.gd")

const ATT_SELF := 2.0
const ATT_ALLY := 1.5
const ATT_ENEMY := -2.0
const OWN_ZONE_THREAT_BONUS := 40.0
const GATHER_SCAVENGE_BONUS := 10.0
const HAZARD_MARK_PENALTY := 2.5
const MISSION_REFUEL_PENALTY := 7.0
const GENERIC_USEFUL_CAP := 62.0
const BALANCE_USEFUL_WEIGHT := 0.08
const GRANT_ACTION_WEIGHT := 0.45
const ENGAGED_WEAPON_EQUIP_BONUS := 16.0

var hints = AiMissionHintsScript.new()
var _score_depth: int = 0


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


func is_damage_obj(obj: Variant) -> bool:
	if has_tag(obj, "damage"):
		return true
	if has_tag(obj, "heal") or has_tag(obj, "food"):
		return false
	var effect_dict: Variant = read_ai(obj).get("effect", {})
	if not (effect_dict is Dictionary):
		return false
	return float(effect_dict.get("target", 0)) > 0.0 and has_tag(obj, "weapon")


func estimated_damage(obj: Variant) -> float:
	var effect_dict: Variant = read_ai(obj).get("effect", {})
	if effect_dict is Dictionary:
		return absf(float(effect_dict.get("target", 0)))
	return 0.0


func is_player_target(target: Variant) -> bool:
	return target != null and is_instance_valid(target) and target.has_method("is_player") and target.is_player()


func non_player_targets(candidates: Array) -> Array:
	var result: Array = []
	for target in candidates:
		if not is_player_target(target):
			result.append(target)
	return result


func score_damage_target(player: Variant, skill: Variant, target: Variant) -> float:
	if target == null or is_player_target(target):
		return -99.0
	var threat: float = _monster_threat(target)
	var dmg: float = estimated_damage(skill)
	var hp: float = float(target.get("hp")) if target.get("hp") != null else 0.0
	var lethal: bool = dmg > 0.0 and hp > 0.0 and dmg >= hp
	var score: float = threat
	if lethal:
		score += 50.0 + threat * 0.01
	if player != null and player.monster_zone != null and player.monster_zone.has(target):
		score += OWN_ZONE_THREAT_BONUS
	return score


func useful(player: Variant, card: Variant) -> float:
	if card == null:
		return 0.0
	var value: float = ai_useful(card)
	if value == 0.0:
		var skill: Variant = _primary_play_skill(card)
		if skill != null:
			value = ai_useful(skill)
	var needed: bool = hints.is_needed_card(card, _game_of(player))
	if needed:
		value += 15.0
	elif value >= 85.0 and not has_tag(card, "food") and not has_tag(card, "weapon") and not has_tag(card, "heal") and not has_tag(card, "fuel") and not has_tag(card, "ammo") and not _is_weapon_card(card):
		value = GENERIC_USEFUL_CAP
	if has_tag(card, "food") and player != null:
		var hunger: int = int(player.get("hunger"))
		if hunger >= 3:
			value += 12.0
		elif hunger >= 2:
			value += 5.0
	return clampf(value, 0.0, 100.0)


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
		return _heal_effect(player, target, player_part, target_part, att)
	if has_tag(obj, "food"):
		return _food_effect(player, target)
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


func score_grant_target(_player: Variant, target: Variant, skill: Variant = null) -> float:
	return _peek_best_action_score(target, _grant_types_of(skill))


func score_block(player: Variant, block: Variant) -> float:
	if block == null or not is_instance_valid(block):
		return -99.0
	var score: float = 0.0
	var dest: Variant = hints.nearest_travel_block(player)
	var obj_dist: int = hints.nearest_objective_distance(player)
	if dest != null and is_instance_valid(dest) and block.has_method("distance_to"):
		var after: int = block.distance_to(dest)
		score += float(obj_dist - after) * 2.0
	if block.has_method("has_objective_mark") and block.has_objective_mark():
		score += 3.0
	if block.has_method("count_monster_mark") and block.count_monster_mark() > 0:
		score -= float(block.count_monster_mark()) * HAZARD_MARK_PENALTY
	score -= _block_hazard(block)
	return score


func _score_card_action(player: Variant, card: Variant) -> float:
	if card == null or not is_instance_valid(card):
		return -99.0
	var skill: Variant = _primary_play_skill(card)
	var base: float = ai_order(card)
	if base == 0.0 and skill != null:
		base = ai_order(skill)
	if str(card.get("card_type")) == "equipment":
		base += 0.05 * useful(player, card)
		if _equipment_would_overflow(player, card) and not _has_same_name_equipped(player, card):
			base -= 4.0
			if not _is_weapon_card(card) and not hints.is_needed_card(card, _game_of(player)):
				base -= 8.0
		if not _is_weapon_card(card) and hints.is_staying_to_gather(player):
			base -= 6.0
		if _is_weapon_card(card) and _should_boost_weapon_equip(player):
			base += ENGAGED_WEAPON_EQUIP_BONUS
		return base
	if skill != null and has_tag(skill, "heal"):
		return _score_heal(player, skill)
	if skill != null and has_tag(skill, "food"):
		return _score_food(player, skill)
	if (skill != null and has_tag(skill, "grant_action")) or has_tag(card, "grant_action"):
		return _score_grant_action(player, skill if skill != null else card)
	if skill != null:
		base += _best_target_effect(player, skill)
		base += _situational_skill_bonus(player, skill)
	else:
		base += 0.025 * useful(player, card)
	return base


func _score_skill_action(player: Variant, skill: Variant) -> float:
	if skill == null or not is_instance_valid(skill):
		return -99.0
	if has_tag(skill, "heal"):
		return _score_heal(player, skill)
	if has_tag(skill, "food"):
		return _score_food(player, skill)
	if has_tag(skill, "grant_action"):
		return _score_grant_action(player, skill)
	if has_tag(skill, "hunger_ap"):
		return _score_hunger_ap(player, skill)
	if _is_balance_skill(skill):
		return _score_balance(player, skill)
	if _is_reveal_obj(skill) and not _has_unrevealed_for_skill(player, skill):
		return 0.0
	var base: float = ai_order(skill)
	if has_tag(skill, "mission") or str(skill.get("skill_type")) == "任务":
		base = maxf(base, 12.0)
		base += 4.0
	base += _best_target_effect(player, skill)
	base += _situational_skill_bonus(player, skill)
	return base


func _score_move(player: Variant, block: Variant) -> float:
	if player != null and player.monster_zone != null and player.monster_zone.size() > 0:
		return -99.0
	if hints.nearest_objective_distance(player) == 0:
		return 0.0
	var dest: Variant = hints.nearest_travel_block(player)
	if dest != null and is_instance_valid(dest) and block != null and block.has_method("distance_to"):
		var current_d: int = hints.nearest_objective_distance(player)
		if block.distance_to(dest) >= current_d:
			return 0.0
	var score: float = 4.0 + score_block(player, block)
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
	if pile_key != "game_deck" and hints.is_staying_to_gather(player) and hints.pile_has_needed_items(pile_key):
		score += GATHER_SCAVENGE_BONUS
	return score


func _best_target_effect(player: Variant, skill: Variant) -> float:
	if player == null or not player.has_method("get_skill_valid_targets"):
		return effect(player, skill, player)
	var select_n: int = int(skill.get("select_target")) if skill.get("select_target") != null else 0
	if select_n == 0 and str(skill.get("target_type")) == "":
		return effect(player, skill, player)
	var targets: Array = player.get_skill_valid_targets(skill)
	if is_damage_obj(skill):
		targets = non_player_targets(targets)
		if targets.is_empty():
			return -99.0
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
	if has_tag(skill, "ammo") and _has_underfilled_weapon(player, "ammo"):
		bonus += 4.0
	if has_tag(skill, "fuel") and _has_underfilled_weapon(player, "fuel"):
		bonus += 3.0
	if _is_refuel_skill(skill) and _mission_still_needs_fuel(player):
		bonus -= MISSION_REFUEL_PENALTY
	if has_tag(skill, "damage") and player != null and player.monster_zone != null and player.monster_zone.size() > 0:
		bonus += 3.0
	return bonus


func _damage_bonus(player: Variant, target: Variant) -> float:
	if target == null or not (target.has_method("is_monster") and target.is_monster()):
		return 0.0
	var bonus: float = _monster_threat(target) * 0.05
	if player != null and player.monster_zone != null and player.monster_zone.has(target):
		bonus += 6.0
	return bonus


func _score_heal(player: Variant, skill: Variant) -> float:
	var value: float = _best_target_effect(player, skill)
	if value <= 0.0:
		return 0.0
	return value


func _heal_effect(_player: Variant, target: Variant, player_part: float, target_part: float, att: float) -> float:
	var urgency: float = _heal_urgency(target)
	if urgency <= 0.0:
		return 0.0
	return player_part * 0.25 + urgency * 10.0 + att * 0.3 * absf(target_part)


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
	var raw: Variant = monster.get("ai_threat")
	if raw != null:
		return float(raw)
	return 0.0


func _is_weapon_card(card: Variant) -> bool:
	if has_tag(card, "weapon"):
		return true
	if card != null and card.get("weapon") == true:
		return true
	var skill: Variant = _primary_play_skill(card)
	return skill != null and has_tag(skill, "weapon")


func _primary_play_skill(card: Variant) -> Variant:
	if card == null or not card.has_method("get_all_skills"):
		return null
	for skill in card.get_all_skills():
		if skill != null and str(skill.get("active")) == "action":
			return skill
	return null


func _equipment_capacity(player: Variant) -> int:
	var cap: int = 4
	if player != null and player.role_card != null and is_instance_valid(player.role_card):
		cap = int(player.role_card.equipment_capacity)
	return cap


func _equipment_used_size(player: Variant) -> int:
	if player == null or player.equipment_zone == null:
		return 0
	var used: int = 0
	for e in player.equipment_zone:
		if e == null:
			continue
		used += int(e.get("size")) if e.get("size") != null else 0
	return used


func _card_size(card: Variant) -> int:
	if card == null:
		return 1
	if card.get("size") != null:
		return int(card.get("size"))
	return 1


func _equipment_would_overflow(player: Variant, card: Variant) -> bool:
	return _equipment_used_size(player) + _card_size(card) > _equipment_capacity(player)


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


func _block_hazard(block: Variant) -> float:
	if block == null or not is_instance_valid(block):
		return 0.0
	var total: float = 0.0
	var skills: Variant = block.get("skills")
	if not (skills is Array):
		return 0.0
	for skill in skills:
		total += float(read_ai(skill).get("hazard", 0))
	return total


func _score_food(player: Variant, skill: Variant) -> float:
	var select_n: int = int(skill.get("select_target")) if skill.get("select_target") != null else 0
	var value: float = 0.0
	if select_n == 0 and str(skill.get("target_type")) == "":
		value = _party_food_score(player)
	else:
		value = _best_target_effect(player, skill)
	if value <= 0.0:
		return 0.0
	return ai_order(skill) + value


func _party_food_score(player: Variant) -> float:
	var best: float = 0.0
	var game: Variant = _game_of(player)
	var people: Array = []
	if game != null and game.has_method("get_all_players"):
		people = game.get_all_players()
	elif game != null and game.get("players") is Array:
		people = game.get("players")
	if people.is_empty() and player != null:
		people = [player]
	for who in people:
		var s: float = _food_effect(player, who)
		if s > best:
			best = s
	return best


func _food_effect(player: Variant, target: Variant) -> float:
	if target == null or not is_instance_valid(target):
		return 0.0
	var hunger: int = int(target.get("hunger")) if target.get("hunger") != null else 0
	var value: float = _food_hunger_value(hunger)
	if value <= 0.0:
		return 0.0
	if player != null and target == player:
		return value + 1.0
	var self_hunger: int = int(player.get("hunger")) if player != null and player.get("hunger") != null else 0
	if self_hunger >= hunger:
		return value * 0.7
	return value * 0.9


func _food_hunger_value(hunger: int) -> float:
	if hunger <= 1:
		return 0.0
	if hunger >= 5:
		return 8.0
	if hunger >= 3:
		return 5.0
	return 1.5


func _score_grant_action(player: Variant, skill: Variant) -> float:
	if player == null or not player.has_method("get_skill_valid_targets"):
		return 0.0
	var grant_types: Array = _grant_types_of(skill)
	var best: float = 0.0
	for target in player.get_skill_valid_targets(skill):
		if not is_player_target(target):
			continue
		var s: float = _peek_best_action_score(target, grant_types)
		if s > best:
			best = s
	if best <= 0.0:
		return 0.0
	return ai_order(skill) + best * GRANT_ACTION_WEIGHT


func _grant_types_of(skill: Variant) -> Array:
	var raw: Variant = read_ai(skill).get("grant_types", [])
	return raw if raw is Array else []


func _should_boost_weapon_equip(player: Variant) -> bool:
	if player == null or player.monster_zone == null or player.monster_zone.size() <= 0:
		return false
	return not _has_usable_equipped_weapon_attack(player)


func _has_usable_equipped_weapon_attack(player: Variant) -> bool:
	if player == null or player.get("skills") == null:
		return false
	for skill in player.skills:
		if skill == null or not is_instance_valid(skill):
			continue
		if not has_tag(skill, "weapon") or not has_tag(skill, "damage"):
			continue
		if player.has_method("can_use_active_skill") and player.can_use_active_skill(skill):
			return true
	return false


func _score_hunger_ap(player: Variant, _skill: Variant) -> float:
	if player == null:
		return 0.0
	var hunger: int = int(player.get("hunger"))
	if hunger >= 3:
		return 0.0
	if player.get_effective_action_count() > 0:
		return 0.0
	var saved_ap: int = player.action_count
	var saved_phase: String = str(player.get("in_phase"))
	player.in_phase = "action"
	player.action_count = maxi(saved_ap, 1)
	var best: float = _peek_best_action_score(player)
	player.action_count = saved_ap
	player.in_phase = saved_phase
	if best <= 0.0:
		return 0.0
	return 2.0 + minf(best * 0.2, 3.0)


func _score_balance(player: Variant, _skill: Variant) -> float:
	if player == null or player.hand == null:
		return 0.0
	var scored: Array = []
	for card in player.hand:
		if card == null:
			continue
		if str(card.get("source")) == "scavenge":
			continue
		scored.append(card)
	if scored.size() < 2:
		return 0.0
	scored.sort_custom(func(a, b): return useful(player, a) < useful(player, b))
	var u1: float = useful(player, scored[0])
	var u2: float = useful(player, scored[1])
	var score: float = 5.0 - BALANCE_USEFUL_WEIGHT * (u1 + u2)
	if _is_priority_keep_card(player, scored[0]) or _is_priority_keep_card(player, scored[1]):
		score -= 8.0
	return score


func _is_priority_keep_card(player: Variant, card: Variant) -> bool:
	if card == null:
		return false
	if _is_weapon_card(card) or has_tag(card, "weapon") or has_tag(card, "heal") or has_tag(card, "food"):
		return true
	var skill: Variant = _primary_play_skill(card)
	if skill != null and (has_tag(skill, "heal") or has_tag(skill, "weapon") or has_tag(skill, "food")):
		return true
	return hints.is_needed_card(card, _game_of(player))


func _is_balance_skill(skill: Variant) -> bool:
	if skill == null:
		return false
	return str(skill.get("english_name")) == "balance" or str(skill.get("skill_name")) == "制衡"


func _is_refuel_skill(skill: Variant) -> bool:
	if skill == null:
		return false
	return str(skill.get("english_name")) == "refuel" or str(skill.get("skill_name")) == "加油"


func _mission_still_needs_fuel(player: Variant) -> bool:
	return hints.remaining_needed_count("燃料", _game_of(player)) > 0


func _is_reveal_obj(obj: Variant) -> bool:
	if obj == null:
		return false
	if has_tag(obj, "reveal"):
		return true
	return str(obj.get("english_name")) == "binoculars"


func _has_unrevealed_for_skill(player: Variant, skill: Variant) -> bool:
	if player == null or not player.has_method("get_current_block"):
		return false
	var current: Variant = player.get_current_block()
	if current == null or not is_instance_valid(current):
		return false
	var range_str: String = str(skill.get("range")) if skill != null and skill.get("range") != null else ""
	if range_str == "":
		range_str = "long"
	if current.has_method("has_unrevealed_block_in_range"):
		return current.has_unrevealed_block_in_range(range_str)
	return false


func _peek_best_action_score(player: Variant, allowed_types: Variant = null) -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	if _score_depth >= 1:
		return 0.0
	_score_depth += 1
	var saved_phase: String = str(player.get("in_phase"))
	var saved_ap: int = int(player.get("action_count"))
	player.in_phase = "action"
	if player.get_effective_action_count() < 1:
		player.action_count = 1
	var best: float = 0.0
	var actions: Array = LegalActionsScript.enumerate(player, allowed_types)
	for action in actions:
		if _should_skip_peek(action):
			continue
		var score: float = score_action(player, action)
		if score > best:
			best = score
	player.action_count = saved_ap
	player.in_phase = saved_phase
	_score_depth -= 1
	return best


func _should_skip_peek(action: Dictionary) -> bool:
	var skill: Variant = action.get("skill")
	var card: Variant = action.get("card")
	if has_tag(skill, "grant_action") or has_tag(card, "grant_action"):
		return true
	if has_tag(skill, "hunger_ap") or has_tag(card, "hunger_ap"):
		return true
	if skill != null and _is_balance_skill(skill):
		return true
	return false


func _game_of(_player: Variant) -> Variant:
	return Game
