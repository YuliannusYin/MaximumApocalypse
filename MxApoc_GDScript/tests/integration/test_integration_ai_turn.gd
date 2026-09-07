extends TestBase

## AI 座位入局与行动阶段不卡死。

const AIPlayerInputScript = preload("res://src/ai/ai_player_input.gd")


func test_initialize_game_creates_ai_seat() -> void:
	var mission: MissionData = DataManager.get_mission(0)
	assert_not_null(mission, "任务 0 应存在")
	var seats: Array = [
		{"type": "human", "survivor": DataManager.get_survivor("firefighter")},
		{"type": "ai", "survivor": DataManager.get_survivor("hunter")},
	]
	Game.initialize_game(mission, {}, seats)
	assert_eq(Game.players.size(), 2, "AI 座位应创建玩家")
	assert_false(Game.players[0].is_ai, "座位 0 应为真人")
	assert_true(Game.players[1].is_ai, "座位 1 应为 AI")
	assert_true(Game.players[1].input.get_script() == AIPlayerInputScript, "AI 玩家输入应为 AIPlayerInput")


func test_ai_wait_player_action_exits() -> void:
	var p: Player = _make_player("AI")
	p.is_ai = true
	p.in_phase = "action"
	p.action_count = 0
	p.input = AIPlayerInputScript.new()
	Game.players = [p]
	await p.wait_player_action()
	assert_true(true, "无可用行动时 wait_player_action 应结束")
