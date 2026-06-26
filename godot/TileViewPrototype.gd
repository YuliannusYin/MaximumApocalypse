# TileViewPrototype.gd
extends Node2D

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
	
	# --- 3. 动态生成地块名字文本 ---
	name_label = Label.new()
	name_label.text = static_template.tile_name
	name_label.position = Vector2(8, 8)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 16)
	add_child(name_label)
	
	# --- 4. 动态生成状态信息文本 ---
	info_label = Label.new()
	info_label.position = Vector2(8, 40)
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_label.add_theme_font_size_override("font_size", 11)
	add_child(info_label)
	_refresh_info_text() # 填充具体文字内容
	
	# --- 5. 动态生成迷雾遮罩层 (覆盖在最上方) ---
	#fog_rect = ColorRect.new()
	#fog_rect.size = size
	#fog_rect.color = Color(0.08, 0.08, 0.1, 0.98) # 接近全黑的深色方框代表迷雾
	#add_child(fog_rect)
	
	# 动态在迷雾上加一行细字提示未探索
	#var fog_label = Label.new()
	#fog_label.text = "未探索 (%d,%d)" % [pos.x, pos.y]
	#fog_label.position = Vector2(8, size.y - 24)
	#fog_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	#fog_label.add_theme_font_size_override("font_size", 10)
	#fog_rect.add_child(fog_label)
	
	# 根据数据的初始状态控制迷雾显隐
	#update_fog_state()

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
	
	# 解析拾荒堆颜色枚举的文本
	var scav_color_str = "无"
	if "ScavengeColor" in Enums:
		scav_color_str = Enums.ScavengeColor.keys()[static_template.scavenge_type]
	
	# 组装展示文本
	var txt = "ID: %s\n" % static_template.id
	txt += "爆怪骰子: %s\n" % str(static_template.spawn_values)
	txt += "拾荒牌堆: %s\n" % scav_color_str
	
	# 如果局内有怪物，动态追加红字标记
	if tile_runtime_data["monster_tokens"] > 0:
		txt += "\n[ 🔴 怪物数量: %d ]" % tile_runtime_data["monster_tokens"]
		
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
