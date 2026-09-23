extends TestBase

## 拾荒牌交易：通用技能可用性、成交/拒绝、装备迁移、科学家不进弃牌堆、快照 used_count。

const GameStateSerializerScript = preload("res://src/net/game_state_serializer.gd")
const AiScorerScript = preload("res://src/ai/ai_scorer.gd")
const AIPlayerInputScript = preload("res://src/ai/ai_player_input.gd")


func _setup_trade_world(p1: Player, p2: Player, same_block: bool = true) -> MapBlock:
	var b1: MapBlock = _make_block("camp", 0, 0, true)
	var b2: MapBlock = _make_block("hospital", 1, 0, true)
	Game.players = [p1, p2]
	Game.map_area = [b1, b2]
	Game.monster_pile = Pile.new()
	Game.monster_discard_pile = Pile.new()
	Game.red_scavenge_pile = Pile.new()
	Game.green_scavenge_pile = Pile.new()
	Game.blue_scavenge_pile = Pile.new()
	Game.scavenge_discard_pile = Pile.new()
	p1.current_block = b1
	p2.current_block = b1 if same_block else b2
	p1.in_phase = "action"
	p2.in_phase = "action"
	return b1


func _make_trader(player_name: String) -> Player:
	var p: Player = _make_player(player_name)
	p.in_phase = "action"
	p.action_count = 4
	var rc: RoleCard = RoleCard.new()
	rc.equipment_capacity = 4
	rc.hand_size_limit = 10
	p.role_card = rc
	return p


func _get_trade_skill() -> Skill:
	for sd in DataManager.get_common_skills():
		if sd.english_name == "trade":
			return Game._create_skill_from_data(sd)
	return null


func _make_scavenge_equip(card_name: String, english_name: String = "", size: int = 1) -> EquipmentCard:
	var card: EquipmentCard = _make_equipment(card_name)
	card.source = "scavenge"
	card.size = size
	if english_name != "":
		card.english_name = english_name
	var skill: Skill = Skill.new()
	skill.skill_name = card_name + "技能"
	skill.english_name = (english_name if english_name != "" else card_name) + "_skill"
	card.add_skill(skill)
	return card


func test_common_skills_include_trade() -> void:
	var names: Array = []
	for sd in DataManager.get_common_skills():
		names.append(sd.english_name)
	assert_true(names.has("trade"), "common_skills 应包含交易")
	assert_true(names.has("balance"), "common_skills 应仍包含制衡")


func test_can_use_trade_when_same_block_both_have_scavenge() -> void:
	var a: Player = _make_trader("A")
	var b: Player = _make_trader("B")
	_setup_trade_world(a, b, true)
	a.hand.append(_make_scavenge_card("医疗用品"))
	b.hand.append(_make_scavenge_card("解毒剂"))
	var skill: Skill = _get_trade_skill()
	a.add_skill(skill)
	assert_true(a.can_use_active_skill(skill), "同地块双方都有拾荒牌时应可交易")


func test_cannot_use_trade_on_different_blocks() -> void:
	var a: Player = _make_trader("A")
	var b: Player = _make_trader("B")
	_setup_trade_world(a, b, false)
	a.hand.append(_make_scavenge_card("医疗用品"))
	b.hand.append(_make_scavenge_card("解毒剂"))
	var skill: Skill = _get_trade_skill()
	a.add_skill(skill)
	assert_false(a.can_use_active_skill(skill), "不同地块不可交易")


func test_cannot_use_trade_when_partner_has_no_scavenge() -> void:
	var a: Player = _make_trader("A")
	var b: Player = _make_trader("B")
	_setup_trade_world(a, b, true)
	a.hand.append(_make_scavenge_card("医疗用品"))
	var skill: Skill = _get_trade_skill()
	a.add_skill(skill)
	assert_false(a.can_use_active_skill(skill), "对方无拾荒牌时按钮应变灰")


func test_hand_swap_success() -> void:
	var a: Player = _make_trader("A")
	var b: Player = _make_trader("B")
	_setup_trade_world(a, b, true)
	var med: ScavengeCard = _make_scavenge_card("医疗用品")
	var antidote: ScavengeCard = _make_scavenge_card("解毒剂")
	a.hand.append(med)
	b.hand.append(antidote)
	var skill: Skill = _get_trade_skill()
	a.add_skill(skill)
	var a_cli: CliPlayerInput = CliPlayerInput.new()
	var b_cli: CliPlayerInput = CliPlayerInput.new()
	a_cli.queue_choose_target([b])
	a_cli.queue_choose_card([med])
	b_cli.queue_confirm(true)
	b_cli.queue_choose_card([antidote])
	a.input = a_cli
	b.input = b_cli
	await a.use_active_skill(skill)
	assert_true(a.hand.has(antidote), "A 应拿到解毒剂")
	assert_true(b.hand.has(med), "B 应拿到医疗用品")
	assert_false(a.hand.has(med), "A 不应再持有医疗用品")
	assert_eq(skill.used_count, 1, "成交应消耗本回合交易次数")


