class_name CardView
extends Panel

## 卡牌视图组件。
## 图片优先显示：有图片时显示图片+牌名(中下)+射程(名字下)+左上角标识；无图片时退回纯文字布局。
## 交互（悬停/点击/双击/拖拽）由父容器 HandDisplayArea 处理。

const CARD_W := 100
const CARD_H := 140
const SELECTED_OFFSET := 20.0
const SELECTED_BORDER_COLOR := Color(1.0, 0.84, 0.0, 1.0)
const SELECTED_BORDER_WIDTH := 3

# 射程中文映射（none 不显示）
const RANGE_MAP: Dictionary = {
	"short": "短程",
	"medium": "中程",
	"long": "远程",
	"infinity": "无限",
}

# 卡牌类型背景色（无图片时使用）
const TYPE_COLORS: Dictionary = {
	"action": Color(0.30, 0.45, 0.65, 1.0),
	"equipment": Color(0.30, 0.55, 0.35, 1.0),
	"consumable": Color(0.55, 0.50, 0.25, 1.0),
	"food": Color(0.55, 0.50, 0.25, 1.0),
	"monster": Color(0.55, 0.25, 0.25, 1.0),
	"scavenge": Color(0.40, 0.40, 0.45, 1.0),
}

var _card: Variant = null
var _texture_rect: TextureRect
var _badge_label: Label
var _name_label: Label
var _range_label: Label
var _type_label: Label
var _cost_label: Label
var _effect_label: Label
var _base_position: Vector2 = Vector2.ZERO
var _is_selected: bool = false
var _is_hovered: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = Vector2(CARD_W, CARD_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_content()
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _init() -> void:
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = Vector2(CARD_W, CARD_H)


## 设置卡牌数据并刷新显示。
func set_card(card: Variant) -> void:
	_card = card
	if is_inside_tree():
		_refresh()


## 设置基础位置（在手牌区中的排列位置）。
func set_base_position(pos: Vector2) -> void:
	_base_position = pos
	if _is_selected:
		position = pos + Vector2(0, -SELECTED_OFFSET)
	else:
		position = pos


## 返回基础位置。
func get_base_position() -> Vector2:
	return _base_position


func get_card() -> Variant:
	return _card


## 选中状态（上移 20px + 金色边框 + z_index 提升）。
func set_selected(selected: bool) -> void:
	_is_selected = selected
	if selected:
		position = _base_position + Vector2(0, -SELECTED_OFFSET)
		z_index = 1
	else:
		position = _base_position
		z_index = 0
	_apply_style()


func is_selected() -> bool:
	return _is_selected


## 悬停状态（仅记录标志，不上移位置；上移效果专用于选中状态）。
func set_hovered(hovered: bool) -> void:
	_is_hovered = hovered
	# 悬停不再触发上浮，位置由选中状态决定


# === 构建 ===

func _build_content() -> void:
	# 图片背景
	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_preset(PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_texture_rect.visible = false
	add_child(_texture_rect)
	# 左上角标识（装备牌格子数 / 行动牌金色"行动"）
	_badge_label = Label.new()
	_badge_label.position = Vector2(4, 4)
	_badge_label.size = Vector2(48, 16)
	_badge_label.add_theme_font_size_override("font_size", 11)
	_badge_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_badge_label.add_theme_constant_override("outline_size", 3)
	_badge_label.visible = false
	add_child(_badge_label)
	# 牌名（图片模式在中下，文字模式在顶部）
	_name_label = Label.new()
	_name_label.position = Vector2(4, 4)
	_name_label.size = Vector2(CARD_W - 8, 36)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 3)
	add_child(_name_label)
	# 射程（图片模式，名字下方）
	_range_label = Label.new()
	_range_label.position = Vector2(4, CARD_H - 32)
	_range_label.size = Vector2(CARD_W - 8, 18)
	_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range_label.add_theme_font_size_override("font_size", 11)
	_range_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_range_label.add_theme_constant_override("outline_size", 3)
	_range_label.visible = false
	add_child(_range_label)
	# 卡牌类型（文字模式）
	_type_label = Label.new()
	_type_label.position = Vector2(4, 42)
	_type_label.size = Vector2(CARD_W - 8, 16)
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_label.add_theme_font_size_override("font_size", 10)
	add_child(_type_label)
	# 消耗（文字模式）
	_cost_label = Label.new()
	_cost_label.position = Vector2(4, 60)
	_cost_label.size = Vector2(CARD_W - 8, 16)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override("font_size", 10)
	add_child(_cost_label)
	# 效果简述（文字模式，底部）
	_effect_label = Label.new()
	_effect_label.position = Vector2(4, 78)
	_effect_label.size = Vector2(CARD_W - 8, CARD_H - 82)
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_effect_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_effect_label.add_theme_font_size_override("font_size", 9)
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_effect_label)
	_refresh()


