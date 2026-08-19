extends GutTest

## GameStateMachine 单元测试。


# === 测试用 mock player ===

class MockPlayer extends RefCounted:
	var player_name: String = "Mock"
	var hp: int = 10
	var max_hp: int = 10
	var hand: Array = []
	var game_deck: Variant = null
	var current_block: Variant = null
	var triggers_received: Array = []
	var turns_taken: int = 0
	var draw_count: int = 0
	var draw_monster_count: int = 0

	func is_alive() -> bool:
		return hp > 0

	func get_current_block():
		return current_block

	func draw(n: int) -> void:
		draw_count += n

	func draw_monster(n: int) -> void:
		draw_monster_count += n

	func start_turn() -> void:
		turns_taken += 1

	func trigger(trigger_name: String, event: Dictionary) -> void:
		triggers_received.append(trigger_name)

	func choose(options: Array) -> String:
		return "不进行重调"

	func wait_redraw_decision() -> bool:
		return false


# === 辅助方法 ===

func _make_gsm() -> GameStateMachine:
	var gsm: GameStateMachine = GameStateMachine.new()
	gsm.init()
	return gsm


func _make_player(name: String = "P", hp: int = 10) -> MockPlayer:
	var p: MockPlayer = MockPlayer.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	return p


func _setup_game(players: Array = []) -> void:
	Game.players = players
	Game.map_area = []
	Game.mission_config = null
	Game.coop_death_mode = false
	Game.game_over_called = false
	Game.game_result = ""
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


func after_each() -> void:
	Game.players = []
	Game.map_area = []
	Game.mission_config = null
	Game.game_over_called = false
	Game.game_result = ""
	if Game.state_machine != null and is_instance_valid(Game.state_machine):
		Game.state_machine.init()


# === 1. 初始化与状态 ===

func test_init_sets_defaults() -> void:
	var gsm: GameStateMachine = GameStateMachine.new()
	gsm.current_state = GameStateMachine.GameState.PLAYING
	gsm.game_result = GameStateMachine.GameResult.WIN
	gsm.current_player = _make_player()
	gsm.turn_queue = [_make_player()]
	gsm.skip_turn_marks = {_make_player(): true}
	gsm.turn_number = 5
	gsm.init()
	assert_eq(gsm.current_state, GameStateMachine.GameState.WAITING)
	assert_eq(gsm.game_result, -1)
	assert_null(gsm.current_player)
	assert_eq(gsm.turn_queue.size(), 0)
	assert_eq(gsm.skip_turn_marks.size(), 0)
	assert_eq(gsm.turn_number, 0)


func test_default_state_is_waiting() -> void:
	var gsm: GameStateMachine = GameStateMachine.new()
	assert_eq(gsm.get_game_state(), GameStateMachine.GameState.WAITING)
	assert_false(gsm.is_playing())
	assert_false(gsm.is_game_over())


# === 2. 状态转换 ===

func test_transition_waiting_to_playing_valid() -> void:
	var gsm: GameStateMachine = _make_gsm()
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	assert_eq(gsm.get_game_state(), GameStateMachine.GameState.PLAYING)


func test_transition_playing_to_game_over_valid() -> void:
	var gsm: GameStateMachine = _make_gsm()
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	gsm.transition_to(GameStateMachine.GameState.GAME_OVER)
	assert_eq(gsm.get_game_state(), GameStateMachine.GameState.GAME_OVER)


func test_transition_waiting_to_game_over_invalid() -> void:
	var gsm: GameStateMachine = _make_gsm()
	gsm.transition_to(GameStateMachine.GameState.GAME_OVER)
	assert_eq(gsm.get_game_state(), GameStateMachine.GameState.WAITING, "非法转换不应生效")


func test_transition_game_over_to_playing_invalid() -> void:
	var gsm: GameStateMachine = _make_gsm()
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	gsm.transition_to(GameStateMachine.GameState.GAME_OVER)
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	assert_eq(gsm.get_game_state(), GameStateMachine.GameState.GAME_OVER, "GAME_OVER 不可回退")


# === 3. 游戏结束 ===

func test_game_over_sets_result_and_state() -> void:
	var gsm: GameStateMachine = _make_gsm()
	_setup_game()
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	gsm.game_over(GameStateMachine.GameResult.LOSE)
	assert_eq(gsm.get_game_state(), GameStateMachine.GameState.GAME_OVER)
	assert_eq(gsm.get_game_result(), GameStateMachine.GameResult.LOSE)
	assert_null(gsm.current_player)
	assert_true(gsm.is_game_over())


