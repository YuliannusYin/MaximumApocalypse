extends TestBase

## MissionConfig 单元测试（三层架构：组件/脚本编排）。
## 覆盖：check_win AND 组合 / check_lose OR 组合 / 无组件默认（空真）/
## get_action_options 汇总 / on_event 转发 / setup_components 注入 /
## mission_action 行动选项执行链路。
## 使用内嵌 class 手动 append 组件实例到 mc 各数组（不经注册表）。


# === 测试用内嵌组件/脚本 ===

# 记录型判定组件：按 flag 判定并记录 setup 调用与参数。
class FlagComponent extends MissionComponent:
	var win: bool = true
	var lose: bool = false
	var setup_called: bool = false
	var setup_game: Variant = null
	var setup_config: Variant = null

	func setup(game: Game, mission_config: MissionConfig) -> void:
		setup_called = true
		setup_game = game
		setup_config = mission_config

	func check_win(game: Game) -> bool:
		return win

	func check_lose(game: Game) -> bool:
		return lose


# 记录型触发器组件：记录收到的事件名。
class RecordingTriggerComponent extends MissionComponent:
	var events: Array = []

	func on_event(game: Game, event_name: String, event: Dictionary) -> void:
		events.append(event_name)


# 记录型行动组件：返回预置选项。
class RecordingActionComponent extends MissionComponent:
	var options: Array = []

	func get_action_options(game: Game, player: Player) -> Array:
		return options


# 记录型任务脚本：综合记录 setup / 事件 / 判定 / 选项。
class RecordingScript extends MissionScript:
	var setup_called: bool = false
	var events: Array = []
	var win: bool = true
	var lose: bool = false
	var options: Array = []

	func setup(game: Game, mission_config: MissionConfig) -> void:
		setup_called = true

	func on_event(game: Game, event_name: String, event: Dictionary) -> void:
		events.append(event_name)

	func check_win(game: Game) -> bool:
		return win

	func check_lose(game: Game) -> bool:
		return lose

	func get_action_options(game: Game, player: Player) -> Array:
		return options


# === 辅助方法 ===

func _make_mission_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	p.input = CliPlayerInput.new()
	return p


# === 1. check_win（AND 组合） ===

func test_check_win_all_components_true() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var c1 := FlagComponent.new()
	var c2 := FlagComponent.new()
	mc.win_condition_components.append(c1)
	mc.win_condition_components.append(c2)
	assert_true(mc.check_win(null), "两组件均 true 应为 true")


func test_check_win_one_component_false() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var c1 := FlagComponent.new()
	var c2 := FlagComponent.new()
	c2.win = false
	mc.win_condition_components.append(c1)
	mc.win_condition_components.append(c2)
	assert_false(mc.check_win(null), "任一组件 false 应为 false")


func test_check_win_script_false_blocks() -> void:
	var mc: MissionConfig = MissionConfig.new()
	mc.win_condition_components.append(FlagComponent.new())
	var script := RecordingScript.new()
	script.win = false
	mc.mission_script_instance = script
	assert_false(mc.check_win(null), "脚本 false 应阻断胜利")


func test_check_win_script_true_with_components() -> void:
	var mc: MissionConfig = MissionConfig.new()
	mc.win_condition_components.append(FlagComponent.new())
	var script := RecordingScript.new()
	script.win = true
	mc.mission_script_instance = script
	assert_true(mc.check_win(null), "组件与脚本均 true 应为 true")


func test_check_win_empty_vacuously_true() -> void:
	var mc: MissionConfig = MissionConfig.new()
	assert_true(mc.check_win(null), "无组件且无脚本时应空真")


# === 2. check_lose（OR 组合） ===

func test_check_lose_any_component_true() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var c1 := FlagComponent.new()
	var c2 := FlagComponent.new()
	c2.lose = true
	mc.lose_condition_components.append(c1)
	mc.lose_condition_components.append(c2)
	assert_true(mc.check_lose(null), "任一组件 true 应为 true")


func test_check_lose_all_false() -> void:
	var mc: MissionConfig = MissionConfig.new()
	mc.lose_condition_components.append(FlagComponent.new())
	mc.lose_condition_components.append(FlagComponent.new())
	assert_false(mc.check_lose(null), "全部组件 false 应为 false")


func test_check_lose_script_true() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var script := RecordingScript.new()
	script.lose = true
	mc.mission_script_instance = script
	assert_true(mc.check_lose(null), "脚本 true 应判定失败")


func test_check_lose_empty_defaults_false() -> void:
	var mc: MissionConfig = MissionConfig.new()
	assert_false(mc.check_lose(null), "无组件且无脚本时应为 false")


# === 3. get_action_options 汇总 ===

