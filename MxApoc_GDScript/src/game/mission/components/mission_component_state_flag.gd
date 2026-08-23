class_name MissionComponentStateFlag
extends MissionComponent

## 任务状态旗标胜利条件组件（服务任务 5 bomb_defused / 任务 6 van_repaired）。
## 组件 id：state_flag；类别：win_condition（胜利条件）。
## params：
## - key: String——mission_state 中需为 true 的旗标键名
## 判定：mission_state.get(key, false) == true。
## 旗标由任务脚本或其他组件（如行动组件执行成功时）写入。

## 任务配置引用。setup 时注入，用于读取 mission_state。
var _mission_config: MissionConfig = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_mission_config = mission_config


func check_win(game: Game) -> bool:
	if _mission_config == null:
		return false
	var key: String = params.get("key", "")
	if key == "":
		return false
	return _mission_config.mission_state.get(key, false) == true
