class_name MissionScript
extends RefCounted

## 任务专用脚本基类。三层架构第三层：仅用于组件无法表达的极特殊任务逻辑。
## 与组件共用同一事件/判定/行动注入通道（on_event / check_win / check_lose / get_action_options）。

## 脚本参数。由任务 JSON 声明注入，各脚本自行约定键名。
var params: Dictionary = {}


## 初始化钩子。任务开始时注入游戏实例与任务配置，默认空实现。
func setup(game: Game, mission_config: MissionConfig) -> void:
	pass


## 事件回调。默认空实现。
func on_event(game: Game, event_name: String, event: Dictionary) -> void:
	pass


## 行动选项查询。默认返回空数组。
func get_action_options(game: Game, player: Player) -> Array:
	return []


## 胜利条件判定。默认 true（不参与胜利判定）。
func check_win(game: Game) -> bool:
	return true


## 失败条件判定。默认 false（不参与失败判定）。
func check_lose(game: Game) -> bool:
	return false
