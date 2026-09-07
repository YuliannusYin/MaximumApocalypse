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


func test_wait_redraw_without_weapon_then_with_weapon() -> void:
	var p: Player = _make_player("AI")
	var junk: Card = _make_card("junk")
	junk.ai = {"order": 0, "useful": 90}
	p.hand.append(junk)
	var input = AIPlayerInputScript.new()
	assert_true(await input.wait_redraw_decision(p), "手里没有武器应重调")
	var weapon: Card = _make_card("弓")
	weapon.ai = {"order": 8, "useful": 20, "tags": ["weapon"]}
	p.hand.clear()
	p.hand.append(weapon)
	assert_false(await input.wait_redraw_decision(p), "手里有武器牌应停止重调")


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


func test_wait_action_skips_fizzled_card() -> void:
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 4
	var here: MapBlock = _make_block("购物中心", 0, 0, true)
	var there: MapBlock = _make_block("加油站", 1, 0, true)
	Game.map_area = [here, there]
	Game.players = [p]
	p.current_block = here
	var card: Card = _make_equipment("梯子")
	card.english_name = "ladder"
	card.card_type = "equipment"
	card.ai = {"order": 8, "useful": 80, "tags": ["equip"]}
	p.hand.append(card)
	var input = AIPlayerInputScript.new()
	input.think_seconds = 0.0
	var first: Variant = await input.wait_action(p)
	assert_true(first is Dictionary)
	assert_eq(first.get("type"), "card", "第一次应选手里的高分装备")
	var second: Variant = await input.wait_action(p)
	assert_true(second is Dictionary)
	assert_ne(second.get("type"), "card", "空放后同指纹卡牌本回合不再选")


func test_choose_card_balance_prompt_discards_low_useful() -> void:
	var p: Player = _make_player("AI")
	var keep: Card = _make_card("猎枪")
	keep.ai = {"order": 8, "useful": 80, "tags": ["weapon"]}
	var junk: Card = _make_card("junk")
	junk.ai = {"order": 0, "useful": 10}
	var mid: Card = _make_card("mid")
	mid.ai = {"order": 0, "useful": 20}
	var input = AIPlayerInputScript.new()
	input.set_request_owner(p)
	var picked: Array = await input.choose_card(2, [keep, junk, mid], null, "\"制衡\": 选择两张求生者游戏牌")
	assert_eq(picked.size(), 2)
	assert_false(picked.has(keep), "制衡应按弃牌选低 useful，不应丢掉猎枪")
	assert_true(picked.has(junk))
	assert_true(picked.has(mid))


func test_wait_action_skips_fizzled_reveal_skill() -> void:
	var p: Player = _make_player("AI")
	p.in_phase = "action"
	p.action_count = 4
	var here: MapBlock = _make_block("购物中心", 0, 0, true)
	var there: MapBlock = _make_block("加油站", 1, 0, false)
	Game.map_area = [here, there]
	Game.players = [p]
	p.current_block = here
	var skill := Skill.new()
	skill.skill_name = "双筒望远镜"
	skill.english_name = "binoculars"
	skill.active = "action"
	skill.range = "long"
	skill.ai = {"order": 9, "useful": 0, "tags": ["reveal"], "effect": {"player": 1, "target": 0}}
	p.add_skill(skill)
	var input = AIPlayerInputScript.new()
	input.think_seconds = 0.0
	var first: Variant = await input.wait_action(p)
	assert_true(first is Dictionary)
	assert_eq(first.get("type"), "skill", "第一次应选望远镜")
	var second: Variant = await input.wait_action(p)
	assert_true(second is Dictionary)
	assert_ne(str(second.get("skill").english_name) if second.get("skill") != null else "", "binoculars", "展示技能空放后应改选")


func test_choose_block_inline_empty_when_already_at_dest() -> void:
	var mc := MissionConfig.new()
	var fuel := MissionComponentAddVanFuel.new()
	fuel.params = {"block_name": "面包车", "card_name": "燃料", "count": 4}
	mc.action_components = [fuel]
	Game.mission_config = mc
	mc.setup_components(Game)
	var van: MapBlock = _make_block("面包车", 0, 0, true)
	var east: MapBlock = _make_block("旷野", 1, 0, true)
	Game.map_area = [van, east]
	var p: Player = _make_player("AI")
	p.current_block = van
	p.hand.append(_make_card("燃料"))
	Game.players = [p]
	var input = AIPlayerInputScript.new()
	input.set_request_owner(p)
	var picked: Array = await input.choose_block_inline([east], "摩托车", 1)
	assert_eq(picked.size(), 0, "已在行进目标时多步移动应停")


