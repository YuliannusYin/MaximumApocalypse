class_name TableMapController
extends Node2D

## 程序化绘制的废土桌面，避免地图区域退化成单一色块。
class TableSurface extends Control:
	var surface_size: Vector2 = Vector2.ZERO

	func _draw() -> void:
		if surface_size.x <= 0.0 or surface_size.y <= 0.0:
			return
		var rect := Rect2(Vector2.ZERO, surface_size)
		draw_rect(rect, Color("#171817"))
		# 多层内缩色带模拟旧金属/木板桌面的边缘压暗。
		for i in range(7):
			var inset := float(i * 18)
			var alpha := 0.16 - float(i) * 0.018
			draw_rect(
				Rect2(Vector2(inset, inset), surface_size - Vector2(inset * 2.0, inset * 2.0)),
				Color(0.30, 0.25, 0.18, alpha),
				false,
				2.0
			)
		# 固定种子的斑驳颗粒，保持每次刷新一致且不抢地图图片的注意力。
		for i in range(150):
			var px := fmod(float(i * 97 + 31), maxf(surface_size.x - 20.0, 1.0)) + 10.0
			var py := fmod(float(i * 53 + 17), maxf(surface_size.y - 20.0, 1.0)) + 10.0
			var radius := 1.0 + float(i % 3)
			var tone := 0.20 + float(i % 5) * 0.012
			draw_circle(Vector2(px, py), radius, Color(tone, tone * 0.88, tone * 0.68, 0.12))
		# 极低对比的横向桌面纹理，提供方向感但不形成额外网格。
		for y in range(24, int(surface_size.y), 32):
			draw_line(
				Vector2(12.0, y),
				Vector2(surface_size.x - 12.0, y + sin(float(y)) * 1.5),
				Color(0.52, 0.43, 0.29, 0.035),
				1.0
			)
		draw_rect(rect.grow(-8.0), Color(0.62, 0.46, 0.25, 0.30), false, 2.0)
		draw_rect(rect.grow(-16.0), Color(0.02, 0.02, 0.02, 0.55), false, 3.0)

## 地图与相机控制器。
## 管理桌子背景、地图块视图、相机拖拽/缩放/边界限制、移动高亮。

signal block_clicked(block: Variant)
signal block_inspected(block: Variant)
signal avatar_clicked(block: Variant)

const WINDOW_W := 1430
const WINDOW_H := 780
const BLOCK_SIZE := 144
const BLOCK_GAP := 8
const TABLE_MARGIN := 220
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1
const DRAG_THRESHOLD := 6.0

# === 桌子/摄像头 ===
var _table_bg: Control
var _map_container: Node2D
var _table_size: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _did_drag: bool = false

# === 地图块视图缓存 ===
var _block_views: Dictionary = {}

var _table_layer: CanvasLayer

# === 头像移动动画 ===
var _avatar_anim_busy: bool = false  # 头像移动动画播放中（防重入）


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

	_table_bg = TableSurface.new()
	_table_bg.position = -_table_size / 2.0
	_table_bg.size = _table_size
	_table_bg.set("surface_size", _table_size)
	_table_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_container.add_child(_table_bg)
	_table_bg.queue_redraw()

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
		view.block_inspected.connect(_on_block_inspected_signal)
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


