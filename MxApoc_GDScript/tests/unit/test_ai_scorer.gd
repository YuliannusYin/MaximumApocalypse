extends TestBase

## AiScorer 态度与效果分。

const AiScorerScript = preload("res://src/ai/ai_scorer.gd")


func test_attitude_self_ally_enemy() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("A")
	var ally: Player = _make_player("B")
	var monster: Monster = Monster.new()
	assert_eq(scorer.attitude(p, p), AiScorerScript.ATT_SELF)
	assert_eq(scorer.attitude(p, ally), AiScorerScript.ATT_ALLY)
	assert_eq(scorer.attitude(p, monster), AiScorerScript.ATT_ENEMY)


func test_damage_effect_positive_vs_monster_negative_vs_ally() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("A")
	p.max_hp = 10
	p.hp = 10
	var ally: Player = _make_player("B")
	ally.max_hp = 10
	ally.hp = 10
	var monster: Monster = Monster.new()
	monster.hp = 6
	monster.max_hp = 6
	monster.damage_value = 3
	monster.monster_level = "normal"
	var skill := Skill.new()
	skill.ai = {"order": 9, "useful": 0, "tags": ["damage"], "effect": {"player": 0, "target": 2}}
	assert_gt(scorer.effect(p, skill, monster), 0.0, "伤害打怪物应为正")
	assert_lt(scorer.effect(p, skill, ally), 0.0, "伤害打队友应为负")


func test_needed_mission_item_boosts_useful() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("A")
	var card: Card = _make_card("燃料")
	card.ai = {"order": 0, "useful": 2}
	Game.mission_config = MissionConfig.new()
	var component: MissionComponent = MissionComponentAddVanFuel.new()
	component.params = {"card_name": "燃料"}
	Game.mission_config.action_components.append(component)
	assert_gt(scorer.useful(p, card), 2.0, "任务需求物资 useful 应加权")
	assert_eq(scorer.useful(p, card), 17.0, "任务加成应为 +15")


func test_prefer_high_threat_and_lethal_targets() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("A")
	var high: Monster = Monster.new()
	high.hp = 10
	high.max_hp = 10
	high.ai_threat = 80
	var lethal: Monster = Monster.new()
	lethal.hp = 2
	lethal.max_hp = 2
	lethal.ai_threat = 30
	var skill := Skill.new()
	skill.ai = {"order": 9, "useful": 0, "tags": ["damage"], "effect": {"player": 0, "target": 2}}
	assert_gt(scorer.score_damage_target(p, skill, high), scorer.score_damage_target(p, skill, lethal) - 50.0, "高威胁应高于同条件低威胁")
	var low_unlethal: Monster = Monster.new()
	low_unlethal.hp = 10
	low_unlethal.max_hp = 10
	low_unlethal.ai_threat = 30
	assert_gt(scorer.score_damage_target(p, skill, lethal), scorer.score_damage_target(p, skill, high), "一击毙命可压过不能击杀的高威胁")
	assert_gt(scorer.score_damage_target(p, skill, high), scorer.score_damage_target(p, skill, low_unlethal), "同不能击杀时高威胁优先")


func test_monster_instantiate_copies_threat() -> void:
	var card: MonsterCard = _make_monster_card()
	card.ai = {"threat": 42}
	var monster: Monster = card.instantiate(null)
	assert_eq(monster.ai_threat, 42)


func _setup_rescue_fuel_map() -> Dictionary:
	var mc := MissionConfig.new()
	var rescue := MissionComponentSpendActionRescue.new()
	rescue.params = {"block_name": "警察局"}
	var fuel := MissionComponentAddVanFuel.new()
	fuel.params = {"block_name": "面包车", "card_name": "燃料", "count": 4}
	var rally := MissionComponentAllPlayersAtBlock.new()
	rally.params = {"block_name": "面包车"}
	mc.action_components = [rescue, fuel]
	mc.win_condition_components = [rally]
	Game.mission_config = mc
	mc.setup_components(Game)
	var van: MapBlock = _make_block("面包车", 0, 0, true)
	var east: MapBlock = _make_block("旷野", 1, 0, true)
	var west: MapBlock = _make_block("旷野", -1, 0, true)
	var police: MapBlock = _make_block("警察局", 2, 0, true)
	Game.map_area = [van, east, west, police]
	return {"van": van, "east": east, "west": west, "police": police}


