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
const COURIER_MOVE_BONUS := 8.0
const COURIER_IDLE_PENALTY := 8.0
const NEEDED_TARGET_PENALTY := -99.0
const STARVE_FOOD_BONUS := 4.0
const STARVE_SCAVENGE_FOOD_BONUS := 6.0
const PULL_BASE := 2.0
const CAMOUFLAGE_ESCAPE := 2.0
const SKIP_HUNGER_SCORE := 6.0
const DUPLICATE_EQUIP_PENALTY := 40.0
const REPAIR_DUPLICATE_PENALTY := 8.0
const LETHAL_ACTION_BONUS := 12.0
const AOE_WEAPON_EQUIP_BONUS := 18.0
const ENGAGED_IDLE_PENALTY := 10.0
const TEAM_BUFF_BASE := 6.0
const TEAM_BUFF_PER_FIGHTER := 6.0
const STUN_BASE := 8.0
const MARK_CLEAR_WEIGHT := 6.0
const ALLY_SPLASH_WEIGHT := 8.0
const GRENADE_SPLASH := 3.0
const WILDERNESS_LEAVE_BONUS := 40.0
const PARTY_SPREAD_MAX := 2
const FOLLOW_CLOSE_BONUS := 3.0

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
	if _is_card_like(item):
		if _should_avoid_needed_target(obj, item):
			return NEEDED_TARGET_PENALTY
		return useful(player, item)
	if item != null and item.has_method("is_map_block") and item.is_map_block():
		return score_block(player, item)
	if item != null and item.has_method("is_player") and item.is_player():
		if obj != null and (has_tag(obj, "pull") or _is_pull_skill(obj)):
			return score_pull_target(player, item)
		return attitude(player, item)
	return 0.0


func retrieve_card_score(player: Variant, card: Variant) -> float:
	var value: float = useful(player, card)
	if _has_same_name_equipped(player, card) and not _is_fuel_card(card):
		value -= DUPLICATE_EQUIP_PENALTY
	return value


func score_skill_target(player: Variant, skill: Variant, target: Variant) -> float:
	if is_damage_obj(skill):
		return score_damage_target(player, skill, target)
	if has_tag(skill, "grant_action"):
		return score_grant_target(player, target, skill)
	if has_tag(skill, "pull") or _is_pull_skill(skill):
		return score_pull_target(player, target)
	if _should_avoid_needed_target(skill, target):
		return NEEDED_TARGET_PENALTY
	return effect(player, skill, target)


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
	var peeked: Dictionary = _peek_best_action(target, _grant_types_of(skill))
	if _is_unproductive_grant_peek(peeked):
		return 0.0
	return score_action(target, peeked)


func score_block(player: Variant, block: Variant) -> float:
	if block == null or not is_instance_valid(block):
		return -99.0
	var score: float = 0.0
	var dest: Variant = hints.nearest_travel_block(player)
	var obj_dist: int = hints.nearest_objective_distance(player)
	if dest != null and is_instance_valid(dest):
		var after: int = hints.path_distance(block, dest)
		score += float(obj_dist - after) * 2.0
	if block.has_method("has_objective_mark") and block.has_objective_mark():
		score += 3.0
	if block.has_method("count_monster_mark") and block.count_monster_mark() > 0:
		score -= float(block.count_monster_mark()) * HAZARD_MARK_PENALTY
	score -= _block_hazard(block)
	return score


func score_clear_marks_block(player: Variant, block: Variant) -> float:
	if block == null or not is_instance_valid(block):
		return -99.0
	var marks: int = 0
	if block.has_method("count_monster_mark"):
		marks = int(block.count_monster_mark())
	if marks <= 0:
		return 0.0
	var score: float = float(marks) * MARK_CLEAR_WEIGHT
	var dest: Variant = hints.nearest_travel_block(player)
	if dest != null and is_instance_valid(dest):
		if dest == block:
			score += 10.0
		else:
			var dist: int = hints.path_distance(block, dest)
			score += maxf(0.0, 6.0 - float(dist))
	return score