## 仅在 GUI 未消费的事件上开始拖拽 / 缩放，避免手牌、按钮、弹窗被左键拖走。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging = true
		_drag_start = event.position
		_did_drag = false
	elif event is InputEventMouseButton and _map_container != null and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_map(event.position, 1.0 + ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_map(event.position, 1.0 - ZOOM_STEP)


## 拖拽一旦开始，在 `_input` 中跟踪移动与松开，以免鼠标滑到 UI 上时卡住。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
		_did_drag = false
	elif event is InputEventMouseMotion and _dragging and _map_container != null:
		if not _did_drag and event.position.distance_to(_drag_start) >= DRAG_THRESHOLD:
			_did_drag = true
		if _did_drag:
			_map_container.position += event.relative
			_clamp_camera()


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


## 按 block 实例查询其地块视图；无有效视图时返回 null。
func get_block_view(block: Variant) -> Variant:
	if block == null or not is_instance_valid(block):
		return null
	return _block_views.get(block.get_instance_id())


## 教程挖洞：当前玩家在地图上的头像（或所在地块）。
func get_current_player_avatar_rect() -> Rect2:
	var current: Variant = Game.get_current_player()
	if current == null or not is_instance_valid(current):
		return Rect2()
	var block: Variant = current.get("current_block")
	var view: Variant = get_block_view(block)
	if view == null or not is_instance_valid(view):
		return Rect2()
	return view.get_player_avatar_rect(current)


## 教程挖洞：带怪物标记的地块包围盒。
func get_marked_blocks_rect() -> Rect2:
	var merged := Rect2()
	for block in Game.map_area:
		if block == null or not is_instance_valid(block):
			continue
		if int(block.get("monster_marks")) <= 0:
			continue
		var view: Variant = get_block_view(block)
		if view == null or not is_instance_valid(view):
			continue
		var r: Rect2 = view.get_monster_marks_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		if merged.size == Vector2.ZERO:
			merged = r
		else:
			merged = merged.merge(r)
	return merged


## 教程挖洞：指定地块整体。
func get_block_global_rect(block: Variant) -> Rect2:
	var view: Variant = get_block_view(block)
	if view == null or not is_instance_valid(view):
		return Rect2()
	return view.get_global_rect()


## 头像移动动画：以浮动头像从源地块中心滑至目标地块中心（约 0.35 秒）。
## 动画期间隐藏源/目标地块视图中该玩家的头像，结束后移除浮动头像并恢复显示。
## 本方法为 async 协程，调用方可 await；源/目标视图缺失或动画播放中时直接返回（调用方降级直接刷新）。
func play_avatar_move(player: Variant, source_block: Variant, target_block: Variant) -> void:
	if _avatar_anim_busy:
		return
	if player == null or not is_instance_valid(player):
		return
	if _map_container == null or not is_instance_valid(_map_container):
		return
	var source_view: Variant = get_block_view(source_block)
	var target_view: Variant = get_block_view(target_block)
	if source_view == null or not is_instance_valid(source_view):
		return
	if target_view == null or not is_instance_valid(target_view):
		return
	_avatar_anim_busy = true
	# 头像贴图取法与 MapBlockView._update_grid 一致：role_card.english_name -> ImageCache
	var eng: String = ""
	var role: Variant = player.get("role_card")
	if role != null and is_instance_valid(role):
		eng = role.get("english_name")
	var tex: Texture2D = null
	if not eng.is_empty():
		tex = ImageCache.get_player_avatar(eng)
	# 浮动节点：有贴图用 TextureRect（尺寸同地块内头像格 40x40）；取不到贴图用灰色 ColorRect 占位
	var float_size: Vector2 = Vector2(40, 40)
	var floater: Control = null
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		floater = tr
	else:
		var cr := ColorRect.new()
		cr.color = Color(0.5, 0.5, 0.5, 0.85)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		float_size = Vector2(32, 32)
		floater = cr
	floater.size = float_size
	# 源/目标地块中心（view.position 基于 _map_container 坐标系，浮动层挂同一容器保证坐标一致）
	var half_block: Vector2 = Vector2(BLOCK_SIZE, BLOCK_SIZE) / 2.0
	var source_center: Vector2 = source_view.position + half_block
	var target_center: Vector2 = target_view.position + half_block
	floater.position = source_center - float_size / 2.0
	_map_container.add_child(floater)
	# 动画期间隐藏源/目标地块视图中该玩家的头像
	source_view.set_avatar_hidden(player, true)
	target_view.set_avatar_hidden(player, true)
	# 浮动头像从源中心滑至目标中心
	var tween: Tween = create_tween()
	var tweener: PropertyTweener = tween.tween_property(floater, "position", target_center - float_size / 2.0, 0.35)
	tweener.set_trans(Tween.TRANS_SINE)
	tweener.set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	# 清理浮动节点并恢复两地块头像显示
	if floater != null and is_instance_valid(floater):
		floater.queue_free()
	if source_view != null and is_instance_valid(source_view):
		source_view.set_avatar_hidden(player, false)
	if target_view != null and is_instance_valid(target_view):
		target_view.set_avatar_hidden(player, false)
	_avatar_anim_busy = false


func _on_block_clicked_signal(block: Variant) -> void:
	block_clicked.emit(block)


func _on_block_inspected_signal(block: Variant) -> void:
	block_inspected.emit(block)


func _on_avatar_clicked_signal(block: Variant) -> void:
	avatar_clicked.emit(block)