func test_score_block_prefers_neighbor_toward_police() -> void:
	var blocks: Dictionary = _setup_rescue_fuel_map()
	var p: Player = _make_player("AI")
	p.current_block = blocks["van"]
	p.action_count = 4
	var scorer = AiScorerScript.new()
	assert_gt(
		scorer.score_block(p, blocks["east"]),
		scorer.score_block(p, blocks["west"]),
		"朝警察局的邻格应高于反方向"
	)
	assert_gt(
		scorer.score_action(p, {"type": "move", "target": blocks["east"]}),
		scorer.score_action(p, {"type": "move", "target": blocks["west"]}),
		"主动移动应朝警察局走"
	)


func _setup_mission0_hole_map() -> Dictionary:
	var coords: Array = [
		[0, 0], [1, 0], [2, 0], [3, 0], [4, 0],
		[0, 1], [1, 1], [2, 1], [4, 1], [5, 1],
		[1, 2], [2, 2], [3, 2], [4, 2],
	]
	var by_coord: Dictionary = {}
	var map_area: Array = []
	for c in coords:
		var block_name: String = "旷野"
		if int(c[0]) == 5 and int(c[1]) == 1:
			block_name = "面包车"
		var block: MapBlock = _make_block(block_name, int(c[0]), int(c[1]), true)
		map_area.append(block)
		by_coord["%d,%d" % [int(c[0]), int(c[1])]] = block
	Game.map_area = map_area
	var rally := MissionComponentAllPlayersAtBlock.new()
	rally.params = {"block_name": "面包车"}
	var mc := MissionConfig.new()
	mc.win_condition_components = [rally]
	Game.mission_config = mc
	mc.setup_components(Game)
	return by_coord


func test_score_move_detours_hole_instead_of_camping() -> void:
	var blocks: Dictionary = _setup_mission0_hole_map()
	var p: Player = _make_player("AI")
	p.current_block = blocks["2,1"]
	p.action_count = 4
	var scorer = AiScorerScript.new()
	assert_eq(scorer.hints.nearest_objective_distance(p), 5, "到面包车的图距离应为 5")
	assert_gt(
		scorer.score_action(p, {"type": "move", "target": blocks["2,0"]}),
		0.0,
		"东侧有空洞时应绕北/南走，而不是所有移动为 0"
	)
	assert_lte(
		scorer.score_action(p, {"type": "move", "target": blocks["1,1"]}),
		0.0,
		"西邻离面包车更远，移动分应 ≤ 0"
	)


func test_score_move_zero_when_already_at_travel_dest() -> void:
	_setup_rescue_fuel_map()
	var p: Player = _make_player("AI")
	p.current_block = Game.map_area[0]
	p.action_count = 4
	p.hand.append(_make_card("燃料"))
	var scorer = AiScorerScript.new()
	var east: MapBlock = Game.map_area[1]
	assert_lte(scorer.score_action(p, {"type": "move", "target": east}), 0.0, "已在最近行动点时移动分应 ≤ 0")


func test_heal_full_hp_scores_zero() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("AI", 10, 10)
	p.hp = 10
	p.max_hp = 10
	p.in_phase = "action"
	p.action_count = 4
	var block: MapBlock = _make_block("购物中心", 0, 0, true)
	Game.map_area = [block]
	Game.players = [p]
	p.current_block = block
	var skill := Skill.new()
	skill.skill_name = "缝合"
	skill.english_name = "suture"
	skill.active = "action"
	skill.select_target = 1
	skill.filter_target_range = "short"
	skill.ai = {"order": 6, "useful": 0, "tags": ["heal"], "effect": {"player": 1, "target": 2}}
	p.add_skill(skill)
	assert_lte(scorer.score_action(p, {"type": "skill", "skill": skill}), 0.0, "满血治疗分应 ≤ 0")
	assert_eq(scorer.effect(p, skill, p), 0.0, "满血治疗效果分应为 0")


