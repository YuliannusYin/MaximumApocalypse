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


## 行动组件技能声明（action 类组件实现；其他类别返回 null）。
## 返回 Dictionary 或 null，键：
## - skill_name: String——技能栏按钮名（与设计文档技能名一致）
## - block_match: Callable(block: MapBlock) -> bool——地块匹配（进入匹配地块时挂载）
## - filter: Callable(player: Player) -> bool——可用性（false 时技能栏灰化；不含地块匹配）
## - execute: Callable(player: Player)——执行体（协程可，内部含行动扣减与效果）
## - confirm: Callable(player: Player) -> String——确认门文案
## - ai: Dictionary——AI 评分（缺省见 `_mission_action_ai`）
func get_action_skill_decl() -> Variant:
	return null


## AI 是否应把本行动当作行进目标。忽略玩家当前所在格与剩余行动点；完成态仍拦截。
## 有 `params.block_name` 的行动去该地名；无地名（摧毁标记 / 解救检定）由 hints 收集场上目标标记地块。
func ai_should_travel(_player: Player) -> bool:
	return false


## 任务行动技能默认 AI 分：可用时优先于普通战斗/移动。
func _mission_action_ai() -> Dictionary:
	return {
		"order": 12,
		"useful": 0,
		"tags": ["mission"],
		"effect": {"player": 4, "target": 0},
	}
