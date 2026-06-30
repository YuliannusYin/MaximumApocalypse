# MissionObjective.gd
# 任务目标数据类 - 定义任务的特殊胜利条件

class_name MissionObjective
extends Resource

# 目标类型枚举
enum ObjectiveType {
	KILL_MONSTERS,      # 杀死特定怪物
	COLLECT_ITEMS,      # 收集特定物品
	RESCUE_NPC,         # 解救NPC
	REACH_LOCATION,     # 到达特定地点
	DELIVER_ITEM,       # 交付物品到特定地点
	CUSTOM              # 自定义目标
}

# 目标类型
@export var objective_type: ObjectiveType

# 目标描述（用于UI显示）
@export_multiline var description: String

# 目标ID（唯一标识）
@export var objective_id: String

# 目标参数（根据类型不同）
# KILL_MONSTERS: {"monster_id": "zombie_walker", "count": 2}
# COLLECT_ITEMS: {"item_id": "medical_small", "count": 2}
# RESCUE_NPC: {"npc_id": "scientist"}
# REACH_LOCATION: {"location_id": "hospital"}
# DELIVER_ITEM: {"item_id": "antidote", "location_id": "hospital", "count": 3}
@export var target_data: Dictionary = {}

# 是否必须完成（true=必须完成才能胜利，false=可选目标）
@export var is_required: bool = true

# 目标进度（运行时状态，不从文件加载）
var current_progress: int = 0
var is_completed: bool = false