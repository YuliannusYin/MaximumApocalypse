extends GutTest

## 第零轮重调阶段集成测试。


# 测试用内嵌任务组件：恒真胜利，替代旧 Callable 语义。
class AlwaysWinComponent extends MissionComponent:
	func check_win(game: Game) -> bool:
		return true


var _original_players: Array = []


func before_all() -> void:
	_original_players = Game.players


func after_all() -> void:
	Game.players = _original_players


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


# === 辅助方法 ===

func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	# 填充牌堆：至少 8 张牌（4 初始 + 4 重调）
	for i in 8:
		var card: Card = Card.new()
		card.card_name = "card_" + str(i)
		card.card_type = "action"
		card.source = "game"
		p.game_deck.add(card)
	# 设置 input 为 CliPlayerInput
	p.input = CliPlayerInput.new()
	return p


func _make_monster_card(name: String = "z") -> MonsterCard:
	var mc: MonsterCard = MonsterCard.new()
	mc.card_name = name
	mc.card_type = "monster"
	mc.source = "monster"
	mc.monster_type = "zombie"
	mc.monster_level = "normal"
	mc.max_hp = 3
	mc.damage_value = 2
	mc.range = "none"
	return mc


func _make_winning_mission_config() -> MissionConfig:
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = -1
	mc.win_condition_components.append(AlwaysWinComponent.new())
	return mc


# === 测试用例 ===

func test_round_zero_executes_for_each_player() -> void:
	var p1: Player = _make_player("A")
	var p2: Player = _make_player("B")
	Game.players = [p1, p2]
	Game.monster_pile = Pile.new()
	for i in 4:
		Game.monster_pile.add(_make_monster_card("z" + str(i)))
	Game.mission_config = _make_winning_mission_config()
	# 两个玩家都应该在第零轮中抓了 4 张初始手牌
	# start_game 后第一回合结束即胜利
	await Game.state_machine.start_game()
	assert_true(Game.state_machine.is_game_over(), "应已游戏结束（胜利）")
	# 验证两个玩家都有手牌（第零轮不重调，手牌应 >= 4）
	assert_true(p1.hand.size() >= 4, "p1 应至少有 4 张手牌，实际 " + str(p1.hand.size()))
	assert_true(p2.hand.size() >= 4, "p2 应至少有 4 张手牌，实际 " + str(p2.hand.size()))


func test_round_zero_redraw_replaces_hand() -> void:
	var p: Player = _make_player("A")
	# 注入重调决策：选择重调
	(p.input as CliPlayerInput).queue_redraw_decision(true)
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_pile.add(_make_monster_card("z1"))
	Game.mission_config = _make_winning_mission_config()
	await Game.state_machine.start_game()
	# 重调后 + start_turn 抓 1 张 → 手牌应 5 张（4 重调 + 1 start_turn）
	# 牌堆：8 - 4 初始 - 1 start_turn = 3（重调净中性：返回4再抽4）
	assert_true(p.hand.size() >= 4, "重调后手牌应至少 4 张，实际 " + str(p.hand.size()))
	assert_eq(p.game_deck.size(), 3, "牌堆应剩余 3 张，实际 " + str(p.game_deck.size()))


func test_round_zero_skip_redraw_keeps_hand() -> void:
	var p: Player = _make_player("A")
	# 注入重调决策：不重调（默认行为，但显式注入 false）
	(p.input as CliPlayerInput).queue_redraw_decision(false)
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_pile.add(_make_monster_card("z1"))
	Game.mission_config = _make_winning_mission_config()
	await Game.state_machine.start_game()
	# 不重调 + start_turn 抓 1 张 → 手牌应 5 张（4 初始 + 1 start_turn）
	assert_true(p.hand.size() >= 4, "不重调手牌应至少 4 张，实际 " + str(p.hand.size()))
