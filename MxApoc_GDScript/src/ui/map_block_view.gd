class_name MapBlockView
extends Panel

const BLOCK_SIZE := 144
const GRID_N := 3
const CELL_SIZE: float = float(BLOCK_SIZE) / float(GRID_N)
const ICON_SIZE: float = 40.0
const ICON_OFFSET: float = (CELL_SIZE - ICON_SIZE) / 2.0
const SEAT_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.25, 1.0),
	Color(0.25, 0.45, 0.85, 1.0),
	Color(0.25, 0.75, 0.35, 1.0),
	Color(0.9, 0.8, 0.25, 1.0),
]

var _block: MapBlock
var _texture_rect: TextureRect
var _name_label: Label
var _grid_cells: Array[TextureRect] = []  # 3×3 九宫格，索引 = row*3+col
var _highlight_panel: Panel  # 高亮覆盖层，渲染在最顶层
var _move_highlight_panel: Panel  # 移动选取高亮覆盖层（绿色/金黄色）
var _objective_mark_icon: TextureRect  # 任务标记图标（固定位置）
var _block_texture: Texture2D  # 缓存已选中的地块变体纹理（revealed 后锁定，destroyed 复用）

signal block_clicked(block: Variant)
signal avatar_clicked(block: Variant)


func _init() -> void:
	custom_minimum_size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
	size = Vector2(BLOCK_SIZE, BLOCK_SIZE)


func setup(block: MapBlock, is_current_player_block: bool = false) -> void:
	_block = block
	_clear_children()
	_build_content()
	refresh(is_current_player_block)


func refresh(is_current_player_block: bool = false, current_player: Variant = null) -> void:
	if _block == null or not is_instance_valid(_block):
		return
	if _block.is_destroyed():
		_apply_destroyed_style()
	elif _block.is_revealed():
		_apply_revealed_style()
	else:
		_apply_unrevealed_style()
	if is_current_player_block:
		_highlight_panel.visible = true
	else:
		_highlight_panel.visible = false
	_update_grid(current_player)


func _build_content() -> void:
	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_preset(PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

	_name_label = Label.new()
	_name_label.position = Vector2(0, BLOCK_SIZE - 48)
	_name_label.size = Vector2(BLOCK_SIZE, 24)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 4)
	add_child(_name_label)

	# 九宫格：3×3 个 TextureRect，用于显示玩家头像和怪物标记
	_grid_cells.clear()
	for row in GRID_N:
		for col in GRID_N:
			var cell := TextureRect.new()
			cell.position = Vector2(col * CELL_SIZE + ICON_OFFSET, row * CELL_SIZE + ICON_OFFSET)
			cell.size = Vector2(ICON_SIZE, ICON_SIZE)
			cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			cell.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.visible = false
			add_child(cell)
			_grid_cells.append(cell)

	# 高亮覆盖层：渲染在最顶层，金色粗边框
	_highlight_panel = Panel.new()
	_highlight_panel.set_anchors_preset(PRESET_FULL_RECT)
	_highlight_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_panel.visible = false
	var hl_style := StyleBoxFlat.new()
	hl_style.bg_color = Color(0, 0, 0, 0)
	hl_style.border_width_left = 5
	hl_style.border_width_top = 5
	hl_style.border_width_right = 5
	hl_style.border_width_bottom = 5
	hl_style.border_color = Color(1.0, 0.84, 0.0, 1.0)
	hl_style.corner_radius_top_left = 4
	hl_style.corner_radius_top_right = 4
	hl_style.corner_radius_bottom_left = 4
	hl_style.corner_radius_bottom_right = 4
	_highlight_panel.add_theme_stylebox_override("panel", hl_style)
	add_child(_highlight_panel)

	# 移动选取高亮覆盖层：渲染在最顶层，绿色/金黄色边框
	_move_highlight_panel = Panel.new()
	_move_highlight_panel.set_anchors_preset(PRESET_FULL_RECT)
	_move_highlight_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_move_highlight_panel.visible = false
	add_child(_move_highlight_panel)

	# 任务标记图标：固定在右上角
	_objective_mark_icon = TextureRect.new()
	_objective_mark_icon.position = Vector2(BLOCK_SIZE - ICON_SIZE - 4, 4)
	_objective_mark_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	_objective_mark_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_objective_mark_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_objective_mark_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_objective_mark_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_mark_icon.visible = false
	add_child(_objective_mark_icon)


func _apply_unrevealed_style() -> void:
	var back: Texture2D = ImageCache.get_block_back_texture()
	if back != null:
		_texture_rect.texture = back
		_texture_rect.modulate = Color(1, 1, 1, 1)
		_name_label.text = ""
	else:
		_texture_rect.texture = null
		_name_label.text = "?"
	_name_label.visible = true
	add_theme_stylebox_override("panel", _make_fill_style(Color(0.22, 0.22, 0.26, 1.0)))