func _score_card_action(player: Variant, card: Variant) -> float:
	if card == null or not is_instance_valid(card):
		return -99.0
	var skill: Variant = _primary_play_skill(card)
	var base: float = ai_order(card)
	if base == 0.0 and skill != null:
		base = ai_order(skill)
	if str(card.get("card_type")) == "equipment":
		if _wilderness_blocks_staying(player, card):
			return 0.0
		return _score_equip_card(player, card, base)
	if skill != null and has_tag(skill, "heal"):
		return _score_heal(player, skill)
	if skill != null and has_tag(skill, "food"):
		return _score_food(player, skill)
	if (skill != null and has_tag(skill, "grant_action")) or has_tag(card, "grant_action"):
		return _score_grant_action(player, skill if skill != null else card)
	if skill != null and (has_tag(skill, "skip_hunger") or has_tag(card, "skip_hunger") or _is_skip_hunger_skill(skill)):
		return _score_skip_hunger(player)
	if skill != null and (has_tag(skill, "pull") or _is_pull_skill(skill)):
		return _score_pull(player, skill)
	if skill != null and (_is_stun_obj(skill) or _is_stun_obj(card)):
		return _score_stun(player, skill)
	if skill != null and (_is_team_buff_obj(skill) or _is_team_buff_obj(card)):
		return _score_team_buff(player, skill if skill != null else card)
	if _is_volley_obj(skill) or _is_volley_obj(card):
		return _score_volley(player, skill if skill != null else card)
	if skill != null:
		base += _best_target_effect(player, skill)
		base += _situational_skill_bonus(player, skill)
	else:
		base += 0.025 * useful(player, card)
	if _is_courier(player) and _is_courier_idle_obj(skill if skill != null else card):
		base -= COURIER_IDLE_PENALTY
	if _is_engaged(player) and _is_engaged_idle_obj(skill if skill != null else card):
		base -= ENGAGED_IDLE_PENALTY
	if _wilderness_blocks_staying(player, skill if skill != null else card):
		return 0.0
	return base


func _score_skill_action(player: Variant, skill: Variant) -> float:
	if skill == null or not is_instance_valid(skill):
		return -99.0
	if _is_punch_skill(skill) and _has_usable_equipped_weapon_attack(player):
		return 0.0
	if has_tag(skill, "heal"):
		return _score_heal(player, skill)
	if has_tag(skill, "food"):
		return _score_food(player, skill)
	if has_tag(skill, "grant_action"):
		if _is_on_must_leave(player):
			return 0.0
		return _score_grant_action(player, skill)
	if has_tag(skill, "hunger_ap"):
		if _is_on_must_leave(player):
			return 0.0
		return _score_hunger_ap(player, skill)
	if has_tag(skill, "skip_hunger") or _is_skip_hunger_skill(skill):
		if _is_on_must_leave(player):
			return 0.0
		return _score_skip_hunger(player)
	if has_tag(skill, "pull") or _is_pull_skill(skill):
		if _is_on_must_leave(player):
			return 0.0
		return _score_pull(player, skill)
	if _is_stun_obj(skill):
		return _score_stun(player, skill)
	if _is_team_buff_obj(skill):
		return _score_team_buff(player, skill)
	if _is_volley_obj(skill):
		return _score_volley(player, skill)
	if _is_camouflage_discard(skill):
		if _is_on_must_leave(player):
			return 0.0
		return _score_camouflage_discard(player)
	if _is_balance_skill(skill):
		if _is_on_must_leave(player):
			return 0.0
		return _score_balance(player, skill)
	if _is_reveal_obj(skill) and not _has_unrevealed_for_skill(player, skill):
		return 0.0
	var base: float = ai_order(skill)
	if has_tag(skill, "mission") or str(skill.get("skill_type")) == "任务":
		base = maxf(base, 12.0)
		base += 4.0
	base += _best_target_effect(player, skill)
	base += _situational_skill_bonus(player, skill)
	if _is_courier(player) and _is_courier_idle_obj(skill):
		base -= COURIER_IDLE_PENALTY
	if _is_engaged(player) and _is_engaged_idle_obj(skill):
		base -= ENGAGED_IDLE_PENALTY
	if _wilderness_blocks_staying(player, skill):
		return 0.0
	return base


