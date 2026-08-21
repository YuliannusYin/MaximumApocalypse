class_name MissionComponentEscortEquipmentAtBlock
extends MissionComponent

## 护送装备（如科学家）抵达地块胜利条件组件。
## 组件 id：escort_equipment_at_block；类别：win_condition（胜利条件）。
## params：
## - rescued_key: String（默认 "scientist_rescued"）——mission_state 中标记已获救的键
## - holder_key: String（默认 "scientist_holder"）——mission_state 中持有者玩家引用的键
## - block_name: String——护送目标地块名（如 "撤离点"）
## 判定：mission_state[rescued_key] == true 且持有者有效存活且其 current_block 地块名匹配才胜利。
## rescued_key / holder_key 由 spend_action_rescue 等解救类组件写入。

## 任务配置引用。setup 时注入，用于读取 mission_state。
var _mission_config: MissionConfig = null


func setup(game: Game, mission_config: MissionConfig) -> void:
	_mission_config = mission_config


func check_win(game: Game) -> bool:
	if _mission_config == null:
		return false
	if _mission_config.mission_state.get(params.get("rescued_key", "scientist_rescued"), false) != true:
		return false
	var holder: Variant = _mission_config.mission_state.get(params.get("holder_key", "scientist_holder"), null)
	if holder == null or not is_instance_valid(holder):
		return false
	if not holder.has_method("is_alive") or not holder.is_alive():
		return false
	if holder.current_block == null or not is_instance_valid(holder.current_block):
		return false
	return holder.current_block.block_name == params.get("block_name", "")
