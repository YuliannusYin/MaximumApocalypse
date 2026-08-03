extends GutTest

## 消防员卡牌使用流程单元测试。
## 覆盖 use_card 行动牌分支（content 执行 + 弃牌）、consume_action、
## get_charge_count、game.get_card / game.get_target。
## 设计文档：GameDesignDocus/GameSystem/Entities/Player.md


# === 辅助方法 ===

func _make_firefighter_player(hp: int = 32, max_hp: int = 32) -> Player:
	var p: Player = Player.new()
	p.player_name = "消防员"
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


func _make_monster(monster_name: String = "test_monster") -> Monster:
	var mc: MonsterCard = MonsterCard.new()
	mc.card_name = monster_name
	mc.monster_type = "zombie"
	mc.monster_level = "normal"
	mc.max_hp = 3
	mc.damage_value = 2
	mc.range = "none"
	return mc.instantiate(null)


func _make_card(card_name: String = "test_card", type: String = "action") -> Card:
	var c: Card = Card.new()
	c.card_name = card_name
	c.card_type = type
	c.source = "game"
	return c


## 从消防员 survivor 数据中取出指定卡牌的原始字典。
func _get_firefighter_card_dict(card_name: String) -> Dictionary:
	var sd: SurvivorData = DataManager.get_survivor("firefighter")
	assert_not_null(sd, "应能加载消防员 survivor 数据")
	for card_dict in sd.deck:
		if card_dict.get("card_name", "") == card_name:
			return card_dict
	return {}


## 从消防员数据创建一张真实卡牌（含编译后的技能 Callable）。
func _make_firefighter_card(card_name: String) -> Card:
	var card_dict: Dictionary = _get_firefighter_card_dict(card_name)
	assert(!card_dict.is_empty(), "未找到消防员卡牌: " + card_name)
	return Game._create_game_card_from_dict(card_dict)


## 从消防员数据创建一张装备牌。
func _make_firefighter_equipment(card_name: String) -> EquipmentCard:
	var card: Card = _make_firefighter_card(card_name)
	return card as EquipmentCard


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


# === 测试用例 ===

# 测试 1: 急救包 use_card 流程（select_target=1，content=target.recover(4)）
func test_use_card_first_aid_kit() -> void:
	var p: Player = _make_firefighter_player(10, 20)
	_setup_game_for_player(p)
	var card: Card = _make_firefighter_card("急救包")
	p.hand.append(card)
	# mock input：choose_target 返回玩家自身
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([p])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用急救包应成功")
	assert_eq(p.hp, 14, "急救包应回复 4 点生命值（10 + 4 = 14）")
	assert_eq(p.game_discard_pile.get_all().size(), 1, "急救包应进入弃牌堆")
	assert_eq(p.game_discard_pile.get_all()[0].card_name, "急救包", "弃牌堆首张应为急救包")


# 测试 2: 灭火器 stun 流程（select_target=-1，content 遍历 event.targets 调用 stun）
func test_use_card_fire_extinguisher() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	var m1: Monster = _make_monster("zombie1")
	var m2: Monster = _make_monster("zombie2")
	p.monster_zone = [m1, m2]
	var card: Card = _make_firefighter_card("灭火器")
	p.hand.append(card)
	# select_target=-1：模拟自动选取全部怪物
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_target([m1, m2])
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用灭火器应成功")
	assert_true(m1.stunned, "怪物1应被击晕")
	assert_true(m2.stunned, "怪物2应被击晕")


# 测试 3: 能量饮料 add_temp_skill + draw 流程
func test_use_card_energy_drink() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	# draw(1) 需要牌堆有牌
	p.game_deck.add(_make_card("drawn1"))
	var card: Card = _make_firefighter_card("能量饮料")
	p.hand.append(card)
	var result: bool = await p.use_card(card)
	assert_true(result, "使用能量饮料应成功")
	# 验证临时技能已挂载
	var found: bool = false
	for s in p.get_all_skills():
		if s.english_name == "energy_drink_satiety":
			found = true
			break
	assert_true(found, "应挂载 energy_drink_satiety 临时技能")
	# 能量饮料被弃置 + draw(1) 抓 1 张 → 手牌净 1 张
	assert_eq(p.hand.size(), 1, "应抓 1 张牌（draw(1)）")


# 测试 4: consume_action 扣除行动次数
# use_card 系统结算时统一扣 1 点行动次数（action_count -= 1），
# content 中 consume_action(1) 再扣 1 点，共扣 2 点。
func test_use_card_consume_action() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	p.action_count = 2
	var card: Card = _make_card("action1", "action")
	var s: Skill = Skill.new()
	s.active = "action"
	s.content = func(player: Player, _t, _ev: Dictionary, _g) -> void:
		player.consume_action(1)
	card.add_skill(s)
	p.hand.append(card)
	var result: bool = await p.use_card(card)
	assert_true(result, "使用行动牌应成功")
	# use_card 扣 1 + content consume_action(1) 扣 1 = 2，初始 2 → 0
	assert_eq(p.action_count, 0, "应共扣除 2 点行动次数（use_card 系统扣 1 + consume_action 扣 1）")


# 测试 5: get_charge_count 查询装备填充物
# 注意：firefighter.json 中打火机 content 使用 english_name "lighter" 调用
# get_charge_count / get_equipment，但 get_equipment 按 card_name 匹配，
# 故此处使用 card_name "打火机" 查询。详见报告中的实现 bug 说明。
func test_get_charge_count() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	var lighter: EquipmentCard = _make_firefighter_equipment("打火机")
	assert_not_null(lighter, "应能创建打火机装备牌")
	p.equipment_zone.append(lighter)
	var count: int = p.get_charge_count("打火机")
	assert_eq(count, 2, "打火机初始填充物应为 2")


# 测试 6: game.get_card 按名称查找卡牌
func test_game_get_card() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	var axe: Card = _make_firefighter_card("值得信赖的斧子")
	assert_not_null(axe, "应能创建【值得信赖的斧子】")
	p.game_deck.add(axe)
	var found: Card = Game.get_card("值得信赖的斧子", p.game_deck)
	assert_not_null(found, "应在玩家牌堆中找到【值得信赖的斧子】")
	assert_eq(found.card_name, "值得信赖的斧子", "返回卡牌名应匹配")


# 测试 7: game.get_target 获取地块上的所有目标（玩家 + 怪物）
func test_game_get_target() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	var block: MapBlock = _make_block("b1", 0, 0)
	Game.map_area = [block]
	p.current_block = block
	var m: Monster = _make_monster("zombie1")
	p.monster_zone = [m]
	var targets: Array = Game.get_target(p.get_current_block())
	assert_eq(targets.size(), 2, "应返回 2 个目标（玩家 + 怪物）")
	assert_true(targets.has(p), "目标列表应含玩家")
	assert_true(targets.has(m), "目标列表应含怪物")
