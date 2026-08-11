class_name MapManagerNew
extends Node

# ==============================================================================
# 信号与配置
# ==============================================================================
## 当某个坐标的地块被翻开时发出
signal block_revealed(coordinate: Vector2, map_block: MapBlock)

## 当某个地块状态变更时发出 (如被销毁)
signal block_status_changed(coordinate: Vector2, new_status: MapBlock.Status)

@export_file("*.json") var map_blocks_json_path: String = "res://data/map_blocks/map_blocks.json"

# ==============================================================================
# 数据缓存与网格存储
# ==============================================================================
## 存储 JSON 中的原始模板配置: Dictionary[String, Dictionary] (Key 为 english_name)
var _block_templates: Dictionary = {}

## 运行时的地图二维网格数据: Dictionary[Vector2, MapBlock]
var _grid_map: Dictionary = {}

## 当前地图尺寸
var grid_size: Vector2i = Vector2i.ZERO


# ==============================================================================
# 初始化与数据加载
# ==============================================================================

func _ready() -> void:
	load_map_templates()


## 1. 读取并解析 map_blocks.json 模板文件
func load_map_templates() -> void:
	_block_templates.clear()
	
	if not FileAccess.file_exists(map_blocks_json_path):
		push_error("MapManager: 找不到配置文件 -> %s" % map_blocks_json_path)
		return

	var file := FileAccess.open(map_blocks_json_path, FileAccess.READ)
	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	
	if error != OK:
		push_error("MapManager: JSON 解析失败! 错误信息: %s 在第 %d 行" % [json.get_error_message(), json.get_error_line()])
		return

	var data = json.data
	if data is Array:
		for block_dict in data:
			if block_dict is Dictionary and block_dict.has("english_name"):
				var eng_name: String = block_dict["english_name"]
				_block_templates[eng_name] = block_dict
		print_rich("[color=green]MapManager: 成功加载 %d 个地块模板！[/color]" % _block_templates.size())
	else:
		push_error("MapManager: JSON 根节点必须是一个 Array 结构！")


# ==============================================================================
# 地图网格生成
# ==============================================================================

## 2. 根据指定的尺寸生成全局地图网格 (例如 3x3)
## [param width]: 网格宽度
## [param height]: 网格高度
## [param default_block_key]: 可选。如果指定了有效的 Key（如 "wilderness"），则整张地图全部填充该地块；如果留空，则从 JSON 模板中随机抽取。
## [param allow_duplicate]: 随机模式下，是否允许同一张地图内生成重复的地块（默认 false：模拟不重复抽牌机制）
func generate_grid(width: int, height: int, default_block_key: String = "", allow_duplicate: bool = false) -> void:
	clear_map()
	
	if _block_templates.is_empty():
		push_error("MapManager: 无法生成地图，因为没有加载任何地块模板！")
		return

	grid_size = Vector2i(width, height)
	
	# 构造可用的随机 key 列表（地块牌堆）
	var draw_deck: Array = _block_templates.keys().duplicate()
	draw_deck.shuffle() # 洗牌

	for x in range(width):
		for y in range(height):
			var coord := Vector2(x, y)
			var target_key: String = default_block_key
			
			# 如果未指定默认地块，或传入的 Key 不在模板库中，则进行随机抽取
			if target_key.is_empty() or not _block_templates.has(target_key):
				if allow_duplicate:
					# 允许重复：完全随机抽取一个 Key
					target_key = _block_templates.keys().pick_random()
				else:
					# 不允许重复：从牌堆顶抽一张
					if draw_deck.is_empty():
						# 牌堆抽空了（比如地图格子数大于地块模板种类数），重新补充牌堆
						draw_deck = _block_templates.keys().duplicate()
						draw_deck.shuffle()
					target_key = draw_deck.pop_back()
				
			var block_instance := create_block_by_key(target_key, coord)
			if block_instance:
				_grid_map[coord] = block_instance

	print_rich("[color=cyan]MapManager: 成功生成 %dx%d 地图网格，共计 %d 个地块！[/color]" % [width, height, _grid_map.size()])


## 3. 根据模板 Key 创建一个独立的 MapBlock 实例
func create_block_by_key(template_key: String, coord: Vector2 = Vector2.ZERO) -> MapBlock:
	if not _block_templates.has(template_key):
		push_error("MapManager: 试图创建未知的地块 Key: %s" % template_key)
		return null

	var template_data: Dictionary = _block_templates[template_key]
	
	# 实例化地块对象
	var map_block := MapBlock.new()
	map_block.coordinate = coord
	
	# 使用 init_from_json_dict 完成初始化（包括通过 SkillFactory 生成 Skill 列表）
	map_block.init_from_json_dict(template_data)
	
	return map_block


## 清理所有网格数据
func clear_map() -> void:
	_grid_map.clear()
	grid_size = Vector2i.ZERO


# ==============================================================================
# 地图网格操作与查询接口
# ==============================================================================

## 根据坐标获取地块对象
func get_block_at(coord: Vector2) -> MapBlock:
	return _grid_map.get(coord, null)


## 检查坐标是否在网格范围内
func is_valid_coordinate(coord: Vector2) -> bool:
	return coord.x >= 0 and coord.x < grid_size.x and coord.y >= 0 and coord.y < grid_size.y


## 动态替换/更新指定坐标的地块
func replace_block_at(coord: Vector2, new_template_key: String) -> MapBlock:
	if not is_valid_coordinate(coord):
		push_error("MapManager: 坐标越界 -> %s" % str(coord))
		return null

	var new_block := create_block_by_key(new_template_key, coord)
	if new_block:
		_grid_map[coord] = new_block
	return new_block


# ==============================================================================
# 事件与流程触发接口 (与 EffectContext 协同)
# ==============================================================================

## 翻开指定坐标的地块
func reveal_block_at(coord: Vector2, context: EffectContext) -> void:
	var block := get_block_at(coord)
	if block == null or block.is_revealed:
		return

	block.is_revealed = true
	
	# 设置执行上下文参数
	context.extra_data["target_block"] = block
	
	# 触发该地块上的 ON_REVEAL 技能逻辑
	block.trigger_event("on_reveal_block", context)
	
	block_revealed.emit(coord, block)


## 角色移动进入指定地块
func enter_block_at(coord: Vector2, context: EffectContext) -> void:
	var block := get_block_at(coord)
	if block == null:
		return

	context.extra_data["target_block"] = block
	
	# 触发进入事件
	block.trigger_event("on_enter_block", context)


## 角色离开指定地块
func leave_block_at(coord: Vector2, context: EffectContext) -> void:
	var block := get_block_at(coord)
	if block == null:
		return

	context.extra_data["target_block"] = block
	
	# 触发离开事件
	block.trigger_event("on_leave_block", context)