func _score_move(player: Variant, block: Variant) -> float:
	var current: Variant = _current_block_of(player)
	var leaving: bool = _is_must_leave_block(current) and not _is_must_leave_block(block)
	if _is_engaged(player) and not leaving:
		return -99.0
	if leaving:
		var leave_score: float = WILDERNESS_LEAVE_BONUS + score_block(player, block)
		return maxf(leave_score, 8.0)
	if hints.nearest_objective_distance(player) == 0:
		return 0.0
	var dest: Variant = hints.nearest_travel_block(player)
	if dest != null and is_instance_valid(dest) and block != null:
		var current_d: int = hints.nearest_objective_distance(player)
		if hints.path_distance(block, dest) >= current_d:
			return 0.0
	var score: float = 4.0 + score_block(player, block)
	if _is_courier(player):
		score += COURIER_MOVE_BONUS
	if player != null and player.get_effective_action_count() <= 1:
		score -= 1.0
		if _block_forces_stealth(block) or _is_must_leave_block(block):
			return 0.0
	var cohesion: float = _cohesion_move_adjust(player, block)
	if cohesion < 0.0:
		return 0.0
	score += cohesion
	return score


func _score_pile_draw(player: Variant, pile_key: String) -> float:
	if _is_engaged(player):
		return 0.0
	if _is_on_must_leave(player):
		return 0.0
	if pile_key == "game_deck" and _player_is_starving(player):
		return 0.0
	var score: float = 3.5
	if player != null and player.hand != null and player.hand.size() >= 8:
		score -= 2.0
	if pile_key != "game_deck":
		score += 0.5
	if player != null and int(player.get("hunger")) >= 4:
		score += 1.0
	if pile_key != "game_deck" and hints.is_staying_to_gather(player) and hints.pile_has_needed_items(pile_key):
		score += GATHER_SCAVENGE_BONUS
	if pile_key != "game_deck" and _player_is_starving(player) and hints.pile_has_food(pile_key):
		score += STARVE_SCAVENGE_FOOD_BONUS
	if _is_courier(player):
		score -= COURIER_IDLE_PENALTY
	return score


func _best_target_effect(player: Variant, skill: Variant) -> float:
	if player == null or not player.has_method("get_skill_valid_targets"):
		return effect(player, skill, player)
	var select_n: int = int(skill.get("select_target")) if skill.get("select_target") != null else 0
	if select_n == 0 and str(skill.get("target_type")) == "":
		return effect(player, skill, player)
	var raw: Array = player.get_skill_valid_targets(skill)
	var ally_penalty: float = 0.0
	if is_damage_obj(skill) and (has_tag(skill, "aoe") or select_n < 0):
		for t in raw:
			if is_player_target(t):
				ally_penalty += ALLY_SPLASH_WEIGHT * estimated_damage(skill)
	var targets: Array = raw
	if is_damage_obj(skill):
		targets = non_player_targets(raw)
		if targets.is_empty():
			return -99.0
	if targets.is_empty():
		return 0.0
	if select_n < 0:
		var total: float = 0.0
		for t in targets:
			total += _score_damage_hit(player, skill, t) if is_damage_obj(skill) else effect(player, skill, t)
		return total - ally_penalty
	if is_damage_obj(skill) and _is_grenade_obj(skill):
		return _score_grenade(player, skill, targets)
	var best: float = -99.0
	for t in targets:
		var s: float = _score_damage_hit(player, skill, t) if is_damage_obj(skill) else effect(player, skill, t)
		if s > best:
			best = s
	return (best if best > -99.0 else 0.0) - ally_penalty


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
	if _is_repair_skill(skill) and _repair_best_is_duplicate(player):
		bonus -= REPAIR_DUPLICATE_PENALTY
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
	if _player_is_starving(player):
		value += STARVE_FOOD_BONUS
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
		return 8.0 + STARVE_FOOD_BONUS
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
		var peeked: Dictionary = _peek_best_action(target, grant_types)
		if _is_unproductive_grant_peek(peeked):
			continue
		var s: float = score_action(target, peeked)
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
	if player.has_method("get_effective_action_count") and player.get_effective_action_count() <= 1:
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
	var peeked: Dictionary = _peek_best_action(player, allowed_types)
	if peeked.is_empty():
		return 0.0
	return score_action(player, peeked)


func _peek_best_action(player: Variant, allowed_types: Variant = null) -> Dictionary:
	if player == null or not is_instance_valid(player):
		return {}
	if _score_depth >= 1:
		return {}
	_score_depth += 1
	var saved_phase: String = str(player.get("in_phase"))
	var saved_ap: int = int(player.get("action_count"))
	player.in_phase = "action"
	if player.get_effective_action_count() < 1:
		player.action_count = 1
	var best: Dictionary = {}
	var best_score: float = 0.0
	var actions: Array = LegalActionsScript.enumerate(player, allowed_types)
	for action in actions:
		if _should_skip_peek(action):
			continue
		var score: float = score_action(player, action)
		if score > best_score:
			best_score = score
			best = action
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


