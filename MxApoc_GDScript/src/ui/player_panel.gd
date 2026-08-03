class_name PlayerPanel
extends Control

## 玩家面板组件。
## 渲染 A-K 元素（座位号/角色牌/标记/HP/潜行/饥饿/行动/怪物区/装备区/手牌数）。
## 两种布局：is_self=true 使用底部大面板，is_self=false 使用顶部队友面板。
## 位置规则：底部大面板（y=560）显示当前回合玩家；顶部小面板（y=20/200/380）显示其他玩家。

signal monster_zone_clicked(player: Variant)
signal equipment_zone_clicked(player: Variant)
signal hand_clicked(player: Variant)

const SEAT_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.25, 1.0),
	Color(0.25, 0.45, 0.85, 1.0),
	Color(0.25, 0.75, 0.35, 1.0),
	Color(0.9, 0.8, 0.25, 1.0),
]
const GOLD_BORDER := Color(1.0, 0.84, 0.0, 1.0)
const CURRENT_TURN_BORDER_WIDTH := 3

# 布局配置：is_self → {element_key → Rect2(position, size)}
const SELF_LAYOUT: Dictionary = {
	"A": Rect2(40, 560, 30, 30),
	"B": Rect2(40, 560, 120, 180),
	"C": Rect2(50, 680, 100, 50),
	"D": Rect2(160, 560, 60, 30),
	"E": Rect2(160, 590, 60, 30),
	"F": Rect2(160, 620, 60, 30),
	"G": Rect2(160, 650, 60, 30),
	"H": Rect2(160, 680, 60, 60),
	"I": Rect2(220, 560, 60, 60),
	"J": Rect2(220, 620, 60, 60),
	"K": Rect2(220, 680, 60, 60),
}
const TEAMMATE_LAYOUT: Dictionary = {
	"A": Rect2(20, 20, 20, 20),
	"B": Rect2(20, 20, 100, 150),
	"C": Rect2(30, 120, 80, 40),
	"D": Rect2(120, 20, 50, 25),
	"E": Rect2(120, 45, 50, 25),
	"F": Rect2(120, 70, 50, 25),
	"G": Rect2(120, 95, 50, 25),
	"H": Rect2(120, 120, 50, 50),
	"I": Rect2(170, 20, 50, 50),
	"J": Rect2(170, 70, 50, 50),
	"K": Rect2(170, 120, 50, 50),
}

var _player: Variant = null
var _is_self: bool = false
var _is_current_turn: bool = false
var _layout: Dictionary = {}
var _y_offset: int = 0  # 队友面板的 y 偏移（队友2=180, 队友3=360）

# 元素节点引用
var _seat_label: Label
var _role_card_panel: Panel
var _role_card_texture: TextureRect
var _role_name_label: Label
var _role_state_label: Label
var _marks_label: Label
var _hp_label: Label
var _sneak_label: Label
var _hunger_label: Label
var _action_label: Label
var _monster_button: Button
var _equipment_button: Button
var _hand_button: Button
var _border: Panel


func _ready() -> void:
	_build_layout()


## 设置面板索引（0=self, 1=队友1, 2=队友2, 3=队友3），计算 y 偏移。
func set_panel_index(idx: int) -> void:
	var new_offset: int = 0
	if idx >= 2:
		new_offset = (idx - 1) * 180
	if new_offset != _y_offset:
		_y_offset = new_offset
		if is_inside_tree():
			_build_layout()
			refresh(false)


## 设置面板显示的玩家。若 is_self 变化则重建布局。
func set_player(player: Variant, is_self: bool) -> void:
	var need_rebuild: bool = (is_self != _is_self)
	_player = player
	_is_self = is_self
	if need_rebuild:
		_layout = SELF_LAYOUT if is_self else TEAMMATE_LAYOUT
		if is_inside_tree():
			_build_layout()
	refresh(false)


## 设置当前回合高亮。
func set_current_turn(is_current: bool) -> void:
	_is_current_turn = is_current
	_apply_border()
	if _action_label != null:
		_action_label.visible = is_current


## 刷新所有元素的数据。
func refresh(show_current_highlight: bool = true) -> void:
	if _player == null or not is_instance_valid(_player):
		_set_visible(false)
		return
	_set_visible(true)
	if show_current_highlight:
		var current: Variant = Game.get_current_player()
		_is_current_turn = (current != null and is_instance_valid(current) and current == _player)
	_apply_border()
	_update_seat()
	_update_role_card()
	_update_marks()
	_update_hp()
	_update_sneak()
	_update_hunger()
	_update_action()
	_update_monster_zone()
	_update_equipment_zone()
	_update_hand()