func test_choose_block_inline_detours_hole() -> void:
	var coords: Array = [
		[2, 0], [3, 0], [4, 0],
		[1, 1], [2, 1], [4, 1], [5, 1],
		[2, 2], [3, 2], [4, 2],
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
	var p: Player = _make_player("AI")
	p.current_block = by_coord["2,1"]
	Game.players = [p]
	var input = AIPlayerInputScript.new()
	input.set_request_owner(p)
	var picked: Array = await input.choose_block_inline(
		[by_coord["2,0"], by_coord["1,1"], by_coord["2,2"]],
		"耐力",
		1
	)
	assert_eq(picked.size(), 1, "绕空洞时应选出更近的邻格")
	assert_true(picked[0] == by_coord["2,0"] or picked[0] == by_coord["2,2"], "应走北或南，而不是西")


func _push_card_only_context(player: Player) -> void:
	player._operation_context_stack.append({
		"kind": "limited_action",
		"remaining_actions": 2,
		"allowed_action_types": ["card"],
		"completed": false,
	})


func _axe_skill() -> Skill:
	var skill := Skill.new()
	skill.skill_name = "值得信赖的斧子"
	skill.english_name = "reliable_axe"
	skill.active = "action"
	skill.select_target = 1
	skill.filter_target_range = "short"
	skill.ai = {"order": 9, "useful": 0, "tags": ["damage", "weapon"], "effect": {"player": 0, "target": 4}}
	return skill


func _lighter_skill() -> Skill:
	var skill := Skill.new()
	skill.skill_name = "打火机"
	skill.english_name = "lighter"
	skill.active = "action"
	skill.select_target = -1
	skill.filter_target_range = "short"
	skill.filter_target = func(_player, target, _event, _game) -> bool:
		return target != null and target.has_method("is_monster") and target.is_monster()
	skill.ai = {"order": 9, "useful": 0, "tags": ["damage", "aoe", "weapon"], "effect": {"player": 0, "target": 3}}
	return skill


func _weapon_card(card_name: String) -> EquipmentCard:
	var card: EquipmentCard = _make_equipment(card_name)
	card.weapon = true
	card.ai = {"order": 8, "useful": 80, "tags": ["equip", "weapon"]}
	return card


func test_ai_card_only_limited_action_plays_hand_card() -> void:
	var p: Player = _ready_combat_player()
	var card: EquipmentCard = _weapon_card("猎枪")
	p.hand.append(card)
	_push_card_only_context(p)
	var input = AIPlayerInputScript.new()
	input.think_seconds = 0.0
	p.input = input
	var choice: Variant = await input.wait_action(p)
	assert_true(choice is Dictionary, "迷你回合有手牌时应行动")
	assert_eq(choice.get("type"), "card", "仅手牌白名单应选卡牌而不是拳打")
	assert_eq(choice.get("card"), card)


func test_ai_card_only_limited_action_ends_without_cards() -> void:
	var p: Player = _ready_combat_player()
	_push_card_only_context(p)
	var input = AIPlayerInputScript.new()
	input.think_seconds = 0.0
	p.input = input
	var choice: Variant = await input.wait_action(p)
	assert_null(choice, "仅手牌迷你回合空手牌时应结束而不是循环技能")


func test_ai_prefers_axe_over_punch() -> void:
	var p: Player = _ready_combat_player()
	p.add_skill(_axe_skill())
	var input = AIPlayerInputScript.new()
	input.think_seconds = 0.0
	p.input = input
	var choice: Variant = await input.wait_action(p)
	assert_true(choice is Dictionary)
	assert_eq(choice.get("type"), "skill")
	assert_eq(choice.get("skill").english_name, "reliable_axe", "已装备斧子应压过拳打")


func test_ai_equips_weapon_before_punch_when_engaged() -> void:
	var p: Player = _ready_combat_player()
	var gun: EquipmentCard = _weapon_card("猎枪")
	p.hand.append(gun)
	var input = AIPlayerInputScript.new()
	input.think_seconds = 0.0
	p.input = input
	var choice: Variant = await input.wait_action(p)
	assert_true(choice is Dictionary)
	assert_eq(choice.get("type"), "card", "有怪且未武装时应先装备武器")
	assert_eq(choice.get("card"), gun)


func test_ai_uses_equipped_lighter_before_equipping_shotgun() -> void:
	var p: Player = _ready_combat_player()
	p.add_skill(_lighter_skill())
	p.hand.append(_weapon_card("猎枪"))
	var input = AIPlayerInputScript.new()
	input.think_seconds = 0.0
	p.input = input
	var choice: Variant = await input.wait_action(p)
	assert_true(choice is Dictionary)
	assert_eq(choice.get("type"), "skill", "已有可用武器时应攻击而不是再装备")
	assert_eq(choice.get("skill").english_name, "lighter")


func test_choose_card_overflow_skips_needed_fuel() -> void:
	var mc := MissionConfig.new()
	var fuel_comp := MissionComponentAddVanFuel.new()
	fuel_comp.params = {"block_name": "面包车", "card_name": "燃料", "count": 4}
	mc.action_components = [fuel_comp]
	Game.mission_config = mc
	mc.setup_components(Game)
	var p: Player = _make_player("AI")
	var keep: Card = _make_card("燃料")
	keep.ai = {"order": 0, "useful": 90, "tags": ["fuel"]}
	var junk: Card = _make_card("游侠帽")
	junk.ai = {"order": 3, "useful": 58, "tags": ["equip"]}
	var input = AIPlayerInputScript.new()
	input.set_request_owner(p)
	var picked: Array = await input.choose_card(1, [keep, junk], null, "\"装备栏超限\": 请弃置装备区中的装备以容纳新装备")
	assert_eq(picked.size(), 1)
	assert_eq(picked[0], junk, "溢出弃置有非任务候选时不应丢燃料")


func test_ai_last_ap_prefers_punch_over_equip() -> void:
	var p: Player = _ready_combat_player()
	p.action_count = 1
	p.hand.append(_weapon_card("猎枪"))
	var input = AIPlayerInputScript.new()
	input.think_seconds = 0.0
	p.input = input
	var choice: Variant = await input.wait_action(p)
	assert_true(choice is Dictionary)
	assert_eq(choice.get("type"), "skill", "最后 1 点行动应出拳打而不是换装")
	assert_eq(choice.get("skill").english_name, "punch")