func test_own_zone_beats_higher_threat_ally_monster() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("AI")
	var own: Monster = Monster.new()
	own.hp = 4
	own.max_hp = 4
	own.ai_threat = 23
	var other: Monster = Monster.new()
	other.hp = 12
	other.max_hp = 12
	other.ai_threat = 57
	p.monster_zone.append(own)
	var skill := Skill.new()
	skill.ai = {"order": 9, "useful": 0, "tags": ["damage"], "effect": {"player": 0, "target": 2}}
	assert_gt(
		scorer.score_damage_target(p, skill, own),
		scorer.score_damage_target(p, skill, other),
		"自己怪物区的怪应高于更高 threat 的别人的怪"
	)


func test_gather_scavenge_beats_leaving_gas() -> void:
	var mc := MissionConfig.new()
	var fuel := MissionComponentAddVanFuel.new()
	fuel.params = {"block_name": "面包车", "card_name": "燃料", "count": 4}
	var rally := MissionComponentAllPlayersAtBlock.new()
	rally.params = {"block_name": "面包车"}
	mc.action_components = [fuel]
	mc.win_condition_components = [rally]
	Game.mission_config = mc
	mc.setup_components(Game)
	var gas: MapBlock = _make_block("加油站", 0, 0, true)
	gas.scavenge_colors = PackedStringArray(["red"])
	var wild: MapBlock = _make_block("旷野", 1, 0, true)
	var van: MapBlock = _make_block("面包车", 3, 0, true)
	Game.map_area = [gas, wild, van]
	Game.red_scavenge_pile = Pile.new()
	Game.red_scavenge_pile.add(_make_scavenge_card("燃料", "red"))
	var p: Player = _make_player("AI")
	p.current_block = gas
	p.action_count = 4
	Game.players = [p]
	var scorer = AiScorerScript.new()
	assert_gt(
		scorer.score_action(p, {"type": "pile_draw", "pile_key": "red_scavenge"}),
		scorer.score_action(p, {"type": "move", "target": wild}),
		"采集格拾荒应高于离开加油站"
	)


func test_hazard_lowers_wilderness_block_score() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("AI")
	var safe: MapBlock = _make_block("避难所", 0, 0, true)
	var wild: MapBlock = _make_block("旷野", 1, 0, true)
	var hazard := Skill.new()
	hazard.ai = {"order": 0, "useful": 0, "hazard": 6}
	wild.add_skill(hazard)
	p.current_block = safe
	assert_gt(scorer.score_block(p, safe), scorer.score_block(p, wild), "有 hazard 的旷野应低于安全格")


func test_food_prefers_hungry_self_over_fed_ally() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("AI")
	p.hunger = 6
	var ally: Player = _make_player("Ally")
	ally.hunger = 1
	var block: MapBlock = _make_block("购物中心", 0, 0, true)
	Game.map_area = [block]
	Game.players = [p, ally]
	p.current_block = block
	ally.current_block = block
	var skill := Skill.new()
	skill.select_target = 1
	skill.filter_target_range = "short"
	skill.ai = {"order": 5, "useful": 0, "tags": ["food"], "effect": {"player": 2, "target": 0}}
	assert_gt(scorer.effect(p, skill, p), scorer.effect(p, skill, ally), "研钵应优先饥饿的自己")
	assert_eq(scorer.effect(p, skill, ally), 0.0, "目标饥饿 ≤ 1 时食物分应为 0")
	p.add_skill(skill)
	assert_gt(scorer.score_action(p, {"type": "skill", "skill": skill}), 0.0, "自己饥饿时应出食物技能")


