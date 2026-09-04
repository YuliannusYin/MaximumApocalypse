extends TestBase

## 手牌/装备栏超限机制单元测试（"先入手后判定"语义）。
## 覆盖：手牌未满正常入手（无弹窗）、手牌满弹窗选中弃置（旧牌弃、新牌留、弹窗候选含新牌）、
## 手牌满取消（新牌自动弃置 + "自动弃置"日志）、draw(n) 同批合并单次弹窗（K 动态、后入手先弃）、
## draw_scavenge 先入手、抓取技能触发后再弹窗、
## equip 装备栏超限弹窗（弃装备腾位 / 取消中止并弃牌）、use_card 装备超限取消后行动点照常消耗。


# === 辅助方法 ===

func _make_overflow_player(hp: int = 10, max_hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = "TestPlayer"
	p.hp = hp
	p.max_hp = max_hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_overflow_equipment(name: String = "test_equip", size: int = 1) -> EquipmentCard:
	var e: EquipmentCard = EquipmentCard.new()
	e.card_name = name
	e.card_type = "equipment"
	e.card_subtype = "equipment"
	e.source = "game"
	e.size = size
	return e


func _make_role(hand_limit: int = 10, equip_capacity: int = 5) -> RoleCard:
	var r: RoleCard = RoleCard.new()
	r.hand_size_limit = hand_limit
	r.equipment_capacity = equip_capacity
	return r


func _setup_game_for_player(p: Player) -> void:
	Game.players = [p]
	Game.map_area = []
	Game.monster_pile = Pile.new()
	Game.monster_discard_pile = Pile.new()
	Game.scavenge_discard_pile = Pile.new()
	Game.red_scavenge_pile = Pile.new()
	Game.green_scavenge_pile = Pile.new()
	Game.blue_scavenge_pile = Pile.new()
	Game.coop_death_mode = false
	Game.mission_config = null
	Game.removed_cards = []
	Game.game_over_called = false
	Game.game_result = ""
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


## 探针 input：记录 choose_card 调用参数与调用时的手牌快照
##（用于验证超限弹窗的候选区域、prompt 与"先入手后判定"——弹窗时新牌已在手牌候选中）。
## order_log 非空时按调用顺序追加 "popup"，用于验证弹窗与其他结算的先后顺序。
class _ChooseCardSpyInput extends CliPlayerInput:
	var calls: Array = []
	var player_ref: Player = null  # 弹窗时快照其手牌
	var order_log = null  # 共享顺序记录数组（可选，未启用时保持 null）

	func choose_card(n: int, param: Variant = "hand", filter: Variant = null, prompt: String = "", min_n: int = -1) -> Array:
		var hand_at_call: Array = []
		if player_ref != null and is_instance_valid(player_ref):
			hand_at_call = player_ref.hand.duplicate()
		calls.append({"n": n, "param": param, "prompt": prompt, "hand_at_call": hand_at_call})
		if order_log != null:
			order_log.append("popup")
		return await super.choose_card(n, param, filter, prompt, min_n)


# === 一、手牌未满：正常入手，无弹窗 ===

func test_gain_and_draw_below_hand_limit_adds_to_hand() -> void:
	var p: Player = _make_overflow_player()
	_setup_game_for_player(p)
	p.role_card = _make_role(10, 5)
	var spy: _ChooseCardSpyInput = _ChooseCardSpyInput.new()
	p.input = spy
	# gain：手牌未满直接入手
	var c1: Card = _make_card("c1")
	await p.gain(c1)
	assert_true(p.hand.has(c1), "手牌未满时 gain 应直接入手")
	# try_add_card_to_hand：手牌未满直接入手并返回 true
	var c2: Card = _make_card("c2")
	assert_true(await p.try_add_card_to_hand(c2), "手牌未满时 try_add_card_to_hand 应返回 true")
	assert_true(p.hand.has(c2), "手牌未满时 try_add_card_to_hand 应直接入手")
	# draw：手牌未满直接入手
	var c3: Card = _make_card("c3")
	p.game_deck.add(c3)
	await p.draw(1)
	assert_true(p.hand.has(c3), "手牌未满时 draw 应直接入手")
	assert_eq(p.hand.size(), 3, "三张牌均应入手，无弹窗弃牌")
	assert_true(spy.calls.is_empty(), "手牌未满时不应触发任何超限弹窗")


# === 二、手牌满：弹窗选中弃 1 张（旧牌弃、新牌留） ===

func test_hand_overflow_select_discards_chosen_and_keeps_new() -> void:
	var p: Player = _make_overflow_player()
	_setup_game_for_player(p)
	p.role_card = _make_role(2, 5)  # 手牌上限 2
	var c1: Card = _make_card("c1")
	var c2: Card = _make_card("c2")
	p.hand.append(c1)
	p.hand.append(c2)
	var spy: _ChooseCardSpyInput = _ChooseCardSpyInput.new()
	spy.player_ref = p
	p.input = spy
	spy.queue_choose_card([c1])  # 弹窗选中弃置旧牌 c1
	var new_card: Card = _make_card("new_card")
	await p.gain(new_card)
	# 先入手后判定：new_card 先进手牌，弹窗弃 1 张后手牌数回到上限
	assert_false(p.hand.has(c1), "所选的 c1 应被弃置")
	assert_true(p.game_discard_pile.get_all().has(c1), "c1 应进入游戏牌弃牌堆")
	assert_true(p.hand.has(new_card), "新牌应留在手牌")
	assert_eq(p.hand.size(), 2, "手牌数应等于上限 2")
	# 弹窗参数：候选区域为手牌、精确选 1 张、prompt 注明手牌超限与数量
	assert_eq(spy.calls.size(), 1, "应弹窗一次")
	assert_eq(spy.calls[0]["param"], "hand", "弹窗候选区域应为手牌")
	assert_eq(spy.calls[0]["n"], 1, "应精确选择 1 张")
	assert_true(str(spy.calls[0]["prompt"]).contains("手牌超限"), "prompt 应注明手牌超限")
	assert_true(str(spy.calls[0]["prompt"]).contains("1"), "prompt 应注明弃置数量 1")
	# 先入手后判定的关键差异：弹窗时新牌已在手牌候选中
	assert_true(spy.calls[0]["hand_at_call"].has(new_card), "弹窗时候选应包含新牌（新牌已先入手）")


# === 三、手牌满：弹窗取消（新牌自动弃置） ===

func test_hand_overflow_cancel_auto_discards_new_card() -> void:
	var p: Player = _make_overflow_player()
	_setup_game_for_player(p)
	Game.log_list = []
	p.role_card = _make_role(2, 5)
	var c1: Card = _make_card("c1")
	var c2: Card = _make_card("c2")
	p.hand.append(c1)
	p.hand.append(c2)
	var spy: _ChooseCardSpyInput = _ChooseCardSpyInput.new()
	spy.player_ref = p
	p.input = spy
	spy.queue_choose_card([])  # 模拟玩家取消
	var new_card: Card = _make_card("new_card")
	var added: bool = await p.try_add_card_to_hand(new_card)
	# 先入手后判定：新牌先入手，取消后被自动弃置（后入手先弃，本批仅 1 张）
	assert_true(added, "先入手后判定语义下 try_add_card_to_hand 恒返回 true")
	assert_false(p.hand.has(new_card), "取消后新牌应被自动弃置")
	assert_true(p.game_discard_pile.get_all().has(new_card), "取消后新牌应被直接弃置")
	assert_eq(p.hand.size(), 2, "手牌数应回到上限 2")
	assert_true(p.hand.has(c1) and p.hand.has(c2), "原手牌应全部保留")
	assert_eq(spy.calls.size(), 1, "应弹窗一次")
	assert_true(spy.calls[0]["hand_at_call"].has(new_card), "弹窗候选应包含新牌（先入手后判定）")
	assert_true(
		Game.log_list.any(func(l): return l.contains("手牌超限，自动弃置")),
		"应输出手牌超限自动弃置日志"
	)


# === 四、draw(2) 手牌=上限：同批合并单次弹窗（选中弃 2 张旧牌） ===

func test_draw_two_at_limit_single_popup_select_two() -> void:
	var p: Player = _make_overflow_player()
	_setup_game_for_player(p)
	p.role_card = _make_role(2, 5)
	var c1: Card = _make_card("c1")
	var c2: Card = _make_card("c2")
	p.hand.append(c1)
	p.hand.append(c2)
	var c3: Card = _make_card("c3")
	var c4: Card = _make_card("c4")
	p.game_deck.add(c3)
	p.game_deck.add(c4)  # 摸牌顺序：c3 先、c4 后
	var spy: _ChooseCardSpyInput = _ChooseCardSpyInput.new()
	spy.player_ref = p
	p.input = spy
	spy.queue_choose_card([c1, c2])  # 单次弹窗一次选 2 张旧牌弃置
	await p.draw(2)
	# 同批合并：两张新牌均入手后仅一次弹窗，K = 4 - 2 = 2
	assert_eq(spy.calls.size(), 1, "draw(2) 同批超限应合并为单次弹窗")
	assert_eq(spy.calls[0]["n"], 2, "应精确选择 2 张")
	assert_true(str(spy.calls[0]["prompt"]).contains("手牌超限"), "prompt 应注明手牌超限")
	assert_true(str(spy.calls[0]["prompt"]).contains("2"), "prompt 应注明弃置数量 2")
	assert_true(
		spy.calls[0]["hand_at_call"].has(c3) and spy.calls[0]["hand_at_call"].has(c4),
		"弹窗时候选应包含两张新牌（先入手后判定）"
	)
	assert_false(p.hand.has(c1) or p.hand.has(c2), "所选的 c1/c2 应被弃置")
	assert_true(p.hand.has(c3) and p.hand.has(c4), "两张新牌均应留在手牌")
	assert_eq(p.hand.size(), 2, "手牌数应等于上限 2")
	assert_true(
		p.game_discard_pile.get_all().has(c1) and p.game_discard_pile.get_all().has(c2),
		"c1/c2 应进入游戏牌弃牌堆"
	)


# === 五、draw(2) 手牌=上限：取消 → 自动弃置 2 张新牌（后入手先弃） ===

func test_draw_two_at_limit_cancel_auto_discards_new_cards() -> void:
	var p: Player = _make_overflow_player()
	_setup_game_for_player(p)
	Game.log_list = []
	p.role_card = _make_role(2, 5)
	var c1: Card = _make_card("c1")
	var c2: Card = _make_card("c2")
	p.hand.append(c1)
	p.hand.append(c2)
	var c3: Card = _make_card("c3")
	var c4: Card = _make_card("c4")
	p.game_deck.add(c3)
	p.game_deck.add(c4)  # 摸牌顺序：c3 先、c4 后
	var spy: _ChooseCardSpyInput = _ChooseCardSpyInput.new()
	spy.player_ref = p
	p.input = spy
	spy.queue_choose_card([])  # 模拟玩家取消
	await p.draw(2)
	# 取消：自动弃置本批新牌中后入手的 2 张（c4、c3），原手牌保留
	assert_eq(spy.calls.size(), 1, "应弹窗一次")
	assert_eq(spy.calls[0]["n"], 2, "K 应为 2")
	assert_false(p.hand.has(c3) or p.hand.has(c4), "取消后两张新牌应被自动弃置")
	assert_true(p.hand.has(c1) and p.hand.has(c2), "原手牌应全部保留")
	assert_eq(p.hand.size(), 2, "手牌数应回到上限 2")
	# 后入手先弃：后摸的 c4 先进弃牌堆，先摸的 c3 后进
	var discarded: Array = p.game_discard_pile.get_all()
	assert_eq(discarded.size(), 2, "弃牌堆应有 2 张牌")
	assert_eq(discarded[0], c4, "后摸的 c4 应先被自动弃置")
	assert_eq(discarded[1], c3, "先摸的 c3 应后被自动弃置")
	assert_true(
		Game.log_list.any(func(l): return l.contains("手牌超限，自动弃置")),
		"应输出手牌超限自动弃置日志"
	)


# === 六、draw(2) 手牌=上限-1：整批入手后仅弹窗 1 次选 1 张（K=1） ===

func test_draw_two_at_limit_minus_one_single_popup_k_one() -> void:
	var p: Player = _make_overflow_player()
	_setup_game_for_player(p)
	p.role_card = _make_role(2, 5)
	var c1: Card = _make_card("c1")
	p.hand.append(c1)
	var c2: Card = _make_card("c2")
	var c3: Card = _make_card("c3")
	p.game_deck.add(c2)
	p.game_deck.add(c3)
	var spy: _ChooseCardSpyInput = _ChooseCardSpyInput.new()
	spy.player_ref = p
	p.input = spy
	spy.queue_choose_card([c1])
	await p.draw(2)
	# 两张均入手后统一结算：K = 3 - 2 = 1，仅一次弹窗精确选 1 张
	assert_eq(spy.calls.size(), 1, "应合并为单次弹窗")
	assert_eq(spy.calls[0]["n"], 1, "K 应为 1（精确选 1 张）")
	assert_true(str(spy.calls[0]["prompt"]).contains("手牌超限"), "prompt 应注明手牌超限")
	assert_true(str(spy.calls[0]["prompt"]).contains("1"), "prompt 应注明弃置数量 1")
	assert_false(p.hand.has(c1), "所选的 c1 应被弃置")
	assert_true(p.hand.has(c2) and p.hand.has(c3), "两张新牌均应入手保留")
	assert_eq(p.hand.size(), 2, "手牌数应等于上限 2")
	assert_true(p.game_discard_pile.get_all().has(c1), "c1 应进入游戏牌弃牌堆")


# === 七、拾荒 draw_scavenge：新牌先入手、抓取技能触发后再弹窗 ===

func test_draw_scavenge_at_hand_full_popup_after_draw_skill() -> void:
	var p: Player = _make_overflow_player()
	_setup_game_for_player(p)
	p.role_card = _make_role(2, 5)
	var c1: Card = _make_card("c1")
	var c2: Card = _make_card("c2")
	p.hand.append(c1)
	p.hand.append(c2)
	# 拾荒牌自带 forced 抓取技能，记录触发顺序（用于验证技能先于弹窗）
	var order: Array = []
	var s1: ScavengeCard = _make_scavenge_card("s1")
	var draw_skill: Skill = Skill.new()
	draw_skill.skill_name = "抓取顺序探针"
	draw_skill.trigger = "on_draw_scavenge_card"
	draw_skill.forced = true
	draw_skill.content = func(_pl, _tg, _ev: Dictionary, _g) -> void:
		order.append("skill")
	s1.skills.append(draw_skill)
	var spy: _ChooseCardSpyInput = _ChooseCardSpyInput.new()
	spy.player_ref = p
	spy.order_log = order
	p.input = spy
	spy.queue_choose_card([c1])  # 弹窗选中弃置旧牌 c1
	var pile: Pile = Pile.new()
	pile.add(s1)
	await p.draw_scavenge(1, pile)
	# 先入手后判定：s1 先入手，抓取技能触发之后才弹超限窗
	assert_eq(order, ["skill", "popup"], "抓取技能应先于超限弹窗触发")
	assert_true(p.hand.has(s1), "弃 1 张腾位后拾荒牌应留在手牌")
	assert_false(p.hand.has(c1), "所选的 c1 应被弃置")
	assert_true(p.game_discard_pile.get_all().has(c1), "c1 应进入游戏牌弃牌堆")
	assert_eq(p.hand.size(), 2, "手牌数应保持上限 2")
	assert_eq(spy.calls.size(), 1, "应弹窗一次")
	assert_eq(spy.calls[0]["param"], "hand", "弹窗候选区域应为手牌")
	assert_true(spy.calls[0]["hand_at_call"].has(s1), "弹窗时候选应包含新拾荒牌（先入手后判定）")


# === 八、装备栏超限：弹窗选中弃装备 ===

func test_equip_overflow_select_discards_equipment_then_equips() -> void:
	var p: Player = _make_overflow_player()
	_setup_game_for_player(p)
	p.role_card = _make_role(10, 1)  # 装备栏容量 1
	var e1: EquipmentCard = _make_overflow_equipment("e1", 1)
	await p.equip(e1)
	assert_eq(p.equipment_zone.size(), 1, "前置：e1 已占用全部容量")
	var e2: EquipmentCard = _make_overflow_equipment("e2", 1)
	p.hand.append(e2)
	var spy: _ChooseCardSpyInput = _ChooseCardSpyInput.new()
	p.input = spy
	var entity1: Equipment = p.equipment_zone[0]
	spy.queue_choose_card([entity1])
	var result: bool = await p.equip(e2)
	assert_true(result, "弃置旧装备腾位后新装备应成功装备")
	assert_eq(p.equipment_zone.size(), 1, "装备区应仍为 1 个实体")
	assert_true(p.has_equipment("e2"), "新装备 e2 应在装备区")
	assert_false(p.has_equipment("e1"), "旧装备 e1 应被弃置")
	assert_true(p.game_discard_pile.get_all().has(e1), "e1 来源卡应进入弃牌堆")
	assert_false(p.hand.has(e2), "e2 应离开手牌进入装备区")
	# 弹窗参数：候选为装备区列表，prompt 注明装备栏超限
	assert_eq(spy.calls.size(), 1, "应弹窗一次")
	assert_eq(spy.calls[0]["param"].size(), 1, "弹窗候选应为装备区内可弃置装备列表")
	assert_true(spy.calls[0]["param"].has(entity1), "弹窗候选应包含待弃置的旧装备")
	assert_true(str(spy.calls[0]["prompt"]).contains("装备栏超限"), "prompt 应注明装备栏超限")


# === 九、装备栏超限：弹窗取消（直接 equip 验证） ===

func test_equip_overflow_cancel_aborts_and_discards_card() -> void:
	var p: Player = _make_overflow_player()
	_setup_game_for_player(p)
	Game.log_list = []
	p.role_card = _make_role(10, 1)
	var e1: EquipmentCard = _make_overflow_equipment("e1", 1)
	await p.equip(e1)
	var e2: EquipmentCard = _make_overflow_equipment("e2", 1)
	p.hand.append(e2)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_card([])  # 模拟玩家取消
	p.input = cli
	var result: bool = await p.equip(e2)
	assert_false(result, "取消后装备流程应中止，返回 false")
	assert_true(p.has_equipment("e1"), "原装备 e1 应保留")
	assert_eq(p.equipment_zone.size(), 1, "装备区应保持 1 个实体")
	assert_false(p.has_equipment("e2"), "e2 不应进入装备区")
	assert_false(p.hand.has(e2), "e2 应离开手牌被弃置")
	assert_true(p.game_discard_pile.get_all().has(e2), "待装备的 e2 应被弃置")
	assert_true(
		Game.log_list.any(func(l): return l.contains("装备栏超限")),
		"应输出装备栏超限弃牌日志"
	)


# === 十、装备栏超限：use_card 流程取消（行动点照常消耗） ===

func test_use_card_equipment_overflow_cancel_consumes_action() -> void:
	var p: Player = _make_overflow_player()
	_setup_game_for_player(p)
	p.role_card = _make_role(10, 1)
	var e1: EquipmentCard = _make_overflow_equipment("e1", 1)
	await p.equip(e1)
	var e2: EquipmentCard = _make_overflow_equipment("e2", 1)
	p.hand.append(e2)
	p.action_count = 2
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_card([])  # 装备栏超限弹窗取消
	p.input = cli
	await p.use_card(e2)
	assert_eq(p.action_count, 1, "装备超限取消时行动点应照常消耗 1 点")
	assert_false(p.has_equipment("e2"), "e2 不应进入装备区")
	assert_true(p.has_equipment("e1"), "原装备 e1 应保留")
	assert_true(p.game_discard_pile.get_all().has(e2), "待装备的 e2 应被弃置")


## === 十一、装备超限候选过滤：排除 size=0 与科学家 ===

func test_equip_overflow_filters_zero_size_and_scientist() -> void:
	var p: Player = _make_overflow_player()
	_setup_game_for_player(p)
	p.role_card = _make_role(10, 3)
	var scientist: EquipmentCard = _make_overflow_equipment("科学家", 1)
	scientist.english_name = "scientist"
	var zero_size: EquipmentCard = _make_overflow_equipment("zero_size", 0)
	var normal: EquipmentCard = _make_overflow_equipment("normal", 1)
	await p.equip(scientist)
	await p.equip(zero_size)
	await p.equip(normal)
	p.role_card.equipment_capacity = 2
	var replacement: EquipmentCard = _make_overflow_equipment("replacement", 1)
	p.hand.append(replacement)
	var spy: _ChooseCardSpyInput = _ChooseCardSpyInput.new()
	p.input = spy
	spy.queue_choose_card([p.get_equipment("normal")])
	assert_true(await p.equip(replacement), "选取普通装备腾位后应成功装备")
	assert_eq(spy.calls.size(), 1, "应触发一次装备超限选择")
	var candidates: Array = spy.calls[0]["param"]
	assert_false(candidates.has(p.get_equipment("科学家")), "科学家不应出现在装备超限候选中")
	assert_false(candidates.any(func(e): return e.card_name == "zero_size"), "size=0 装备不应出现在候选中")
	assert_true(p.has_equipment("科学家"), "科学家应继续留在装备区")
	assert_true(p.has_equipment("zero_size"), "size=0 装备应继续留在装备区")


## === 十二、科学家不可被 discard/remove_card ===

func test_scientist_is_not_discardable_or_removable() -> void:
	var p: Player = _make_overflow_player()
	_setup_game_for_player(p)
	p.role_card = _make_role(10, 5)
	var scientist: EquipmentCard = _make_overflow_equipment("科学家", 1)
	scientist.english_name = "scientist"
	await p.equip(scientist)
	var entity: Equipment = p.get_equipment("科学家")
	await p.discard(entity)
	assert_true(p.has_equipment("科学家"), "装备区内科学家不能被 discard")
	assert_false(p.game_discard_pile.get_all().has(scientist), "科学家不能进入弃牌堆")
	await p.remove_card(entity)
	assert_true(p.has_equipment("科学家"), "装备区内科学家不能被 remove_card")
	assert_false(Game.removed_cards.has(scientist), "科学家不能被移出游戏")
	var hand_scientist: EquipmentCard = _make_overflow_equipment("科学家", 1)
	hand_scientist.english_name = "scientist"
	p.hand.append(hand_scientist)
	await p.discard(hand_scientist)
	assert_true(p.hand.has(hand_scientist), "手牌区内科学家不能被 discard")
	await p.remove_card(hand_scientist)
	assert_true(p.hand.has(hand_scientist), "手牌区内科学家不能被 remove_card")
	assert_false(Game.removed_cards.has(hand_scientist), "手牌区内科学家不能被移出游戏")


func test_choose_to_discard_filters_hand_scientist() -> void:
	var p: Player = _make_overflow_player()
	_setup_game_for_player(p)
	p.role_card = _make_role(10, 5)
	var scientist: EquipmentCard = _make_overflow_equipment("科学家", 1)
	scientist.english_name = "scientist"
	var normal: Card = _make_card("normal")
	p.hand.append(scientist)
	p.hand.append(normal)
	var spy: _ChooseCardSpyInput = _ChooseCardSpyInput.new()
	p.input = spy
	spy.queue_choose_card([normal])
	await p.choose_to_discard(1)
	assert_eq(spy.calls.size(), 1, "选择弃牌应弹窗一次")
	assert_false(spy.calls[0]["param"].has(scientist), "手牌中的科学家不应出现在弃牌候选中")
	assert_true(p.game_discard_pile.get_all().has(normal), "普通牌应正常被弃置")
	assert_true(p.hand.has(scientist), "科学家应继续留在手牌")
