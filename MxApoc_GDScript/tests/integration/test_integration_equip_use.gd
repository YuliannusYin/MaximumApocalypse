extends TestBase

## 集成测试：装备 + 消耗填充物 + 使用卡牌 + 卸下 全链路。
## 覆盖 Player.equip + EquipmentCard.consume_charge + Player.use_card + Player.unequip。
## 设计文档：GameDesignDocus/GameSystem/Entities/Player.md


# === 辅助方法 ===

func _make_charged_equipment(name: String = "test_equip", charge: int = 3) -> EquipmentCard:
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


# === 测试用例 ===

func test_equip_then_consume_charge_then_unequip() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	var e: EquipmentCard = _make_charged_equipment("weapon", 3)
	# 1. 装备
	await p.equip(e)
	assert_true(p.has_equipment("weapon"), "应已装备")
	assert_eq(p.equipment_zone.size(), 1)
	# 2. 消耗 2 点填充物
	var ok: bool = await p.consume_charge(e, 2)
	assert_true(ok, "消耗应成功")
	assert_eq(e.get_charge(), 1, "应剩 1 点填充物")
	# 3. 卸下
	await p.unequip(e)
	assert_false(p.has_equipment("weapon"), "应已卸下")
	assert_eq(p.equipment_zone.size(), 0)


func test_use_card_equipment_routes_to_equip() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	p.action_count = 4
	var e: EquipmentCard = _make_charged_equipment("weapon", 3)
	p.hand.append(e)
	# 使用装备牌应路由到 equip
	var ok: bool = await p.use_card(e)
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
	var ok: bool = await p.use_card(c)
	assert_true(ok, "使用应成功")
	assert_eq(p.hand.size(), 0, "手牌应清空")
	assert_eq(p.game_discard_pile.get_all().size(), 1, "应进入弃牌堆")
	assert_eq(p.action_count, 4, "无行动技能的卡牌不应消耗行动次数")


func test_equip_same_name_discards_existing() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	var e1: EquipmentCard = _make_charged_equipment("weapon", 3)
	var e2: EquipmentCard = _make_charged_equipment("weapon", 5)
	# 先装备 e1
	await p.equip(e1)
	assert_true(p.has_equipment("weapon"))
	# 再装备同名 e2，应弃置 e1
	await p.equip(e2)
	assert_eq(p.equipment_zone.size(), 1, "装备区应只有 1 个（同名替换）")
	assert_eq(p.game_discard_pile.get_all().size(), 1, "旧装备应进入弃牌堆")
	assert_eq(p.game_discard_pile.get_all()[0], e1, "弃置的应是 e1")
	# 新装备应在装备区（装备区持有 Equipment 实体，来源卡通过 equipment_card 回引）
	assert_eq(p.equipment_zone[0].equipment_card, e2, "装备区实体的来源卡应是 e2")


func test_consume_charge_insufficient_returns_false() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	var e: EquipmentCard = _make_charged_equipment("weapon", 2)
	await p.equip(e)
	# 尝试消耗 3 点（不足）
	var ok: bool = await p.consume_charge(e, 3)
	assert_false(ok, "填充物不足应返回 false")
	assert_eq(e.get_charge(), 2, "填充物应不变")