func test_get_action_options_aggregates_components() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var c1 := RecordingActionComponent.new()
	c1.options = [{"id": "a", "label": "A", "execute": Callable()}]
	var c2 := RecordingActionComponent.new()
	c2.options = [{"id": "b", "label": "B", "execute": Callable()}]
	mc.action_components.append(c1)
	mc.action_components.append(c2)
	var options: Array = mc.get_action_options(null, null)
	assert_eq(options.size(), 2, "应汇总两个组件的选项")
	assert_eq(options[0].get("id"), "a")
	assert_eq(options[1].get("id"), "b")


func test_get_action_options_includes_script() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var c1 := RecordingActionComponent.new()
	c1.options = [{"id": "a", "label": "A", "execute": Callable()}]
	mc.action_components.append(c1)
	var script := RecordingScript.new()
	script.options = [{"id": "s", "label": "S", "execute": Callable()}]
	mc.mission_script_instance = script
	var options: Array = mc.get_action_options(null, null)
	assert_eq(options.size(), 2, "应包含组件与脚本的选项")
	assert_eq(options[1].get("id"), "s")


func test_get_action_options_empty_by_default() -> void:
	var mc: MissionConfig = MissionConfig.new()
	assert_eq(mc.get_action_options(null, null).size(), 0, "无组件时应返回空数组")


# === 4. on_event 转发 ===

func test_on_event_forwards_to_triggers_and_script() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var trigger := RecordingTriggerComponent.new()
	mc.trigger_components.append(trigger)
	var script := RecordingScript.new()
	mc.mission_script_instance = script
	mc.on_event(null, "turn_started", {"player": null})
	mc.on_event(null, "monster_died", {"monster": null, "source": null})
	assert_eq(trigger.events, ["turn_started", "monster_died"], "触发器组件应收到全部转发事件")
	assert_eq(script.events, ["turn_started", "monster_died"], "脚本应收到全部转发事件")


func test_on_event_no_triggers_no_error() -> void:
	var mc: MissionConfig = MissionConfig.new()
	mc.on_event(null, "turn_started", {})
	assert_true(true, "无触发器时调用不应报错")


# === 5. setup_components ===

func test_setup_components_calls_setup_on_all() -> void:
	var mc: MissionConfig = MissionConfig.new()
	var win_c := FlagComponent.new()
	var lose_c := FlagComponent.new()
	var trigger_c := FlagComponent.new()
	var action_c := FlagComponent.new()
	mc.win_condition_components.append(win_c)
	mc.lose_condition_components.append(lose_c)
	mc.trigger_components.append(trigger_c)
	mc.action_components.append(action_c)
	var script := RecordingScript.new()
	mc.mission_script_instance = script
	mc.setup_components(null)
	assert_true(win_c.setup_called, "胜利组件 setup 应被调用")
	assert_true(lose_c.setup_called, "失败组件 setup 应被调用")
	assert_true(trigger_c.setup_called, "触发器组件 setup 应被调用")
	assert_true(action_c.setup_called, "行动组件 setup 应被调用")
	assert_true(script.setup_called, "脚本 setup 应被调用")
	assert_eq(win_c.setup_config, mc, "setup 应收到 mission_config 自身")


func test_setup_components_no_components_no_error() -> void:
	var mc: MissionConfig = MissionConfig.new()
	mc.setup_components(null)
	assert_true(true, "无组件时调用不应报错")


# === 6. mission_action 行动选项执行链路 ===

func test_mission_action_execute_chain() -> void:
	var called: Array = []
	var component := RecordingActionComponent.new()
	component.options = [{"id": "x", "label": "X", "execute": func() -> void: called.append("executed")}]
	var mc: MissionConfig = MissionConfig.new()
	mc.action_components.append(component)
	Game.mission_config = mc
	var p: Player = _make_mission_player("P")
	(p.input as CliPlayerInput).queue_action({"type": "mission_action", "option_id": "x"})
	(p.input as CliPlayerInput).queue_action(null)
	await p.wait_player_action()
	assert_eq(called, ["executed"], "任务行动 execute 应被调用")


func test_mission_action_unknown_option_not_executed() -> void:
	var called: Array = []
	var component := RecordingActionComponent.new()
	component.options = [{"id": "x", "label": "X", "execute": func() -> void: called.append("executed")}]
	var mc: MissionConfig = MissionConfig.new()
	mc.action_components.append(component)
	Game.mission_config = mc
	var p: Player = _make_mission_player("P")
	(p.input as CliPlayerInput).queue_action({"type": "mission_action", "option_id": "not_exist"})
	(p.input as CliPlayerInput).queue_action(null)
	await p.wait_player_action()
	assert_eq(called, [], "未知 option_id 不应执行任何选项")


func test_mission_action_no_mission_config_no_error() -> void:
	Game.mission_config = null
	var p: Player = _make_mission_player("P")
	(p.input as CliPlayerInput).queue_action({"type": "mission_action", "option_id": "x"})
	(p.input as CliPlayerInput).queue_action(null)
	await p.wait_player_action()
	assert_true(true, "无任务配置时 mission_action 应静默忽略")
