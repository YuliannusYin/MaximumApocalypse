class_name MissionComponent
extends RefCounted

## 任务组件基类。三层架构第二层：可复用条件组件。
## 组件按 JSON 声明位置区分职责：
## - win_conditions（胜利条件组件）：实现 check_win
## - lose_conditions（失败条件组件）：实现 check_lose
## - triggers（触发器组件）：实现 on_event
## - actions（行动选项组件）：实现 get_action_options

## 组件参数。由任务 JSON 声明注入，各组件自行约定键名。
var params: Dictionary = {}


## 初始化钩子。任务开始时注入游戏实例与任务配置，默认空实现。
func setup(game: Game, mission_config: MissionConfig) -> void:
	pass


## 胜利条件判定。默认 true（不参与胜利判定）。
func check_win(game: Game) -> bool:
	return true


## 失败条件判定。默认 false（不参与失败判定）。
func check_lose(game: Game) -> bool:
	return false


## 事件回调。触发器组件在此响应游戏事件，默认空实现。
func on_event(game: Game, event_name: String, event: Dictionary) -> void:
	pass


## 行动选项查询。行动选项组件在此返回可选行动，默认返回空数组。
func get_action_options(game: Game, player: Player) -> Array:
	return []
