# MapBoard.gd
extends Node2D

# --- 配置常量：指定你的资源存放路径 ---
const TILES_FOLDER_PATH = "res://data/blocks/"
const VAN_TILE_PATH = "res://data/blocks/van.tres"

# --- 渲染配置 ---
@export var tile_size: Vector2 = Vector2(140, 140)  # 方框的长宽
@export var grid_spacing: float = 12.0             # 方框间距
@export var total_tiles_needed: int = 13           # 想要生成的普通地块总数

# --- 内部运行数据 ---
var spawned_tile_views: Dictionary = {}
var loaded_templates: Array[MapBlockData] = []
var van_template: MapBlockData

func _ready() -> void:
	print("[MapBoard] 节点已就绪，开始自主独立生成地图...")
	
	# 1. 自动从文件夹读取地块资源
	_load_tile_resources_from_folder()
	_load_van_resource()
	
	# 安全检查
	if loaded_templates.is_empty():
		push_error("[MapBoard 错误] 未能在指定文件夹找到任何有效的 MapBlockData 普通资源！请检查路径：" + TILES_FOLDER_PATH)
		return
	if van_template == null:
		push_error("[MapBoard 错误] 未能成功加载面包车资源！请检查路径：" + VAN_TILE_PATH)
		return
		
	# 2. 构建并补齐剧本牌库
	var final_pool = _build_final_tile_pool()
	
	# 3. 运行核心算法：生成数据并渲染 2D 画面
	_generate_and_render_map(final_pool)


# --- ⚙️ 内部核心逻辑函数 ---

## 自动扫描并加载文件夹内所有的地块文件
func _load_tile_resources_from_folder() -> void:
	var dir = DirAccess.open(TILES_FOLDER_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				# 清理可能存在的 remap 后缀
				var clean_name = file_name.replace(".remap", "")
				
				# 🚨【修复核心】：严格限制后缀为 .tres，且名字不能包含 van，防止面包车混入普通池
				if clean_name.ends_with(".tres") and not clean_name.contains("van"):
					var full_path = TILES_FOLDER_PATH + clean_name
					
					var res = load(full_path)
					if res is MapBlockData:
						loaded_templates.append(res)
						print("成功自动加载普通地块: " + clean_name)
						
			file_name = dir.get_next()
	else:
		push_error("无法打开文件夹路径: " + TILES_FOLDER_PATH)

## 加载独立的面包车资源
func _load_van_resource() -> void:
	if ResourceLoader.exists(VAN_TILE_PATH):
		var res = load(VAN_TILE_PATH)
		if res is MapBlockData:
			van_template = res
			print("成功独立加载面包车模板: " + VAN_TILE_PATH)

## 根据需要的数量，通过取余循环自动补齐并打乱牌库
func _build_final_tile_pool() -> Array[MapBlockData]:
	var pool: Array[MapBlockData] = []
	for i in range(total_tiles_needed):
		var index = i % loaded_templates.size()
		pool.append(loaded_templates[index])
	pool.shuffle() # 洗牌打乱顺序
	return pool

## 生成并使用方框+文字渲染地图
func _generate_and_render_map(draw_pile: Array[MapBlockData]) -> void:
	# 清理可能存在的旧节点
	for child in get_children():
		child.queue_free()
	spawned_tile_views.clear()
	GameState.map_grid.clear()
	
	# 计算网格单行最大宽度（尽量接近正方形）
	var width: int = ceil(sqrt(total_tiles_needed))
	
	# 铺设普通网格
	for tile_index in range(total_tiles_needed):
		var x = tile_index % width
		var y = tile_index / width
		var pos = Vector2i(x, y)
		
		var current_data = draw_pile.pop_front()
		
		# 录入全局账本
		GameState.map_grid[pos] = {
			"template_id": current_data.id,
			"data": current_data,
			"is_revealed": false, 
			"monster_tokens": 0,
			"dropped_cards": []
		}
		
		_create_prototyping_tile(pos, GameState.map_grid[pos])
			
	# 探测边缘放置面包车
	var van_pos = _find_valid_van_position()
	if van_pos != Vector2i(-99, -99):
		GameState.map_grid[van_pos] = {
			"template_id": van_template.id,
			"data": van_template,
			"is_revealed": true, # 面包车初始可见
			"monster_tokens": 0,
			"dropped_cards": []
		}
		_create_prototyping_tile(van_pos, GameState.map_grid[van_pos])
		print("[MapBoard] 地图渲染完毕！面包车坐落于外围: ", van_pos)

## 纯代码动态组合“方框+文字”地块节点
func _create_prototyping_tile(grid_pos: Vector2i, runtime_data: Dictionary) -> void:
	var tile_node = Node2D.new()
	add_child(tile_node)
	
	# 像素坐标换算
	var pixel_x = grid_pos.x * (tile_size.x + grid_spacing)
	var pixel_y = grid_pos.y * (tile_size.y + grid_spacing)
	tile_node.position = Vector2(pixel_x, pixel_y)
	
	# 绑定我们在上一步创建的纯代码渲染脚本
	tile_node.set_script(preload("res://TileViewPrototype.gd"))
	tile_node.setup(grid_pos, runtime_data, tile_size)
	
	# 存入组件视图缓存
	spawned_tile_views[grid_pos] = tile_node

## 边缘空位探测算法
func _find_valid_van_position() -> Vector2i:
	var potential_positions: Array[Vector2i] = []
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	for pos in GameState.map_grid.keys():
		for dir in directions:
			var target_pos = pos + dir
			if not GameState.map_grid.has(target_pos):
				if not potential_positions.has(target_pos):
					potential_positions.append(target_pos)
					
	if not potential_positions.is_empty():
		potential_positions.shuffle()
		return potential_positions[0]
		
	return Vector2i(-99, -99)
