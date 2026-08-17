extends GutTest

## "手榴弹"与"齐射"实现单元测试。
## 覆盖：get_total_charge_count / clear_charge / Monster.get_current_block / 齐射端到端 / 手榴弹端到端
## 设计 spec：.trae/specs/implement-grenade-and-volley/spec.md


# === 辅助方法 ===

func _make_player(hp: int = 28, max_hp: int = 28) -> Player:
	var p: Player = Player.new()
	p.player_name = "枪手"
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


func _make_monster(monster_name: String = "test_monster", hp: int = 20) -> Monster:
	var mc: MonsterCard = MonsterCard.new()
	mc.card_name = monster_name
	mc.monster_type = "zombie"
	mc.monster_level = "normal"
	mc.max_hp = hp
	mc.damage_value = 2
	mc.range = "none"
	return mc.instantiate(null)


## 创建弹药类武器装备牌
func _make_ammo_weapon(card_name: String = "test_weapon", charge: int = 3, max_charge: int = 6) -> EquipmentCard:
	var c: EquipmentCard = EquipmentCard.new()
	c.card_name = card_name
	c.english_name = card_name
	c.card_type = "equipment"
	c.source = "game"
	c.charge_type = "ammo"
	c.charge_max = max_charge
	c.charge_current = charge
	c.size = 1
	c.range = "short"
	return c


## 创建燃料类装备牌（用于验证不影响其他 charge_type）
func _make_fuel_equipment(card_name: String = "test_fuel", charge: int = 2) -> EquipmentCard:
	var c: EquipmentCard = EquipmentCard.new()
	c.card_name = card_name
	c.english_name = card_name
	c.card_type = "equipment"
	c.source = "game"
	c.charge_type = "fuel"
	c.charge_max = 4
	c.charge_current = charge
	c.size = 1
	return c


## 从枪手数据创建一张真实卡牌
func _make_gunslinger_card(card_name: String) -> Card:
	var sd: SurvivorData = DataManager.get_survivor("gunslinger")
	assert_not_null(sd, "应能加载枪手 survivor 数据")
	for card_dict in sd.deck:
		if card_dict.get("card_name", "") == card_name:
			return Game._create_game_card_from_dict(card_dict)
	assert(false, "未找到枪手卡牌: " + card_name)
	return null


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


# === 1. get_total_charge_count ===

# 测试 1: 多装备累加弹药总数
func test_get_total_charge_count_multiple_ammo() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var w1: EquipmentCard = _make_ammo_weapon("手枪A", 2)
	var w2: EquipmentCard = _make_ammo_weapon("手枪B", 3)
	await p.equip(w1)
	await p.equip(w2)
	assert_eq(p.get_total_charge_count("ammo"), 5, "两把弹药武器（2+3）应累加为 5")


# 测试 2: 无匹配 charge_type 返回 0
func test_get_total_charge_count_no_match_returns_zero() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var fuel: EquipmentCard = _make_fuel_equipment("燃料", 2)
	await p.equip(fuel)
	assert_eq(p.get_total_charge_count("ammo"), 0, "仅有燃料装备时 ammo 总数应为 0")


# === 2. clear_charge ===

# 测试 3: clear_charge 清零弹药并输出弃掉日志
func test_clear_charge_zeros_ammo_and_logs() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 3)
	await p.equip(weapon)
	var weapon_entity: Equipment = p.equipment_zone[0]
	assert_eq(weapon_entity.get_charge(), 3, "使用前应有 3 发弹药")
	await p.clear_charge("ammo")
	assert_eq(weapon_entity.charge_current, 0, "clear_charge 后弹药应清零")
	assert_eq(weapon.charge_current, 0, "卡牌 charge_current 应同步为 0")
	assert_true(
		Game.log_list.any(func(l): return l.contains("弃掉了") and l.contains("ammo") and l.contains("3")),
		"应输出 弃掉了 3 发 ammo 弹药 日志"
	)


# 测试 4: clear_charge 不影响其他 charge_type
func test_clear_charge_preserves_other_charge_type() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var ammo_weapon: EquipmentCard = _make_ammo_weapon("手枪", 2)
	var fuel_equip: EquipmentCard = _make_fuel_equipment("燃料", 2)
	await p.equip(ammo_weapon)
	await p.equip(fuel_equip)
	await p.clear_charge("ammo")
	assert_eq(ammo_weapon.charge_current, 0, "弹药武器应被清零")
	assert_eq(fuel_equip.charge_current, 2, "燃料装备不应受影响")


# === 3. Monster.get_current_block ===

# 测试 5: 返回所属玩家当前地块
func test_monster_get_current_block_returns_owner_block() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("b1", 1, 1)
	p.current_block = block
	var monster: Monster = _make_monster("僵尸", 20)
	p.monster_zone = [monster]
	assert_eq(monster.get_current_block(), block, "应返回所属玩家的当前地块")


