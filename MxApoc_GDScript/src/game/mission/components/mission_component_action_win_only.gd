class_name MissionComponentActionWinOnly
extends MissionComponent

## 行动胜利占位组件（服务任务 8/9）。
## 组件 id：action_win_only；类别：win_condition（胜利条件）。
## params：无。
## check_win 恒返回 false。用于胜利仅由行动组件触发 Game.game_over("win") 的任务
## （如任务 8/9）：此类任务若 win_conditions 为空，MissionConfig.check_win 的
## 空真语义会导致开局即误判胜利，挂载本组件可阻止该误判。

func check_win(game: Game) -> bool:
	return false