func test_refuel_loses_to_move_toward_van_when_fuel_still_needed() -> void:
	var mc := MissionConfig.new()
	var fuel := MissionComponentAddVanFuel.new()
	fuel.params = {"block_name": "面包车", "card_name": "燃料", "count": 4}
	var rally := MissionComponentAllPlayersAtBlock.new()
	rally.params = {"block_name": "面包车"}
	mc.action_components = [fuel]
	mc.win_condition_components = [rally]
	Game.mission_config = mc
	mc.setup_components(Game)
	var van: MapBlock = _make_block("面包车", 0, 0, true)
	var east: MapBlock = _make_block("旷野", 1, 0, true)
	Game.map_area = [van, east]
	var p: Player = _make_player("AI")
	p.current_block = east
	p.action_count = 4
	p.in_phase = "action"
	p.hand.append(_make_card("燃料"))
	Game.players = [p]
	var bike: EquipmentCard = _make_equipment("摩托车")
	bike.charge_type = "fuel"
	bike.charge_max = 2
	bike.charge_current = 0
	p.equipment_zone.append(bike)
	var refuel := Skill.new()
	refuel.english_name = "refuel"
	refuel.skill_name = "加油"
	refuel.ai = {"order": 5, "useful": 0, "tags": ["fuel"], "effect": {"player": 1, "target": 0}}
	p.add_skill(refuel)
	var scorer = AiScorerScript.new()
	assert_gt(
		scorer.score_action(p, {"type": "move", "target": van}),
		scorer.score_action(p, {"type": "skill", "skill": refuel}),
		"任务仍缺燃料时朝面包车走应高于给载具加油"
	)


func test_balance_scores_nonpositive_when_discarding_weapons() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 4
	var gun: Card = _make_card("猎枪")
	gun.ai = {"order": 8, "useful": 80, "tags": ["weapon"]}
	var kit: Card = _make_card("急救包")
	kit.ai = {"order": 6, "useful": 70, "tags": ["heal"]}
	p.hand.append(gun)
	p.hand.append(kit)
	var skill := Skill.new()
	skill.english_name = "balance"
	skill.skill_name = "制衡"
	skill.ai = {"order": 3, "useful": 0, "tags": ["draw"], "effect": {"player": 1, "target": 0}}
	assert_lte(scorer.score_action(p, {"type": "skill", "skill": skill}), 0.0, "制衡丢掉武器/治疗时应 ≤ 0")


func test_grant_action_prefers_teammate_with_real_play() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 4
	var fighter: Player = _make_player("Fighter")
	fighter.in_phase = "action"
	fighter.action_count = 4
	var idle: Player = _make_player("Idle")
	idle.in_phase = "action"
	idle.action_count = 4
	var block: MapBlock = _make_block("旷野", 0, 0, true)
	Game.map_area = [block]
	Game.players = [p, fighter, idle]
	p.current_block = block
	fighter.current_block = block
	idle.current_block = block
	var monster: Monster = Monster.new()
	monster.hp = 5
	monster.max_hp = 5
	monster.ai_threat = 40
	fighter.monster_zone.append(monster)
	var punch := Skill.new()
	punch.english_name = "punch"
	punch.active = "action"
	punch.select_target = 1
	punch.filter_target_range = "short"
	punch.ai = {"order": 9, "useful": 0, "tags": ["damage"], "effect": {"player": 0, "target": 2}}
	fighter.add_skill(punch)
	assert_gt(scorer.score_grant_target(p, fighter), scorer.score_grant_target(p, idle), "对讲机应选有实着的队友")
	var grant := Skill.new()
	grant.english_name = "walkie_talkie"
	grant.select_target = 1
	grant.filter_target_range = "infinity"
	grant.ai = {"order": 4, "useful": 0, "tags": ["grant_action"], "effect": {"player": 1, "target": 0}}
	assert_gt(scorer.score_action(p, {"type": "skill", "skill": grant}), 0.0, "有可行动队友时支援分应为正")


func test_size_full_nonweapon_equip_scores_below_zero() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("AI")
	p.role_card = RoleCard.new()
	p.role_card.equipment_capacity = 4
	var turret: EquipmentCard = _make_equipment("自动炮塔")
	turret.size = 2
	turret.ai = {"order": 8, "useful": 80, "tags": ["weapon"]}
	var mine: EquipmentCard = _make_equipment("感应地雷")
	mine.size = 1
	var pistol: EquipmentCard = _make_equipment("手枪")
	pistol.size = 1
	pistol.weapon = true
	pistol.ai = {"order": 8, "useful": 80, "tags": ["weapon"]}
	p.equipment_zone.append(turret)
	p.equipment_zone.append(mine)
	p.equipment_zone.append(pistol)
	var binoculars: EquipmentCard = _make_equipment("双筒望远镜")
	binoculars.size = 1
	binoculars.card_type = "equipment"
	binoculars.ai = {"order": 3, "useful": 58, "tags": ["equip"]}
	assert_lt(scorer.score_action(p, {"type": "card", "card": binoculars}), 0.0, "size 已满时望远镜挤装分应低于 0")


