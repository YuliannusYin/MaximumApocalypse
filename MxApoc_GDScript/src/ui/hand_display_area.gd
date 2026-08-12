class_name HandDisplayArea
extends Control

## 手牌显示区。
## 水平排列当前玩家的手牌。支持悬停上浮、单击选中。
## 选中状态由外部（game_scene_2d.gd 的确认按钮）驱动卡牌使用流程。

const AREA_X := 265
const AREA_Y := 620
const AREA_W := 900
const AREA_H := 150
const CARD_W := 110
const CARD_H := 150
const CARD_GAP := 8
const CARD_Y := 0.0  # 卡牌在手牌区内的 y 偏移（垂直居中）

signal card_selected(card: Variant)
signal card_deselected()

var _player: Variant = null
var _card_views: Array = []
var _selected_view: CardView = null
var _is_stacked: bool = false


func _ready() -> void:
	position = Vector2(AREA_X, AREA_Y)
	size = Vector2(AREA_W, AREA_H)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _init() -> void:
	custom_minimum_size = Vector2(AREA_W, AREA_H)


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
		_is_stacked = false
		return
	# 计算总宽度（含间隔）
	var total_w: float = count * CARD_W + maxi(count - 1, 0) * CARD_GAP
	if total_w <= AREA_W:
		# 正常排列，居中
		_is_stacked = false
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
	else:
		# 堆叠排列，从左开始
		_is_stacked = true
		var overlap: float = (float(count) * CARD_W - AREA_W) / float(maxi(count - 1, 1))
		var step: float = CARD_W - overlap
		for i in range(count):
			var card: Variant = hand[i]
			if card == null or not is_instance_valid(card):
				continue
			var view := CardView.new()
			add_child(view)
			view.set_card(card)
			var pos := Vector2(i * step, CARD_Y)
			view.set_base_position(pos)
			view.position = pos
			_card_views.append(view)


## 清除选中状态。
func clear_selection() -> void:
	if _selected_view != null and is_instance_valid(_selected_view):
		_selected_view.set_selected(false)
		_selected_view = null
		card_deselected.emit()


# === 鼠标交互 ===

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(event.position)
	elif event is InputEventMouseMotion:
		_update_hover(event.position)


# === 悬停/点击 ===

func _update_hover(local_pos: Vector2) -> void:
	var hovered := _find_card_at(local_pos)
	for view in _card_views:
		if view == null or not is_instance_valid(view):
			continue
		view.set_hovered(view == hovered)


func _handle_click(local_pos: Vector2) -> void:
	var view := _find_card_at(local_pos)
	if view == null:
		# Click empty space - deselect
		if _selected_view != null and is_instance_valid(_selected_view):
			_selected_view.set_selected(false)
			_selected_view = null
			card_deselected.emit()
		return
	if _selected_view == view:
		return  # Already selected
	if _selected_view != null and is_instance_valid(_selected_view):
		_selected_view.set_selected(false)
	_selected_view = view
	view.set_selected(true)
	card_selected.emit(view.get_card())


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