func _is_courier(player: Variant) -> bool:
	return hints.player_holds_needed_item(player, _game_of(player))


func _score_equip_card(player: Variant, card: Variant, base: float) -> float:
	if _has_same_name_equipped(player, card) and not _is_fuel_card(card):
		return 0.0
	if _overflow_would_discard_needed(player, card) and not _may_drop_needed_for_weapon(player, card):
		return 0.0
	if _is_on_must_leave(player) and not _is_weapon_card(card):
		return 0.0
	base += 0.05 * useful(player, card)
	if _equipment_would_overflow(player, card) and not _has_same_name_equipped(player, card):
		base -= 4.0
		if not _is_weapon_card(card) and not hints.is_needed_card(card, _game_of(player)):
			base -= 8.0
	if not _is_weapon_card(card) and hints.is_staying_to_gather(player):
		base -= 6.0
	if not _is_weapon_card(card) and _is_courier(player):
		base -= COURIER_IDLE_PENALTY
	if _is_weapon_card(card) and _has_usable_equipped_weapon_attack(player):
		if _is_aoe_weapon_card(card) and _tile_monster_count(player) >= 2 and not _equipment_would_overflow(player, card):
			base += AOE_WEAPON_EQUIP_BONUS
		else:
			return 0.0
	elif _is_weapon_card(card) and _should_boost_weapon_equip(player):
		base += ENGAGED_WEAPON_EQUIP_BONUS
	return base


func _may_drop_needed_for_weapon(player: Variant, card: Variant) -> bool:
	if not _is_weapon_card(card):
		return false
	if player == null or player.monster_zone == null:
		return false
	return player.monster_zone.size() > 0


func _overflow_would_discard_needed(player: Variant, card: Variant) -> bool:
	if player == null or card == null or player.equipment_zone == null:
		return false
	if not _equipment_would_overflow(player, card):
		return false
	var kept: Array = []
	var used: int = 0
	for e in player.equipment_zone:
		if e == null:
			continue
		if not _is_fuel_card(card) and str(e.get("card_name")) == str(card.get("card_name")):
			continue
		kept.append(e)
		used += _card_size(e)
	var cap: int = _equipment_capacity(player)
	var need: int = used + _card_size(card) - cap
	if need <= 0:
		return false
	kept.sort_custom(func(a, b): return useful(player, a) < useful(player, b))
	var freed: int = 0
	for e in kept:
		freed += _card_size(e)
		if hints.is_needed_card(e, _game_of(player)):
			return true
		if freed >= need:
			return false
	return false


func _should_avoid_needed_target(obj: Variant, target: Variant) -> bool:
	if obj == null:
		return false
	if has_tag(obj, "mission") or str(obj.get("skill_type")) == "任务":
		return false
	if not _is_card_like(target):
		return false
	return hints.is_needed_card(target, Game)


func _is_card_like(item: Variant) -> bool:
	if item == null:
		return false
	if item.get("card_type") != null:
		return true
	if item.get("card_name") != null and item.get("in_equipment_area") == true:
		return true
	return false


func _is_fuel_card(card: Variant) -> bool:
	if card == null:
		return false
	return str(card.get("english_name")) == "fuel" or hints.matches_item_family(str(card.get("card_name")), "燃料")


func _is_courier_idle_obj(obj: Variant) -> bool:
	if obj == null:
		return false
	if has_tag(obj, "draw") or has_tag(obj, "reveal"):
		return true
	var english_name: String = str(obj.get("english_name"))
	return english_name == "repair" or english_name == "scout" or english_name == "resourceful" or english_name == "binoculars"


func _player_is_starving(player: Variant) -> bool:
	if player == null:
		return false
	if int(player.get("hunger")) >= 5:
		return true
	if player.has_method("has_mark") and player.has_mark("hunger_damage_level"):
		return true
	if player.has_method("count_mark") and int(player.count_mark("hunger_damage_level")) > 0:
		return true
	return false


func _player_has_food(player: Variant) -> bool:
	if player == null or player.get("hand") == null:
		return false
	for card in player.hand:
		if card == null:
			continue
		if has_tag(card, "food"):
			return true
		var skill: Variant = _primary_play_skill(card)
		if skill != null and has_tag(skill, "food"):
			return true
		if hints.matches_item_family(str(card.get("card_name")), "食物"):
			return true
	return false


