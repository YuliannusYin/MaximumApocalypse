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
