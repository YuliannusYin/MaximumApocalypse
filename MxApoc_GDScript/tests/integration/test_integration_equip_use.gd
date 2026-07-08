extends GutTest

## 集成测试：装备 + 消耗填充物 + 使用卡牌 + 卸下 全链路。
## 覆盖 Player.equip + EquipmentCard.consume_charge + Player.use_card + Player.unequip。
## 设计文档：GameDesignDocus/GameSystem/Entities/Player.md


# === 辅助方法 ===

func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_equipment(name: String = "test_equip", charge: int = 3) -> EquipmentCard:
	var e: EquipmentCard = EquipmentCard.new()
	e.card_name = name
	e.card_type = "equipment"
	e.card_subtype = "equipment"
	e.source = "game"
	e.charge_type = "ammo"
	e.charge_max = charge
	e.charge_current = charge
	return e


func _make_action_card(name: String = "action1") -> Card:
	var c: Card = Card.new()
	c.card_name = name
	c.card_type = "action"
	c.source = "game"
	return c


func _clear_game() -> void:
	Game.players = []
	Game.map_area = []
	Game.monster_pile = null
	Game.monster_discard_pile = null
	Game.scavenge_discard_pile = null
	Game.red_scavenge_pile = null
	Game.green_scavenge_pile = null
	Game.blue_scavenge_pile = null
	Game.mission_config = null
	Game.removed_cards = []
	Game.game_over_called = false
	Game.game_result = ""
	Game.coop_death_mode = false
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()


# === 测试用例 ===

func test_equip_then_consume_charge_then_unequip() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	var e: EquipmentCard = _make_equipment("weapon", 3)
	# 1. 装备
	p.equip(e)
	assert_true(p.has_equipment("weapon"), "应已装备")
	assert_eq(p.equipment_zone.size(), 1)
	# 2. 消耗 2 点填充物
	var ok: bool = p.consume_charge(e, 2)
	assert_true(ok, "消耗应成功")
	assert_eq(e.get_charge(), 1, "应剩 1 点填充物")
	# 3. 卸下
	p.unequip(e)
	assert_false(p.has_equipment("weapon"), "应已卸下")
	assert_eq(p.equipment_zone.size(), 0)


func test_use_card_equipment_routes_to_equip() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	p.action_count = 4
	var e: EquipmentCard = _make_equipment("weapon", 3)
	p.hand.append(e)
	# 使用装备牌应路由到 equip
	var ok: bool = p.use_card(e)
	assert_true(ok, "使用应成功")
	assert_true(p.has_equipment("weapon"), "应已装备")
	assert_eq(p.equipment_zone.size(), 1, "装备区应有 1 张")
	assert_eq(p.action_count, 3, "应消耗 1 行动次数")


func test_use_card_action_routes_to_discard() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	p.action_count = 4
	var c: Card = _make_action_card("action1")
	p.hand.append(c)
	# 使用行动牌应路由到 discard
	var ok: bool = p.use_card(c)
	assert_true(ok, "使用应成功")
	assert_eq(p.hand.size(), 0, "手牌应清空")
	assert_eq(p.game_discard_pile.get_all().size(), 1, "应进入弃牌堆")
	assert_eq(p.action_count, 3, "应消耗 1 行动次数")


func test_equip_same_name_discards_existing() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	var e1: EquipmentCard = _make_equipment("weapon", 3)
	var e2: EquipmentCard = _make_equipment("weapon", 5)
	# 先装备 e1
	p.equip(e1)
	assert_true(p.has_equipment("weapon"))
	# 再装备同名 e2，应弃置 e1
	p.equip(e2)
	assert_eq(p.equipment_zone.size(), 1, "装备区应只有 1 个（同名替换）")
	assert_eq(p.game_discard_pile.get_all().size(), 1, "旧装备应进入弃牌堆")
	assert_eq(p.game_discard_pile.get_all()[0], e1, "弃置的应是 e1")
	# 新装备应在装备区
	assert_eq(p.equipment_zone[0], e2, "装备区应是 e2")


func test_consume_charge_insufficient_returns_false() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	var e: EquipmentCard = _make_equipment("weapon", 2)
	p.equip(e)
	# 尝试消耗 3 点（不足）
	var ok: bool = p.consume_charge(e, 3)
	assert_false(ok, "填充物不足应返回 false")
	assert_eq(e.get_charge(), 2, "填充物应不变")
