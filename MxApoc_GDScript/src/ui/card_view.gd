class_name CardView
extends Panel

## 卡牌视图组件。
## 图片优先显示：有图片时显示图片+牌名(中下)+距离(名字下)+左上角标识；无图片时退回纯文字布局。
## 交互（悬停/点击/双击/拖拽）由父容器 HandDisplayArea 处理。

const CARD_W := 100
const CARD_H := 140
const PANEL_W := 110
const PANEL_H := 150
const BORDER := 5
const SELECTED_OFFSET := 15.0
const SELECTED_BORDER_COLOR := Color(1.0, 0.84, 0.0, 1.0)
const SELECTED_BORDER_WIDTH := 3
# 悬停上浮参数（仅手牌区实例通过 set_hover_lift_enabled 启用）
const HOVER_LIFT := 12.0  # 上浮像素
const HOVER_SCALE := Vector2(1.08, 1.08)  # 放大倍数
const HOVER_Z_INDEX := 10  # 悬停层级（高于选中态的 1）
const HOVER_DURATION := 0.12  # 悬停动画时长（秒）

# 距离中文映射（仅 short/medium/long 显示，none/infinity/空不显示）
const RANGE_MAP: Dictionary = {
	"short": "短距离",
	"medium": "中距离",
	"long": "长距离",
}

