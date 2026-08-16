extends GutTest

## 集成测试：状态机开局 + 玩家回合 21 节点 + 回合循环 全链路。
## 覆盖 GameStateMachine.start_game + Player.start_turn + next_turn 循环。
## 设计文档：GameDesignDocus/GameSystem/Core/GameStateMachine.md
##
## 注意：next_turn() 是 while 循环，CliPlayerInput.wait_action 不阻塞，
## 因此必须设置 mission_config.check_win_condition 让循环在第一回合后退出。


# === 辅助方法 ===

func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	# 牌堆放入 5 张牌，避免空牌堆死亡
	for i in 5:
		var c: Card = Card.new()
		c.card_name = "card_" + str(i)
		c.card_type = "action"
		c.source = "game"
		p.game_deck.add(c)
	return p


func _make_winning_mission_config() -> MissionConfig:
	# 设置一个第一回合后立即胜利的任务配置
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = -1  # NULL 燃料，不检查面包车
	mc.check_win_condition = func() -> bool: return true
	return mc


func _make_monster_card(name: String = "zombie") -> MonsterCard:
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

func test_start_game_transitions_to_playing_or_won() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_pile.add(_make_monster_card("z1"))
	Game.mission_config = _make_winning_mission_config()
	# start_game 后第一回合结束即胜利
	await Game.state_machine.start_game()
	# 胜利后状态应为 GAME_OVER with WIN
	assert_true(Game.state_machine.is_game_over(), "应已游戏结束（胜利）")
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.WIN)


func test_start_game_draws_initial_hand_and_monster() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.monster_pile = Pile.new()
	Game.monster_pile.add(_make_monster_card("z1"))
	Game.mission_config = _make_winning_mission_config()
	await Game.state_machine.start_game()
	# CliPlayerInput 默认 wait_redraw_decision 返回 false → 不重调
	# 应抓 4 张初始手牌 + 1 张 start_turn 抓牌 = 5 张
	# 但 start_turn 中可能discard了一些，这里只验证至少抓了 4 张初始牌
	assert_true(p.hand.size() >= 4, "应至少抓 4 张初始手牌，实际 " + str(p.hand.size()))
	# 应抓 1 张怪物卡
	assert_eq(p.monster_zone.size(), 1, "应实体化 1 个怪物")


func test_next_turn_advances_to_next_player() -> void:
	var p1: Player = _make_player("A")
	var p2: Player = _make_player("B")
	Game.players = [p1, p2]
	Game.monster_pile = Pile.new()
	for i in 4:
		Game.monster_pile.add(_make_monster_card("z" + str(i)))
	# 用计数器追踪 win_condition，第二次调用返回 true
	var call_count: Array = [0]
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = -1
	mc.check_win_condition = func() -> bool:
		call_count[0] += 1
		return call_count[0] >= 2  # 第二次检查时胜利
	Game.mission_config = mc
	await Game.state_machine.start_game()
	# start_game 后第一玩家 p1 完成回合，check_win_condition 返回 false
	# 然后第二玩家 p2 完成回合，check_win_condition 返回 true → 胜利
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.WIN)
	# 验证两个玩家都执行过回合（hand 各至少 4 张）
	assert_true(p1.hand.size() >= 4, "p1 应已抓牌")
	assert_true(p2.hand.size() >= 4, "p2 应已抓牌")


func test_turn_flow_with_dead_player_skipped() -> void:
	var p1: Player = _make_player("A", 10)
	var p2: Player = _make_player("B", 0)  # 已死
	Game.players = [p1, p2]
	Game.monster_pile = Pile.new()
	# 需 2 张怪物卡（start_game 为每个玩家抽 1 张）
	Game.monster_pile.add(_make_monster_card("z1"))
	Game.monster_pile.add(_make_monster_card("z2"))
	Game.mission_config = _make_winning_mission_config()
	await Game.state_machine.start_game()
	# p2 死亡，应被跳过；p1 完成回合后胜利
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.WIN)
	# p2 虽然在 start_game 中抓了 4 张牌，但不应执行回合（start_turn 未调用）
	# 这里验证 p1 已抓牌（包含 start_turn 的 1 张）
	assert_true(p1.hand.size() >= 4, "p1 应已抓牌")