func _score_skip_hunger(player: Variant) -> float:
	if not _player_is_starving(player):
		return 0.0
	if _player_has_food(player):
		return 0.0
	return SKIP_HUNGER_SCORE


func _is_skip_hunger_skill(skill: Variant) -> bool:
	if skill == null:
		return false
	return str(skill.get("english_name")) == "energy_drink"


func _is_pull_skill(skill: Variant) -> bool:
	if skill == null:
		return false
	return str(skill.get("english_name")) == "stretcher" or str(skill.get("skill_name")) == "轮床"


func score_pull_target(player: Variant, target: Variant) -> float:
	if player == null or target == null or not is_instance_valid(target):
		return 0.0
	if not is_player_target(target) or target == player:
		return 0.0
	if target.get("monster_zone") != null and target.monster_zone.size() > 0:
		return 0.0
	var dest: Variant = hints.nearest_travel_block(target)
	if dest == null or not is_instance_valid(dest):
		return 0.0
	var ally_block: Variant = target.get_current_block() if target.has_method("get_current_block") else target.get("current_block")
	var self_block: Variant = player.get_current_block() if player.has_method("get_current_block") else player.get("current_block")
	if ally_block == null or self_block == null:
		return 0.0
	var ally_dist: int = hints.path_distance(ally_block, dest)
	if ally_dist < 2:
		return 0.0
	var self_dist: int = hints.path_distance(self_block, dest)
	if self_dist >= ally_dist:
		return 0.0
	return PULL_BASE + minf(float(ally_dist - self_dist), 2.0)


func _score_pull(player: Variant, skill: Variant) -> float:
	if player == null or not player.has_method("get_skill_valid_targets"):
		return 0.0
	var best: float = 0.0
	for target in player.get_skill_valid_targets(skill):
		var s: float = score_pull_target(player, target)
		if s > best:
			best = s
	return best


func _is_camouflage_discard(skill: Variant) -> bool:
	if skill == null:
		return false
	return str(skill.get("english_name")) == "camouflage_discard" or str(skill.get("skill_name")) == "伪装"


func _score_camouflage_discard(player: Variant) -> float:
	if player == null or player.monster_zone == null or player.monster_zone.size() <= 0:
		return 0.0
	var hp: int = int(player.get_hp()) if player.has_method("get_hp") else int(player.get("hp"))
	if hp <= 3:
		return 0.0
	if _has_usable_equipped_weapon_attack(player):
		return 0.0
	var min_hp: int = 99
	for monster in player.monster_zone:
		if monster == null:
			continue
		var mhp: int = int(monster.get("hp")) if monster.get("hp") != null else 0
		if mhp > 0 and mhp < min_hp:
			min_hp = mhp
	var ap: int = player.get_effective_action_count() if player.has_method("get_effective_action_count") else 0
	if ap * 2 >= min_hp:
		return 0.0
	return CAMOUFLAGE_ESCAPE


func _is_repair_skill(skill: Variant) -> bool:
	if skill == null:
		return false
	return str(skill.get("english_name")) == "repair" or str(skill.get("skill_name")) == "维修"


func _repair_best_is_duplicate(player: Variant) -> bool:
	var game: Variant = _game_of(player)
	if game == null or not game.has_method("get_all_discard_pile_equipments"):
		return false
	var list: Array = game.get_all_discard_pile_equipments()
	if list.is_empty():
		return false
	var best_card: Variant = null
	var best_u: float = -1.0
	for card in list:
		if card == null:
			continue
		var u: float = useful(player, card)
		if u > best_u:
			best_u = u
			best_card = card
	if best_card == null:
		return false
	return _has_same_name_equipped(player, best_card)


func _is_unproductive_grant_peek(action: Dictionary) -> bool:
	if action.is_empty():
		return true
	var action_type: String = str(action.get("type", ""))
	if action_type == "pile_draw" and str(action.get("pile_key", "")) == "game_deck":
		return true
	if has_tag(action.get("skill"), "grant_action") or has_tag(action.get("card"), "grant_action"):
		return true
	return false


func action_damage_key(action: Dictionary) -> float:
	var skill: Variant = action.get("skill")
	if skill == null:
		skill = _primary_play_skill(action.get("card"))
	if skill == null or not is_damage_obj(skill):
		return 0.0
	return estimated_damage(skill)


