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
	await p.equip(lighter)
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


# 测试 8: 消防员的耐力 — 第一步取消：牌退回手牌，不消耗行动次数
# defer_action_cost=true 时 use_card 不预先扣行动；content 第一步取消返回 false → 牌退回手牌，不弃牌
func test_firefighter_stamina_cancel_at_step1() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	p.action_count = 2
	# 构建地图：中心块 (1,1) + 四向相邻块
	var center: MapBlock = _make_block("center", 1, 1)
	var north: MapBlock = _make_block("north", 1, 0)
	var south: MapBlock = _make_block("south", 1, 2)
	var east: MapBlock = _make_block("east", 2, 1)
	var west: MapBlock = _make_block("west", 0, 1)
	Game.map_area = [center, north, south, east, west]
	p.current_block = center
	# 创建消防员的耐力卡牌
	var card: Card = _make_firefighter_card("消防员的耐力")
	p.hand.append(card)
	# mock input：第一步选取时取消（返回 null）
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_block([])  # 第一步取消（空数组表示取消）
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_false(result, "第一步取消应返回 false")
	assert_eq(p.action_count, 2, "不应消耗行动次数")
	assert_eq(p.hand.size(), 1, "牌应退回手牌")
	assert_eq(p.hand[0].card_name, "消防员的耐力", "手牌中应为消防员的耐力")
	assert_eq(p.game_discard_pile.get_all().size(), 0, "弃牌堆应为空")


# 测试 9: 消防员的耐力 — 完成 3 步移动：消耗 1 行动，抓 1 张牌
func test_firefighter_stamina_complete_3_steps() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	p.action_count = 2
	# 构建线性地图：(0,1) <-> (1,1) <-> (2,1) <-> (3,1)
	var b01: MapBlock = _make_block("b01", 0, 1)
	var b11: MapBlock = _make_block("b11", 1, 1)
	var b21: MapBlock = _make_block("b21", 2, 1)
	var b31: MapBlock = _make_block("b31", 3, 1)
	Game.map_area = [b01, b11, b21, b31]
	p.current_block = b11
	# 牌堆需要有牌才能 draw(1)
	p.game_deck.add(_make_card("drawn1"))
	# 创建消防员的耐力卡牌
	var card: Card = _make_firefighter_card("消防员的耐力")
	p.hand.append(card)
	# mock input：依次选择 b21, b31, b21（来回走）
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_block([b21])  # 步骤1: b11 -> b21（数组形式，单元素数组）
	cli.queue_choose_block([b31])  # 步骤2: b21 -> b31
	cli.queue_choose_block([b21])  # 步骤3: b31 -> b21
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "使用消防员的耐力应成功")
	assert_eq(p.action_count, 1, "应消耗 1 点行动次数")
	assert_eq(p.current_block, b21, "应最终在 b21")
	assert_eq(p.hand.size(), 1, "手牌应有 1 张（抓到的牌，消防员的耐力已弃置）")
	assert_eq(p.game_discard_pile.get_all().size(), 1, "弃牌堆应有 1 张（消防员的耐力）")


# 测试 10: 消防员的耐力 — 第二步取消：结束移动，抓 1 张牌
func test_firefighter_stamina_cancel_at_step2() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	p.action_count = 2
	# 构建线性地图：(0,1) <-> (1,1) <-> (2,1) <-> (3,1)
	var b01: MapBlock = _make_block("b01", 0, 1)
	var b11: MapBlock = _make_block("b11", 1, 1)
	var b21: MapBlock = _make_block("b21", 2, 1)
	var b31: MapBlock = _make_block("b31", 3, 1)
	Game.map_area = [b01, b11, b21, b31]
	p.current_block = b11
	# 牌堆需要有牌才能 draw(1)
	p.game_deck.add(_make_card("drawn1"))
	# 创建消防员的耐力卡牌
	var card: Card = _make_firefighter_card("消防员的耐力")
	p.hand.append(card)
	# mock input：第一步选 b21，第二步取消
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_block([b21])  # 步骤1: b11 -> b21（数组形式，单元素数组）
	cli.queue_choose_block([])  # 步骤2: 取消（空数组表示取消）
	p.input = cli
	var result: bool = await p.use_card(card)
	assert_true(result, "第二步取消应正常结束（返回 true）")
	assert_eq(p.action_count, 1, "应消耗 1 点行动次数（第一步移动时消耗）")
	assert_eq(p.current_block, b21, "应在 b21")
	assert_eq(p.hand.size(), 1, "手牌应有 1 张（抓到的牌）")
	assert_eq(p.game_discard_pile.get_all().size(), 1, "弃牌堆应有 1 张（消防员的耐力）")