func _set_visible(v: bool) -> void:
	for child in get_children():
		child.visible = v


# === 布局构建 ===

func _build_layout() -> void:
	_clear_children()
	_layout = SELF_LAYOUT if _is_self else TEAMMATE_LAYOUT
	# 边框（围绕内容区域）
	var content_rect: Rect2 = _compute_content_rect()
	_border = Panel.new()
	_border.position = Vector2(content_rect.position.x, content_rect.position.y + _y_offset)
	_border.size = content_rect.size
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_border)
	# A: 座位号
	_seat_label = _make_label(_layout["A"], 14)
	_seat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_seat_label)
	# B: 角色牌
	_role_card_panel = _make_panel(_layout["B"])
	add_child(_role_card_panel)
	_role_card_texture = TextureRect.new()
	_role_card_texture.set_anchors_preset(PRESET_FULL_RECT)
	_role_card_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_role_card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_role_card_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_role_card_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_role_card_panel.add_child(_role_card_texture)
	_role_name_label = Label.new()
	_role_name_label.set_anchors_preset(PRESET_FULL_RECT)
	_role_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_role_name_label.add_theme_font_size_override("font_size", 12)
	_role_name_label.offset_left = 4
	_role_name_label.offset_top = 4
	_role_name_label.offset_right = -4
	_role_name_label.offset_bottom = -4
	_role_card_panel.add_child(_role_name_label)
	_role_state_label = Label.new()
	_role_state_label.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_role_state_label.position = Vector2(0, -16)
	_role_state_label.size = Vector2(_layout["B"].size.x, 14)
	_role_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_state_label.add_theme_font_size_override("font_size", 10)
	_role_card_panel.add_child(_role_state_label)
	# C: 标记区
	_marks_label = _make_label(_layout["C"], 10)
	_marks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_marks_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_marks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_marks_label)
	# D/E/F/G: HP/潜行/饥饿/行动
	_hp_label = _make_label(_layout["D"], 12)
	add_child(_hp_label)
	_sneak_label = _make_label(_layout["E"], 12)
	add_child(_sneak_label)
	_hunger_label = _make_label(_layout["F"], 12)
	add_child(_hunger_label)
	_action_label = _make_label(_layout["G"], 12)
	_action_label.visible = false
	add_child(_action_label)
	# H: 空（仅装饰）
	var h_panel: Panel = _make_panel(_layout["H"])
	add_child(h_panel)
	# I: 怪物区按钮
	_monster_button = _make_button(_layout["I"], "×0")
	_monster_button.pressed.connect(_on_monster_clicked)
	add_child(_monster_button)
	# J: 装备区按钮
	_equipment_button = _make_button(_layout["J"], "×0")
	_equipment_button.pressed.connect(_on_equipment_clicked)
	add_child(_equipment_button)
	# K: 手牌数按钮
	_hand_button = _make_button(_layout["K"], "×0")
	_hand_button.pressed.connect(_on_hand_clicked)
	add_child(_hand_button)
	_apply_border()


# === 数据更新 ===

func _update_seat() -> void:
	if _player == null:
		return
	var seat: int = _player.get("seat_number")
	_seat_label.text = str(seat + 1)
	var color_idx: int = seat % SEAT_COLORS.size()
	_seat_label.add_theme_stylebox_override("normal", _make_fill_style(SEAT_COLORS[color_idx]))


func _update_role_card() -> void:
	if _player == null:
		return
	var role: Variant = _player.get("role_card")
	var name_str: String = ""
	var state_str: String = ""
	var is_front: bool = true
	if role != null and is_instance_valid(role):
		name_str = role.get("role_name")
		is_front = role.get("is_front_side")
		state_str = "饥饿" if not is_front else "正常"
	if not _player.is_alive():
		state_str = "已死亡"
		name_str = _player.get("player_name") if name_str.is_empty() else name_str
	# 尝试加载角色牌图片
	var tex: Texture2D = null
	if role != null and is_instance_valid(role):
		var eng: String = role.get("english_name")
		if not eng.is_empty():
			tex = ImageCache.get_role_card_texture(eng, is_front)
	if tex != null:
		_role_card_texture.texture = tex
		_role_card_texture.modulate = Color(0.5, 0.5, 0.5, 0.7) if not _player.is_alive() else Color(1, 1, 1, 1)
		_role_name_label.visible = false
	else:
		_role_card_texture.texture = null
		_role_name_label.text = name_str
		_role_name_label.visible = true
	_role_state_label.text = state_str
	# 背景色（图片存在时作为底色，不存在时作为主色）
	var bg: Color = Color(0.20, 0.22, 0.26, 1.0)
	if not _player.is_alive():
		bg = Color(0.3, 0.15, 0.15, 0.9)
	elif role != null and is_instance_valid(role) and not is_front:
		bg = Color(0.35, 0.25, 0.15, 1.0)
	_role_card_panel.add_theme_stylebox_override("panel", _make_fill_style(bg))


