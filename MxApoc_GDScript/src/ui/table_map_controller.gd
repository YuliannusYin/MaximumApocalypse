class_name TableMapController
extends Node2D

## 地图与相机控制器。
## 管理桌子背景、地图块视图、相机拖拽/缩放/边界限制、移动高亮。

signal block_clicked(block: Variant)
signal avatar_clicked(block: Variant)

const WINDOW_W := 1430
const WINDOW_H := 780
const BLOCK_SIZE := 144
const BLOCK_GAP := 4
const TABLE_MARGIN := 200
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1

# === 桌子/摄像头 ===
var _table_bg: ColorRect
var _map_container: Node2D
var _table_size: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO

# === 地图块视图缓存 ===
var _block_views: Dictionary = {}

var _table_layer: CanvasLayer


func setup(table_layer: CanvasLayer) -> void:
	_table_layer = table_layer


func build_table_and_map() -> void:
	var mw: int = max(Game.map_width, 1)
	var mh: int = max(Game.map_height, 1)
	var map_pw: float = mw * (BLOCK_SIZE + BLOCK_GAP) - BLOCK_GAP
	var map_ph: float = mh * (BLOCK_SIZE + BLOCK_GAP) - BLOCK_GAP
	_table_size = Vector2(map_pw + TABLE_MARGIN * 2, map_ph + TABLE_MARGIN * 2)

	_map_container = Node2D.new()
	_map_container.position = Vector2(WINDOW_W / 2.0, WINDOW_H / 2.0)
	_table_layer.add_child(_map_container)

	_table_bg = ColorRect.new()
	_table_bg.position = -_table_size / 2.0
	_table_bg.size = _table_size
	_table_bg.color = Color(0.30, 0.32, 0.34, 1.0)
	_map_container.add_child(_table_bg)

	for block in Game.map_area:
		if block == null or not is_instance_valid(block):
			continue
		var view := MapBlockView.new()
		var coord: Dictionary = block.coordinate
		var bx: float = -map_pw / 2.0 + coord["x"] * (BLOCK_SIZE + BLOCK_GAP)
		var by: float = -map_ph / 2.0 + coord["y"] * (BLOCK_SIZE + BLOCK_GAP)
		view.position = Vector2(bx, by)
		_map_container.add_child(view)
		view.setup(block)
		_block_views[block.get_instance_id()] = view
		view.block_clicked.connect(_on_block_clicked_signal)
		view.avatar_clicked.connect(_on_avatar_clicked_signal)

	refresh_map()


func refresh_map() -> void:
	var current: Variant = Game.get_current_player()
	var current_block: Variant = null
	if current != null and is_instance_valid(current):
		current_block = current.get("current_block")
	for block in Game.map_area:
		if block == null or not is_instance_valid(block):
			continue
		var view: Variant = _block_views.get(block.get_instance_id())
		if view == null or not is_instance_valid(view):
			continue
		var is_current: bool = (current_block != null and is_instance_valid(current_block)
			and block == current_block)
		view.refresh(is_current, current)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_dragging = event.pressed
		if _dragging:
			_drag_start = event.position
	elif event is InputEventMouseMotion and _dragging and _map_container != null:
		_map_container.position += event.relative
		_clamp_camera()
	elif event is InputEventMouseButton and _map_container != null and event.pressed and _dragging:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_map(event.position, 1.0 + ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_map(event.position, 1.0 - ZOOM_STEP)


func _clamp_camera() -> void:
	if _map_container == null:
		return
	var scaled_size: Vector2 = _table_size * _map_container.scale.x
	var half: Vector2 = scaled_size / 2.0
	# 桌子边缘不超出窗口；桌子小于窗口时允许在窗口内移动（min/max 统一处理两种情形）
	var min_x: float = min(half.x, WINDOW_W - half.x)
	var max_x: float = max(half.x, WINDOW_W - half.x)
	var min_y: float = min(half.y, WINDOW_H - half.y)
	var max_y: float = max(half.y, WINDOW_H - half.y)
	_map_container.position.x = clampf(_map_container.position.x, min_x, max_x)
	_map_container.position.y = clampf(_map_container.position.y, min_y, max_y)


## 以鼠标位置为锚点缩放地图。
func _zoom_map(anchor: Vector2, factor: float) -> void:
	var old_scale: float = _map_container.scale.x
	var new_scale: float = clampf(old_scale * factor, ZOOM_MIN, ZOOM_MAX)
	if abs(new_scale - old_scale) < 0.001:
		return
	var local_before: Vector2 = (anchor - _map_container.position) / old_scale
	_map_container.scale = Vector2(new_scale, new_scale)
	_map_container.position = anchor - local_before * new_scale
	_clamp_camera()


## 刷新移动高亮：valid_blocks 中地块设为 green（在 selected_blocks 中设为 golden），其余设为 none。
## active 为 false 或 valid_blocks 为空时清空所有高亮。
func refresh_move_highlights(active: bool, valid_blocks: Array, selected_blocks: Array) -> void:
	if not active or valid_blocks.is_empty():
		for view in _block_views.values():
			if view != null and is_instance_valid(view):
				view.set_move_highlight("none")
		return
	for block in Game.map_area:
		if block == null or not is_instance_valid(block):
			continue
		var view: Variant = _block_views.get(block.get_instance_id())
		if view == null or not is_instance_valid(view):
			continue
		var is_valid: bool = false
		for b in valid_blocks:
			if b == block:
				is_valid = true
				break
		if is_valid:
			var is_selected: bool = false
			for s in selected_blocks:
				if s == block:
					is_selected = true
					break
			if is_selected:
				view.set_move_highlight("golden")
			else:
				view.set_move_highlight("green")
		else:
			view.set_move_highlight("none")


func get_block_views() -> Dictionary:
	return _block_views


func _on_block_clicked_signal(block: Variant) -> void:
	block_clicked.emit(block)


func _on_avatar_clicked_signal(block: Variant) -> void:
	avatar_clicked.emit(block)
