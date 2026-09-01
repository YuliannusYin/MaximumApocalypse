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
var _anim_tween: Tween = null  # 当前动画 Tween（翻入/标记/摧毁共用，新动画 kill 旧动画重启）
var _hidden_players: Dictionary = {}  # 隐藏头像的玩家 instance_id -> true（头像移动动画期间）
var _last_mark_count: int = -1  # 上次刷新记录的怪物标记数（供外部对比增减，未变则不播动画）
var _cell_player_ids: Dictionary = {}  # 头像格索引 -> 玩家 instance_id（应用头像隐藏状态用）
var _avatar_cell_count: int = 0  # 头像占用的格数（其后连续段为怪物标记格）

signal block_clicked(block: Variant)
signal block_inspected(block: Variant)
signal avatar_clicked(block: Variant)

const CLICK_THRESHOLD := 6.0

var _left_pressing: bool = false
var _left_press_pos: Vector2 = Vector2.ZERO


func _init() -> void:
	custom_minimum_size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
	size = Vector2(BLOCK_SIZE, BLOCK_SIZE)
	mouse_filter = Control.MOUSE_FILTER_PASS


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
	# 记录本次怪物标记数，供外部（GameScene2D）对比判断增减
	_last_mark_count = _block.monster_marks


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


## ================= 动画与头像隐藏（纯表现层，fire-and-forget） =================

## 终止当前动画并复位中断可能残留的中间状态（self.modulate 保留，供摧毁灰化持续生效）。
func _kill_anim_tween() -> void:
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null
	scale = Vector2.ONE
	for cell in _grid_cells:
		cell.scale = Vector2.ONE
		cell.modulate = Color(1, 1, 1, 1)


## 地块揭示翻入动画：水平缩放 0.05 → 1（带回弹，约 0.35 秒）。
func play_reveal_animation() -> void:
	_kill_anim_tween()
	pivot_offset = size / 2.0
	scale = Vector2(0.05, 1.0)
	_anim_tween = create_tween()
	var tweener: PropertyTweener = _anim_tween.tween_property(self, "scale:x", 1.0, 0.35)
	tweener.set_trans(Tween.TRANS_BACK)
	tweener.set_ease(Tween.EASE_OUT)


## 怪物标记反馈动画。added=true：最新标记图标弹入（scale 0→1.25→1，约 0.3 秒）；
## added=false：剩余标记快速淡出闪烁（modulate.a 0.5 → 1，约 0.2 秒）后复位；
## 找不到具体标记格时降级为地块整体轻微脉冲。播放前记录当前标记数。
func play_mark_pulse(added: bool) -> void:
	if _block == null or not is_instance_valid(_block):
		return
	# 播放前把当前标记数存入 _last_mark_count
	_last_mark_count = _block.monster_marks
	_kill_anim_tween()
	var mark_cells: Array[TextureRect] = _get_mark_cells()
	if added:
		var target: TextureRect = null
		if not mark_cells.is_empty():
			target = mark_cells[mark_cells.size() - 1]
		if target != null:
			# 最新标记图标弹入
			target.pivot_offset = target.size / 2.0
			target.scale = Vector2.ZERO
			_anim_tween = create_tween()
			_anim_tween.tween_property(target, "scale", Vector2(1.25, 1.25), 0.18)
			_anim_tween.tween_property(target, "scale", Vector2.ONE, 0.12)
		else:
			# 降级：地块整体轻微脉冲
			_anim_tween = create_tween()
			_anim_tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.15)
			_anim_tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	else:
		# 标记减少：对剩余标记（无则地块整体）快速淡出闪烁后复位
		var nodes: Array = mark_cells.duplicate()
		if nodes.is_empty():
			nodes.append(self)
		_anim_tween = create_tween().set_parallel(true)
		for node in nodes:
			var fade_tweener: PropertyTweener = _anim_tween.tween_property(node, "modulate:a", 1.0, 0.2)
			fade_tweener.from(0.5)


## 地块摧毁灰化动画：modulate 变暗至灰并轻微下沉（约 0.4 秒），与 refresh 的摧毁样式叠加共存。
func play_destroyed_animation() -> void:
	_kill_anim_tween()
	var target_y: float = position.y + 4.0
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(self, "modulate", Color(0.45, 0.45, 0.45), 0.4)
	_anim_tween.tween_property(self, "position:y", target_y, 0.4)


## 隐藏/恢复本地块上指定玩家的头像（头像移动动画期间使用）。
func set_avatar_hidden(player: Variant, hidden: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	var pid: int = player.get_instance_id()
	if hidden:
		_hidden_players[pid] = true
	else:
		_hidden_players.erase(pid)
	_apply_avatar_visibility()


## 返回上次刷新记录的怪物标记数（供外部对比增减；标记数未变则不播动画）。
func get_last_mark_count() -> int:
	return _last_mark_count


## 遍历头像格，将处于隐藏名单中的玩家头像设为不可见（隐藏者仍占格，避免其他头像位置跳动）。
func _apply_avatar_visibility() -> void:
	for cell_idx in _cell_player_ids:
		var idx: int = cell_idx
		if idx < 0 or idx >= _grid_cells.size():
			continue
		_grid_cells[idx].visible = not _hidden_players.has(_cell_player_ids[cell_idx])


## 取当前怪物标记对应的九宫格格子（头像格之后的连续段）。
func _get_mark_cells() -> Array[TextureRect]:
	var cells: Array[TextureRect] = []
	if _block == null or not is_instance_valid(_block):
		return cells
	var count: int = _block.monster_marks
	for i in count:
		var idx: int = _avatar_cell_count + i
		if idx < 0 or idx >= _grid_cells.size():
			break
		var cell: TextureRect = _grid_cells[idx]
		if cell.visible and cell.texture != null:
			cells.append(cell)
	return cells


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
	_cell_player_ids.clear()
	_avatar_cell_count = 0
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
				_cell_player_ids[idx] = player.get_instance_id()
				if current_player != null and player == current_player:
					_grid_cells[idx].mouse_filter = Control.MOUSE_FILTER_STOP
					if not _grid_cells[idx].is_connected("gui_input", _on_avatar_cell_input):
						_grid_cells[idx].gui_input.connect(_on_avatar_cell_input)
				idx += 1
	# 头像占用的格数（其后连续段为怪物标记格）
	_avatar_cell_count = idx
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
	# 统一应用头像隐藏状态（refresh 被外部频繁调用后隐藏状态仍需生效）
	_apply_avatar_visibility()
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		block_inspected.emit(_block)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_pressing = true
			_left_press_pos = event.position
		else:
			if _left_pressing and event.position.distance_to(_left_press_pos) < CLICK_THRESHOLD:
				block_clicked.emit(_block)
			_left_pressing = false
	elif event is InputEventMouseMotion and _left_pressing:
		if event.position.distance_to(_left_press_pos) >= CLICK_THRESHOLD:
			_left_pressing = false


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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		block_inspected.emit(_block)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		avatar_clicked.emit(_block)