func _score_damage_hit(player: Variant, skill: Variant, target: Variant) -> float:
	if is_player_target(target):
		return -ALLY_SPLASH_WEIGHT * estimated_damage(skill)
	var score: float = effect(player, skill, target)
	var dmg: float = estimated_damage(skill)
	var hp: float = float(target.get("hp")) if target.get("hp") != null else 0.0
	if dmg > 0.0 and hp > 0.0 and dmg >= hp:
		score += LETHAL_ACTION_BONUS
	score += dmg * 0.01
	return score


func _score_grenade(player: Variant, skill: Variant, monsters: Array) -> float:
	var best: float = -99.0
	for primary in monsters:
		var score: float = _score_damage_hit(player, skill, primary)
		for other in _monsters_on_same_tile(player, primary):
			if other == primary:
				continue
			score += GRENADE_SPLASH * 2.0 + _damage_bonus(player, other)
		for ally in _players_on_same_tile(primary):
			if ally == player:
				continue
			score -= ALLY_SPLASH_WEIGHT * GRENADE_SPLASH
		if score > best:
			best = score
	return best if best > -99.0 else 0.0


func _score_stun(player: Variant, skill: Variant) -> float:
	if player == null or not player.has_method("get_skill_valid_targets"):
		return 0.0
	var monsters: Array = non_player_targets(player.get_skill_valid_targets(skill))
	if monsters.size() < 2:
		return 0.0
	var total_hp: float = 0.0
	var incoming: float = 0.0
	for monster in monsters:
		if monster == null:
			continue
		total_hp += float(monster.get("hp")) if monster.get("hp") != null else 0.0
		incoming += _monster_attack(monster)
	if incoming <= 0.0:
		return 0.0
	var ap: int = player.get_effective_action_count() if player.has_method("get_effective_action_count") else 0
	var best_dmg: float = _best_equipped_weapon_damage(player)
	if ap > 0 and best_dmg * float(ap) >= total_hp:
		var hp: int = int(player.get_hp()) if player.has_method("get_hp") else int(player.get("hp"))
		if incoming < float(hp):
			return 0.0
	return ai_order(skill) + STUN_BASE + incoming * 2.0 + float(monsters.size()) * 3.0


func _score_team_buff(player: Variant, skill: Variant) -> float:
	var fighters: int = _engaged_fighter_count(player)
	if fighters <= 0:
		return 0.0
	return ai_order(skill) + TEAM_BUFF_BASE + TEAM_BUFF_PER_FIGHTER * float(fighters)


func _score_volley(player: Variant, skill: Variant) -> float:
	var ammo: int = 0
	if player != null and player.has_method("get_total_charge_count"):
		ammo = int(player.get_total_charge_count("ammo"))
	if ammo <= 0:
		return 0.0
	var dump_dmg: float = float(ammo * 2)
	var monsters: Array = []
	if player != null and player.has_method("get_skill_valid_targets"):
		monsters = non_player_targets(player.get_skill_valid_targets(skill))
	if monsters.is_empty():
		return 0.0
	var lethal_tank: bool = false
	var best: float = 0.0
	for target in monsters:
		var hp: float = float(target.get("hp")) if target.get("hp") != null else 0.0
		var hit: float = dump_dmg * 2.0 + _damage_bonus(player, target)
		if dump_dmg > 0.0 and hp > 0.0 and dump_dmg >= hp:
			hit += LETHAL_ACTION_BONUS
			if hp >= 8.0:
				lethal_tank = true
		if hit > best:
			best = hit
	if ammo > 3 and not lethal_tank:
		return 0.0
	return ai_order(skill) + best


func _is_punch_skill(skill: Variant) -> bool:
	if skill == null:
		return false
	return str(skill.get("english_name")) == "punch" or str(skill.get("skill_name")) == "拳打"


func _is_stun_obj(obj: Variant) -> bool:
	if obj == null:
		return false
	if has_tag(obj, "stun"):
		return true
	return str(obj.get("english_name")) == "fire_extinguisher" or str(obj.get("skill_name")) == "灭火器"


func _is_team_buff_obj(obj: Variant) -> bool:
	if obj == null:
		return false
	if has_tag(obj, "team_buff"):
		return true
	return str(obj.get("english_name")) == "check_weapon" or str(obj.get("skill_name")) == "检查武器"