# 距离标签颜色（键与 RANGE_MAP 对应）
const RANGE_COLORS: Dictionary = {
	"short": Color(1.0, 0.55, 0.0),
	"medium": Color(1.0, 0.85, 0.0),
	"long": Color(0.0, 0.85, 0.7),
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
var _content_panel: Panel
var _base_position: Vector2 = Vector2.ZERO
var _is_selected: bool = false
var _is_hovered: bool = false
var _zone_label: Label
var _charge_label: Label
var _hover_lift_enabled: bool = false
var _hover_tween: Tween = null
var _move_tween: Tween = null


func _ready() -> void:
	custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	size = Vector2(PANEL_W, PANEL_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_content()
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _content_panel != null and is_instance_valid(_content_panel):
		for child in _content_panel.get_children():
			if child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _init() -> void:
	custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	size = Vector2(PANEL_W, PANEL_H)


## 设置卡牌数据并刷新显示。
func set_card(card: Variant) -> void:
	_card = card
	if is_inside_tree():
		_refresh()


## 设置基础位置并直接落位（含选中偏移）。仅供全量重建路径使用（直接落位无动画）。
func set_base_position(pos: Vector2) -> void:
	_base_position = pos
	if _hover_lift_enabled:
		# 基点变化：终止残留的悬停动画并复位视觉，避免与外部重排 Tween 冲突
		_kill_hover_tween()
		_is_hovered = false
		scale = Vector2.ONE
		z_index = 1 if _is_selected else 0
	if _is_selected:
		position = pos + Vector2(0, -SELECTED_OFFSET)
	else:
		position = pos


## 仅更新基础位置数据并复位悬停视觉残留，不直接写 position。
## 供差量刷新路径使用：位置变化由 move_to 统一通道平滑完成。
func update_base_position(pos: Vector2) -> void:
	_base_position = pos
	if _hover_lift_enabled:
		# 复位悬停视觉残留，避免旧 hover 状态与后续重排动画冲突
		_kill_hover_tween()
		_is_hovered = false
		scale = Vector2.ONE
		z_index = 1 if _is_selected else 0


## 返回基础位置。
func get_base_position() -> Vector2:
	return _base_position


func get_card() -> Variant:
	return _card


## 选中状态（金色边框 + z_index 提升 + 平滑上浮/回落，仅启用上浮的实例有位移）。
func set_selected(selected: bool) -> void:
	_is_selected = selected
	if _hover_lift_enabled:
		# 终止悬停上浮动画，z_index 与位置由选中态接管
		_kill_hover_tween()
	if selected:
		z_index = 1
		# 选中平滑上浮；未启用上浮的实例（弹窗等）保持原行为：仅金边与 z_index，无位移
		if _hover_lift_enabled:
			move_to(_base_position + Vector2(0, -SELECTED_OFFSET), 0.15)
	else:
		z_index = 0
		if _hover_lift_enabled:
			move_to(_base_position, 0.15)
	_apply_style()


func is_selected() -> bool:
	return _is_selected


## 启用悬停上浮（仅手牌区实例启用；弹窗等其他使用方默认关闭，行为不变）。
func set_hover_lift_enabled(enabled: bool) -> void:
	_hover_lift_enabled = enabled
	if not enabled:
		_kill_hover_tween()
		_kill_move_tween()


## 悬停状态：启用上浮的实例在非选中时平滑上浮放大，移开平滑复位；选中态优先。
func set_hovered(hovered: bool) -> void:
	if hovered == _is_hovered:
		return  # 状态未变，避免重复重建 Tween 导致动画抖动
	_is_hovered = hovered
	if not _hover_lift_enabled:
		return
	_kill_hover_tween()
	# 选中态优先：选中中的卡不上浮，复位时也仅复位缩放（位置/z_index 由选中逻辑管理）
	if hovered and _is_selected:
		return
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.set_parallel(true)
	if hovered:
		# 位置动画走统一通道 move_to，与 _hover_tween 的 scale/z_index 并行但不冲突
		move_to(_base_position + Vector2(0, -HOVER_LIFT), HOVER_DURATION)
		_hover_tween.tween_property(self, "scale", HOVER_SCALE, HOVER_DURATION)
		_hover_tween.tween_property(self, "z_index", HOVER_Z_INDEX, HOVER_DURATION)
	else:
		_hover_tween.tween_property(self, "scale", Vector2.ONE, HOVER_DURATION)
		if not _is_selected:
			move_to(_base_position, HOVER_DURATION)
			_hover_tween.tween_property(self, "z_index", 0, HOVER_DURATION)


## 终止悬停动画（若在运行）。
func _kill_hover_tween() -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = null


## 位置动画统一通道：终止旧位置动画后从当前位置平滑移动到 target。
## 所有 position 变化（重排/滑入/选中上浮回落/hover 上浮复位）均经此入口，
## 确保同一时刻至多一个位置动画，杜绝并行 Tween 互相覆盖。
func move_to(target: Vector2, duration: float = 0.2) -> void:
	_kill_move_tween()
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "position", target, duration)
	_move_tween.finished.connect(func() -> void: _move_tween = null)


## 终止位置动画（若在运行）。
func _kill_move_tween() -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null


## 设置区域标签文本（如"装备区"、"手牌区"）。空文本时隐藏。
func set_zone_label(text: String) -> void:
	if _zone_label != null and is_instance_valid(_zone_label):
		if text.is_empty():
			_zone_label.visible = false
		else:
			_zone_label.text = text
			_zone_label.visible = true


# === 构建 ===

func _build_content() -> void:
	_content_panel = Panel.new()
	_content_panel.position = Vector2(BORDER, BORDER)
	_content_panel.size = Vector2(CARD_W, CARD_H)
	_content_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content_panel)
	# 图片背景
	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_preset(PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_texture_rect.visible = false
	_content_panel.add_child(_texture_rect)
	# 左上角标识（装备牌格子数 / 行动牌金色"行动"）
	_badge_label = Label.new()
	_badge_label.position = Vector2(4, 4)
	_badge_label.size = Vector2(48, 16)
	_badge_label.add_theme_font_size_override("font_size", 11)
	_badge_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_badge_label.add_theme_constant_override("outline_size", 3)
	_badge_label.visible = false
	_content_panel.add_child(_badge_label)
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
	_content_panel.add_child(_name_label)
	# 距离（名字下方；图片模式在牌名下，文字模式在牌名正下方）
	_range_label = Label.new()
	_range_label.position = Vector2(4, CARD_H - 32)
	_range_label.size = Vector2(CARD_W - 8, 18)
	_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range_label.add_theme_font_size_override("font_size", 11)
	_range_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_range_label.add_theme_constant_override("outline_size", 3)
	_range_label.visible = false
	_content_panel.add_child(_range_label)
	# 卡牌类型（文字模式）
	_type_label = Label.new()
	_type_label.position = Vector2(4, 42)
	_type_label.size = Vector2(CARD_W - 8, 16)
	_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_label.add_theme_font_size_override("font_size", 10)
	_content_panel.add_child(_type_label)
	# 消耗（文字模式）
	_cost_label = Label.new()
	_cost_label.position = Vector2(4, 60)
	_cost_label.size = Vector2(CARD_W - 8, 16)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override("font_size", 10)
	_content_panel.add_child(_cost_label)
	# 效果简述（文字模式，底部）
	_effect_label = Label.new()
	_effect_label.position = Vector2(4, 78)
	_effect_label.size = Vector2(CARD_W - 8, CARD_H - 82)
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_effect_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_effect_label.add_theme_font_size_override("font_size", 9)
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_panel.add_child(_effect_label)
	# 区域标签（左下角，混合区域时显示）
	_zone_label = Label.new()
	_zone_label.position = Vector2(2, CARD_H - 12)
	_zone_label.size = Vector2(44, 12)
	_zone_label.add_theme_font_size_override("font_size", 9)
	_zone_label.add_theme_color_override("font_color", Color.WHITE)
	_zone_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_zone_label.add_theme_constant_override("outline_size", 3)
	_zone_label.visible = false
	_content_panel.add_child(_zone_label)
	# 填充物信息（右上角，装备牌有 charge_max > 0 时显示）
	_charge_label = Label.new()
	_charge_label.position = Vector2(CARD_W - 50, 4)
	_charge_label.size = Vector2(46, 16)
	_charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_charge_label.add_theme_font_size_override("font_size", 11)
	_charge_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3, 1.0))
	_charge_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_charge_label.add_theme_constant_override("outline_size", 3)
	_charge_label.visible = false
	_content_panel.add_child(_charge_label)
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
		if _zone_label != null and is_instance_valid(_zone_label):
			_zone_label.visible = false
		if _charge_label != null and is_instance_valid(_charge_label):
			_charge_label.visible = false
		_apply_style()
		return
	var card_name: String = _card.get("card_name")
	var tex: Texture2D = ImageCache.get_card_texture(card_name)
	if tex != null:
		_apply_image_layout(tex)
	else:
		_apply_text_layout()
	_apply_style()


