class_name MissionComponentObjectiveMarksCleared
extends MissionComponent

## 任务标记清除胜利条件组件（服务任务 9/11/12）。
## 组件 id：objective_marks_cleared；类别：win_condition（胜利条件）。
## params：
## - count: int（缺省 0 = 全清模式）——需要移除的任务标记数量
## 依赖：MissionConfig.initial_objective_mark_count（开局场上任务标记总数，
## 由 Game.initialize_game() 在 build_map 之后遍历 map_area 统计写入）。
## 判定：
## - 全清模式（count <= 0）：当前场上未移除标记数为 0 且初始标记数 > 0
##   （无标记任务返回 false 防误判）
## - count 模式（count > 0）：已移除数（initial - 当前）>= count
## 当前数 = 遍历 map_area 存活地块累加 objective_marks.size()
## （数组中均为未移除标记，removed 的已被 erase）。

## 任务配置引用。setup 时注入，用于读取 initial_objective_mark_count。
var _mission_config: MissionConfig = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_mission_config = mission_config


func check_win(game: Game) -> bool:
	if game == null or not is_instance_valid(game):
		return false
	if _mission_config == null:
		return false
	var initial: int = _mission_config.initial_objective_mark_count
	var current: int = _count_current_marks(game)
	var required: int = int(params.get("count", 0))
	if required <= 0:
		return current == 0 and initial > 0
	return initial - current >= required


## 统计当前场上未移除任务标记总数（仅存活地块）。
func _count_current_marks(game: Game) -> int:
	var total: int = 0
	for block in game.map_area:
		if block == null or not is_instance_valid(block):
			continue
		if not block.is_alive():
			continue
		total += block.objective_marks.size()
	return total