func test_refuse_does_not_record_use() -> void:
	var a: Player = _make_trader("A")
	var b: Player = _make_trader("B")
	_setup_trade_world(a, b, true)
	var med: ScavengeCard = _make_scavenge_card("医疗用品")
	var antidote: ScavengeCard = _make_scavenge_card("解毒剂")
	a.hand.append(med)
	b.hand.append(antidote)
	var skill: Skill = _get_trade_skill()
	a.add_skill(skill)
	var a_cli: CliPlayerInput = CliPlayerInput.new()
	var b_cli: CliPlayerInput = CliPlayerInput.new()
	a_cli.queue_choose_target([b])
	a_cli.queue_choose_card([med])
	b_cli.queue_confirm(false)
	a.input = a_cli
	b.input = b_cli
	await a.use_active_skill(skill)
	assert_true(a.hand.has(med), "拒绝后牌应留在原处")
	assert_true(b.hand.has(antidote), "拒绝后对方牌应留在原处")
	assert_eq(skill.used_count, 0, "拒绝不消耗交易次数")


func test_cancel_choose_card_does_not_record_use() -> void:
	var a: Player = _make_trader("A")
	var b: Player = _make_trader("B")
	_setup_trade_world(a, b, true)
	var med: ScavengeCard = _make_scavenge_card("医疗用品")
	var antidote: ScavengeCard = _make_scavenge_card("解毒剂")
	a.hand.append(med)
	b.hand.append(antidote)
	var skill: Skill = _get_trade_skill()
	a.add_skill(skill)
	var a_cli: CliPlayerInput = CliPlayerInput.new()
	var b_cli: CliPlayerInput = CliPlayerInput.new()
	a_cli.queue_choose_target([b])
	a_cli.queue_choose_card([med])
	b_cli.queue_confirm(true)
	b_cli.queue_choose_card([])
	a.input = a_cli
	b.input = b_cli
	await a.use_active_skill(skill)
	assert_true(a.hand.has(med))
	assert_true(b.hand.has(antidote))
	assert_eq(skill.used_count, 0, "取消选牌不消耗交易次数")


func test_equipment_swap_moves_skills() -> void:
	var a: Player = _make_trader("A")
	var b: Player = _make_trader("B")
	_setup_trade_world(a, b, true)
	var vest: EquipmentCard = _make_scavenge_equip("防弹背心", "bulletproof_vest")
	var pack: EquipmentCard = _make_scavenge_equip("背包", "backpack")
	assert_true(await a.equip(vest))
	assert_true(await b.equip(pack))
	var a_skill: Skill = vest.get_all_skills()[0]
	var b_skill: Skill = pack.get_all_skills()[0]
	assert_true(a.skills.has(a_skill), "装备前 A 应挂载背心技能")
	assert_true(b.skills.has(b_skill), "装备前 B 应挂载背包技能")
	var skill: Skill = _get_trade_skill()
	a.add_skill(skill)
	var a_cli: CliPlayerInput = CliPlayerInput.new()
	var b_cli: CliPlayerInput = CliPlayerInput.new()
	a_cli.queue_choose_target([b])
	a_cli.queue_choose_card([a.get_equipment("防弹背心")])
	b_cli.queue_confirm(true)
	b_cli.queue_choose_card([b.get_equipment("背包")])
	a.input = a_cli
	b.input = b_cli
	await a.use_active_skill(skill)
	assert_true(a.has_equipment("背包"), "A 应装备背包")
	assert_true(b.has_equipment("防弹背心"), "B 应装备背心")
	assert_false(a.has_equipment("防弹背心"))
	assert_true(a.skills.has(b_skill), "背包技能应转到 A")
	assert_true(b.skills.has(a_skill), "背心技能应转到 B")
	assert_false(a.skills.has(a_skill), "A 不应再持有背心技能")


func test_equipment_overflow_goes_to_hand() -> void:
	var a: Player = _make_trader("A")
	var b: Player = _make_trader("B")
	b.role_card.equipment_capacity = 1
	_setup_trade_world(a, b, true)
	var vest: EquipmentCard = _make_scavenge_equip("防弹背心", "bulletproof_vest")
	var pack: EquipmentCard = _make_scavenge_equip("背包", "backpack")
	var junk: ScavengeCard = _make_scavenge_card("一无所获")
	assert_true(await a.equip(vest))
	assert_true(await b.equip(pack))
	b.hand.append(junk)
	var skill: Skill = _get_trade_skill()
	a.add_skill(skill)
	var a_cli: CliPlayerInput = CliPlayerInput.new()
	var b_cli: CliPlayerInput = CliPlayerInput.new()
	a_cli.queue_choose_target([b])
	a_cli.queue_choose_card([a.get_equipment("防弹背心")])
	b_cli.queue_confirm(true)
	b_cli.queue_choose_card([junk])
	a.input = a_cli
	b.input = b_cli
	await a.use_active_skill(skill)
	assert_true(b.has_equipment("背包"), "B 原装备应留下")
	assert_false(b.has_equipment("防弹背心"), "栏位不够时背心不应装上")
	assert_true(b.hand.has(vest), "溢出的背心应进 B 手牌")
	assert_true(a.hand.has(junk), "A 应拿到回礼手牌")


