extends GutTest

## 拾荒基础设施单元测试。
## 覆盖：ImageCache 拾荒图片加载、Pile/EquipmentCard/MapBlock/ScavengeCard 基础设施、
## Player.gain/get_discard_pile/choose_card、Game.create_scavenge_card、装备区字段维护。
## 卡牌效果以实机验证为准，不做逐卡效果测试。


# === 辅助方法 ===

func _make_player(hp: int = 10, max_hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = "TestPlayer"
	p.hp = hp
	p.max_hp = max_hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	p.in_phase = "action"
	p.action_count = 2
	return p


func _make_card(card_name: String = "test_card", type: String = "action") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.card_type = type
	c.source = "game"
	return c


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
	Game.log_list = []
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func before_each() -> void:
	_clear_game()


func after_each() -> void:
	_clear_game()


# === 一、基础设施测试 ===

func test_image_cache_loads_scavenging_images() -> void:
	# 触发 ImageCache 惰性初始化（扫描 images/scavenging/ 等目录）
	ImageCache.get_card_texture("")
	# 图片文件名用下划线命名（如「弹药_少量.png」），_card_textures 按文件主名索引
	assert_true(ImageCache._card_textures.has("弹药_少量"), "应加载弹药_少量图片")
	assert_true(ImageCache._card_textures.has("大炸药"), "应加载大炸药图片")
	assert_true(ImageCache._card_textures.has("医疗用品_小型"), "应加载医疗用品_小型图片")
	assert_true(ImageCache._card_textures.has("防弹背心"), "应加载防弹背心图片")
	assert_true(ImageCache._card_textures.has("背包"), "应加载背包图片")
	assert_true(ImageCache._card_textures.has("手电筒"), "应加载手电筒图片")
	assert_true(ImageCache._card_textures.has("科学家"), "应加载科学家图片")
	assert_true(ImageCache._card_textures.has("燃料"), "应加载燃料图片")
	assert_true(ImageCache._card_textures.has("一无所获"), "应加载一无所获图片")
	assert_true(ImageCache._card_textures.has("解毒剂"), "应加载解毒剂图片")
	assert_true(ImageCache._card_textures.has("伏击"), "应加载伏击图片")


func test_image_cache_normalizes_card_name_lookup() -> void:
	# card_name 用全角括号/感叹号，图片文件名用下划线/无标点，查找时应规范化匹配
	# 「弹药（少量）」应命中「弹药_少量.png」
	var exact: Variant = ImageCache._card_textures.get("弹药_少量", null)
	var normalized: Variant = ImageCache.get_card_texture("弹药（少量）")
	assert_eq(normalized, exact, "card_name「弹药（少量）」应通过规范化命中「弹药_少量」图片")
	# 「伏击！」应命中「伏击.png」
	var ambush_exact: Variant = ImageCache._card_textures.get("伏击", null)
	var ambush_normalized: Variant = ImageCache.get_card_texture("伏击！")
	assert_eq(ambush_normalized, ambush_exact, "card_name「伏击！」应通过规范化命中「伏击」图片")
	# 「医疗用品（小型）」应命中「医疗用品_小型.png」
	var med_exact: Variant = ImageCache._card_textures.get("医疗用品_小型", null)
	var med_normalized: Variant = ImageCache.get_card_texture("医疗用品（小型）")
	assert_eq(med_normalized, med_exact, "card_name「医疗用品（小型）」应通过规范化命中「医疗用品_小型」图片")


func test_pile_peek_top() -> void:
	var p: Pile = Pile.new()
	var c1: Card = _make_card("c1")
	var c2: Card = _make_card("c2")
	var c3: Card = _make_card("c3")
	p.add(c1)
	p.add(c2)
	p.add(c3)
	var top2: Array = p.peek_top(2)
	assert_eq(top2.size(), 2, "peek_top(2) 应返回前 2 张")
	assert_eq(top2[0], c1, "首张应为 c1")
	assert_eq(top2[1], c2, "次张应为 c2")
	assert_eq(p.size(), 3, "peek_top 不应修改原牌堆")


func test_pile_put_bottom() -> void:
	var p: Pile = Pile.new()
	p.add(_make_card("c1"))
	var bottom: Card = _make_card("c2")
	p.put_bottom(bottom)
	assert_eq(p.size(), 2, "put_bottom 后应有 2 张")
	assert_eq(p.get_all()[1], bottom, "put_bottom 的牌应在末尾")


func test_equipment_card_in_equipment_area_default_false() -> void:
	var ec: EquipmentCard = EquipmentCard.new()
	assert_false(ec.in_equipment_area, "新建装备牌默认不在装备区")


func test_equipment_card_fill_charge() -> void:
	var ec: EquipmentCard = EquipmentCard.new()
	ec.charge_max = 4
	ec.charge_current = 0
	ec.fill_charge()
	assert_eq(ec.charge_current, 4, "fill_charge 应将填充物填满到上限")


func test_map_block_is_map_block() -> void:
	var b: MapBlock = MapBlock.new()
	assert_true(b.is_map_block(), "MapBlock.is_map_block 应返回 true")


func test_scavenge_card_get_color() -> void:
	var sc: ScavengeCard = ScavengeCard.new()
	sc.color = "red"
	assert_eq(sc.get_color(), "red", "get_color 应返回 red")
	sc.color = "blue"
	assert_eq(sc.get_color(), "blue", "get_color 应返回 blue")


func test_player_gain() -> void:
	var p: Player = _make_player()
	var c: Card = _make_card("c1")
	p.gain(c)
	assert_eq(p.hand.size(), 1, "gain 后手牌应有 1 张")
	assert_eq(p.hand[p.hand.size() - 1], c, "gain 的牌应在手牌末尾")


func test_player_get_discard_pile() -> void:
	var p: Player = _make_player()
	var dp: Pile = Pile.new()
	p.game_discard_pile = dp
	assert_eq(p.get_discard_pile(), dp, "get_discard_pile 应返回 game_discard_pile")


func test_player_choose_card_array_mode() -> void:
	var p: Player = _make_player()
	var cli: CliPlayerInput = CliPlayerInput.new()
	var c1: Card = _make_card("c1")
	var c2: Card = _make_card("c2")
	cli.queue_choose_card([c1])
	p.input = cli
	# Array 模式：直接作为候选卡牌列表传入
	var chosen: Array = await p.choose_card(1, [c1, c2])
	assert_eq(chosen.size(), 1, "应返回 1 张牌")
	assert_eq(chosen[0], c1, "应返回队列中注入的 c1")


func test_game_create_scavenge_card_found() -> void:
	var card: Card = Game.create_scavenge_card("弹药（少量）")
	assert_not_null(card, "应能创建【弹药（少量）】")
	assert_eq(card.card_name, "弹药（少量）")
	assert_eq(card.source, "scavenge", "拾荒卡 source 应为 scavenge")


func test_game_create_scavenge_card_not_found() -> void:
	var card: Card = Game.create_scavenge_card("不存在的卡名")
	assert_null(card, "不存在的卡名应返回 null")


# === 二、装备区字段维护测试 ===

func test_equip_sets_in_equipment_area_true() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var e: EquipmentCard = EquipmentCard.new()
	e.card_name = "test_equip"
	e.card_type = "equipment"
	e.card_subtype = "equipment"
	e.source = "game"
	await p.equip(e)
	var entity: Equipment = p.get_equipment("test_equip")
	assert_not_null(entity, "装备区应有 Equipment 实体")
	assert_true(entity.in_equipment_area, "装备后实体 in_equipment_area 应为 true")


func test_unequip_sets_in_equipment_area_false() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var e: EquipmentCard = EquipmentCard.new()
	e.card_name = "test_equip"
	e.card_type = "equipment"
	e.card_subtype = "equipment"
	e.source = "game"
	await p.equip(e)
	var entity: Equipment = p.get_equipment("test_equip")
	await p.unequip(e)
	assert_false(entity.in_equipment_area, "卸下后实体 in_equipment_area 应为 false")
