extends GutTest

## 集成测试：胜利条件检查 全链路。
## 覆盖 MissionConfig.check_win + GameStateMachine.check_win_condition + game_over("win")。
## 设计文档：GameDesignDocus/GameSystem/Core/GameStateMachine.md


# === 测试用内嵌任务组件 ===

# 按 params.win 判定胜利的临时组件，用于替代旧 Callable 语义。
class DummyWinComponent extends MissionComponent:
	func check_win(game: Game) -> bool:
		return params.get("win", true)


# === 辅助方法 ===

func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func _make_block(name: String = "B", x: int = 0, y: int = 0) -> MapBlock:
	var b: MapBlock = MapBlock.new()
	b.block_name = name
	b.set_coordinate(x, y)
	b.revealed = true
	return b


## 构造带单个胜利组件的任务配置（win 组件经注册表实例化后手动挂载）。
func _make_mission_config(win: bool, van_fuel: int = -1) -> MissionConfig:
	var mc: MissionConfig = MissionConfig.new()
	mc.van_fuel_required = van_fuel
	mc.win_condition_components.append(MissionComponentRegistry.create("dummy_win", {"win": win}))
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
	MissionComponentRegistry.reset()
	MissionComponentRegistry.register("dummy_win", DummyWinComponent)


func after_each() -> void:
	_clear_game()
	MissionComponentRegistry.reset()


# === 测试用例 ===

func test_check_win_condition_null_fuel_wins_when_mission_returns_true() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.state_machine.transition_to(GameStateMachine.GameState.PLAYING)
	Game.mission_config = _make_mission_config(true)
	var result: bool = Game.state_machine.check_win_condition()
	assert_true(result, "应胜利")
	assert_true(Game.state_machine.is_game_over(), "应进入 GAME_OVER")
	assert_eq(Game.state_machine.get_game_result(), GameStateMachine.GameResult.WIN)
	assert_eq(Game.game_result, "win")


func test_check_win_condition_returns_false_when_mission_returns_false() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.state_machine.transition_to(GameStateMachine.GameState.PLAYING)
	Game.mission_config = _make_mission_config(false)
	var result: bool = Game.state_machine.check_win_condition()
	assert_false(result, "任务条件不满足应不胜利")
	assert_false(Game.state_machine.is_game_over(), "不应进入 GAME_OVER")


func test_check_win_condition_missing_van_returns_false() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.state_machine.transition_to(GameStateMachine.GameState.PLAYING)
	Game.mission_config = _make_mission_config(true, 5)  # 需要燃料
	# 地图上没有面包车
	Game.map_area = []
	var result: bool = Game.state_machine.check_win_condition()
	assert_false(result, "无面包车应不胜利")


func test_check_win_condition_not_playing_returns_false() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	# 不进入 PLAYING 状态
	Game.mission_config = _make_mission_config(true)
	var result: bool = Game.state_machine.check_win_condition()
	assert_false(result, "非 PLAYING 状态应不检查")


func test_check_win_condition_no_mission_config_returns_false() -> void:
	var p: Player = _make_player("A")
	Game.players = [p]
	Game.state_machine.transition_to(GameStateMachine.GameState.PLAYING)
	Game.mission_config = null
	var result: bool = Game.state_machine.check_win_condition()
	assert_false(result, "无任务配置应不胜利")