## 图片布局：图片背景 + 牌名(中下) + 距离(名字下) + 左上角标识。
func _apply_image_layout(tex: Texture2D) -> void:
	_texture_rect.texture = tex
	_texture_rect.visible = true
	# 牌名移到中下
	_name_label.text = _card.get("card_name")
	_name_label.position = Vector2(4, CARD_H - 58)
	_name_label.size = Vector2(CARD_W - 8, 26)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 12)
	# 距离（仅 short/medium/long 显示；每次显示前重设颜色与位置，防止复用残留）
	var range_str := _safe_string(_card.get("range"))
	if RANGE_MAP.has(range_str):
		_range_label.text = RANGE_MAP[range_str]
		_range_label.add_theme_color_override("font_color", RANGE_COLORS[range_str])
		_range_label.position = Vector2(4, CARD_H - 32)
		_range_label.size = Vector2(CARD_W - 8, 18)
		_range_label.visible = true
	else:
		_range_label.visible = false
	# 左上角标识
	_apply_badge()
	# 隐藏文字模式标签
	_type_label.visible = false
	_cost_label.visible = false
	_effect_label.visible = false
	_apply_charge_display()


## 文字布局：纯文字显示；有距离时在牌名正下方显示距离并下移类型/消耗/效果标签。
func _apply_text_layout() -> void:
	_texture_rect.visible = false
	_badge_label.visible = false
	_name_label.text = _card.get("card_name")
	_name_label.position = Vector2(4, 4)
	_name_label.size = Vector2(CARD_W - 8, 36)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 12)
	# 距离（仅 short/medium/long 显示；有距离时下移类型/消耗/效果避免重叠）
	var range_str := _safe_string(_card.get("range"))
	if RANGE_MAP.has(range_str):
		_range_label.text = RANGE_MAP[range_str]
		_range_label.add_theme_color_override("font_color", RANGE_COLORS[range_str])
		_range_label.position = Vector2(4, 40)
		_range_label.size = Vector2(CARD_W - 8, 16)
		_range_label.visible = true
		_type_label.position = Vector2(4, 56)
		_cost_label.position = Vector2(4, 74)
		_effect_label.position = Vector2(4, 92)
		_effect_label.size = Vector2(CARD_W - 8, CARD_H - 96)
	else:
		_range_label.visible = false
		_type_label.position = Vector2(4, 42)
		_cost_label.position = Vector2(4, 60)
		_effect_label.position = Vector2(4, 78)
		_effect_label.size = Vector2(CARD_W - 8, CARD_H - 82)
	var ctype: String = _card.get("card_type")
	_type_label.text = _type_display(ctype)
	_type_label.visible = true
	_cost_label.text = _cost_display()
	_cost_label.visible = true
	_effect_label.text = _effect_display()
	_effect_label.visible = true
	_apply_charge_display()


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


## 显示填充物信息（右上角）：charge_max > 0 时显示"cur/max"。
func _apply_charge_display() -> void:
	if _charge_label == null or not is_instance_valid(_charge_label):
		return
	if _card == null or not is_instance_valid(_card):
		_charge_label.visible = false
		return
	var charge_max_val: Variant = _card.get("charge_max")
	if charge_max_val is int and charge_max_val > 0:
		var charge_cur_val: Variant = _card.get("charge_current")
		var cur: int = charge_cur_val if charge_cur_val is int else 0
		_charge_label.text = "%d/%d" % [cur, charge_max_val]
		_charge_label.visible = true
	else:
		_charge_label.visible = false


func _apply_style() -> void:
	# 外层面板：黑色背景 + 选中时金色边框
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = Color.BLACK
	if _is_selected:
		outer_style.border_width_left = SELECTED_BORDER_WIDTH
		outer_style.border_width_top = SELECTED_BORDER_WIDTH
		outer_style.border_width_right = SELECTED_BORDER_WIDTH
		outer_style.border_width_bottom = SELECTED_BORDER_WIDTH
		outer_style.border_color = SELECTED_BORDER_COLOR
	add_theme_stylebox_override("panel", outer_style)
	# 内层面板：卡牌类型背景色
	var bg: Color = Color(0.30, 0.30, 0.34, 1.0)
	if _card != null and is_instance_valid(_card):
		var ctype: String = _card.get("card_type")
		bg = TYPE_COLORS.get(ctype, Color(0.30, 0.30, 0.34, 1.0))
	if _content_panel != null and is_instance_valid(_content_panel):
		var inner_style := StyleBoxFlat.new()
		inner_style.bg_color = bg
		_content_panel.add_theme_stylebox_override("panel", inner_style)


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
