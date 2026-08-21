extends GutTest

## Game 任务组件挂载与事件转发单元测试（三层架构第二/三层）。
## 覆盖：_mount_mission_components 注册表实例化挂载 / 未知 id 容错 /
## EventBus 信号 → mission_config.on_event 事件转发。


# === 测试用内嵌组件/脚本 ===

class DummyWinComponent extends MissionComponent:
	func check_win(game: Game) -> bool:
		return true


class DummyLoseComponent extends MissionComponent:
	func check_lose(game: Game) -> bool:
		return false


# 记录型触发器组件：记录事件名与事件体。
class RecordingTriggerComponent extends MissionComponent:
	var events: Array = []
	var payloads: Array = []

	func on_event(game: Game, event_name: String, event: Dictionary) -> void:
		events.append(event_name)
		payloads.append(event)


class DummyActionComponent extends MissionComponent:
	func get_action_options(game: Game, player: Player) -> Array:
		return [{"id": "a", "label": "A", "execute": Callable()}]


class DummyScript extends MissionScript:
	pass


# === 辅助方法 ===

func _make_player(name: String = "P", hp: int = 10) -> Player:
	var p: Player = Player.new()
	p.player_name = name
	p.hp = hp
	p.max_hp = hp
	p.game_deck = Pile.new()
	p.game_discard_pile = Pile.new()
	return p


func before_each() -> void:
	MissionComponentRegistry.reset()
	MissionScriptRegistry.reset()
	Game.mission_config = null


func after_each() -> void:
	MissionComponentRegistry.reset()
	MissionScriptRegistry.reset()
	Game.mission_config = null


# === 1. _mount_mission_components ===

func test_mount_mission_components_full() -> void:
	MissionComponentRegistry.register("dummy_win", DummyWinComponent)
	MissionComponentRegistry.register("dummy_lose", DummyLoseComponent)
	MissionComponentRegistry.register("dummy_trigger", RecordingTriggerComponent)
	MissionComponentRegistry.register("dummy_action", DummyActionComponent)
	MissionScriptRegistry.register("dummy_script", DummyScript)
	var mission: MissionData = MissionData.new({
		"win_conditions": [{"component": "dummy_win", "params": {"key": 1}}],
		"lose_conditions": [{"component": "dummy_lose", "params": {}}],
		"triggers": [{"component": "dummy_trigger", "params": {}}],
		"actions": [{"component": "dummy_action", "params": {}}],
		"mission_script": "dummy_script",
	})
	Game.mission_config = MissionConfig.new()
	Game._mount_mission_components(mission)
	assert_eq(Game.mission_config.win_condition_components.size(), 1, "应挂载 1 个胜利组件")
	assert_true(Game.mission_config.win_condition_components[0] is DummyWinComponent, "胜利组件类型应正确")
	assert_eq(Game.mission_config.win_condition_components[0].params.get("key"), 1, "params 应注入组件")
	assert_eq(Game.mission_config.lose_condition_components.size(), 1, "应挂载 1 个失败组件")
	assert_true(Game.mission_config.lose_condition_components[0] is DummyLoseComponent, "失败组件类型应正确")
	assert_eq(Game.mission_config.trigger_components.size(), 1, "应挂载 1 个触发器组件")
	assert_true(Game.mission_config.trigger_components[0] is RecordingTriggerComponent, "触发器组件类型应正确")
	assert_eq(Game.mission_config.action_components.size(), 1, "应挂载 1 个行动组件")
	assert_true(Game.mission_config.action_components[0] is DummyActionComponent, "行动组件类型应正确")
	assert_not_null(Game.mission_config.mission_script_instance, "应挂载任务脚本实例")
	assert_true(Game.mission_config.mission_script_instance is DummyScript, "任务脚本类型应正确")


func test_mount_mission_components_unknown_component_ignored() -> void:
	var mission: MissionData = MissionData.new({
		"win_conditions": [{"component": "not_exist", "params": {}}],
	})
	Game.mission_config = MissionConfig.new()
	Game._mount_mission_components(mission)
	assert_eq(Game.mission_config.win_condition_components.size(), 0, "未知组件 id 应被跳过")
	assert_push_error("未知任务组件 id 'not_exist'", "应产生未知组件 id 的 push_error")


func test_mount_mission_components_unknown_script_ignored() -> void:
	var mission: MissionData = MissionData.new({
		"mission_script": "not_exist_script",
	})
	Game.mission_config = MissionConfig.new()
	Game._mount_mission_components(mission)
	assert_null(Game.mission_config.mission_script_instance, "未知脚本 id 不应挂载实例")
	assert_push_error("未知任务脚本 id 'not_exist_script'", "应产生未知脚本 id 的 push_error")


func test_mount_mission_components_clears_stale_arrays() -> void:
	MissionComponentRegistry.register("dummy_win", DummyWinComponent)
	var mission: MissionData = MissionData.new({
		"win_conditions": [{"component": "dummy_win", "params": {}}],
	})
	Game.mission_config = MissionConfig.new()
	Game.mission_config.win_condition_components.append(DummyWinComponent.new())
	Game.mission_config.trigger_components.append(RecordingTriggerComponent.new())
	Game._mount_mission_components(mission)
	assert_eq(Game.mission_config.win_condition_components.size(), 1, "重复挂载应先清空旧组件")
	assert_eq(Game.mission_config.trigger_components.size(), 0, "未声明的组件数组应被清空")


func test_mount_mission_components_empty_mission() -> void:
	var mission: MissionData = MissionData.new({})
	Game.mission_config = MissionConfig.new()
	Game._mount_mission_components(mission)
	assert_eq(Game.mission_config.win_condition_components.size(), 0)
	assert_eq(Game.mission_config.lose_condition_components.size(), 0)
	assert_eq(Game.mission_config.trigger_components.size(), 0)
	assert_eq(Game.mission_config.action_components.size(), 0)
	assert_null(Game.mission_config.mission_script_instance)


# === 2. EventBus 事件转发 ===

func test_event_forwarding_turn_started() -> void:
	var trigger := RecordingTriggerComponent.new()
	var mc: MissionConfig = MissionConfig.new()
	mc.trigger_components.append(trigger)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	EventBus.turn_started.emit(p)
	assert_eq(trigger.events, ["turn_started"], "触发器应收到 turn_started 事件")
	assert_eq(trigger.payloads[0].get("player"), p, "事件体应包含玩家")


func test_event_forwarding_objective_mark_triggered() -> void:
	var trigger := RecordingTriggerComponent.new()
	var mc: MissionConfig = MissionConfig.new()
	mc.trigger_components.append(trigger)
	Game.mission_config = mc
	var p: Player = _make_player("P")
	var block: MapBlock = MapBlock.new()
	block.block_name = "B"
	EventBus.objective_mark_triggered.emit(p, block, {})
	assert_eq(trigger.events, ["objective_mark_triggered"], "触发器应收到 objective_mark_triggered 事件")
	assert_eq(trigger.payloads[0].get("player"), p, "事件体应包含玩家")
	assert_eq(trigger.payloads[0].get("block"), block, "事件体应包含地块")


func test_event_forwarding_null_config_no_error() -> void:
	Game.mission_config = null
	var p: Player = _make_player("P")
	EventBus.turn_started.emit(p)
	assert_true(true, "mission_config 为 null 时转发应静默忽略")