# 测试 6: 怪物不在任何 player 的 monster_zone 时返回 null
func test_monster_get_current_block_no_owner_returns_null() -> void:
	# before_each 已清空 Game.players
	var monster: Monster = _make_monster("游离怪物", 20)
	assert_eq(monster.get_current_block(), null, "无所属玩家时应返回 null")


# === 4. 齐射端到端 ===

# 测试 7: 齐射清零弹药并对目标造成 X×2 伤害
func test_volley_clears_ammo_and_deals_x_times_two_damage() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("center", 1, 1)
	Game.map_area = [block]
	p.current_block = block
	# 装备 1 把弹药武器，charge=3 → X=3，目标受 6 点伤害
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 3)
	await p.equip(weapon)
	var weapon_entity: Equipment = p.equipment_zone[0]
	# 创建怪物目标（同地块，在 p.monster_zone 中）
	var monster: Monster = _make_monster("僵尸", 20)
	p.monster_zone = [monster]
	# 创建齐射卡牌
	var card: Card = _make_gunslinger_card("齐射")
	assert_not_null(card, "应能创建齐射卡牌")
	p.hand.append(card)
	# mock input：选取怪物为目标
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([monster])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用齐射应成功")
	assert_eq(weapon_entity.charge_current, 0, "弹药应被清零")
	assert_eq(monster.hp, 20 - 6, "怪物应受 6 点伤害（3 发 × 2）")


# === 5. 手榴弹端到端 ===

# 测试 8: 手榴弹对目标 5 伤害 + 同地块溅射 3 伤害
func test_grenade_deals_5_to_target_and_3_splash_to_same_block() -> void:
	var p: Player = _make_player(28, 28)
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("center", 1, 1)
	Game.map_area = [block]
	p.current_block = block
	# 创建两个怪物（同地块，在 p.monster_zone 中）
	var m1: Monster = _make_monster("僵尸A", 20)
	var m2: Monster = _make_monster("僵尸B", 20)
	p.monster_zone = [m1, m2]
	# 创建手榴弹卡牌
	var card: Card = _make_gunslinger_card("手榴弹")
	assert_not_null(card, "应能创建手榴弹卡牌")
	p.hand.append(card)
	# mock input：选取 m1 为目标
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([m1])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用手榴弹应成功")
	assert_eq(m1.hp, 20 - 5, "M1 应受 5 点伤害")
	assert_eq(m2.hp, 20 - 3, "M2 应受 3 点溅射伤害")
	assert_eq(p.hp, 28 - 3, "玩家应受 3 点溅射伤害")


# === 6. 取消保护 ===

# 测试 9: 齐射取消选取目标 — 牌退回手牌，不消耗行动，弹药不清零
func test_volley_cancel_target_returns_to_hand() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("center", 1, 1)
	Game.map_area = [block]
	p.current_block = block
	var weapon: EquipmentCard = _make_ammo_weapon("手枪", 3)
	await p.equip(weapon)
	var weapon_entity: Equipment = p.equipment_zone[0]
	var monster: Monster = _make_monster("僵尸", 20)
	p.monster_zone = [monster]
	var card: Card = _make_gunslinger_card("齐射")
	p.hand.append(card)
	# mock input：取消选取（空数组表示取消）
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_false(result, "取消选取应返回 false")
	assert_eq(p.action_count, 2, "不应消耗行动次数")
	assert_eq(p.hand.size(), 1, "牌应退回手牌")
	assert_eq(p.hand[0].card_name, "齐射", "手牌中应为齐射")
	assert_eq(weapon_entity.charge_current, 3, "取消时弹药不应被清零")
	assert_eq(monster.hp, 20, "取消时目标不应受伤")


# 测试 10: 手榴弹取消选取目标 — 牌退回手牌，不消耗行动，目标不受伤
func test_grenade_cancel_target_returns_to_hand() -> void:
	var p: Player = _make_player()
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("center", 1, 1)
	Game.map_area = [block]
	p.current_block = block
	var m1: Monster = _make_monster("僵尸A", 20)
	var m2: Monster = _make_monster("僵尸B", 20)
	p.monster_zone = [m1, m2]
	var card: Card = _make_gunslinger_card("手榴弹")
	p.hand.append(card)
	# mock input：取消选取（空数组表示取消）
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_false(result, "取消选取应返回 false")
	assert_eq(p.action_count, 2, "不应消耗行动次数")
	assert_eq(p.hand.size(), 1, "牌应退回手牌")
	assert_eq(p.hand[0].card_name, "手榴弹", "手牌中应为手榴弹")
	assert_eq(m1.hp, 20, "取消时目标不应受伤")
	assert_eq(m2.hp, 20, "取消时溅射目标不应受伤")
	assert_eq(p.hp, 28, "取消时玩家不应受伤")