func _is_volley_obj(obj: Variant) -> bool:
	if obj == null:
		return false
	return str(obj.get("english_name")) == "volley" or str(obj.get("skill_name")) == "齐射"


func _is_grenade_obj(obj: Variant) -> bool:
	if obj == null:
		return false
	return str(obj.get("english_name")) == "grenade" or str(obj.get("skill_name")) == "手榴弹"


func _is_engaged(player: Variant) -> bool:
	return player != null and player.monster_zone != null and player.monster_zone.size() > 0


func _is_must_leave_block(block: Variant) -> bool:
	return hints.is_must_leave_block(block) if hints != null else LegalActionsScript.is_must_leave_block(block)


func _current_block_of(player: Variant) -> Variant:
	if player == null:
		return null
	if player.has_method("get_current_block"):
		return player.get_current_block()
	return player.get("current_block")


func _is_on_must_leave(player: Variant) -> bool:
	return _is_must_leave_block(_current_block_of(player))


func _can_clear_zone_and_leave(player: Variant) -> bool:
	if not _is_on_must_leave(player):
		return true
	var ap: int = player.get_effective_action_count() if player != null and player.has_method("get_effective_action_count") else 0
	if ap <= 1:
		return false
	if not _is_engaged(player):
		return true
	var dmg: float = _best_equipped_weapon_damage(player)
	if dmg <= 0.0:
		return false
	var hits: int = 0
	for monster in player.monster_zone:
		if monster == null:
			continue
		var hp: float = float(monster.get("hp")) if monster.get("hp") != null else 0.0
		if hp <= 0.0:
			continue
		hits += int(ceili(hp / dmg))
	return ap >= hits + 1


func _has_safe_leave(player: Variant) -> bool:
	var current: Variant = _current_block_of(player)
	if not _is_must_leave_block(current) or current == null:
		return false
	if not current.has_method("get_adjacent_blocks"):
		return false
	for adj in current.get_adjacent_blocks():
		if adj != null and is_instance_valid(adj) and not _is_must_leave_block(adj):
			return true
	return false


func _wilderness_blocks_staying(player: Variant, obj: Variant) -> bool:
	if not _is_on_must_leave(player):
		return false
	if obj == null:
		return true
	if has_tag(obj, "heal") or has_tag(obj, "food"):
		return false
	if is_damage_obj(obj) or has_tag(obj, "weapon"):
		if _can_clear_zone_and_leave(player):
			return false
		return _has_safe_leave(player)
	return _has_safe_leave(player)


func _cohesion_move_adjust(player: Variant, block: Variant) -> float:
	if player == null or block == null:
		return 0.0
	var game: Variant = _game_of(player)
	if not hints.has_living_allies(player, game):
		return 0.0
	var after_near: int = hints.nearest_ally_distance(player, block, game)
	if after_near > PARTY_SPREAD_MAX:
		return -1.0
	var leader: Variant = hints.party_leader(player, game)
	if leader == null or not is_instance_valid(leader):
		return 0.0
	var current: Variant = _current_block_of(player)
	if leader != player:
		var leader_block: Variant = hints.follow_anchor_block(leader, game)
		if leader_block == null:
			return 0.0
		var before_lead: int = hints.path_distance(current, leader_block)
		var after_lead: int = hints.path_distance(block, leader_block)
		if before_lead >= PARTY_SPREAD_MAX and after_lead > before_lead:
			return -1.0
		if after_lead < before_lead:
			return FOLLOW_CLOSE_BONUS
		return 0.0
	var before_max: int = hints.max_ally_distance(player, current, game)
	var after_max: int = hints.max_ally_distance(player, block, game)
	if after_max > PARTY_SPREAD_MAX and after_max > before_max:
		return -1.0
	return 0.0


func _is_engaged_idle_obj(obj: Variant) -> bool:
	if obj == null:
		return false
	if is_damage_obj(obj) or has_tag(obj, "heal") or has_tag(obj, "food") or has_tag(obj, "stun") or has_tag(obj, "team_buff") or has_tag(obj, "weapon"):
		return false
	if _is_stun_obj(obj) or _is_team_buff_obj(obj):
		return false
	if has_tag(obj, "draw") or has_tag(obj, "reveal") or has_tag(obj, "buff"):
		return true
	var english_name: String = str(obj.get("english_name"))
	return english_name == "upgrade" or english_name == "binoculars" or english_name == "search_corpse" or english_name == "scout" or english_name == "repair" or english_name == "resourceful"


