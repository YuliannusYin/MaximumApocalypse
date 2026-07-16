class_name HandDisplayArea
extends Control

## 手牌显示区。
## 水平排列当前玩家的手牌。支持悬停上浮、单击选中、双击使用、拖拽到结算区使用。
## 拖拽逻辑：左键按下卡牌 → 结算区显示 → 鼠标移动卡牌跟随 → 松开在结算区内=使用/外=取消。右键取消拖拽。

const AREA_X := 300
const AREA_Y := 610
const AREA_W := 890
const AREA_H := 150
const CARD_W := 100
const CARD_H := 140
const CARD_GAP := 8
const CARD_Y := 5.0  # 卡牌在手牌区内的 y 偏移（垂直居中）

signal card_used(card: Variant)

var _player: Variant = null
var _card_views: Array = []
var _selected_view: CardView = null
var _settlement_area: CardSettlementArea = null

# 拖拽状态
var _dragging: bool = false
var _dragged_view: CardView = null
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	position = Vector2(AREA_X, AREA_Y)
	size = Vector2(AREA_W, AREA_H)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _init() -> void:
	custom_minimum_size = Vector2(AREA_W, AREA_H)


## 设置结算区引用（用于拖拽时显示/判断落点）。
func set_settlement_area(area: CardSettlementArea) -> void:
	_settlement_area = area


## 设置当前玩家并刷新手牌显示。
func set_player(player: Variant) -> void:
	_player = player
	refresh()


## 刷新手牌区（重新构建卡牌视图）。
func refresh() -> void:
	_clear_cards()
	if _player == null or not is_instance_valid(_player):
		return
	var hand: Array = _player.get("hand")
	var count: int = hand.size()
	if count == 0:
		return
	# 计算总宽度，居中排列
	var total_w: float = count * CARD_W + maxi(count - 1, 0) * CARD_GAP
	var start_x: float = max((AREA_W - total_w) / 2.0, 0.0)
	for i in range(count):
		var card: Variant = hand[i]
		if card == null or not is_instance_valid(card):
			continue
		var view := CardView.new()
		add_child(view)
		view.set_card(card)
		var pos := Vector2(start_x + i * (CARD_W + CARD_GAP), CARD_Y)
		view.set_base_position(pos)
		view.position = pos
		_card_views.append(view)


## 清除选中状态。
func clear_selection() -> void:
	if _selected_view != null and is_instance_valid(_selected_view):
		_selected_view.set_selected(false)
	_selected_view = null


# === 鼠标交互 ===

func _gui_input(event: InputEvent) -> void:
	if _dragging:
		return  # 拖拽中由 _input 全局处理
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.double_click:
			_handle_double_click(event.position)
		elif event.pressed:
			_try_start_drag(event.position)
		else:
			_handle_click(event.position)
	elif event is InputEventMouseMotion:
		_update_hover(event.position)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion and _dragged_view != null:
		var global_pos: Vector2 = event.position
		var local_pos: Vector2 = global_pos - Vector2(AREA_X, AREA_Y)
		_dragged_view.position = local_pos - _drag_offset
		_update_settlement_highlight(global_pos)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_drag()


# === 拖拽逻辑 ===

func _try_start_drag(local_pos: Vector2) -> void:
	var view := _find_card_at(local_pos)
	if view == null:
		return
	_dragging = true
	_dragged_view = view
	_drag_offset = local_pos - view.position
	move_child(view, get_child_count() - 1)
	view.set_hovered(false)
	if _settlement_area != null:
		_settlement_area.show_area(view.get_card())


func _end_drag(global_pos: Vector2) -> void:
	var card: Variant = _dragged_view.get_card() if _dragged_view != null else null
	var used: bool = false
	if _settlement_area != null and _settlement_area.is_point_inside(global_pos):
		used = true
	_dragging = false
	if _dragged_view != null and is_instance_valid(_dragged_view):
		_dragged_view.position = _dragged_view.get_base_position()
		_dragged_view = null
	if _settlement_area != null:
		_settlement_area.hide_area()
	if used:
		card_used.emit(card)
	call_deferred("refresh")


func _cancel_drag() -> void:
	_dragging = false
	if _dragged_view != null and is_instance_valid(_dragged_view):
		_dragged_view.position = _dragged_view.get_base_position()
		_dragged_view = null
	if _settlement_area != null:
		_settlement_area.hide_area()


func _update_settlement_highlight(global_pos: Vector2) -> void:
	if _settlement_area == null:
		return
	_settlement_area.set_drag_over(_settlement_area.is_point_inside(global_pos))


# === 悬停/点击/双击 ===

func _update_hover(local_pos: Vector2) -> void:
	var hovered := _find_card_at(local_pos)
	for view in _card_views:
		if view == null or not is_instance_valid(view):
			continue
		view.set_hovered(view == hovered)


func _handle_click(local_pos: Vector2) -> void:
	var view := _find_card_at(local_pos)
	if view == null:
		return
	if _selected_view == view:
		return
	if _selected_view != null and is_instance_valid(_selected_view):
		_selected_view.set_selected(false)
	_selected_view = view
	view.set_selected(true)


func _handle_double_click(local_pos: Vector2) -> void:
	var view := _find_card_at(local_pos)
	if view == null:
		return
	card_used.emit(view.get_card())
	call_deferred("refresh")


# === 工具方法 ===

func _find_card_at(local_pos: Vector2) -> CardView:
	for i in range(_card_views.size() - 1, -1, -1):
		var view: CardView = _card_views[i]
		if view == null or not is_instance_valid(view):
			continue
		var rect := Rect2(view.position, Vector2(CARD_W, CARD_H))
		if rect.has_point(local_pos):
			return view
	return null


func _clear_cards() -> void:
	for view in _card_views:
		if view != null and is_instance_valid(view):
			view.queue_free()
	_card_views.clear()
	_selected_view = null
	_dragging = false
	_dragged_view = null
