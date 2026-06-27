# MapBoard.gd
extends Node2D

# --- 配置常量：指定你的资源存放路径 ---
const TILES_FOLDER_PATH = "res://data/blocks/"
const VAN_TILE_PATH = "res://data/blocks/van.tres"

# --- 渲染配置 ---
@export var tile_size: Vector2 = Vector2(140, 140)  # 方框的长宽
@export var grid_spacing: float = 12.0             # 方框间距
@export var map_offset: Vector2 = Vector2(350, 100) # 地图偏移（避开UI面板）

# --- 内部运行数据 ---
var spawned_tile_views: Dictionary = {}
var loaded_templates: Dictionary = {}  # 改为字典，键是地块ID
var van_template: MapBlockData

func _ready() -> void:
	print("[MapBoard] 节点已就绪，等待地图初始化...")

	# 预加载所有地块模板
	_load_all_tile_templates()
	_load_van_resource()

# 预加载所有地块模板到字典中
func _load_all_tile_templates() -> void:
	var dir = DirAccess.open(TILES_FOLDER_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var clean_name = file_name.replace(".remap", "")

				if clean_name.ends_with(".tres") and not clean_name.contains("van"):
					var full_path = TILES_FOLDER_PATH + clean_name
					var res = load(full_path)
					if res is MapBlockData:
						loaded_templates[res.id] = res
						print("[MapBoard] 预加载地块模板: " + res.id + " (" + res.tile_name + ")")
			file_name = dir.get_next()
	else:
		push_error("[MapBoard] 无法打开文件夹: " + TILES_FOLDER_PATH)

func _load_van_resource() -> void:
	if ResourceLoader.exists(VAN_TILE_PATH):
		var res = load(VAN_TILE_PATH)
		if res is MapBlockData:
			van_template = res
			print("[MapBoard] 预加载面包车模板: " + VAN_TILE_PATH)

# 根据关卡配置初始化地图
func initialize_map_from_mission(mission: MissionData) -> void:
	print("[MapBoard] 开始根据关卡配置生成地图...")

	# 清理旧地图
	for child in get_children():
		child.queue_free()
	spawned_tile_views.clear()
	GameState.map_grid.clear()

	# 根据关卡配置创建地块
	var tile_manifest = mission.tile_manifest
	var positions: Array[Vector2i] = []
	var total_tiles = 0

	# 计算总地块数量
	for tile_id in tile_manifest.keys():
		total_tiles += tile_manifest[tile_id]

	# 生成位置网格
	var width = int(ceil(sqrt(total_tiles)))  # 转换为整数
	for i in range(total_tiles):
		var x = i % width
		var y = i / width  # 整数除法
		positions.append(Vector2i(x, y))

	# 打乱位置
	positions.shuffle()

	# 创建地块
	var pos_index = 0
	for tile_id in tile_manifest.keys():
		var count = tile_manifest[tile_id]

		for i in range(count):
			if pos_index >= positions.size():
				break

			var pos = positions[pos_index]
			pos_index += 1

			# 获取地块模板
			var template = loaded_templates.get(tile_id)
			if not template:
				print("[MapBoard] 警告：未找到地块模板 " + tile_id)
				continue

			# 创建地块数据
			var tile_data = {
				"template_id": tile_id,
				"data": template,
				"is_revealed": false,
				"monster_tokens": 0,
				"dropped_cards": []
			}

			# 如果是起始地块，应该翻开显示
			if tile_id == mission.starting_tile_id:
				tile_data["is_revealed"] = true
				print("[MapBoard] 起始地块 " + tile_id + " 已翻开")

			GameState.map_grid[pos] = tile_data
			_create_prototyping_tile(pos, tile_data)

	# 放置面包车（在边缘）
	var van_pos = _find_valid_van_position()
	if van_pos != Vector2i(-99, -99):
		var van_data = {
			"template_id": van_template.id,
			"data": van_template,
			"is_revealed": true,
			"monster_tokens": 0,
			"dropped_cards": []
		}
		GameState.map_grid[van_pos] = van_data
		_create_prototyping_tile(van_pos, van_data)
		print("[MapBoard] 面包车放置在: " + str(van_pos))

	print("[MapBoard] 地图生成完成，共 " + str(GameState.map_grid.size()) + " 个地块")

## 纯代码动态组合"方框+文字"地块节点
func _create_prototyping_tile(grid_pos: Vector2i, runtime_data: Dictionary) -> void:
	var tile_node = Node2D.new()
	add_child(tile_node)

	# 像素坐标换算（加上偏移量）
	var pixel_x = map_offset.x + grid_pos.x * (tile_size.x + grid_spacing)
	var pixel_y = map_offset.y + grid_pos.y * (tile_size.y + grid_spacing)
	tile_node.position = Vector2(pixel_x, pixel_y)

	# 绑定渲染脚本
	tile_node.set_script(load("res://TileViewPrototype.gd"))
	tile_node.setup(grid_pos, runtime_data, tile_size)

	# 存入视图缓存
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

# === 玩家点击地块响应 ===
func on_tile_clicked(tile_pos: Vector2i) -> void:
	print("[MapBoard] 玩家点击地块: " + str(tile_pos))

	# 只在行动阶段可以移动
	if GameState.current_phase != Enums.GamePhase.ACTION:
		print("[MapBoard] 当前不是行动阶段，无法移动")
		return

	# 获取RuleEngine并触发移动
	var game_node = get_parent()
	if game_node and game_node.has_node("RuleEngine"):
		var rule_engine = game_node.get_node("RuleEngine")
		if GameState.active_player_id:
			rule_engine.on_tile_clicked(GameState.active_player_id, tile_pos)

# 更新地块上的角色显示
func update_player_positions() -> void:
	# 清除所有地块上的角色标记
	for pos in spawned_tile_views.keys():
		var tile_view = spawned_tile_views[pos]
		if tile_view.has_method("clear_player_markers"):
			tile_view.clear_player_markers()

	# 为每个玩家在对应地块上显示标记
	for player_id in GameState.players.keys():
		var player = GameState.players[player_id]
		var player_pos = player.position

		if spawned_tile_views.has(player_pos):
			var tile_view = spawned_tile_views[player_pos]
			if tile_view.has_method("add_player_marker"):
				tile_view.add_player_marker(player_id, player.character_name)