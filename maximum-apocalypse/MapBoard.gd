# MapBoard.gd
# 地图板管理器 - 包含地块视图(TileView)内部类
extends Node2D

# --- 配置常量：指定你的资源存放路径 ---
const TILES_FOLDER_PATH = "res://data/blocks/"

# --- 渲染配置 ---
@export var tile_size: Vector2 = Vector2(60, 60)  # 方框的长宽
@export var grid_spacing: float = 12.0             # 方框间距
@export var map_offset: Vector2 = Vector2(10, 10) # 地图偏移（避开UI面板）

# --- 内部运行数据 ---
var spawned_tile_views: Dictionary = {}
var loaded_templates: Dictionary = {}  # 改为字典，键是地块ID
var van_template: MapBlockData

# ============================================================
# 内部类：地块视图 TileView
# 原 TileViewPrototype.gd 合并至此
# ============================================================
class TileView extends Node2D:
	# --- 局内动态创建的组件引用 ---
	var bg_rect: ColorRect
	var border_rect: ColorRect
	var fog_rect: ColorRect
	var name_label: Label
	var info_label: Label
	var click_button: Button
	var player_markers_container: VBoxContainer  # 玩家标记容器

	# --- 数据缓存 ---
	var grid_coordinate: Vector2i
	var tile_runtime_data: Dictionary
	var tile_size: Vector2

	## 初始化入口：由 MapBoard 在动态生成节点后直接调用
	func setup(pos: Vector2i, runtime_data: Dictionary, size: Vector2) -> void:
		grid_coordinate = pos
		tile_runtime_data = runtime_data
		tile_size = size
		var static_template: MapBlockData = runtime_data["data"]

		# --- 1. 动态生成底色方框 ---
		bg_rect = ColorRect.new()
		bg_rect.size = size
		if static_template.id.contains("van"):
			bg_rect.color = Color(0.15, 0.45, 0.25) # 面包车使用深森林绿
		else:
			bg_rect.color = Color(0.2, 0.2, 0.25)   # 普通地块使用深灰蓝色
		add_child(bg_rect)

		# --- 2. 动态生成 1 像素宽的内边框（区分格子边界） ---
		border_rect = ColorRect.new()
		border_rect.size = size - Vector2(2, 2)
		border_rect.position = Vector2(1, 1)
		border_rect.color = bg_rect.color.lightened(0.1) # 边框颜色比背景略亮一点点
		add_child(border_rect)

		# --- 3. 动态生成地块名字文本（包含坐标）
		name_label = Label.new()
		name_label.text = "%s (%d,%d)" % [static_template.tile_name, grid_coordinate.x, grid_coordinate.y]
		name_label.position = Vector2(8, 8)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_font_size_override("font_size", 20)
		add_child(name_label)

		# --- 4. 动态生成状态信息文本 ---
		info_label = Label.new()
		info_label.position = Vector2(8, 40)
		info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info_label.add_theme_font_size_override("font_size", 16)
		add_child(info_label)
		_refresh_info_text() # 填充具体文字内容

		# --- 5. 动态生成迷雾遮罩层 (覆盖在最上方) ---
		fog_rect = ColorRect.new()
		fog_rect.size = size
		fog_rect.color = Color(0.08, 0.08, 0.1, 0.98) # 接近全黑的深色方框代表迷雾
		add_child(fog_rect)

		# 动态在迷雾上加一行细字提示未探索（显示地块ID和坐标）
		var fog_label = Label.new()
		fog_label.text = "未探索 (%d,%d)" % [grid_coordinate.x, grid_coordinate.y]
		fog_label.position = Vector2(8, 8)
		fog_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		fog_label.add_theme_font_size_override("font_size", 20)
		fog_rect.add_child(fog_label)

		# 根据数据的初始状态控制迷雾显隐
		update_fog_state()

		# --- 6. 动态创建点击按钮（用于玩家移动） ---
		_create_click_button(size)

		# --- 7. 动态创建玩家标记容器（显示在该地块上的玩家） ---
		_create_player_markers_container(size)

	## 刷新迷雾层的展示
	func update_fog_state() -> void:
		if fog_rect:
			# 如果数据里被翻开了，迷雾立刻消失，露出底部的名字和数据
			fog_rect.visible = not tile_runtime_data["is_revealed"]

	## 动态刷新地块内的数据文本提示
	func _refresh_info_text() -> void:
		if not info_label: return

		var static_template: MapBlockData = tile_runtime_data["data"]

		# 解析拾荒堆颜色数组的文本（支持多色）
		var scav_color_str = ""
		for color in static_template.scavenge_colors:
			if scav_color_str != "":
				scav_color_str += ","
			scav_color_str += Enums.ScavengeColor.keys()[color]
		if scav_color_str == "":
			scav_color_str = "无"

		# 组装展示文本
		var txt = "爆怪骰子: %s\n" % str(static_template.spawn_value)
		txt += "拾荒牌堆: %s\n" % scav_color_str

		# 如果局内有怪物，动态追加红字标记
		if tile_runtime_data["monster_tokens"] > 0:
			txt += "\n[  怪物数量: %d ]" % tile_runtime_data["monster_tokens"]

		info_label.text = txt

	## 【外部更新接口】当外部修改了怪物数量，调用此函数刷新方框文字
	func update_monster_display(new_count: int) -> void:
		tile_runtime_data["monster_tokens"] = new_count
		_refresh_info_text()

	## 创建透明点击按钮覆盖整个地块
	func _create_click_button(size: Vector2) -> void:
		click_button = Button.new()
		click_button.size = size
		click_button.position = Vector2(0, 0)

		# 设置为完全透明（不显示按钮样式）
		click_button.modulate = Color(1, 1, 1, 0.01)  # 最小可见度，确保可点击

		# 接收鼠标点击
		click_button.mouse_filter = Control.MOUSE_FILTER_STOP

		# 将按钮添加到最后，确保在其他元素之上
		add_child(click_button)

		# 连接点击信号
		click_button.pressed.connect(_on_tile_clicked)

	## 点击地块响应
	func _on_tile_clicked() -> void:
		print("[TileView] 点击了坐标 %s，地块：%s" % [str(grid_coordinate), name_label.text])

		# 通知父节点 MapBoard 触发移动
		var map_board = get_parent()
		if map_board and map_board.has_method("on_tile_clicked"):
			map_board.on_tile_clicked(grid_coordinate)

	## 创建玩家标记容器
	func _create_player_markers_container(size: Vector2) -> void:
		player_markers_container = VBoxContainer.new()
		player_markers_container.position = Vector2(8, size.y - 30)
		player_markers_container.size = Vector2(size.x - 16, 20)
		add_child(player_markers_container)

	## 添加玩家标记
	func add_player_marker(player_id: String, character_name: String) -> void:
		var marker_label = Label.new()
		marker_label.text = "👤 " + character_name
		marker_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))  # 绿色
		marker_label.add_theme_font_size_override("font_size", 12)
		marker_label.name = "player_marker_" + player_id
		player_markers_container.add_child(marker_label)
		print("[TileView] 在地块 " + str(grid_coordinate) + " 显示玩家: " + character_name)

	## 清除所有玩家标记
	func clear_player_markers() -> void:
		for child in player_markers_container.get_children():
			child.queue_free()

