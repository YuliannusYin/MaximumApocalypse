extends TestBase

## 集成测试：胜利条件检查 全链路。
## 覆盖 MissionConfig.check_win + GameStateMachine.check_win_condition + game_over("win")。
## 设计文档：GameDesignDocus/GameSystem/Core/GameStateMachine.md


# === 测试用内嵌任务组件 ===

# 按 params.win 判定胜利的临时组件，用于替代旧 Callable 语义。
class DummyWinComponent extends MissionComponent:
	func check_win(game: Game) -> bool:
		return params.get("win", true)


# === 辅助方法 ===

func _make_block(block_name: String = "test_block", x: int = 0, y: int = 0, revealed: bool = true) -> MapBlock:
	return super._make_block(block_name, x, y, revealed)


## 构造带单个胜利组件的任务配置（win 组件经注册表实例化后手动挂载）。
func _make_mission_config(win: bool, van_fuel: int = -1) -> MissionConfig:
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = van_fuel
	mc.win_condition_components.append(MissionComponentRegistry.create("dummy_win", {"win": win}))
	return mc


func before_each() -> void:
	super.before_each()
	MissionComponentRegistry.reset()
	MissionComponentRegistry.register("dummy_win", DummyWinComponent)


func after_each() -> void:
	super.after_each()
	MissionComponentRegistry.reset()


# === 测试用例 ===

func test_check_win_condition_null_fuel_wins_when_mission_returns_true() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.state_machine.transition_to(GameStateMachine.GameState.PLAYING)
	Game.mission_config = _make_mission_config(true)
	var result: bool = await Game.state_machine.check_win_condition()
	assert_true(result, "应胜利")
	assert_true(Game.state_machine.is_game_over(), "应进入 GAME_OVER")
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.WIN)
	assert_eq(Game.game_result, "win")


func test_check_win_condition_returns_false_when_mission_returns_false() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.state_machine.transition_to(GameStateMachine.GameState.PLAYING)
	Game.mission_config = _make_mission_config(false)
	var result: bool = await Game.state_machine.check_win_condition()
	assert_false(result, "任务条件不满足应不胜利")
	assert_false(Game.state_machine.is_game_over(), "不应进入 GAME_OVER")


func test_check_win_condition_missing_van_returns_false() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.state_machine.transition_to(GameStateMachine.GameState.PLAYING)
	Game.mission_config = _make_mission_config(true, 5)  # 需要燃料
	# 地图上没有面包车
	Game.map_area = []
	var result: bool = await Game.state_machine.check_win_condition()
	assert_false(result, "无面包车应不胜利")


func test_check_win_condition_not_playing_returns_false() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	# 不进入 PLAYING 状态
	Game.mission_config = _make_mission_config(true)
	var result: bool = await Game.state_machine.check_win_condition()
	assert_false(result, "非 PLAYING 状态应不检查")


func test_check_win_condition_no_mission_config_returns_false() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.state_machine.transition_to(GameStateMachine.GameState.PLAYING)
	Game.mission_config = null
	var result: bool = await Game.state_machine.check_win_condition()
	assert_false(result, "无任务配置应不胜利")