func test_unneeded_spare_parts_do_not_outrank_food_when_hungry() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("AI")
	p.hunger = 4
	var parts: Card = _make_card("多余配件")
	parts.ai = {"order": 0, "useful": 90}
	var food: Card = _make_card("食物（大量）")
	food.ai = {"order": 5, "useful": 70, "tags": ["food"]}
	assert_gt(scorer.useful(p, food), scorer.useful(p, parts), "饥饿时食物 useful 应高于非任务配件")


func _punch_skill() -> Skill:
	var skill := Skill.new()
	skill.skill_name = "拳打"
	skill.english_name = "punch"
	skill.active = "action"
	skill.select_target = 1
	skill.filter_target_range = "short"
	skill.ai = {"order": 9, "useful": 0, "tags": ["damage"], "effect": {"player": 0, "target": 2}}
	return skill


func _ready_combat_player() -> Player:
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 4
	var block: MapBlock = _make_block("旷野", 0, 0, true)
	Game.map_area = [block]
	Game.players = [p]
	p.current_block = block
	var monster: Monster = Monster.new()
	monster.hp = 5
	monster.max_hp = 5
	monster.ai_threat = 40
	p.monster_zone.append(monster)
	p.add_skill(_punch_skill())
	return p


func test_axe_skill_outscores_punch() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _ready_combat_player()
	var axe := Skill.new()
	axe.english_name = "reliable_axe"
	axe.active = "action"
	axe.select_target = 1
	axe.filter_target_range = "short"
	axe.ai = {"order": 9, "useful": 0, "tags": ["damage", "weapon"], "effect": {"player": 0, "target": 4}}
	p.add_skill(axe)
	var punch_score: float = scorer.score_action(p, {"type": "skill", "skill": p.skills[0]})
	var axe_score: float = scorer.score_action(p, {"type": "skill", "skill": axe})
	assert_gt(axe_score, punch_score, "斧子 4 伤应压过拳打")


func test_unarmed_weapon_equip_outscores_punch_when_engaged() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _ready_combat_player()
	var gun: EquipmentCard = _make_equipment("猎枪")
	gun.weapon = true
	gun.ai = {"order": 8, "useful": 80, "tags": ["equip", "weapon"]}
	p.hand.append(gun)
	var punch_score: float = scorer.score_action(p, {"type": "skill", "skill": p.skills[0]})
	var equip_score: float = scorer.score_action(p, {"type": "card", "card": gun})
	assert_gt(equip_score, punch_score, "有怪未武装时装备武器应压过拳打")


func test_equipped_weapon_outscores_equipping_another() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _ready_combat_player()
	var lighter := Skill.new()
	lighter.english_name = "lighter"
	lighter.active = "action"
	lighter.select_target = -1
	lighter.filter_target_range = "short"
	lighter.filter_target = func(_player, target, _event, _game) -> bool:
		return target != null and target.has_method("is_monster") and target.is_monster()
	lighter.ai = {"order": 9, "useful": 0, "tags": ["damage", "aoe", "weapon"], "effect": {"player": 0, "target": 3}}
	p.add_skill(lighter)
	var gun: EquipmentCard = _make_equipment("猎枪")
	gun.weapon = true
	gun.ai = {"order": 8, "useful": 80, "tags": ["equip", "weapon"]}
	p.hand.append(gun)
	var attack_score: float = scorer.score_action(p, {"type": "skill", "skill": lighter})
	var equip_score: float = scorer.score_action(p, {"type": "card", "card": gun})
	assert_gt(attack_score, equip_score, "已有可用武器时不应为再装备而放弃攻击")