func _apply_revealed_style() -> void:
	if _block_texture == null:
		_block_texture = ImageCache.get_block_texture(_block.block_name, _block.scavenge_colors, _block.monster_spawn_value)
	if _block_texture != null:
		_texture_rect.texture = _block_texture
		_texture_rect.modulate = Color(1, 1, 1, 1)
	else:
		_texture_rect.texture = null
	_name_label.text = _block.block_name
	_name_label.visible = true
	add_theme_stylebox_override("panel", _make_fill_style(Color(0.38, 0.40, 0.44, 1.0)))


func _apply_destroyed_style() -> void:
	if _block_texture != null:
		_texture_rect.texture = _block_texture
		_texture_rect.modulate = Color(1.0, 0.3, 0.3, 0.85)
		_name_label.text = "已摧毁"
	else:
		_texture_rect.texture = null
		_name_label.text = "已摧毁"
	_name_label.visible = true
	add_theme_stylebox_override("panel", _make_fill_style(Color(0.5, 0.15, 0.15, 0.7)))


## 填充九宫格：玩家头像（前 N 格）+ 怪物标记图标（后 M 格）。
func _update_grid(current_player: Variant = null) -> void:
	# 先清空所有格子
	for cell in _grid_cells:
		cell.texture = null
		cell.visible = false
		cell.modulate = Color(1, 1, 1, 1)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if cell.is_connected("gui_input", _on_avatar_cell_input):
			cell.gui_input.disconnect(_on_avatar_cell_input)
	if _block == null or not is_instance_valid(_block):
		return
	if _block.is_destroyed():
		return
	var idx: int = 0
	# 玩家头像（仅已展示地块显示）
	if _block.is_revealed():
		for player in _block.get_players():
			if player == null or not is_instance_valid(player):
				continue
			if idx >= _grid_cells.size():
				break
			var role: Variant = player.get("role_card")
			var tex: Texture2D = null
			if role != null and is_instance_valid(role):
				var eng: String = role.get("english_name")
				if not eng.is_empty():
					tex = ImageCache.get_player_avatar(eng)
			if tex != null:
				_grid_cells[idx].texture = tex
				_grid_cells[idx].visible = true
				if current_player != null and player == current_player:
					_grid_cells[idx].mouse_filter = Control.MOUSE_FILTER_STOP
					if not _grid_cells[idx].is_connected("gui_input", _on_avatar_cell_input):
						_grid_cells[idx].gui_input.connect(_on_avatar_cell_input)
				idx += 1
	# 怪物标记
	var mark_tex: Texture2D = ImageCache.get_monster_mark_texture()
	var mark_count: int = _block.monster_marks
	for i in mark_count:
		if idx >= _grid_cells.size():
			break
		if mark_tex != null:
			_grid_cells[idx].texture = mark_tex
			_grid_cells[idx].visible = true
			idx += 1
	# 任务标记图标
	var obj_tex: Texture2D = ImageCache.get_objective_mark_texture()
	if obj_tex != null:
		_objective_mark_icon.texture = obj_tex
		_objective_mark_icon.visible = _block.has_objective_mark()
	else:
		_objective_mark_icon.visible = false
	# 地块名始终显示（中心偏下），不因九宫格内容而隐藏


func _clear_children() -> void:
	for child in get_children():
		child.queue_free()


func _make_fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.15, 0.15, 0.15, 1.0)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		block_clicked.emit(_block)


## 设置移动选取高亮状态：none/green/golden。
func set_move_highlight(state: String) -> void:
	if _move_highlight_panel == null or not is_instance_valid(_move_highlight_panel):
		return
	match state:
		"green":
			_move_highlight_panel.visible = true
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0, 0, 0, 0)
			style.border_width_left = 5
			style.border_width_top = 5
			style.border_width_right = 5
			style.border_width_bottom = 5
			style.border_color = Color(0.2, 0.8, 0.2, 1.0)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			_move_highlight_panel.add_theme_stylebox_override("panel", style)
		"golden":
			_move_highlight_panel.visible = true
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0, 0, 0, 0)
			style.border_width_left = 5
			style.border_width_top = 5
			style.border_width_right = 5
			style.border_width_bottom = 5
			style.border_color = Color(1.0, 0.84, 0.0, 1.0)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			_move_highlight_panel.add_theme_stylebox_override("panel", style)
		_:
			_move_highlight_panel.visible = false


func _on_avatar_cell_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		avatar_clicked.emit(_block)