func _refresh() -> void:
	if _card == null or not is_instance_valid(_card):
		_name_label.text = ""
		_type_label.text = ""
		_cost_label.text = ""
		_effect_label.text = ""
		_texture_rect.visible = false
		_badge_label.visible = false
		_range_label.visible = false
		_apply_style()
		return
	var card_name: String = _card.get("card_name")
	var tex: Texture2D = ImageCache.get_card_texture(card_name)
	if tex != null:
		_apply_image_layout(tex)
	else:
		_apply_text_layout()
	_apply_style()


## 图片布局：图片背景 + 牌名(中下) + 射程(名字下) + 左上角标识。
func _apply_image_layout(tex: Texture2D) -> void:
	_texture_rect.texture = tex
	_texture_rect.visible = true
	# 牌名移到中下
	_name_label.text = _card.get("card_name")
	_name_label.position = Vector2(4, CARD_H - 52)
	_name_label.size = Vector2(CARD_W - 8, 20)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 11)
	# 射程（仅 range≠"none" 且非空时显示）
	var range_str := _safe_string(_card.get("range"))
	if not range_str.is_empty() and range_str != "none":
		_range_label.text = "射程 " + RANGE_MAP.get(range_str, range_str)
		_range_label.visible = true
	else:
		_range_label.visible = false
	# 左上角标识
	_apply_badge()
	# 隐藏文字模式标签
	_type_label.visible = false
	_cost_label.visible = false
	_effect_label.visible = false


## 文字布局：保留原有的纯文字显示。
func _apply_text_layout() -> void:
	_texture_rect.visible = false
	_badge_label.visible = false
	_range_label.visible = false
	_name_label.text = _card.get("card_name")
	_name_label.position = Vector2(4, 4)
	_name_label.size = Vector2(CARD_W - 8, 36)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 11)
	var ctype: String = _card.get("card_type")
	_type_label.text = _type_display(ctype)
	_type_label.visible = true
	_cost_label.text = _cost_display()
	_cost_label.visible = true
	_effect_label.text = _effect_display()
	_effect_label.visible = true


## 设置左上角标识：装备牌显示格子数，行动牌显示金色"行动"。
func _apply_badge() -> void:
	var subtype := _safe_string(_card.get("card_subtype"))
	if subtype == "equipment":
		var sz: int = _safe_int(_card.get("size"))
		_badge_label.text = "%d格" % sz
		_badge_label.add_theme_color_override("font_color", Color.WHITE)
		_badge_label.visible = true
	elif subtype == "action":
		_badge_label.text = "行动"
		_badge_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
		_badge_label.visible = true
	else:
		_badge_label.visible = false


func _apply_style() -> void:
	var bg: Color = Color(0.30, 0.30, 0.34, 1.0)
	if _card != null and is_instance_valid(_card):
		var ctype: String = _card.get("card_type")
		bg = TYPE_COLORS.get(ctype, Color(0.30, 0.30, 0.34, 1.0))
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	if _is_selected:
		style.border_width_left = SELECTED_BORDER_WIDTH
		style.border_width_top = SELECTED_BORDER_WIDTH
		style.border_width_right = SELECTED_BORDER_WIDTH
		style.border_width_bottom = SELECTED_BORDER_WIDTH
		style.border_color = SELECTED_BORDER_COLOR
	else:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.15, 0.15, 0.15, 1.0)
	add_theme_stylebox_override("panel", style)


func _type_display(ctype: String) -> String:
	match ctype:
		"action":
			return "行动牌"
		"equipment":
			return "装备牌"
		"consumable":
			return "消耗品"
		"food":
			return "食物"
		"monster":
			return "怪物牌"
		_:
			return ctype


func _cost_display() -> String:
	if _card == null or not is_instance_valid(_card):
		return ""
	var ctype: String = _card.get("card_type")
	if ctype == "action":
		return "消耗：1行动"
	return ""


func _effect_display() -> String:
	if _card == null or not is_instance_valid(_card):
		return ""
	var skills: Array = _card.get("skills")
	if skills.is_empty():
		return ""
	var first: Variant = skills[0]
	if first == null or not is_instance_valid(first):
		return ""
	var desc: String = first.get("skill_description")
	if desc.length() > 80:
		desc = desc.substr(0, 77) + "..."
	return desc


## 安全获取 String 字段（null → ""）。
func _safe_string(val: Variant) -> String:
	if val is String:
		return val
	return ""


## 安全获取 int 字段（null → 0）。
func _safe_int(val: Variant) -> int:
	if val is int:
		return val
	return 0
