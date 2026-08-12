extends GutTest

## 拾荒卡图片实装与使用流程单元测试。
## 覆盖：ImageCache 拾荒图片加载、Pile/EquipmentCard/MapBlock/ScavengeCard 基础设施、
## Player.gain/get_discard_pile/choose_card、Game.create_scavenge_card、
## 装备区字段维护，以及关键拾荒卡（行动牌/装备被动/抓牌触发/item）use_card 流程。
## 参考：tests/unit/test_use_card_firefighter.gd 的 fixture 模式。
## 数据来源：data/scavenge/{red,green,blue,gray}.json


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


func _make_block(block_name: String = "test_block", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = block_name
	b.set_coordinate(x, y)
	return b


func _make_card(card_name: String = "test_card", type: String = "action") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.card_type = type
	c.source = "game"
	return c


func _make_monster_card(card_name: String = "test_monster") -> MonsterCard:
	var mc: MonsterCard = MonsterCard.new()
	mc.card_name = card_name
	mc.card_type = "monster"
	mc.source = "monster"
	mc.monster_type = "zombie"
	mc.monster_level = "normal"
	mc.max_hp = 3
	mc.damage_value = 2
	mc.range = "none"
	return mc


## 通过 Game.create_scavenge_card 创建一张真实拾荒卡（含编译后的技能 Callable）。
func _make_scavenge_card(card_name: String) -> Card:
	var card: Card = Game.create_scavenge_card(card_name)
	assert_not_null(card, "应能创建拾荒卡: " + card_name)
	return card


## 将卡牌自身的 forced trigger 技能挂载到玩家身上。
## 说明：当前 draw_scavenge 不会把被抓取卡的 forced trigger 技能挂载到玩家，
## 故 on_draw_scavenge_card 不会激活卡牌自身的强制触发。此方法模拟设计意图，
## 便于在抓牌流程中验证卡牌技能 content 的执行效果。
func _mount_card_skills(p: Player, card: Card) -> void:
	if card == null or not is_instance_valid(card):
		return
	for s in card.get_all_skills():
		p.add_skill(s)


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


# === 三、关键拾荒卡使用流程测试 ===

# --- 行动牌 ---

# 使用"医疗用品（小型）"回复 4 点生命值
func test_use_medical_supplies_small_recovers_hp() -> void:
	var p: Player = _make_player(6, 20)
	_setup_game_for_player(p)
	var card: Card = _make_scavenge_card("医疗用品（小型）")
	p.hand.append(card)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([p])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用医疗用品（小型）应成功")
	assert_eq(p.hp, 10, "应回复 4 点生命值（6 + 4 = 10）")
	assert_eq(Game.scavenge_discard_pile.size(), 1, "拾荒卡应进入拾荒弃牌堆")


# 使用"解毒剂"清除中毒与饥饿伤害状态
func test_use_antidote_heals_status() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	p.add_mark("poison", 2)
	p.add_mark("hunger_damage_level", 1)
	var card: Card = _make_scavenge_card("解毒剂")
	p.hand.append(card)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([p])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用解毒剂应成功")
	assert_false(p.has_mark("poison"), "解毒剂应清除中毒状态")
	assert_false(p.has_mark("hunger_damage_level"), "解毒剂应清除饥饿伤害状态")


# 使用"炸药"移除地块上所有目标标记并对地块上目标造成 8 点伤害
func test_use_dynamite_destroys_objective_marks() -> void:
	var p: Player = _make_player(32, 32)
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("target", 0, 0)
	block.revealed = true
	block.add_objective_mark({"id": "obj1", "removed": false, "triggered": false})
	block.add_objective_mark({"id": "obj2", "removed": false, "triggered": false})
	Game.map_area = [block]
	p.current_block = block  # 玩家在地块上，作为伤害目标
	var card: Card = _make_scavenge_card("炸药")
	p.hand.append(card)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([block])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用炸药应成功")
	assert_false(block.has_objective_mark(), "炸药应移除地块上所有目标标记")
	assert_eq(p.hp, 24, "炸药应对地块上目标造成 8 点伤害（32 - 8 = 24）")


# 使用"大炸药"摧毁地块（destroy_map_block）
func test_use_big_dynamite_destroys_block() -> void:
	var p: Player = _make_player(32, 32)
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("target", 0, 0)
	block.revealed = true
	Game.map_area = [block]
	# 玩家不在目标地块上，避免 destroy_map_block 的弹出逻辑
	p.current_block = null
	var card: Card = _make_scavenge_card("大炸药")
	p.hand.append(card)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([block])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用大炸药应成功")
	assert_eq(block.block_state, "destroyed", "大炸药应摧毁地块")
	assert_false(Game.map_area.has(block), "被摧毁的地块应从地图区域移除")


# 使用"弹药（少量）"给装备区武器加 2 发弹药
# 已修复：EquipmentCard.add_charge 已实装；ScavengeCard extends EquipmentCard，具备 charge_type 字段。
# 重构后装备区持有 Equipment 实体：choose_target 候选为实体，content 在实体上调用 add_charge（委托回来源卡）。
func test_use_ammo_small_adds_charge() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	var pistol: Card = _make_scavenge_card("手枪")
	pistol.charge_current = 0  # 弹药耗尽以便触发 filter（charge_current < charge_max）
	await p.equip(pistol)
	var pistol_entity: Equipment = p.get_equipment("手枪")
	var card: Card = _make_scavenge_card("弹药（少量）")
	p.hand.append(card)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([pistol_entity])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用弹药（少量）应成功")
	assert_eq(pistol.charge_current, 2, "应填充 2 发弹药")
	assert_eq(Game.scavenge_discard_pile.size(), 1, "弹药卡应进入拾荒弃牌堆")


# 使用"食物（小额）"降低饥饿值
# 已修复：food 卡 filter 使用 player.get_number("hunger")，Player.get_number 已识别 "hunger"。
func test_use_food_small_reduces_hunger() -> void:
	var p: Player = _make_player(10, 10)
	p.hunger = 3  # 饥饿值 > 1 以通过 filter
	_setup_game_for_player(p)
	var card: Card = _make_scavenge_card("食物（小额）")
	p.hand.append(card)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([p])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用食物（小额）应成功")
	assert_eq(p.hunger, 1, "应减少 2 点饥饿值（3 - 2 = 1，最低 1）")
	assert_eq(Game.scavenge_discard_pile.size(), 1, "食物卡应进入拾荒弃牌堆")


# 使用"多余配件"从弃牌堆回手
# 已修复：spare_parts content 调用 player.gain(card[0])，正确取 Array 首元素。
func test_use_spare_parts_returns_card_from_discard() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	var discarded: Card = _make_card("discarded_card")
	discarded.source = "game"
	p.game_discard_pile.add(discarded)
	var card: Card = _make_scavenge_card("多余配件")
	p.hand.append(card)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_card([discarded])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用多余配件应成功")
	assert_true(p.hand.has(discarded), "弃牌堆中的牌应回到手牌")
	assert_eq(Game.scavenge_discard_pile.size(), 1, "多余配件卡应进入拾荒弃牌堆")


# --- 装备被动 ---

# 装备"防弹背心"受到伤害时减伤 2
func test_bulletproof_vest_reduces_damage() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	var vest: Card = _make_scavenge_card("防弹背心")
	await p.equip(vest)
	assert_true(p.has_equipment("防弹背心"), "防弹背心应进入装备区")
	await p.damage(5, null)
	assert_eq(p.hp, 7, "防弹背心应减伤 2（5 - 2 = 3 伤害，10 - 3 = 7）")


# 累计 3 次伤害后销毁防弹背心
# 已修复：Player._card_matches 双匹配 card_name + english_name，remove_card("bulletproof_vest", ...) 可命中。
func test_bulletproof_vest_destroyed_after_3_uses() -> void:
	var p: Player = _make_player(20, 20)
	_setup_game_for_player(p)
	var vest: Card = _make_scavenge_card("防弹背心")
	await p.equip(vest)
	assert_true(p.has_equipment("防弹背心"), "防弹背心应进入装备区")
	# 第一次伤害：减伤 2，使用次数 1
	await p.damage(5, null)
	assert_eq(p.hp, 17, "第一次：减伤 2（5-2=3，20-3=17）")
	assert_true(p.has_equipment("防弹背心"), "第一次后背心仍在装备区")
	# 第二次伤害：减伤 2，使用次数 2
	await p.damage(5, null)
	assert_eq(p.hp, 14, "第二次：减伤 2（17-3=14）")
	assert_true(p.has_equipment("防弹背心"), "第二次后背心仍在装备区")
	# 第三次伤害：减伤 2，使用次数 3 → 销毁
	await p.damage(5, null)
	assert_eq(p.hp, 11, "第三次：减伤 2（14-3=11）")
	assert_false(p.has_equipment("防弹背心"), "第三次后背心应被销毁")


# 装备"背包"后装备栏 +1
# 已修复：Player.increase_equipment_slot 已实装（修改 role_card.equipment_capacity）。
func test_backpack_increases_equipment_slot_on_equip() -> void:
	var p: Player = _make_player(10, 10)
	p.role_card = RoleCard.new()
	p.role_card.equipment_capacity = 3
	_setup_game_for_player(p)
	var backpack: Card = _make_scavenge_card("背包")
	var before: int = p.role_card.equipment_capacity
	await p.equip(backpack)
	assert_eq(p.role_card.equipment_capacity, before + 1, "装备背包后装备栏 +1")


# 卸下"背包"后装备栏 -1
# 已修复：Player.decrease_equipment_slot 已实装；unequip 在 on_unequip 触发后再移除技能，
# 确保背包的 on_unequip 被动仍可见技能。
func test_backpack_decreases_equipment_slot_on_unequip() -> void:
	var p: Player = _make_player(10, 10)
	p.role_card = RoleCard.new()
	p.role_card.equipment_capacity = 3
	_setup_game_for_player(p)
	var backpack: Card = _make_scavenge_card("背包")
	await p.equip(backpack)
	assert_eq(p.role_card.equipment_capacity, 4, "装备后装备栏应为 4")
	await p.unequip(backpack)
	assert_eq(p.role_card.equipment_capacity, 3, "卸下背包后装备栏应恢复为 3")


# "手电筒"替代抓拾荒牌（peek 2 选 1）
# 已修复：content 使用 EventSystem.cancel(event)；draw_scavenge 挂载卡牌 forced 触发技能；
# content 改用 pile.draw() 取出顶 2 张（避免 peek_top 不移除导致的牌堆复制 bug）。
func test_flashlight_replaces_draw_scavenge() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	var flashlight: Card = _make_scavenge_card("手电筒")
	await p.equip(flashlight)
	var pile: Pile = Pile.new()
	var c1: Card = _make_scavenge_card("脏毯子")
	var c2: Card = _make_scavenge_card("老报纸")
	pile.add(c1)
	pile.add(c2)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose(c1)  # 选择保留 c1
	p.input = cli
	await p.draw_scavenge(1, pile)
	assert_true(p.hand.has(c1), "应保留 c1 并进入手牌")
	assert_false(p.hand.has(c2), "c2 不应进入手牌")
	assert_eq(pile.size(), 1, "牌堆应剩 1 张（c2 置于牌堆底）")
	assert_eq(pile.get_all()[0], c2, "c2 应在牌堆底")


# 装备"科学家"强制潜行检定失败
func test_scientist_forces_sneak_fail() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	# 高潜行：正常情况下 sneak_judge 应成功
	p.role_card = RoleCard.new()
	p.role_card.sneak = 20
	var block: MapBlock = _make_block("b", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	var scientist: Card = _make_scavenge_card("科学家")
	await p.equip(scientist)
	assert_true(p.has_equipment("scientist"), "科学家应已在装备区")
	var result: bool = await p.sneak_judge()
	assert_false(result, "科学家应强制潜行检定失败（即便潜行值很高）")


# --- 抓牌触发 ---
# 说明：draw_scavenge 已挂载被抓取卡的 forced trigger 技能（on_draw_scavenge_card），
# 故无需手动 _mount_card_skills；手动挂载会导致技能被双重触发（discard 两次等）。

# 抓到"一无所获"立即弃掉
func test_nothing_found_discards_immediately() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	var pile: Pile = Pile.new()
	var card: Card = _make_scavenge_card("一无所获")
	pile.add(card)
	await p.draw_scavenge(1, pile)
	assert_false(p.hand.has(card), "一无所获应被立即弃掉，不在手牌")
	assert_eq(Game.scavenge_discard_pile.size(), 1, "一无所获应进入拾荒弃牌堆")


# 抓到"伏击！"立即抓 1 张怪物卡并弃掉此卡
func test_ambush_draws_monster_card() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	# 怪物牌堆需有牌以供 draw_monster(1)
	Game.monster_pile.add(_make_monster_card("ambush_zombie"))
	var pile: Pile = Pile.new()
	var card: Card = _make_scavenge_card("伏击！")
	pile.add(card)
	await p.draw_scavenge(1, pile)
	assert_eq(p.monster_zone.size(), 1, "伏击应抓 1 张怪物卡并实体化")
	assert_false(p.hand.has(card), "伏击卡应被弃掉")
	assert_eq(Game.scavenge_discard_pile.size(), 1, "伏击卡应进入拾荒弃牌堆")


# 抓到"燃料"立即装备或弃掉
func test_fuel_equip_or_discard() -> void:
	var p: Player = _make_player(10, 10)
	_setup_game_for_player(p)
	var pile: Pile = Pile.new()
	var card: Card = _make_scavenge_card("燃料")
	pile.add(card)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose("装备燃料")
	p.input = cli
	await p.draw_scavenge(1, pile)
	assert_true(p.has_equipment(card.card_name), "选择装备燃料后应进入装备区")
	assert_false(p.hand.has(card), "燃料不应留在手牌")


# --- item 卡 ---

# 脏毯子/老报纸/满是灰尘的日记本 无技能可进入手牌
func test_item_cards_enter_hand_without_skill() -> void:
	var names: Array = ["脏毯子", "老报纸", "满是灰尘的日记本"]
	for name in names:
		var card: Card = Game.create_scavenge_card(name)
		assert_not_null(card, "应能创建【%s】" % name)
		assert_eq(card.card_type, "item", "%s 应为 item 类型" % name)
		assert_eq(card.get_all_skills().size(), 0, "%s 应无技能" % name)
		var p: Player = _make_player()
		p.gain(card)
		assert_true(p.hand.has(card), "%s 应能进入手牌" % name)