# 测试 11: choose_block_inline 多选场景（count=2 时返回 2 个地块）
# 验证 content 代码调用 player.choose_block_inline(valid_blocks, prompt, 2)
# 时，CLI mock 注入的数组队列被正确消费并返回多块。
func test_choose_block_inline_multi_select_count_2() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	var b3: MapBlock = _make_block("b3", 2, 0)
	var cli: CliPlayerInput = CliPlayerInput.new()
	cli.queue_choose_block([b1, b3])  # 注入两个地块（数组包数组）
	p.input = cli
	var blocks: Array = await p.choose_block_inline([b1, b2, b3], "选择两个地块", 2)
	assert_eq(blocks.size(), 2, "应返回 2 个地块")
	assert_eq(blocks[0], b1, "第一个应为 b1")
	assert_eq(blocks[1], b3, "第二个应为 b3")


# 测试 12: choose_block_inline 队列默认行为（未注入时返回前 count 块）
# CliPlayerInput 在队列为空时默认选取前 count 块。
func test_choose_block_inline_default_returns_first_count() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	var b1: MapBlock = _make_block("b1", 0, 0)
	var b2: MapBlock = _make_block("b2", 1, 0)
	var b3: MapBlock = _make_block("b3", 2, 0)
	var cli: CliPlayerInput = CliPlayerInput.new()
	p.input = cli
	# 队列为空时，CliPlayerInput 默认返回前 count 块
	var blocks: Array = await p.choose_block_inline([b1, b2, b3], "默认选取", 2)
	assert_eq(blocks.size(), 2, "应返回 2 个地块（默认前 2 项）")
	assert_eq(blocks[0], b1, "第一个应为 b1")
	assert_eq(blocks[1], b2, "第二个应为 b2")


# 测试 13: choose_block_inline 空候选返回空数组（不调用 input）
# player.choose_block_inline 在 valid_blocks 为空时直接返回 []，不委托 input。
func test_choose_block_inline_empty_candidates_returns_empty() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	var cli: CliPlayerInput = CliPlayerInput.new()
	p.input = cli
	var blocks: Array = await p.choose_block_inline([], "无可选地块", 1)
	assert_eq(blocks.size(), 0, "空候选应返回空数组")


## 记录 set_prompt 文本的探针 input（CliPlayerInput 子类）。
## 用于验证 player.set_prompt 是否将文本正确委托到 input 层。
class _PromptSpyInput extends CliPlayerInput:
	var last_prompt: String = ""

	func set_prompt(text: String) -> void:
		last_prompt = text


# 测试 14: player.set_prompt 委托给 input 层
# 验证 content 代码调用 player.set_prompt(text) 后文本正确传递到 input。
func test_player_set_prompt_delegates_to_input() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	var spy: _PromptSpyInput = _PromptSpyInput.new()
	p.input = spy
	p.set_prompt("请选择目标地块")
	assert_eq(spy.last_prompt, "请选择目标地块", "set_prompt 应将文本传递给 input")


# 测试 15: player.set_prompt 在无 input 时不崩溃
# input 为 null 时 set_prompt 应安全返回，不报错。
func test_player_set_prompt_no_input_no_crash() -> void:
	var p: Player = _make_firefighter_player()
	_setup_game_for_player(p)
	p.input = null
	p.set_prompt("无 input 时不应崩溃")
	assert_true(true, "无 input 时 set_prompt 应安全返回不报错")
