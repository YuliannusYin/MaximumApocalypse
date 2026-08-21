class_name MissionData
extends RefCounted

## 任务静态数据。
## 从 data/missions/*.json 构造。
## 字段规范见 GameDesignDocus/Engineering/DataFormat.md §2.4。

const DIFFICULTY_DISPLAY := {
	"tutorial": "特别简单",
	"very_easy": "非常简单",
	"easy": "简单",
	"normal": "正常",
	"hard": "困难",
	"very_hard": "非常困难",
}
const DIFFICULTY_ORDER := {
	"tutorial": 0,
	"very_easy": 1,
	"easy": 2,
	"normal": 3,
	"hard": 4,
	"very_hard": 5,
}

var mission_id: int = 0
var mission_name: String = ""
var english_name: String = ""
var difficulty: String = ""  # "tutorial"/"very_easy"/"easy"/"normal"/"hard"/"very_hard"
var difficulty_display: String = ""  # 中文显示名，由 difficulty 映射
var difficulty_order: int = 0  # 排序值，由 difficulty 映射
var van_fuel_required: Variant = null  # int 或 null（NULL 表示不通过面包车胜利）
var intro_text: String = ""
var objective_text: String = ""
var special_setup: String = ""
var monster_pack_type: String = ""  # "alien"/"mutant"/"zombie"/"robot"
var map_blocks_config: Dictionary = {}  # {地块名: 数量}
var map_layout: Array = []  # Array[Array[int]]：二维数组
var map_legend: Dictionary = {}  # 编号说明
var objective_marks: Array = []  # Array[Dictionary]
var scavenge_config: Dictionary = {}  # {颜色: [{card_name, count}]}

## 三层架构声明：胜利条件组件列表。每项 {component: String, params: Dictionary}。
var win_conditions: Array = []
## 三层架构声明：失败条件组件列表。每项 {component: String, params: Dictionary}。
var lose_conditions: Array = []
## 三层架构声明：触发器组件列表。每项 {component: String, params: Dictionary}。
var triggers: Array = []
## 三层架构声明：行动选项组件列表。每项 {component: String, params: Dictionary}。
var actions: Array = []
## 三层架构声明：任务脚本 id（第三层，仅用于组件无法表达的极特殊任务逻辑）。
var mission_script: String = ""


func _init(data: Dictionary = {}) -> void:
	mission_id = int(data.get("mission_id", 0))
	mission_name = data.get("mission_name", "")
	english_name = data.get("english_name", "")
	difficulty = data.get("difficulty", "normal")
	van_fuel_required = data.get("van_fuel_required", null)
	intro_text = data.get("intro_text", "")
	objective_text = data.get("objective_text", "")
	special_setup = data.get("special_setup", "")
	monster_pack_type = data.get("monster_pack_type", "zombie")
	map_blocks_config = data.get("map_blocks_config", {})
	map_layout = data.get("map_layout", [])
	map_legend = data.get("map_legend", {})
	objective_marks = data.get("objective_marks", [])
	scavenge_config = data.get("scavenge_config", {})
	win_conditions = data.get("win_conditions", [])
	lose_conditions = data.get("lose_conditions", [])
	triggers = data.get("triggers", [])
	actions = data.get("actions", [])
	mission_script = data.get("mission_script", "")
	difficulty_display = DIFFICULTY_DISPLAY.get(difficulty, difficulty)
	difficulty_order = int(DIFFICULTY_ORDER.get(difficulty, 0))
