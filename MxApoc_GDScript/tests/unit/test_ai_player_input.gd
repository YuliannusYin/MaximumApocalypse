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
	keep.ai = {"order": 0, "useful": 90}
	var junk: Card = _make_card("junk")
	junk.ai = {"order": 0, "useful": 10}
	var input = AIPlayerInputScript.new()
	input.set_request_owner(p)
	var picked: Array = await input.choose_card(1, [keep, junk], null, "选择一张牌")
	assert_eq(picked.size(), 1)
	assert_eq(picked[0], keep, "应留下高 useful 的牌")


func test_choose_card_discards_low_useful() -> void:
	var p: Player = _make_player("AI")
	var keep: Card = _make_card("燃料")
	keep.ai = {"order": 0, "useful": 90}
	var junk: Card = _make_card("junk")
	junk.ai = {"order": 0, "useful": 10}
	var input = AIPlayerInputScript.new()
	input.set_request_owner(p)
	var picked: Array = await input.choose_card(1, [keep, junk], null, "弃置一张牌")
	assert_eq(picked.size(), 1)
	assert_eq(picked[0], junk, "弃牌应优先弃低 useful")


func test_wait_redraw_below_and_at_threshold() -> void:
	var p: Player = _make_player("AI")
	var low: Card = _make_card("low")
	low.ai = {"order": 0, "useful": 50}
	p.hand.append(low)
	p.hand.append(low)
	var input = AIPlayerInputScript.new()
	assert_true(await input.wait_redraw_decision(p), "均分 50 应重调")
	var high: Card = _make_card("high")
	high.ai = {"order": 0, "useful": 70}
	p.hand.clear()
	p.hand.append(high)
	p.hand.append(high)
	assert_false(await input.wait_redraw_decision(p), "均分 70 应停止重调")


func test_wait_redraw_stops_at_count_cap() -> void:
	var p: Player = _make_player("AI")
	var low: Card = _make_card("low")
	low.ai = {"order": 0, "useful": 50}
	p.hand.append(low)
	var input = AIPlayerInputScript.new()
	input._redraw_count = AIPlayerInputScript.REDRAW_MAX_COUNT
	assert_false(await input.wait_redraw_decision(p), "达到重调次数上限应停止")


func test_choose_target_skips_ally_and_prefers_lethal() -> void:
	var p: Player = _make_player("AI")
	var ally: Player = _make_player("Ally")
	p.in_phase = "action"
	p.action_count = 4
	var block: MapBlock = _make_block("旷野", 0, 0, true)
	Game.map_area = [block]
	Game.players = [p, ally]
	p.current_block = block
	ally.current_block = block
	var boss: Monster = Monster.new()
	boss.hp = 10
	boss.max_hp = 10
	boss.ai_threat = 80
	boss.monster_level = "boss"
	var weak: Monster = Monster.new()
	weak.hp = 2
	weak.max_hp = 2
	weak.ai_threat = 30
	weak.monster_level = "normal"
	p.monster_zone.append(boss)
	p.monster_zone.append(weak)
	var skill: Skill = _punch_skill()
	p.add_skill(skill)
	p.input = AIPlayerInputScript.new()
	p.input.set_request_owner(p)
	var picked: Array = await p.input.choose_target(1, skill, "选择攻击目标")
	assert_eq(picked.size(), 1)
	assert_false(picked[0] is Player, "伤害不应主动选求生者")
	assert_eq(picked[0], weak, "一击毙命应压过不能击杀的高威胁")