func _is_aoe_weapon_card(card: Variant) -> bool:
	if not _is_weapon_card(card):
		return false
	if has_tag(card, "aoe"):
		return true
	var skill: Variant = _primary_play_skill(card)
	return skill != null and has_tag(skill, "aoe")


func _tile_monster_count(player: Variant) -> int:
	var seen: Dictionary = {}
	var count: int = 0
	if player != null and player.monster_zone != null:
		for monster in player.monster_zone:
			if monster == null or not is_instance_valid(monster):
				continue
			var id: int = monster.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			count += 1
	var block: Variant = null
	if player != null and player.has_method("get_current_block"):
		block = player.get_current_block()
	if block == null or not is_instance_valid(block) or not block.has_method("get_players"):
		return count
	for ally in block.get_players():
		if ally == null or ally.monster_zone == null:
			continue
		for monster in ally.monster_zone:
			if monster == null or not is_instance_valid(monster):
				continue
			var mid: int = monster.get_instance_id()
			if seen.has(mid):
				continue
			seen[mid] = true
			count += 1
	return count


func _engaged_fighter_count(player: Variant) -> int:
	var people: Array = _party_of(player)
	var n: int = 0
	for who in people:
		if who == null or not is_instance_valid(who):
			continue
		if who.has_method("is_alive") and not who.is_alive():
			continue
		if who.monster_zone != null and who.monster_zone.size() > 0:
			n += 1
	return n


func _party_of(player: Variant) -> Array:
	var game: Variant = _game_of(player)
	if game != null and game.has_method("get_all_players"):
		return game.get_all_players()
	if game != null and game.get("players") is Array:
		return game.get("players")
	if player != null:
		return [player]
	return []


func _monster_attack(monster: Variant) -> float:
	if monster == null:
		return 0.0
	if monster.get("damage_value") != null:
		return float(monster.get("damage_value"))
	return 0.0


func _best_equipped_weapon_damage(player: Variant) -> float:
	var best: float = 2.0
	if player == null or player.get("skills") == null:
		return best
	for skill in player.skills:
		if skill == null or not is_instance_valid(skill):
			continue
		if not has_tag(skill, "weapon") or not has_tag(skill, "damage"):
			continue
		if player.has_method("can_use_active_skill") and not player.can_use_active_skill(skill):
			continue
		best = maxf(best, estimated_damage(skill))
	return best


func _monsters_on_same_tile(player: Variant, target: Variant) -> Array:
	var result: Array = []
	var block: Variant = _block_of_combat_target(player, target)
	if block == null or not is_instance_valid(block) or not block.has_method("get_players"):
		if player != null and player.monster_zone != null:
			return player.monster_zone.duplicate()
		return result
	var seen: Dictionary = {}
	for ally in block.get_players():
		if ally == null or ally.monster_zone == null:
			continue
		for monster in ally.monster_zone:
			if monster == null or not is_instance_valid(monster):
				continue
			var id: int = monster.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			result.append(monster)
	return result


func _players_on_same_tile(target: Variant) -> Array:
	var block: Variant = null
	if target != null and target.has_method("get_current_block"):
		block = target.get_current_block()
	if block == null and target != null:
		block = target.get("current_block")
	if block == null or not is_instance_valid(block) or not block.has_method("get_players"):
		return []
	return block.get_players()


func _block_of_combat_target(player: Variant, target: Variant) -> Variant:
	if target != null and target.has_method("get_current_block"):
		var block: Variant = target.get_current_block()
		if block != null:
			return block
	if player != null and player.has_method("get_current_block"):
		return player.get_current_block()
	return null


func _block_forces_stealth(block: Variant) -> bool:
	if block == null or not is_instance_valid(block):
		return false
	if block.has_method("count_monster_mark") and int(block.count_monster_mark()) > 0:
		return true
	if str(block.get("block_name")) == "河流" or str(block.get("english_name")) == "river":
		return true
	var skills: Variant = block.get("skills")
	if skills is Array:
		for skill in skills:
			if skill != null and str(skill.get("english_name")) == "river":
				return true
	return false


func is_clear_marks_prompt(prompt: String) -> bool:
	return prompt.contains("无人机") or prompt.to_lower().contains("drone")
