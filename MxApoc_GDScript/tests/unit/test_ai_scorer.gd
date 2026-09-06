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
