class_name MissionComponentTurnCountdown
extends MissionComponent

## 轮数倒计时触发器组件（为后续任务预留）。
## 组件 id：turn_countdown；类别：trigger（触发器）。
## params：
## - rounds: int——倒数轮数
## - auto_activate: bool（默认 false）——setup 时立即激活倒计时
## mission_state 键：
## - countdown_active: bool——倒计时是否已激活
## - countdown_remaining: int——剩余轮数
## - countdown_expired: bool——倒计时是否已归零（check_lose 依据此键判定失败）
## - countdown_activate: true——外部（其他组件/脚本）置 true 时在下一个 on_event 中激活倒计时，激活后清除该标记键
## 轮次边界检测：组件成员 _last_turn_number 记录上一次 turn_started 事件时的
## Game.state_machine.turn_number，当 turn_number 增大且倒计时激活且剩余 > 0 时递减；
## remaining 归零（且原本 > 0）时置 expired = true 并输出日志。

## mission_state 键名常量。
const STATE_KEY_ACTIVE: String = "countdown_active"
const STATE_KEY_REMAINING: String = "countdown_remaining"
const STATE_KEY_EXPIRED: String = "countdown_expired"
const STATE_KEY_ACTIVATE: String = "countdown_activate"

## 任务配置引用。setup 时注入，用于读写 mission_state。
var _mission_config: MissionConfig = null

## 上一次 turn_started 事件时的轮数。-1 表示尚未见过任何 turn_started 事件。
var _last_turn_number: int = -1


func setup(game: Game, mission_config: MissionConfig) -> void:
	_mission_config = mission_config
	if _mission_config == null:
		return
	_mission_config.mission_state[STATE_KEY_ACTIVE] = false
	_mission_config.mission_state[STATE_KEY_REMAINING] = 0
	_mission_config.mission_state[STATE_KEY_EXPIRED] = false
	if params.get("auto_activate", false) == true:
		activate()


## 激活倒计时：active = true、remaining = rounds。供其他组件/脚本调用。
func activate() -> void:
	if _mission_config == null:
		return
	_mission_config.mission_state[STATE_KEY_ACTIVE] = true
	_mission_config.mission_state[STATE_KEY_REMAINING] = int(params.get("rounds", 0))


func on_event(game: Game, event_name: String, event: Dictionary) -> void:
	if _mission_config == null:
		return
	# countdown_activate 标记：外部置 true 时激活倒计时（激活后清除标记键）
	if _mission_config.mission_state.get(STATE_KEY_ACTIVATE, false) == true:
		_mission_config.mission_state.erase(STATE_KEY_ACTIVATE)
		activate()
	if event_name != "turn_started":
		return
	if game == null or not is_instance_valid(game):
		return
	if game.state_machine == null or not is_instance_valid(game.state_machine):
		return
	# 轮次边界检测：turn_number 相比上一次 turn_started 事件增大视为进入新轮
	var turn_number: int = game.state_machine.turn_number
	var crossed_boundary: bool = _last_turn_number >= 0 and turn_number > _last_turn_number
	_last_turn_number = turn_number
	if not crossed_boundary:
		return
	if _mission_config.mission_state.get(STATE_KEY_ACTIVE, false) != true:
		return
	var remaining: int = int(_mission_config.mission_state.get(STATE_KEY_REMAINING, 0))
	if remaining <= 0:
		return
	remaining -= 1
	_mission_config.mission_state[STATE_KEY_REMAINING] = remaining
	if remaining == 0:
		_mission_config.mission_state[STATE_KEY_EXPIRED] = true
		game.log_message("倒计时归零！")


func check_lose(game: Game) -> bool:
	if _mission_config == null:
		return false
	return _mission_config.mission_state.get(STATE_KEY_EXPIRED, false) == true