func test_same_name_equipped_goes_to_hand() -> void:
	var a: Player = _make_trader("A")
	var b: Player = _make_trader("B")
	_setup_trade_world(a, b, true)
	var light_a: EquipmentCard = _make_scavenge_equip("手电筒", "flashlight")
	var light_b: EquipmentCard = _make_scavenge_equip("手电筒", "flashlight")
	var junk: ScavengeCard = _make_scavenge_card("一无所获")
	assert_true(await a.equip(light_a))
	assert_true(await b.equip(light_b))
	b.hand.append(junk)
	var skill: Skill = _get_trade_skill()
	a.add_skill(skill)
	var a_cli: CliPlayerInput = CliPlayerInput.new()
	var b_cli: CliPlayerInput = CliPlayerInput.new()
	a_cli.queue_choose_target([b])
	a_cli.queue_choose_card([a.get_equipment("手电筒")])
	b_cli.queue_confirm(true)
	b_cli.queue_choose_card([junk])
	a.input = a_cli
	b.input = b_cli
	await a.use_active_skill(skill)
	assert_true(b.has_equipment("手电筒"), "B 原手电筒留下")
	assert_true(b.hand.has(light_a), "同名冲突的手电筒进手牌")
	assert_eq(Game.scavenge_discard_pile.size(), 0, "同名冲突不得弃置")


func test_scientist_trade_does_not_discard() -> void:
	var a: Player = _make_trader("A")
	var b: Player = _make_trader("B")
	_setup_trade_world(a, b, true)
	var scientist: Card = Game.create_scavenge_card("科学家")
	assert_not_null(scientist, "应能创建科学家")
	var med: ScavengeCard = _make_scavenge_card("医疗用品")
	assert_true(await a.equip(scientist))
	b.hand.append(med)
	var skill: Skill = _get_trade_skill()
	a.add_skill(skill)
	var a_cli: CliPlayerInput = CliPlayerInput.new()
	var b_cli: CliPlayerInput = CliPlayerInput.new()
	a_cli.queue_choose_target([b])
	a_cli.queue_choose_card([a.get_equipment("科学家")])
	b_cli.queue_confirm(true)
	b_cli.queue_choose_card([med])
	a.input = a_cli
	b.input = b_cli
	await a.use_active_skill(skill)
	assert_true(b.has_equipment("科学家"), "科学家应装备到 B")
	assert_false(a.has_equipment("科学家"))
	assert_true(a.hand.has(med))
	assert_eq(Game.scavenge_discard_pile.size(), 0, "科学家交易不得进弃牌堆")
	assert_false(Game.removed_cards.has(scientist), "科学家不应被移出游戏")


func test_snapshot_skill_uses_roundtrip() -> void:
	var player: Player = _make_trader("Host")
	player.seat_number = 0
	player.net_id = 1
	var skill: Skill = Skill.new()
	skill.english_name = "trade"
	skill.usable = 1
	skill.used_count = 1
	player.add_skill(skill)
	Game.players = [player]
	Game.map_area = []
	var snapshot: Dictionary = GameStateSerializerScript.snapshot(Game)
	assert_eq(int(snapshot["players"][0]["skill_uses"]["trade"]), 1, "快照应带交易 used_count")
	skill.used_count = 0
	GameStateSerializerScript.apply(Game, snapshot, {1: player})
	assert_eq(skill.used_count, 1, "apply 应按 english_name 写回 used_count")


func test_ai_never_initiates_trade() -> void:
	var a: Player = _make_trader("AI")
	var b: Player = _make_trader("Human")
	_setup_trade_world(a, b, true)
	a.hand.append(_make_scavenge_card("医疗用品"))
	b.hand.append(_make_scavenge_card("解毒剂"))
	var skill: Skill = _get_trade_skill()
	a.add_skill(skill)
	var scorer = AiScorerScript.new()
	var score: float = scorer.score_action(a, {"type": "skill", "skill": skill})
	assert_eq(score, 0.0, "AI 不应主动发起交易")


func test_ai_accepts_trade_confirm() -> void:
	var input = AIPlayerInputScript.new()
	assert_true(await input.confirm("\"交易\": 是否用一张拾荒牌交换「医疗用品」?"))


func test_ai_trade_reply_keeps_scientist_when_alternatives_exist() -> void:
	var p: Player = _make_trader("AI")
	var scientist: ScavengeCard = _make_scavenge_card("科学家")
	scientist.english_name = "scientist"
	scientist.ai = {"order": 0, "useful": 90}
	var junk: ScavengeCard = _make_scavenge_card("一无所获")
	junk.ai = {"order": 0, "useful": 10}
	var input = AIPlayerInputScript.new()
	input.set_request_owner(p)
	var picked: Array = await input.choose_card(
		1, [scientist, junk], null, "\"交易\": 选择一张拾荒牌交换")
	assert_eq(picked.size(), 1)
	assert_eq(picked[0], junk, "有替代时应交出非科学家")
