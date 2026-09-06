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
