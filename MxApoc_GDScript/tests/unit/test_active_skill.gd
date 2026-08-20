extends GutTest

## 通用主动技能单元测试。
## 验证 DataManager 加载、use_active_skill 目标路由与守卫、真实技能集成、
## wait_player_action 循环、start_turn 重置使用次数。
## 设计文档：GameDesignDocus/GameSystem/Common/Skill.md


# === 辅助方法 ===

func _make_player(hp: int = 10, max_hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.hp = hp
	p.max_hp = max_hp
	p.player_name = "TestPlayer"
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	p.in_phase = "action"
	p.action_count = 2
	return p


func _make_block(block_name: String = "test_block", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = block_name
	b.set_coordinate(x, y)
	b.revealed = true
	return b


func _make_card(card_name: String = "test_card", type: String = "action", source: String = "game") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.card_type = type
	c.source = source
	return c


func _make_equipment(card_name: String = "test_equip") -> EquipmentCard:
	var e: EquipmentCard = EquipmentCard.new()
	e.card_name = card_name
	e.card_type = "equipment"
	e.card_subtype = "equipment"
	e.source = "game"
	e.charge_type = "ammo"
	e.charge_max = 3
	e.charge_current = 3
	return e


func _setup_game_with_map(p: Player, blocks: Array) -> void:
	Game.players = [p]
	Game.map_area = blocks
	Game.monster_pile = Pile.new()
	Game.monster_discard_pile = Pile.new()
	Game.red_scavenge_pile = Pile.new()
	Game.green_scavenge_pile = Pile.new()
	Game.blue_scavenge_pile = Pile.new()
	Game.scavenge_discard_pile = Pile.new()


func _get_common_skill(english_name: String) -> Skill:
	for sd in DataManager.get_common_skills():
		if sd.english_name == english_name:
			return Game._create_skill_from_data(sd)
	return null


# === B. use_active_skill 基础守卫 ===

func test_use_active_skill_rejects_null() -> void:
	var p: Player = _make_player()
	await p.use_active_skill(null)
	assert_eq(p.action_count, 2, "null 技能不应消耗行动次数")


func test_use_active_skill_rejects_empty_active() -> void:
	var p: Player = _make_player()
	var s: Skill = Skill.new()
	s.active = ""
	await p.use_active_skill(s)
	assert_eq(p.action_count, 2, "非主动技能不应执行")


func test_use_active_skill_rejects_unusable() -> void:
	var p: Player = _make_player()
	var s: Skill = Skill.new()
	s.active = "action"
	s.usable = 1
	s.record_use()
	await p.use_active_skill(s)
	assert_eq(p.action_count, 2, "不可用技能不应执行")


func test_use_active_skill_filter_fails_returns() -> void:
	var p: Player = _make_player()
	var called: Array = []
	var s: Skill = Skill.new()
	s.active = "action"
	s.filter = func(_pl, _t, _ev, _g) -> bool:
		return false
	s.content = func(_pl, _t, _ev, _g) -> void:
		called.append(true)
	await p.use_active_skill(s)
	assert_eq(called.size(), 0, "filter 失败时 content 不应执行")


# === C. use_active_skill 目标路由 ===

func test_use_active_skill_block_target() -> void:
	var p: Player = _make_player()
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	_setup_game_with_map(p, [b1, b2])
	p.current_block = b1
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_block(b2)
	p.input = cli
	var captured: Array = []
	var s: Skill = Skill.new()
	s.active = "action"
	s.target_type = "block"
	s.content = func(_pl, target, _ev, _g) -> void:
		captured.append(target)
	await p.use_active_skill(s)
	assert_eq(captured, [b2], "content 应收到选中的地块 b2")


func test_use_active_skill_entity_target() -> void:
	var p: Player = _make_player()
	var p2: Player = _make_player()
	p2.player_name = "OtherPlayer"
	var b1: MapBlock = _make_block("b1", 0, 0)
	_setup_game_with_map(p, [b1])
	p.current_block = b1
	p2.current_block = b1
	Game.players = [p, p2]
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose(p2)
	p.input = cli
	var captured: Array = []
	var s: Skill = Skill.new()
	s.active = "action"
	s.target_type = "entity"
	s.filter_target_range = "infinity"
	s.content = func(_pl, target, _ev, _g) -> void:
		captured.append(target)
	await p.use_active_skill(s)
	assert_eq(captured, [p2], "content 应收到选中的玩家 p2")


func test_use_active_skill_pile_target() -> void:
	var p: Player = _make_player()
	var b1: MapBlock = _make_block("b1", 0, 0)
	b1.scavenge_colors = PackedStringArray(["red"])
	_setup_game_with_map(p, [b1])
	p.current_block = b1
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose("red")
	p.input = cli
	var captured: Array = []
	var s: Skill = Skill.new()
	s.active = "action"
	s.target_type = "pile"
	s.content = func(_pl, target, _ev, _g) -> void:
		captured.append(target)
	await p.use_active_skill(s)
	assert_eq(captured, ["red"], "content 应收到选中的颜色 'red'")


func test_use_active_skill_equipment_target() -> void:
	var p: Player = _make_player()
	_setup_game_with_map(p, [])
	var e: EquipmentCard = _make_equipment("fuel_can")
	await p.equip(e)
	var entity: Equipment = p.get_equipment("fuel_can")
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([entity])
	p.input = cli
	var captured: Array = []
	var s: Skill = Skill.new()
	s.active = "action"
	s.target_type = "equipment"
	s.content = func(_pl, target, _ev, _g) -> void:
		captured.append(target)
	await p.use_active_skill(s)
	assert_eq(captured, [entity], "content 应收到选中的装备实体")


# === D. use_active_skill 卡牌选择 ===

func test_use_active_skill_select_card() -> void:
	var p: Player = _make_player()
	_setup_game_with_map(p, [])
	var c1: Card = _make_card("c1")
	var c2: Card = _make_card("c2")
	p.hand.append(c1)
	p.hand.append(c2)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_card([c1, c2])
	p.input = cli
	var captured: Array = []
	var s: Skill = Skill.new()
	s.active = "action"
	s.target_type = ""
	s.select_card = 2
	s.position = "hand"
	s.content = func(_pl, _t, ev: Dictionary, _g) -> void:
		captured.append(ev["cards"])
	await p.use_active_skill(s)
	assert_eq(captured.size(), 1, "content 应执行一次")
	assert_eq(captured[0], [c1, c2], "event.cards 应为选中的两张牌")


# === F. wait_player_action 循环 ===

func test_wait_player_action_exits_on_null() -> void:
	var p: Player = _make_player()
	_setup_game_with_map(p, [])
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_action(null)
	p.input = cli
	await p.wait_player_action()
	assert_true(p.is_alive(), "null 应退出循环，玩家仍存活")


func test_wait_player_action_pile_draw_game_deck() -> void:
	var p: Player = _make_player()
	_setup_game_with_map(p, [])
	p.game_deck.add(_make_card("drawn1"))
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_action({"type": "pile_draw", "pile_key": "game_deck"})
	cli.queue_action(null)
	p.input = cli
	await p.wait_player_action()
	assert_eq(p.hand.size(), 1, "pile_draw game_deck 应摸 1 张牌")
	assert_eq(p.action_count, 1, "摸牌应消耗 1 行动次数")


func test_wait_player_action_pile_draw_scavenge() -> void:
	var p: Player = _make_player()
	_setup_game_with_map(p, [])
	Game.red_scavenge_pile.add(_make_card("scavenge1", "action", "scavenge"))
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_action({"type": "pile_draw", "pile_key": "red_scavenge"})
	cli.queue_action(null)
	p.input = cli
	await p.wait_player_action()
	assert_eq(p.hand.size(), 1, "pile_draw red_scavenge 应抓 1 张拾荒牌")
	assert_eq(p.action_count, 1, "拾荒应消耗 1 行动次数")


func test_execute_pile_draw_invalid_key() -> void:
	var p: Player = _make_player()
	_setup_game_with_map(p, [])
	await p._execute_pile_draw("unknown_key")
	assert_eq(p.action_count, 2, "未知 pile_key 不应消耗行动次数")
	assert_eq(p.hand.size(), 0, "未知 pile_key 不应抓牌")


func test_wait_player_action_card_dict_then_null() -> void:
	var p: Player = _make_player()
	_setup_game_with_map(p, [])
	var c: Card = _make_card("action1", "action")
	p.hand.append(c)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_action({"type": "card", "card": c})
	cli.queue_action(null)
	p.input = cli
	await p.wait_player_action()
	assert_eq(p.hand.size(), 0, "行动牌应被弃置")


# === G. start_turn 重置 ===

func test_start_turn_resets_skill_use_count() -> void:
	var p: Player = _make_player()
	var b1: MapBlock = _make_block("b1", 0, 0)
	_setup_game_with_map(p, [b1])
	p.current_block = b1
	p.game_deck.add(_make_card("c1"))
	var s: Skill = Skill.new()
	s.skill_name = "limited_skill"
	s.active = "action"
	s.usable = 1
	p.add_skill(s)
	s.record_use()
	assert_false(s.is_usable(), "使用一次后应不可用")
	await p.start_turn()
	assert_true(s.is_usable(), "回合开始应重置使用次数")


func test_wait_player_action_move() -> void:
	var p: Player = _make_player()
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	_setup_game_with_map(p, [b1, b2])
	p.current_block = b1
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_action({"type": "move", "target": b2})
	cli.queue_action(null)
	p.input = cli
	await p.wait_player_action()
	assert_eq(p.current_block, b2, "move 动作应将玩家移动到 b2")
	assert_eq(p.action_count, 1, "move 应消耗 1 行动次数")
