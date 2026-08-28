extends GutTest

## Game.get_random_cards 单元测试。
## 覆盖：牌足时返回 n 张不重复、不足 n 张返回全部、无牌返回空数组、n<=0 返回空数组、
## 装备区 Equipment 实体映射为来源 EquipmentCard。


# === 辅助方法 ===

func _make_player() -> Player:
	var p: Player = Player.new()
	p.player_name = "TestPlayer"
	p.hp = 10
	p.max_hp = 10
	return p


func _make_card(card_name: String) -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.card_type = "action"
	c.source = "game"
	return c


func _make_equipment_entry(card_name: String) -> Equipment:
	var card: EquipmentCard = EquipmentCard.new()
	card.card_name = card_name
	card.card_type = "equipment"
	var e: Equipment = Equipment.new()
	e.equipment_name = card_name
	e.equipment_card = card
	return e


# === 一、get_random_cards ===

func test_get_random_cards_returns_n_unique_when_enough() -> void:
	var p: Player = _make_player()
	for i in range(5):
		p.hand.append(_make_card("c%d" % i))
	var cards: Array = Game.get_random_cards(p, ["hand"], 3)
	assert_eq(cards.size(), 3, "手牌 5 张抽 3 张应返回 3 张")
	var seen: Array = []
	for card in cards:
		assert_false(seen.has(card), "返回的牌不应重复")
		assert_true(p.hand.has(card), "返回的牌应来自手牌")
		seen.append(card)


func test_get_random_cards_returns_all_when_fewer_than_n() -> void:
	var p: Player = _make_player()
	var c0: Card = _make_card("c0")
	var c1: Card = _make_card("c1")
	p.hand.append(c0)
	p.hand.append(c1)
	var cards: Array = Game.get_random_cards(p, ["hand"], 5)
	assert_eq(cards.size(), 2, "手牌 2 张抽 5 张应返回全部 2 张")
	assert_true(cards.has(c0) and cards.has(c1), "应包含全部手牌")


func test_get_random_cards_returns_empty_when_no_cards() -> void:
	var p: Player = _make_player()
	var cards: Array = Game.get_random_cards(p, ["hand", "equipment"], 3)
	assert_eq(cards.size(), 0, "无牌时应返回空数组")


func test_get_random_cards_returns_empty_when_n_le_zero() -> void:
	var p: Player = _make_player()
	p.hand.append(_make_card("c0"))
	assert_eq(Game.get_random_cards(p, ["hand"], 0).size(), 0, "n=0 应返回空数组")
	assert_eq(Game.get_random_cards(p, ["hand"], -1).size(), 0, "n<0 应返回空数组")


func test_get_random_cards_maps_equipment_entities_to_cards() -> void:
	var p: Player = _make_player()
	var entry: Equipment = _make_equipment_entry("eq0")
	p.equipment_zone.append(entry)
	p.hand.append(_make_card("c0"))
	p.hand.append(_make_card("c1"))
	var cards: Array = Game.get_random_cards(p, ["hand", "equipment"], 3)
	assert_eq(cards.size(), 3, "手牌 2 张 + 装备 1 件应返回 3 张")
	assert_true(cards.has(entry.equipment_card), "装备区应映射为来源 EquipmentCard")
	for card in cards:
		assert_false(card is Equipment, "返回的不应是 Equipment 实体")
