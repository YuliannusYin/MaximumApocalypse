extends TestBase

## 集成测试：状态机开局 + 玩家回合 21 节点 + 回合循环 全链路。
## 覆盖 GameStateMachine.start_game + Player.start_turn + next_turn 循环。
## 设计文档：GameDesignDocus/GameSystem/Core/GameStateMachine.md
##
## 注意：next_turn() 是 while 循环，CliPlayerInput.wait_action 不阻塞，
## 因此必须设置 mission_config 胜利组件让循环在第一回合后退出。

# === 测试用内嵌任务组件 ===

# 恒真胜利组件，替代旧 Callable 语义。
class AlwaysWinComponent extends MissionComponent:
	func check_win(game: Game) -> bool:
		return true


# 计数胜利组件：第一次检查返回 false，第二次起返回 true（用于验证回合推进）。
class CountingWinComponent extends MissionComponent:
	var call_count: Array = [0]

	func check_win(game: Game) -> bool:
		call_count[0] += 1
		return call_count[0] >= 2


# === 辅助方法 ===

func _make_player(player_name: String = "TestPlayer", hp: int = 10, max_hp: int = -1) -> Player:
	var p: Player = super._make_player(player_name, hp, max_hp)
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
	mc.win_condition_components.append(AlwaysWinComponent.new())
	return mc


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
	# 用计数胜利组件追踪检查次数，第二次调用返回 true
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = -1
	mc.win_condition_components.append(CountingWinComponent.new())
	Game.mission_config = mc
	await Game.state_machine.start_game()
	# start_game 后第一玩家 p1 完成回合，check_win_condition 返回 false
	# 然后第二玩家 p2 完成回合，check_win_condition 返回 true → 胜利
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.WIN)
	# 验证两个玩家都执行过回合（hand 各至少 4 张）
	assert_true(p1.hand.size() >= 4, "p1 应已抓牌")
	assert_true(p2.hand.size() >= 4, "p2 应已抓牌")


func test_next_turn_builds_fresh_turn_event_per_player() -> void:
	const GameEventScript = preload("res://src/core/game_event.gd")
	var p1: Player = _make_player("A")
	var p2: Player = _make_player("B")
	Game.players = [p1, p2]
	Game.monster_pile = Pile.new()
	for i in 4:
		Game.monster_pile.add(_make_monster_card("z" + str(i)))
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = -1
	mc.win_condition_components.append(CountingWinComponent.new())
	Game.mission_config = mc
	await Game.state_machine.start_game()
	# p1、p2 各自都应建立自己的正式 TurnEvent，owner 各自归属正确，且都已 completed。
	var turn1: Variant = p1.get_turn_event()
	var turn2: Variant = p2.get_turn_event()
	assert_not_null(turn1)
	assert_not_null(turn2)
	assert_eq(turn1.owner, p1)
	assert_eq(turn2.owner, p2)
	assert_eq(turn1.status, GameEventScript.Status.COMPLETED)
	assert_eq(turn2.status, GameEventScript.Status.COMPLETED)
	assert_eq(turn1.turn_number, Game.state_machine.get_turn_number())
	assert_eq(turn2.turn_number, Game.state_machine.get_turn_number())


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
