# Mission.gd
class_name Mission
extends BaseEntity


## 基础元数据
var mission_id: int = 0
var mission_name: String = ""
var english_name: String = ""
var difficulty: String = ""
var van_fuel_required: int = 0
var intro_text: String = ""
var objective_text: String = ""
var special_setup: String = ""
var monster_pack_type: String = ""

## 地图配置与布局
var map_blocks_config: Dictionary = {} # "地块名": 数量
var map_layout: Array = []             # 二维数组布局矩阵
var map_legend: Dictionary = {}        # 图例说明字典

## 目标标记配置
var objective_marks: Array = []

## 拾荒牌堆配置 (抽牌堆颜色 -> 卡牌配置列表)
# 结构: {"red": [{"card_name": "食物", "count": 2}, ...], "green": [...]}
var scavenge_config: Dictionary = {}

## 胜利条件代码/标识
var win_condition_code: String = ""


## 从 JSON 字典解析任务数据
func init_from_json_dict(data: Dictionary) -> void:
	mission_id = data.get("mission_id", 0)
	mission_name = data.get("mission_name", "")
	english_name = data.get("english_name", "")
	difficulty = data.get("difficulty", "")
	van_fuel_required = data.get("van_fuel_required", 0)
	intro_text = data.get("intro_text", "")
	objective_text = data.get("objective_text", "")
	special_setup = data.get("special_setup", "")
	monster_pack_type = data.get("monster_pack_type", "")
	
	map_blocks_config = data.get("map_blocks_config", {}).duplicate()
	map_layout = data.get("map_layout", []).duplicate(true)
	map_legend = data.get("map_legend", {}).duplicate(true)
	
	objective_marks = data.get("objective_marks", []).duplicate(true)
	scavenge_config = data.get("scavenge_config", {}).duplicate(true)
	win_condition_code = data.get("win_condition_code", "")


## 构建并获取未分配的“随机地图块池”（Tiles Pool）
## 自动扣除 map_legend 里固定指定的地块（如 spawn/0 -> 购物中心，game_end/2 -> 面包车）
func generate_random_tile_pool() -> Array[String]:
	var pool: Array[String] = []
	var config_copy: Dictionary = map_blocks_config.duplicate()
	
	# 扫描 map_legend，剔减固定占用的地图块
	for key in map_legend:
		var legend_val = map_legend[key]
		if legend_val is Dictionary and legend_val.has("block_name"):
			var fixed_name: String = legend_val["block_name"]
			if config_copy.has(fixed_name):
				config_copy[fixed_name] -= 1
				if config_copy[fixed_name] <= 0:
					config_copy.erase(fixed_name)
	
	# 将剩余的地图块按数量打散装入池中
	for block_name in config_copy:
		var count: int = config_copy[block_name]
		for i in range(count):
			pool.append(block_name)
			
	return pool