func _update_marks() -> void:
	if _player == null:
		return
	var marks_dict: Dictionary = _player.get("marks")
	if marks_dict.is_empty():
		_marks_label.text = "无标记"
		return
	var parts: PackedStringArray = []
	for key in marks_dict:
		parts.append("%s:%d" % [key, marks_dict[key]])
	_marks_label.text = ", ".join(parts)


func _update_hp() -> void:
	if _player == null:
		return
	_hp_label.text = "%d/%d" % [_player.get("hp"), _player.get("max_hp")]


func _update_sneak() -> void:
	if _player == null:
		return
	_sneak_label.text = "潜行 %d" % _player.get_sneak()


func _update_hunger() -> void:
	if _player == null:
		return
	_hunger_label.text = "饥饿 %d/6" % _player.get("hunger")


func _update_action() -> void:
	if _player == null:
		return
	if _is_current_turn:
		_action_label.text = "行动 %d/%d" % [_player.get("action_count"), _player.get("max_action_count")]
		_action_label.visible = true
	else:
		_action_label.visible = false


func _update_monster_zone() -> void:
	if _player == null:
		return
	var zone: Array = _player.get("monster_zone")
	_monster_button.text = "怪物 ×%d" % zone.size()


func _update_equipment_zone() -> void:
	if _player == null:
		return
	var zone: Array = _player.get("equipment_zone")
	var total_size: int = 0
	for e in zone:
		if e != null and is_instance_valid(e):
			total_size += e.get("size")
	_equipment_button.text = "装备 ×%d" % total_size


func _update_hand() -> void:
	if _player == null:
		return
	var hand: Array = _player.get("hand")
	_hand_button.text = "手牌 ×%d" % hand.size()
	# K 按钮仅自己可点击
	_hand_button.disabled = not _is_self


func _apply_border() -> void:
	if _border == null:
		return
	if _is_current_turn:
		_border.add_theme_stylebox_override("panel", _make_border_style(GOLD_BORDER, CURRENT_TURN_BORDER_WIDTH))
	else:
		_border.add_theme_stylebox_override("panel", _make_border_style(Color(0.15, 0.15, 0.15, 1.0), 1))


# === 点击处理 ===

func _on_monster_clicked() -> void:
	monster_zone_clicked.emit(_player)


func _on_equipment_clicked() -> void:
	equipment_zone_clicked.emit(_player)


func _on_hand_clicked() -> void:
	if _is_self:
		hand_clicked.emit(_player)


# === 工具方法 ===

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()


func _make_label(rect: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.position = Vector2(rect.position.x, rect.position.y + _y_offset)
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_panel(rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = Vector2(rect.position.x, rect.position.y + _y_offset)
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _make_fill_style(Color(0.20, 0.22, 0.26, 1.0)))
	return panel


func _make_button(rect: Rect2, text: String) -> Button:
	var btn := Button.new()
	btn.position = Vector2(rect.position.x, rect.position.y + _y_offset)
	btn.size = rect.size
	btn.text = text
	btn.add_theme_font_size_override("font_size", 11)
	return btn


## 计算所有元素的包围盒（用于边框定位）
func _compute_content_rect() -> Rect2:
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	for key in _layout:
		var r: Rect2 = _layout[key]
		min_x = min(min_x, r.position.x)
		min_y = min(min_y, r.position.y)
		max_x = max(max_x, r.position.x + r.size.x)
		max_y = max(max_y, r.position.y + r.size.y)
	if min_x == INF:
		return Rect2(0, 0, 0, 0)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


func _make_fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.15, 0.15, 0.15, 1.0)
	return style


func _make_border_style(border_color: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.border_color = border_color
	return style