func test_game_over_idempotent() -> void:
	var gsm: GameStateMachine = _make_gsm()
	_setup_game()
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	gsm.game_over(GameStateMachine.GameResult.LOSE)
	gsm.game_over(GameStateMachine.GameResult.WIN)
	assert_eq(gsm.get_game_result(), GameStateMachine.GameResult.LOSE, "已结束不应覆盖结果")


func test_game_over_triggers_on_game_over() -> void:
	var gsm: GameStateMachine = _make_gsm()
	var p: MockPlayer = _make_player()
	_setup_game([p])
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	gsm.game_over(GameStateMachine.GameResult.WIN)
	assert_true(p.triggers_received.has("on_game_over"), "应触发 on_game_over")


func test_game_over_sets_game_flags() -> void:
	var gsm: GameStateMachine = _make_gsm()
	_setup_game()
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	gsm.game_over(GameStateMachine.GameResult.LOSE)
	assert_true(Game.game_over_called)
	assert_eq(Game.game_result, "lose")


# === 4. 回合队列填充 ===

func test_fill_new_turn_queue_increments_round() -> void:
	var gsm: GameStateMachine = _make_gsm()
	var p1: MockPlayer = _make_player("A")
	var p2: MockPlayer = _make_player("B")
	_setup_game([p1, p2])
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	gsm._fill_new_turn_queue()
	assert_eq(gsm.turn_number, 1)
	assert_eq(gsm.turn_queue.size(), 2)


func test_fill_new_turn_queue_excludes_dead() -> void:
	var gsm: GameStateMachine = _make_gsm()
	var p1: MockPlayer = _make_player("A", 10)
	var p2: MockPlayer = _make_player("B", 0)
	_setup_game([p1, p2])
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	gsm._fill_new_turn_queue()
	assert_eq(gsm.turn_queue.size(), 1, "死亡玩家不应入队")
	assert_eq(gsm.turn_queue[0], p1)


# === 5. 获取下一个玩家 ===

func test_get_next_player_returns_first() -> void:
	var gsm: GameStateMachine = _make_gsm()
	var p1: MockPlayer = _make_player("A")
	var p2: MockPlayer = _make_player("B")
	_setup_game([p1, p2])
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	var player: Variant = gsm._get_next_player()
	assert_eq(player, p1)


func test_get_next_player_skips_dead() -> void:
	var gsm: GameStateMachine = _make_gsm()
	var p1: MockPlayer = _make_player("A", 0)
	var p2: MockPlayer = _make_player("B", 10)
	_setup_game([p1, p2])
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	var player: Variant = gsm._get_next_player()
	assert_eq(player, p2, "应跳过死亡玩家")


func test_get_next_player_skips_marked() -> void:
	var gsm: GameStateMachine = _make_gsm()
	var p1: MockPlayer = _make_player("A")
	var p2: MockPlayer = _make_player("B")
	_setup_game([p1, p2])
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	gsm.skip_next_turn(p1)
	var player: Variant = gsm._get_next_player()
	assert_eq(player, p2, "应跳过被标记玩家")
	assert_false(gsm.skip_turn_marks.has(p1), "跳过标记应已移除")


func test_get_next_player_returns_null_all_dead() -> void:
	var gsm: GameStateMachine = _make_gsm()
	var p1: MockPlayer = _make_player("A", 0)
	_setup_game([p1])
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	var player: Variant = gsm._get_next_player()
	assert_null(player)


# === 6. 额外回合与跳过 ===

func test_queue_extra_turn_inserts_front() -> void:
	var gsm: GameStateMachine = _make_gsm()
	var p1: MockPlayer = _make_player("A")
	var p2: MockPlayer = _make_player("B")
	_setup_game([p1, p2])
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	gsm._fill_new_turn_queue()
	gsm.queue_extra_turn(p2)
	assert_eq(gsm.turn_queue[0], p2, "额外回合应在队首")


func test_queue_extra_turn_ignores_dead() -> void:
	var gsm: GameStateMachine = _make_gsm()
	var p1: MockPlayer = _make_player("A", 0)
	_setup_game([p1])
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	gsm._fill_new_turn_queue()
	gsm.queue_extra_turn(p1)
	assert_eq(gsm.turn_queue.size(), 0, "死亡玩家不应获得额外回合")


func test_queue_extra_turn_ignores_when_not_playing() -> void:
	var gsm: GameStateMachine = _make_gsm()
	var p1: MockPlayer = _make_player("A")
	_setup_game([p1])
	gsm.queue_extra_turn(p1)
	assert_eq(gsm.turn_queue.size(), 0, "非游戏中不应插入额外回合")