func test_grant_types_card_ignores_punch() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("Doctor")
	p.in_phase = "action"
	p.action_count = 4
	var puncher: Player = _make_player("Puncher")
	puncher.in_phase = "action"
	puncher.action_count = 4
	var armed: Player = _make_player("Armed")
	armed.in_phase = "action"
	armed.action_count = 4
	var block: MapBlock = _make_block("旷野", 0, 0, true)
	Game.map_area = [block]
	Game.players = [p, puncher, armed]
	p.current_block = block
	puncher.current_block = block
	armed.current_block = block
	var monster: Monster = Monster.new()
	monster.hp = 5
	monster.max_hp = 5
	monster.ai_threat = 40
	puncher.monster_zone.append(monster)
	var punch := _punch_skill()
	puncher.add_skill(punch)
	var gun: EquipmentCard = _make_equipment("猎枪")
	gun.weapon = true
	gun.ai = {"order": 8, "useful": 80, "tags": ["equip", "weapon"]}
	armed.hand.append(gun)
	var steroid := Skill.new()
	steroid.english_name = "steroid_injection"
	steroid.select_target = 1
	steroid.filter_target_range = "infinity"
	steroid.filter_target = func(_player, target, _event, _game) -> bool:
		return target != null and target.has_method("is_player") and target.is_player()
	steroid.ai = {"order": 5, "useful": 0, "tags": ["grant_action"], "grant_types": ["card"], "effect": {"player": 1, "target": 0}}
	assert_gt(scorer.score_grant_target(p, armed, steroid), scorer.score_grant_target(p, puncher, steroid), "类固醇只看手牌，不应把只会拳打的人评更高")


func test_grant_action_includes_self() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _ready_combat_player()
	var grant := Skill.new()
	grant.english_name = "adrenaline_injection"
	grant.select_target = 1
	grant.filter_target_range = "infinity"
	grant.filter_target = func(_player, target, _event, _game) -> bool:
		return target != null and target.has_method("is_player") and target.is_player()
	grant.ai = {"order": 5, "useful": 0, "tags": ["grant_action"], "effect": {"player": 1, "target": 0}}
	assert_gt(scorer.score_action(p, {"type": "skill", "skill": grant}), 0.0, "可自用的支援牌在自己有实着时应为正")


func _setup_fuel_van_east() -> Dictionary:
	var mc := MissionConfig.new()
	var fuel := MissionComponentAddVanFuel.new()
	fuel.params = {"block_name": "面包车", "card_name": "燃料", "count": 4}
	var rally := MissionComponentAllPlayersAtBlock.new()
	rally.params = {"block_name": "面包车"}
	mc.action_components = [fuel]
	mc.win_condition_components = [rally]
	Game.mission_config = mc
	mc.setup_components(Game)
	var van: MapBlock = _make_block("面包车", 0, 0, true)
	var east: MapBlock = _make_block("旷野", 1, 0, true)
	var far: MapBlock = _make_block("农场", 2, 0, true)
	Game.map_area = [van, east, far]
	return {"van": van, "east": east, "far": far}


func test_courier_move_beats_scout_draw_and_repair() -> void:
	var blocks: Dictionary = _setup_fuel_van_east()
	var p: Player = _make_player("AI")
	p.current_block = blocks["east"]
	p.action_count = 4
	p.in_phase = "action"
	p.hand.append(_make_card("燃料"))
	Game.players = [p]
	p.game_deck.add(_make_card("junk"))
	var scout := Skill.new()
	scout.english_name = "scout"
	scout.ai = {"order": 3, "useful": 0, "tags": ["reveal"], "effect": {"player": 1, "target": 0}}
	var repair := Skill.new()
	repair.english_name = "repair"
	repair.ai = {"order": 4, "useful": 0, "tags": ["draw"], "effect": {"player": 1, "target": 0}}
	p.add_skill(scout)
	p.add_skill(repair)
	var scorer = AiScorerScript.new()
	var move_score: float = scorer.score_action(p, {"type": "move", "target": blocks["van"]})
	assert_gt(move_score, scorer.score_action(p, {"type": "skill", "skill": scout}), "持有燃料时朝面包车走应高于侦察")
	assert_gt(move_score, scorer.score_action(p, {"type": "pile_draw", "pile_key": "game_deck"}), "持有燃料时朝面包车走应高于抽游戏牌")
	assert_gt(move_score, scorer.score_action(p, {"type": "skill", "skill": repair}), "持有燃料时朝面包车走应高于维修")


