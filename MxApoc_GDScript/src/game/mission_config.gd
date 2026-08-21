class_name MissionConfig
extends RefCounted

## 任务配置结构。由任务包加载，存储本局任务的可配置项与运行时状态。
## 三层架构第二/三层运行时容器：持有按 JSON 声明挂载的组件实例与任务脚本实例。
## 设计文档：GameDesignDocus/GameSystem/Game/Game.md#任务配置结构missionconfig

## 启动面包车所需燃料值。-1 表示 NULL（该任务不通过面包车胜利，如任务 4/8/9/11）。
var van_fuel_required: int = -1

## 胜利条件组件列表。全部 check_win 为 true 才满足任务特定胜利条件。
var win_condition_components: Array = []

## 失败条件组件列表。任一 check_lose 为 true 即任务失败。
var lose_condition_components: Array = []

## 触发器组件列表。接收 Game 转发的游戏事件（on_event）。
var trigger_components: Array = []

## 行动选项组件列表。提供任务专属行动选项（get_action_options）。
var action_components: Array = []

## 任务脚本实例（第三层）。仅用于组件无法表达的极特殊任务逻辑，可为 null。
var mission_script_instance: MissionScript = null

## 任务特定运行时状态存储。各任务自行约定键名。
## 常用键见 IdentifierMapping.md §八（如 scientist_info_recorded / scientist_rescued / bomb_defused）。
var mission_state: Dictionary = {}


## 初始化全部组件与脚本实例。任务开始时由 Game.initialize_game() 调用。
func setup_components(game: Game) -> void:
	for component in win_condition_components:
		component.setup(game, self)
	for component in lose_condition_components:
		component.setup(game, self)
	for component in trigger_components:
		component.setup(game, self)
	for component in action_components:
		component.setup(game, self)
	if mission_script_instance != null:
		mission_script_instance.setup(game, self)


## 任务胜利条件判定。所有胜利组件为 true 且（无脚本或脚本为 true）才为 true；
## 无组件且无脚本时返回 true（空真）。
func check_win(game: Game) -> bool:
	for component in win_condition_components:
		if not component.check_win(game):
			return false
	if mission_script_instance != null and not mission_script_instance.check_win(game):
		return false
	return true


## 任务失败条件判定。任一失败组件或脚本返回 true 即为 true；否则 false。
func check_lose(game: Game) -> bool:
	for component in lose_condition_components:
		if component.check_lose(game):
			return true
	if mission_script_instance != null and mission_script_instance.check_lose(game):
		return true
	return false


## 事件转发。将游戏事件转发给全部触发器组件与脚本。
func on_event(game: Game, event_name: String, event: Dictionary) -> void:
	for component in trigger_components:
		component.on_event(game, event_name, event)
	if mission_script_instance != null:
		mission_script_instance.on_event(game, event_name, event)


## 汇总任务行动选项。合并全部行动组件与脚本的返回值。
## 每项为 Dictionary，含 id / label / execute 键。
func get_action_options(game: Game, player: Player) -> Array:
	var options: Array = []
	for component in action_components:
		options.append_array(component.get_action_options(game, player))
	if mission_script_instance != null:
		options.append_array(mission_script_instance.get_action_options(game, player))
	return options
