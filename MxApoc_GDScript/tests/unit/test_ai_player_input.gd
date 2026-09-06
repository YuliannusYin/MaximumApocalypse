extends TestBase

## AIPlayerInput 决策：攻击优先、无预算结束、选牌留高 useful。

const AIPlayerInputScript = preload("res://src/ai/ai_player_input.gd")


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
	p.is_ai = true
	var block: MapBlock = _make_block("旷野", 0, 0, true)
	Game.map_area = [block]
	Game.players = [p]
	p.current_block = block
	var monster: Monster = Monster.new()
	monster.hp = 5
	monster.max_hp = 5
	monster.damage_value = 3
	monster.monster_level = "normal"
	p.monster_zone.append(monster)
	p.add_skill(_punch_skill())
	return p


func test_ai_wait_action_prefers_attack_skill() -> void:
	var p: Player = _ready_combat_player()
	var input = AIPlayerInputScript.new()
	input.think_seconds = 0.0
	p.input = input
	var choice: Variant = await input.wait_action(p)
	assert_true(choice is Dictionary, "有合法攻击时应返回行动字典")
	assert_eq(choice.get("type"), "skill", "有怪时应优先技能攻击")
	assert_eq(choice.get("skill").english_name, "punch")


func test_ai_wait_action_ends_when_no_budget() -> void:
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 0
	var input = AIPlayerInputScript.new()
	var choice: Variant = await input.wait_action(p)
	assert_null(choice, "无高分行动应结束回合")


func test_choose_card_keeps_high_useful() -> void:
	var p: Player = _make_player("AI")
	var keep: Card = _make_card("燃料")
	keep.ai = {"order": 0, "useful": 9}
	var junk: Card = _make_card("junk")
	junk.ai = {"order": 0, "useful": 1}
	var input = AIPlayerInputScript.new()
	input.set_request_owner(p)
	var picked: Array = await input.choose_card(1, [keep, junk], null, "选择一张牌")
	assert_eq(picked.size(), 1)
	assert_eq(picked[0], keep, "应留下高 useful 的牌")
