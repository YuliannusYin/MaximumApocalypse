class_name CardSettlementArea
extends Control

## 卡牌结算区。
## 默认隐藏，玩家拖拽手牌时显示。松开鼠标在结算区内 = 使用卡牌，松开在结算区外 = 取消。

const AREA_X := 400
const AREA_Y := 190
const AREA_W := 600
const AREA_H := 400
const HIGHLIGHT_COLOR := Color(0.4, 0.5, 0.2, 0.6)
const DEFAULT_COLOR := Color(0.2, 0.22, 0.26, 0.85)

signal card_dropped(card: Variant)
signal drag_cancelled()

var _bg: Panel
var _label: Label
var _is_drag_over: bool = false


func _ready() -> void:
	position = Vector2(AREA_X, AREA_Y)
	size = Vector2(AREA_W, AREA_H)
	visible = false
	_build_content()


func _init() -> void:
	custom_minimum_size = Vector2(AREA_W, AREA_H)


## 显示结算区（拖拽开始时调用）。
func show_area(card: Variant) -> void:
	visible = true
	_is_drag_over = false
	_apply_style()
	if card != null and is_instance_valid(card):
		_label.text = "将卡牌拖到此处松开以使用：\n" + card.get("card_name")
	else:
		_label.text = "将卡牌拖到此处松开以使用"


## 隐藏结算区。
func hide_area() -> void:
	visible = false


## 设置鼠标是否悬停在结算区上（高亮反馈）。
func set_drag_over(over: bool) -> void:
	_is_drag_over = over
	_apply_style()


## 判断屏幕坐标是否在结算区内。
func is_point_inside(screen_pos: Vector2) -> bool:
	var local_pos: Vector2 = screen_pos - Vector2(AREA_X, AREA_Y)
	return local_pos.x >= 0 and local_pos.x < AREA_W and local_pos.y >= 0 and local_pos.y < AREA_H


func _build_content() -> void:
	_bg = Panel.new()
	_bg.set_anchors_preset(PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_label = Label.new()
	_label.set_anchors_preset(PRESET_CENTER)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.text = ""
	_bg.add_child(_label)
	_apply_style()


func _apply_style() -> void:
	if _bg == null:
		return
	var style := StyleBoxFlat.new()
	if _is_drag_over:
		style.bg_color = HIGHLIGHT_COLOR
	else:
		style.bg_color = DEFAULT_COLOR
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.5, 0.5, 1.0) if _is_drag_over else Color(0.3, 0.3, 0.3, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_bg.add_theme_stylebox_override("panel", style)