func test_equip_that_would_discard_fuel_scores_zero_unless_engaged_weapon() -> void:
	_setup_fuel_van_east()
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("AI")
	p.role_card = RoleCard.new()
	p.role_card.equipment_capacity = 1
	p.in_phase = "action"
	p.action_count = 4
	var fuel: EquipmentCard = _make_equipment("燃料")
	fuel.english_name = "fuel"
	fuel.size = 1
	fuel.charge_type = "fuel"
	fuel.ai = {"order": 0, "useful": 90, "tags": ["fuel"]}
	p.equipment_zone.append(fuel)
	Game.players = [p]
	var binoculars: EquipmentCard = _make_equipment("双筒望远镜")
	binoculars.size = 1
	binoculars.card_type = "equipment"
	binoculars.ai = {"order": 3, "useful": 58, "tags": ["equip"]}
	assert_lte(scorer.score_action(p, {"type": "card", "card": binoculars}), 0.0, "没纠缠时挤掉燃料的装备分应 ≤ 0")
	var gun: EquipmentCard = _make_equipment("猎枪")
	gun.weapon = true
	gun.size = 1
	gun.ai = {"order": 8, "useful": 80, "tags": ["equip", "weapon"]}
	var monster: Monster = Monster.new()
	monster.hp = 5
	monster.max_hp = 5
	monster.ai_threat = 40
	p.monster_zone.append(monster)
	assert_gt(scorer.score_action(p, {"type": "card", "card": gun}), 0.0, "纠缠时装武器即使会挤燃料仍可为正")


func test_stretcher_zero_when_same_tile_positive_when_pull_helps() -> void:
	var blocks: Dictionary = _setup_fuel_van_east()
	var scorer = AiScorerScript.new()
	var doc: Player = _make_player("Doc")
	var ally: Player = _make_player("Ally")
	doc.in_phase = "action"
	doc.action_count = 4
	ally.in_phase = "action"
	ally.action_count = 4
	doc.current_block = blocks["van"]
	ally.current_block = blocks["van"]
	Game.players = [doc, ally]
	var pull := Skill.new()
	pull.english_name = "stretcher"
	pull.skill_name = "轮床"
	pull.select_target = 1
	pull.filter_target_range = "long"
	pull.filter_target = func(_player, target, _event, _game) -> bool:
		return target != null and target.has_method("is_player") and target.is_player() and target != _player
	pull.ai = {"order": 1, "useful": 0, "tags": ["pull"], "effect": {"player": 1, "target": 0}}
	doc.add_skill(pull)
	assert_lte(scorer.score_action(doc, {"type": "skill", "skill": pull}), 0.0, "同格轮床分应 ≤ 0")
	assert_lte(scorer.score_pull_target(doc, ally), 0.0, "同格拉近目标分应 ≤ 0")
	ally.current_block = blocks["far"]
	assert_gt(scorer.score_pull_target(doc, ally), 0.0, "队友远离目标且拉近有效时应为正")
	assert_gt(scorer.score_action(doc, {"type": "skill", "skill": pull}), 0.0, "有效轮床行动分应为正")


func test_camouflage_scores_below_equipped_weapon_attack() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _ready_combat_player()
	var axe := Skill.new()
	axe.english_name = "reliable_axe"
	axe.active = "action"
	axe.select_target = 1
	axe.filter_target_range = "short"
	axe.ai = {"order": 9, "useful": 0, "tags": ["damage", "weapon"], "effect": {"player": 0, "target": 4}}
	p.add_skill(axe)
	var camo := Skill.new()
	camo.english_name = "camouflage_discard"
	camo.skill_name = "伪装"
	camo.ai = {"order": 2, "useful": 0, "tags": ["stealth"], "effect": {"player": 0, "target": 0}}
	p.add_skill(camo)
	assert_gt(
		scorer.score_action(p, {"type": "skill", "skill": axe}),
		scorer.score_action(p, {"type": "skill", "skill": camo}),
		"伪装应低于已装备武器攻击"
	)