# ============================================================
# MapBoard 主类方法
# ============================================================

func _ready() -> void:
	print("[MapBoard] 节点已就绪，等待地图初始化...")

	# 预加载所有地块模板
	_load_all_tile_templates()
	_load_van_resource()

	# 连接地块翻开的信号
	GameState.tile_revealed.connect(_on_tile_revealed)

# 预加载所有地块模板到字典中（按基础名称分组）
func _load_all_tile_templates() -> void:
	var dir = DirAccess.open(TILES_FOLDER_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var clean_name = file_name.replace(".remap", "").replace(".tres", "")

				if clean_name.ends_with(".tres"):
					clean_name = clean_name.replace(".tres", "")

				# 加载所有地块模板（包括面包车）
				var full_path = TILES_FOLDER_PATH + file_name.replace(".remap", "")
				var res = load(full_path)
				if res is MapBlockData:
					# 提取基础名称（去掉骰子值后缀）
					var base_id = res.id
					var last_underscore = res.id.rfind("_")
					if last_underscore > 0:
						var suffix = res.id.substr(last_underscore + 1)
						if suffix.is_valid_int():
							base_id = res.id.substr(0, last_underscore)

					# 按基础名称分组存储变体
					if not loaded_templates.has(base_id):
						loaded_templates[base_id] = []
					loaded_templates[base_id].append(res)
					print("[MapBoard] 预加载地块模板: " + res.id + " -> " + base_id + " (" + res.tile_name + ")")
			file_name = dir.get_next()
	else:
		push_error("[MapBoard] 无法打开文件夹: " + TILES_FOLDER_PATH)

func _load_van_resource() -> void:
	# 面包车现在也从loaded_templates中获取
	if loaded_templates.has("van"):
		var van_variants = loaded_templates["van"]
		if van_variants.size() > 0:
			van_template = van_variants[0]
			print("[MapBoard] 预加载面包车模板: " + van_template.id)

# 根据关卡配置初始化地图
func initialize_map_from_mission(mission: MissionData) -> Vector2i:
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
	var starting_tile_pos: Vector2i = Vector2i(-99, -99)  # 记录起始地块位置

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

			# 获取地块模板（从变体数组中随机选择）
			var variants = loaded_templates.get(tile_id)
			if not variants or variants.size() == 0:
				print("[MapBoard] 警告：未找到地块模板 " + tile_id)
				continue

			var template = variants[randi() % variants.size()]

			# 创建地块数据
			var tile_data = {
				"template_id": template.id,
				"data": template,
				"is_revealed": false,
				"monster_tokens": 0,
				"dropped_cards": []
			}

			# 如果是起始地块，记录位置并翻开显示
			if tile_id == mission.starting_tile_id:
				tile_data["is_revealed"] = true
				starting_tile_pos = pos
				print("[MapBoard] 起始地块 " + template.id + " 已翻开，位置: " + str(pos))

			GameState.map_grid[pos] = tile_data
			_create_tile_view(pos, tile_data)

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
		_create_tile_view(van_pos, van_data)
		print("[MapBoard] 面包车放置在: " + str(van_pos))

		# 如果面包车是起始地块，记录其位置
		if mission.starting_tile_id == "van":
			starting_tile_pos = van_pos
			print("[MapBoard] 面包车作为起始地块，位置: " + str(van_pos))

	print("[MapBoard] 地图生成完成，共 " + str(GameState.map_grid.size()) + " 个地块")
	return starting_tile_pos

## 动态创建地块视图（使用内部类 TileView）
func _create_tile_view(grid_pos: Vector2i, runtime_data: Dictionary) -> void:
	var tile_node = TileView.new()
	add_child(tile_node)

	# 像素坐标换算（加上偏移量）
	var pixel_x = map_offset.x + grid_pos.x * (tile_size.x + grid_spacing)
	var pixel_y = map_offset.y + grid_pos.y * (tile_size.y + grid_spacing)
	tile_node.position = Vector2(pixel_x, pixel_y)

	# 初始化地块视图
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

# === 地块翻开信号响应 ===
func _on_tile_revealed(pos: Vector2i) -> void:
	print("[MapBoard] 收到地块翻开信号: " + str(pos))
	if spawned_tile_views.has(pos):
		var tile_view = spawned_tile_views[pos]
		tile_view.update_fog_state()

# === 更新地块怪物数量显示 ===
func update_tile_monster_count(pos: Vector2i, count: int) -> void:
	if spawned_tile_views.has(pos):
		var tile_view = spawned_tile_views[pos]
		tile_view.update_monster_display(count)
		print("[MapBoard] 更新地块 " + str(pos) + " 的怪物显示: " + str(count))
