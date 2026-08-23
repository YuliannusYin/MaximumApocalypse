class_name MissionComponentKillMonsters
extends MissionComponent

## 击杀怪物胜利条件组件（服务任务 2）。
## 组件 id：kill_monsters；类别：win_condition（胜利条件）+ trigger（击杀计数）。
## params：
## - counts: Dictionary{怪物名: 数量}——需要击杀的怪物及数量，如 {"僵尸潜伏者": 2}
## mission_state 键：
## - kill_counts: Dictionary{怪物名: 已击杀数}——setup 时初始化为 {}
## 说明：任务 JSON 中需同时声明到 triggers（接收 monster_died 事件计数）与
## win_conditions（判定胜利）；两处实例共享 mission_state，计数由触发器实例写入、
## 胜利实例读取。事件体 monster 为 Monster 实例，怪物名取 monster.monster_name
## （由 MonsterCard.instantiate 从卡面 card_name 复制）。

## 任务配置引用。setup 时注入，用于读写 mission_state。
var _mission_config: MissionConfig = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_mission_config = mission_config
	if _mission_config == null:
		return
	_mission_config.mission_state["kill_counts"] = {}


func on_event(game: Game, event_name: String, event: Dictionary) -> void:
	if _mission_config == null:
		return
	if event_name != "monster_died":
		return
	var counts: Dictionary = params.get("counts", {})
	if counts.is_empty():
		return
	var monster: Variant = event.get("monster", null)
	if monster == null or not is_instance_valid(monster):
		return
	var monster_name: String = str(monster.monster_name)
	if not counts.has(monster_name):
		return
	var kill_counts: Dictionary = _mission_config.mission_state.get("kill_counts", {})
	kill_counts[monster_name] = int(kill_counts.get(monster_name, 0)) + 1
	_mission_config.mission_state["kill_counts"] = kill_counts


func check_win(game: Game) -> bool:
	if _mission_config == null:
		return false
	var counts: Dictionary = params.get("counts", {})
	if counts.is_empty():
		return true
	var kill_counts: Dictionary = _mission_config.mission_state.get("kill_counts", {})
	for monster_name in counts:
		if int(kill_counts.get(monster_name, 0)) < int(counts[monster_name]):
			return false
	return true