func test_skip_next_turn_adds_mark() -> void:
	var gsm: GameStateMachine = _make_gsm()
	var p1: MockPlayer = _make_player("A")
	_setup_game([p1])
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	gsm.skip_next_turn(p1)
	assert_true(gsm.skip_turn_marks.has(p1))


func test_skip_next_turn_ignores_when_not_playing() -> void:
	var gsm: GameStateMachine = _make_gsm()
	var p1: MockPlayer = _make_player("A")
	_setup_game([p1])
	gsm.skip_next_turn(p1)
	assert_false(gsm.skip_turn_marks.has(p1))


# === 7. 胜利条件检查 ===

func test_check_win_condition_not_playing_returns_false() -> void:
	var gsm: GameStateMachine = _make_gsm()
	_setup_game()
	assert_false(gsm.check_win_condition())


func test_check_win_condition_no_mission_config_returns_false() -> void:
	var gsm: GameStateMachine = _make_gsm()
	_setup_game()
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	assert_false(gsm.check_win_condition())


func test_check_win_condition_mission_returns_false() -> void:
	var gsm: GameStateMachine = _make_gsm()
	_setup_game()
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	var mc: MissionConfig = MissionConfig.new()
	mc.check_win_condition = func() -> bool: return false
	Game.mission_config = mc
	assert_false(gsm.check_win_condition())


func test_check_win_condition_null_fuel_wins() -> void:
	var gsm: GameStateMachine = _make_gsm()
	_setup_game()
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = -1  # NULL
	mc.check_win_condition = func() -> bool: return true
	Game.mission_config = mc
	var result: bool = gsm.check_win_condition()
	assert_true(result)
	assert_eq(gsm.get_game_state(), GameStateMachine.GameState.GAME_OVER)
	assert_eq(gsm.get_game_result(), GameStateMachine.GameResult.WIN)


# === 8. 查询方法 ===

func test_is_playing() -> void:
	var gsm: GameStateMachine = _make_gsm()
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	assert_true(gsm.is_playing())
	assert_false(gsm.is_game_over())


func test_is_game_over() -> void:
	var gsm: GameStateMachine = _make_gsm()
	gsm.transition_to(GameStateMachine.GameState.PLAYING)
	gsm.transition_to(GameStateMachine.GameState.GAME_OVER)
	assert_true(gsm.is_game_over())
	assert_false(gsm.is_playing())


func test_get_turn_number() -> void:
	var gsm: GameStateMachine = _make_gsm()
	assert_eq(gsm.get_turn_number(), 0)
	gsm.turn_number = 3
	assert_eq(gsm.get_turn_number(), 3)


func test_get_current_player() -> void:
	var gsm: GameStateMachine = _make_gsm()
	assert_null(gsm.get_current_player())
	var p: MockPlayer = _make_player()
	gsm.current_player = p
	assert_eq(gsm.get_current_player(), p)


func test_get_game_result() -> void:
	var gsm: GameStateMachine = _make_gsm()
	assert_eq(gsm.get_game_result(), -1)
	gsm.game_result = GameStateMachine.GameResult.WIN
	assert_eq(gsm.get_game_result(), GameStateMachine.GameResult.WIN)


# === Merged mechanism tests (from cleanup) ===

# 读取 game_state_machine.gd 源码，断言 trigger("on_game_start") 所在行号
# 小于 draw(4) 所在行号（行序断言）。
# 证明 on_game_start 触发器在抓初始手牌之前执行。
func test_start_game_on_game_start_before_draw_4() -> void:
	var path: String = "res://src/core/game_state_machine.gd"
	var content: String = FileAccess.get_file_as_string(path)
	assert_false(content.is_empty(), "应能读取 game_state_machine.gd")
	var lines: PackedStringArray = content.split("\n")
	var on_game_start_line: int = -1
	var draw_4_line: int = -1
	for i in range(lines.size()):
		var line: String = lines[i]
		if on_game_start_line < 0 and line.contains("trigger(\"on_game_start\""):
			on_game_start_line = i
		if draw_4_line < 0 and line.contains("draw(4)"):
			draw_4_line = i
	assert_true(on_game_start_line >= 0, "应找到 trigger(\"on_game_start\") 行")
	assert_true(draw_4_line >= 0, "应找到 draw(4) 行")
	assert_true(
		on_game_start_line < draw_4_line,
		"on_game_start 触发应在 draw(4) 之前（行 %d < 行 %d）" % [on_game_start_line, draw_4_line]
	)