func test_last_ap_punch_beats_weapon_equip() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _ready_combat_player()
	p.action_count = 1
	var gun: EquipmentCard = _make_equipment("猎枪")
	gun.weapon = true
	gun.ai = {"order": 8, "useful": 80, "tags": ["equip", "weapon"]}
	p.hand.append(gun)
	assert_gt(
		scorer.score_action(p, {"type": "skill", "skill": p.skills[0]}),
		scorer.score_action(p, {"type": "card", "card": gun}),
		"最后 1 点行动应优先出伤害而不是换装"
	)


func test_skip_hunger_only_when_starving_without_food() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("AI")
	p.hunger = 2
	p.in_phase = "action"
	p.action_count = 4
	var drink := Skill.new()
	drink.english_name = "energy_drink"
	drink.ai = {"order": 4, "useful": 0, "tags": ["skip_hunger"], "effect": {"player": 1, "target": 0}}
	assert_lte(scorer.score_action(p, {"type": "skill", "skill": drink}), 0.0, "不饿时能量饮料应 ≤ 0")
	p.hunger = 6
	assert_gt(scorer.score_action(p, {"type": "skill", "skill": drink}), 0.0, "饥饿且没食物时能量饮料应为正")
	var food: Card = _make_card("食物（小额）")
	food.ai = {"order": 5, "useful": 70, "tags": ["food"]}
	p.hand.append(food)
	assert_lte(scorer.score_action(p, {"type": "skill", "skill": drink}), 0.0, "手里有食物时不应靠能量饮料拖饥饿")


func test_grant_action_zero_when_best_peek_is_game_deck() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 4
	var idle: Player = _make_player("Idle")
	idle.in_phase = "action"
	idle.action_count = 4
	idle.game_deck.add(_make_card("junk"))
	var block: MapBlock = _make_block("旷野", 0, 0, true)
	Game.map_area = [block]
	Game.players = [p, idle]
	p.current_block = block
	idle.current_block = block
	var grant := Skill.new()
	grant.english_name = "walkie_talkie"
	grant.select_target = 1
	grant.filter_target_range = "infinity"
	grant.filter_target = func(_player, target, _event, _game) -> bool:
		return target != null and target.has_method("is_player") and target.is_player()
	grant.ai = {"order": 4, "useful": 0, "tags": ["grant_action"], "effect": {"player": 1, "target": 0}}
	p.add_skill(grant)
	assert_lte(scorer.score_action(p, {"type": "skill", "skill": grant}), 0.0, "支援若只能抽游戏牌应 ≤ 0")


func test_needed_equipment_target_is_penalized() -> void:
	_setup_fuel_van_east()
	var scorer = AiScorerScript.new()
	var p: Player = _make_player("AI")
	var fuel: EquipmentCard = _make_equipment("燃料")
	fuel.english_name = "fuel"
	fuel.in_equipment_area = true
	var gun: EquipmentCard = _make_equipment("自动炮塔")
	gun.in_equipment_area = true
	var skill := Skill.new()
	skill.english_name = "homemade_bullets"
	skill.ai = {"order": 5, "useful": 0, "tags": ["ammo"], "effect": {"player": 1, "target": 0}}
	assert_lt(scorer.score_skill_target(p, skill, fuel), scorer.score_skill_target(p, skill, gun), "自制子弹不应优先打任务燃料")


func test_same_name_weapon_reequip_scores_zero() -> void:
	var scorer = AiScorerScript.new()
	var p: Player = _ready_combat_player()
	var turret: EquipmentCard = _make_equipment("自动炮塔")
	turret.weapon = true
	turret.ai = {"order": 8, "useful": 80, "tags": ["equip", "weapon"]}
	p.equipment_zone.append(turret)
	var turret2: EquipmentCard = _make_equipment("自动炮塔")
	turret2.weapon = true
	turret2.ai = {"order": 8, "useful": 80, "tags": ["equip", "weapon"]}
	p.hand.append(turret2)
	assert_lte(scorer.score_action(p, {"type": "card", "card": turret2}), 0.0, "已装备同名武器再装应 ≤ 0")

