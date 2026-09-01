extends GutTest

## use_card 与玩家输入引擎机制单元测试。
## 覆盖 use_card 行动牌分支（content 执行 + 弃牌）、consume_action、
## game.get_target、choose_block_inline、set_prompt 委托。
## 卡牌效果以实机验证为准，不做逐卡效果测试。
## 设计文档：GameDesignDocus/GameSystem/Entities/Player.md


# === 辅助方法 ===

func _make_test_player(hp: int = 32, max_hp: int = 32) -> Player:
	var p: Player = Player.new()
	p.player_name = "测试玩家"
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

# 测试 1: 行动牌总计只扣除一次行动次数
# use_card 在效果开始前统一扣 1 点；旧 content 中的扣点调用不应重复扣除。
func test_use_card_consume_action() -> void:
	var p: Player = _make_test_player()
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
	# 初始 2，行动牌总计扣 1 点
	assert_eq(p.action_count, 1, "行动牌总计应只扣除 1 点行动次数")


# 测试 2：行动牌效果执行期间应位于结算区，完成后进入弃牌堆。
func test_action_card_moves_to_settlement_during_content() -> void:
	var p: Player = _make_test_player()
	_setup_game_for_player(p)
	var card: Card = _make_card("settlement_card", "action")
	var observed: Array = []
	var s: Skill = Skill.new()
	s.active = "action"
	s.content = func(player: Player, _t, _ev: Dictionary, _g) -> void:
		observed.append({
			"in_hand": player.hand.has(card),
			"in_settlement": player.card_settlement_zone.has(card),
			"action_count": player.action_count,
		})
	card.add_skill(s)
	p.hand.append(card)

	var result: bool = await p.use_card(card)

	assert_true(result, "使用行动牌应成功")
	assert_eq(observed.size(), 1, "卡牌 content 应执行一次")
	assert_false(observed[0]["in_hand"], "效果执行期间卡牌不应留在手牌")
	assert_true(observed[0]["in_settlement"], "效果执行期间卡牌应位于结算区")
	assert_eq(observed[0]["action_count"], 1, "效果开始前应已扣除行动点")
	assert_false(p.card_settlement_zone.has(card), "效果完成后结算区不应残留卡牌")
	assert_true(p.game_discard_pile.cards.has(card), "效果完成后卡牌应进入弃牌堆")


# 测试 3：行动点扣除失败时，卡牌应从结算区回滚到手牌。
func test_action_card_settlement_rolls_back_when_cost_cancelled() -> void:
	var p: Player = _make_test_player()
	_setup_game_for_player(p)
	var hook: Skill = Skill.new()
	hook.trigger = "before_consume_action"
	hook.forced = true
	hook.content = func(_player: Player, _target, event: Dictionary, _game) -> void:
		EventSystem.cancel(event)
	p.add_skill(hook)
	var card: Card = _make_card("rollback_card", "action")
	var content_called: Array = []
	var s: Skill = Skill.new()
	s.active = "action"
	s.content = func(_player: Player, _target, _event: Dictionary, _game) -> void:
		content_called.append(true)
	card.add_skill(s)
	p.hand.append(card)

	var result: bool = await p.use_card(card)

	assert_false(result, "行动点扣除被取消时卡牌使用应失败")
	assert_eq(p.action_count, 2, "行动点扣除失败时不应消耗行动点")
	assert_true(p.hand.has(card), "行动点扣除失败时卡牌应回到手牌")
	assert_false(p.card_settlement_zone.has(card), "行动点扣除失败时结算区不应残留卡牌")
	assert_eq(content_called.size(), 0, "行动点扣除失败时不应执行卡牌效果")


# 测试 4：延迟扣点卡牌应在 content 首次完成选择并扣点时进入结算区。
func test_deferred_card_enters_settlement_at_content_cost() -> void:
	var p: Player = _make_test_player()
	_setup_game_for_player(p)
	var card: Card = _make_card("deferred_card", "action")
	var observed: Array = []
	var s: Skill = Skill.new()
	s.active = "action"
	s.defer_action_cost = true
	s.content = func(player: Player, _target, _event: Dictionary, _game) -> void:
		observed.append({
			"before_cost_in_hand": player.hand.has(card),
			"before_cost_in_settlement": player.card_settlement_zone.has(card),
		})
		player.consume_action(1)
		observed.append({
			"after_cost_in_hand": player.hand.has(card),
			"after_cost_in_settlement": player.card_settlement_zone.has(card),
			"action_count": player.action_count,
		})
	card.add_skill(s)
	p.hand.append(card)

	var result: bool = await p.use_card(card)

	assert_true(result, "延迟扣点行动牌应使用成功")
	assert_true(observed[0]["before_cost_in_hand"], "content 首次选择完成前卡牌应仍在手牌")
	assert_false(observed[0]["before_cost_in_settlement"], "content 首次选择完成前卡牌不应在结算区")
	assert_false(observed[1]["after_cost_in_hand"], "扣点后卡牌不应仍在手牌")
	assert_true(observed[1]["after_cost_in_settlement"], "扣点时卡牌应进入结算区")
	assert_eq(observed[1]["action_count"], 1, "扣点时应消耗 1 点行动")
	assert_true(p.game_discard_pile.cards.has(card), "效果完成后卡牌应进入弃牌堆")


# 测试 5: game.get_target 获取地块上的所有目标（玩家 + 怪物）
func test_game_get_target() -> void:
	var p: Player = _make_test_player()
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


# 测试 3: choose_block_inline 多选场景（count=2 时返回 2 个地块）
# 验证 content 代码调用 player.choose_block_inline(valid_blocks, prompt, 2)
# 时，CLI mock 注入的数组队列被正确消费并返回多块。
func test_choose_block_inline_multi_select_count_2() -> void:
	var p: Player = _make_test_player()
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


# 测试 4: choose_block_inline 队列默认行为（未注入时返回前 count 块）
# CliPlayerInput 在队列为空时默认选取前 count 块。
func test_choose_block_inline_default_returns_first_count() -> void:
	var p: Player = _make_test_player()
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


# 测试 5: choose_block_inline 空候选返回空数组（不调用 input）
# player.choose_block_inline 在 valid_blocks 为空时直接返回 []，不委托 input。
func test_choose_block_inline_empty_candidates_returns_empty() -> void:
	var p: Player = _make_test_player()
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


# 测试 6: player.set_prompt 委托给 input 层
# 验证 content 代码调用 player.set_prompt(text) 后文本正确传递到 input。
func test_player_set_prompt_delegates_to_input() -> void:
	var p: Player = _make_test_player()
	_setup_game_for_player(p)
	var spy: _PromptSpyInput = _PromptSpyInput.new()
	p.input = spy
	p.set_prompt("请选择目标地块")
	assert_eq(spy.last_prompt, "请选择目标地块", "set_prompt 应将文本传递给 input")


# 测试 7: player.set_prompt 在无 input 时不崩溃
# input 为 null 时 set_prompt 应安全返回，不报错。
func test_player_set_prompt_no_input_no_crash() -> void:
	var p: Player = _make_test_player()
	_setup_game_for_player(p)
	p.input = null
	p.set_prompt("无 input 时不应崩溃")
	assert_true(true, "无 input 时 set_prompt 应安全返回不报错")
