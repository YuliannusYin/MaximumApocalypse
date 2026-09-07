class_name PlayerPanel
extends Control

## 玩家面板组件。
## 渲染座位号/角色卡/标记/HP/潜行/饥饿/行动/怪物区/装备区/手牌数。
## 两种布局：is_self=true 使用底部大面板，is_self=false 使用顶部队友面板。

signal monster_zone_clicked(player: Variant)
signal equipment_zone_clicked(player: Variant)
signal hand_clicked(player: Variant)

const SEAT_COLORS: Array[Color] = [
	Color(0.85, 0.25, 0.25, 1.0),
	Color(0.25, 0.45, 0.85, 1.0),
	Color(0.25, 0.75, 0.35, 1.0),
	Color(0.9, 0.8, 0.25, 1.0),
	Color(0.25, 0.78, 0.78, 1.0),
	Color(0.75, 0.35, 0.85, 1.0),
]
const GOLD_BORDER := Color(1.0, 0.8, 0.3, 1.0)
const CURRENT_TURN_BORDER_WIDTH := 3
const CHROME_BG := Color(0.08, 0.08, 0.09, 0.94)
const CARD_BG := Color(0.16, 0.14, 0.12, 1.0)
const CARD_BG_HUNGER := Color(0.32, 0.22, 0.12, 1.0)
const CARD_BG_DEAD := Color(0.28, 0.12, 0.12, 0.95)
const NAMEPLATE_BG := Color(0.04, 0.04, 0.05, 0.86)
const HP_TRACK_BG := Color(0.12, 0.07, 0.07, 1.0)
const HP_FILL := Color(0.72, 0.16, 0.16, 1.0)
const HUNGER_TRACK_BG := Color(0.14, 0.11, 0.07, 1.0)
const HUNGER_FILL := Color(0.82, 0.52, 0.16, 1.0)
const HUNGER_FILL_WARN := Color(1.0, 0.55, 0.12, 1.0)
const STAT_TRACK_BG := Color(0.12, 0.12, 0.13, 1.0)
const SLOT_BG := Color(0.13, 0.12, 0.11, 1.0)
const SLOT_BG_HOVER := Color(0.20, 0.18, 0.15, 1.0)
const SLOT_BG_PRESSED := Color(0.10, 0.09, 0.08, 1.0)
const SLOT_BORDER := Color(0.38, 0.32, 0.24, 1.0)
const TEXT_MAIN := Color(0.92, 0.90, 0.84, 1.0)
const TEXT_DIM := Color(0.62, 0.60, 0.55, 1.0)
const TEXT_WARN := Color(1.0, 0.48, 0.22, 1.0)
const TEXT_MONSTER := Color(0.95, 0.42, 0.36, 1.0)
const DEAD_BORDER := Color(0.45, 0.16, 0.16, 1.0)

# 自己：立绘 120 + 属性列 60，右缘 300（手牌区从 315 起）；高 220，贴 y=560
const SELF_LAYOUT: Dictionary = {
	"A": Rect2(120, 560, 22, 22),
	"B": Rect2(120, 560, 120, 220),
	"D": Rect2(240, 560, 60, 32),
	"F": Rect2(240, 594, 60, 32),
	"E": Rect2(240, 628, 60, 24),
	"G": Rect2(240, 654, 60, 24),
	"I": Rect2(240, 682, 60, 32),
	"J": Rect2(240, 716, 60, 32),
	"K": Rect2(240, 750, 60, 30),
}
# 队友：立绘 100 + 属性列 50；set_panel_index 以 165 步进
const TEAMMATE_LAYOUT: Dictionary = {
	"A": Rect2(10, 10, 18, 18),
	"B": Rect2(10, 10, 100, 175),
	"D": Rect2(110, 10, 50, 26),
	"F": Rect2(110, 38, 50, 26),
	"E": Rect2(110, 66, 50, 20),
	"G": Rect2(110, 88, 50, 20),
	"I": Rect2(110, 110, 50, 24),
	"J": Rect2(110, 136, 50, 24),
	"K": Rect2(110, 161, 50, 24),
}

var _player: Variant = null
var _is_self: bool = false
var _is_current_turn: bool = false
var _is_operation_focus: bool = false
var _layout: Dictionary = {}
var _x_offset: int = 0  # 队友面板的 x 偏移（idx 2 起每档 +165）
var _y_offset: int = 0

# 元素节点引用
var _chrome: Panel
var _seat_label: Label
var _role_card_panel: Panel
var _role_card_texture: TextureRect
var _fallback_name_label: Label
var _nameplate: Panel
var _role_name_label: Label
var _role_state_label: Label
var _marks_label: Label
var _hp_track: Panel
var _hp_fill: ColorRect
var _hp_label: Label
var _sneak_label: Label
var _hunger_track: Panel
var _hunger_fill: ColorRect
var _hunger_label: Label
var _action_label: Label
var _monster_button: Button
var _equipment_button: Button
var _hand_button: Button
var _border: Panel

# === 反馈动画状态 ===
var _feedback_tween: Tween = null
var _breath_tween: Tween = null
var _breath_active: bool = false
var _home_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_home_position = position
	_build_layout()


## 设置面板索引（0=self, 1~5=队友），队友按 165px 横向排列。
func set_panel_index(idx: int) -> void:
	var new_x: int = 0
	if idx >= 2:
		new_x = (idx - 1) * 165
	if new_x != _x_offset or _y_offset != 0:
		_x_offset = new_x
		_y_offset = 0
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
	set_turn_highlight(is_current)
	if _action_label != null:
		_action_label.visible = is_current or _is_operation_focus


## 设置当前操作事件的焦点玩家。与正式回合高亮独立。
func set_operation_focus(is_focus: bool) -> void:
	_is_operation_focus = is_focus
	if _action_label != null:
		_action_label.visible = _is_current_turn or _is_operation_focus
		_update_action()


## 刷新所有元素的数据。
func refresh(show_current_highlight: bool = true) -> void:
	if _player == null or not is_instance_valid(_player):
		set_turn_highlight(false)
		_set_visible(false)
		return
	_set_visible(true)
	if show_current_highlight:
		var current: Variant = Game.get_current_player()
		_is_current_turn = (current != null and is_instance_valid(current) and current == _player)
		set_turn_highlight(_is_current_turn)
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
	_kill_tween(_feedback_tween)
	_kill_tween(_breath_tween)
	_breath_active = false
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	position = _home_position
	_clear_children()
	_layout = SELF_LAYOUT if _is_self else TEAMMATE_LAYOUT
	var content_rect: Rect2 = _compute_content_rect()
	var chrome_pos := Vector2(content_rect.position.x + _x_offset, content_rect.position.y + _y_offset)
	# 底衬（不参与呼吸，避免整块 HUD 被描边 modulate 带透明）
	_chrome = Panel.new()
	_chrome.position = chrome_pos
	_chrome.size = content_rect.size
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.add_theme_stylebox_override("panel", _make_chrome_style())
	add_child(_chrome)
	# 描边（透明底，仅边框；呼吸高亮只改这个节点）
	_border = Panel.new()
	_border.position = chrome_pos
	_border.size = content_rect.size
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_border)
	_build_portrait()
	# A: 座位徽章叠在立绘左上
	_seat_label = _make_label(_layout["A"], 12 if _is_self else 11)
	_seat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_seat_label.z_index = 2
	add_child(_seat_label)
	# D/F: 生命 / 饥饿条
	_hp_track = _make_bar_track(_layout["D"], HP_TRACK_BG)
	_hp_fill = _make_bar_fill(_hp_track, HP_FILL)
	_hp_label = _make_overlay_label(_hp_track, 11 if _is_self else 9)
	add_child(_hp_track)
	_hunger_track = _make_bar_track(_layout["F"], HUNGER_TRACK_BG)
	_hunger_fill = _make_bar_fill(_hunger_track, HUNGER_FILL)
	_hunger_label = _make_overlay_label(_hunger_track, 11 if _is_self else 9)
	add_child(_hunger_track)
	# E/G: 潜行 / 行动
	_sneak_label = _make_stat_chip(_layout["E"], 11 if _is_self else 9)
	add_child(_sneak_label)
	_action_label = _make_stat_chip(_layout["G"], 11 if _is_self else 9)
	_action_label.visible = false
	add_child(_action_label)
	# I/J/K: 资源槽
	var slot_font: int = 10 if _is_self else 9
	_monster_button = _make_slot_button(_layout["I"], "怪物 ×0", slot_font)
	_monster_button.pressed.connect(_on_monster_clicked)
	add_child(_monster_button)
	_equipment_button = _make_slot_button(_layout["J"], "装备 0/0", slot_font)
	_equipment_button.pressed.connect(_on_equipment_clicked)
	add_child(_equipment_button)
	_hand_button = _make_slot_button(_layout["K"], "手牌 ×0", slot_font)
	_hand_button.pressed.connect(_on_hand_clicked)
	add_child(_hand_button)
	_apply_border()
	set_turn_highlight(_is_current_turn)


func _build_portrait() -> void:
	var frame_w: int = HudTheme.FRAME_WIDTH
	_role_card_panel = _make_panel(_layout["B"])
	_role_card_panel.clip_contents = true
	add_child(_role_card_panel)
	_role_card_texture = TextureRect.new()
	_role_card_texture.set_anchors_preset(PRESET_FULL_RECT)
	_role_card_texture.offset_left = frame_w
	_role_card_texture.offset_top = frame_w
	_role_card_texture.offset_right = -frame_w
	_role_card_texture.offset_bottom = -frame_w
	_role_card_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_role_card_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_role_card_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_role_card_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_role_card_panel.add_child(_role_card_texture)
	_fallback_name_label = Label.new()
	_fallback_name_label.set_anchors_preset(PRESET_FULL_RECT)
	_fallback_name_label.offset_left = frame_w + 4
	_fallback_name_label.offset_top = frame_w + 4
	_fallback_name_label.offset_right = -(frame_w + 4)
	_fallback_name_label.offset_bottom = -(frame_w + 52)
	_fallback_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fallback_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fallback_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fallback_name_label.add_theme_font_size_override("font_size", 12 if _is_self else 10)
	_fallback_name_label.add_theme_color_override("font_color", TEXT_MAIN)
	_fallback_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_role_card_panel.add_child(_fallback_name_label)
	var plate_h: float = 52.0 if _is_self else 44.0
	_nameplate = Panel.new()
	_nameplate.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_nameplate.offset_left = frame_w
	_nameplate.offset_top = -(frame_w + plate_h)
	_nameplate.offset_right = -frame_w
	_nameplate.offset_bottom = -frame_w
	_nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nameplate.add_theme_stylebox_override("panel", _make_fill_style(NAMEPLATE_BG, 0, 0))
	_role_card_panel.add_child(_nameplate)
	var plate_inner_w: float = _layout["B"].size.x - float(HudTheme.FRAME_WIDTH) * 2.0
	_role_name_label = Label.new()
	_role_name_label.position = Vector2(4, 2)
	_role_name_label.size = Vector2(plate_inner_w - 44.0, 16 if _is_self else 14)
	_role_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_role_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_role_name_label.add_theme_font_size_override("font_size", 11 if _is_self else 9)
	_role_name_label.add_theme_color_override("font_color", TEXT_MAIN)
	_role_name_label.clip_text = true
	_role_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nameplate.add_child(_role_name_label)
	_role_state_label = Label.new()
	_role_state_label.position = Vector2(plate_inner_w - 40.0, 2)
	_role_state_label.size = Vector2(44, 16 if _is_self else 14)
	_role_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_role_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_role_state_label.add_theme_font_size_override("font_size", 9 if _is_self else 8)
	_role_state_label.add_theme_color_override("font_color", TEXT_DIM)
	_role_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nameplate.add_child(_role_state_label)
	_marks_label = Label.new()
	_marks_label.position = Vector2(4, 18 if _is_self else 16)
	_marks_label.size = Vector2(plate_inner_w - 8.0, 32 if _is_self else 26)
	_marks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_marks_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_marks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_marks_label.add_theme_font_size_override("font_size", 9 if _is_self else 8)
	_marks_label.add_theme_color_override("font_color", TEXT_DIM)
	_marks_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nameplate.add_child(_marks_label)


# === 数据更新 ===

func _update_seat() -> void:
	if _player == null:
		return
	var seat: int = _player.get("seat_number")
	_seat_label.text = str(seat + 1)
	var color_idx: int = seat % SEAT_COLORS.size()
	var seat_color: Color = SEAT_COLORS[color_idx]
	_seat_label.add_theme_stylebox_override("normal", _make_fill_style(seat_color, 1, 3))
	_seat_label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1.0))
	_seat_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.35))
	_seat_label.add_theme_constant_override("outline_size", 1)


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
		set_turn_highlight(false)
	var tex: Texture2D = null
	if role != null and is_instance_valid(role):
		var eng: String = role.get("english_name")
		if not eng.is_empty():
			tex = ImageCache.get_role_card_texture(eng, is_front)
	_role_name_label.text = name_str
	_role_state_label.text = state_str
	if not _player.is_alive():
		_role_state_label.add_theme_color_override("font_color", TEXT_MONSTER)
	elif not is_front:
		_role_state_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3, 1.0))
	else:
		_role_state_label.add_theme_color_override("font_color", TEXT_DIM)
	if tex != null:
		_role_card_texture.texture = tex
		_role_card_texture.modulate = Color(0.5, 0.5, 0.5, 0.7) if not _player.is_alive() else Color(1, 1, 1, 1)
		_fallback_name_label.visible = false
	else:
		_role_card_texture.texture = null
		_fallback_name_label.text = name_str
		_fallback_name_label.visible = true
	var bg: Color = CARD_BG
	if not _player.is_alive():
		bg = CARD_BG_DEAD
	elif role != null and is_instance_valid(role) and not is_front:
		bg = CARD_BG_HUNGER
	_role_card_panel.add_theme_stylebox_override("panel", HudTheme.make_picture_frame_style(bg))


func _update_marks() -> void:
	if _player == null:
		return
	var marks_dict: Dictionary = _player.get("marks")
	var visible_marks: Array = []
	for key in marks_dict:
		var m = marks_dict[key]
		if m.visible:
			visible_marks.append(m)
	if visible_marks.is_empty():
		_marks_label.text = "无标记"
		_marks_label.add_theme_color_override("font_color", Color(0.45, 0.44, 0.40, 1.0))
		_marks_label.tooltip_text = ""
		return
	var parts: PackedStringArray = []
	var tooltips: PackedStringArray = []
	for m in visible_marks:
		var display: String = m.get_display_text()
		if m.count > 0:
			display += ":" + str(m.count)
		parts.append(display)
		if m.mark_content != "":
			tooltips.append(display + ": " + m.mark_content)
	_marks_label.text = " · ".join(parts)
	_marks_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.55, 1.0))
	_marks_label.tooltip_text = "\n".join(tooltips)


func _update_hp() -> void:
	if _player == null:
		return
	var hp: int = int(_player.get("hp"))
	var max_hp: int = int(_player.get("max_hp"))
	_hp_label.text = "♥ %d/%d" % [hp, max_hp]
	var ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	_set_bar_ratio(_hp_fill, _hp_track, ratio)
	if max_hp > 0 and hp * 2 <= max_hp:
		_hp_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55, 1.0))
	else:
		_hp_label.add_theme_color_override("font_color", TEXT_MAIN)


func _update_sneak() -> void:
	if _player == null:
		return
	var sneak_value: int = _player.get_sneak()
	var block: Variant = _player.get("current_block")
	if block != null and is_instance_valid(block):
		if block.has_method("count_monster"):
			sneak_value -= block.count_monster()
		if block.has_method("count_monster_mark"):
			sneak_value -= block.count_monster_mark()
	_sneak_label.text = "潜行 %d" % sneak_value


func _update_hunger() -> void:
	if _player == null:
		return
	var hunger: int = int(_player.get("hunger"))
	_hunger_label.text = "饥饿 %d/6" % hunger
	_set_bar_ratio(_hunger_fill, _hunger_track, float(hunger) / 6.0)
	if hunger >= 5:
		_hunger_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.15))
		_hunger_fill.color = HUNGER_FILL_WARN
	else:
		_hunger_label.add_theme_color_override("font_color", TEXT_MAIN)
		_hunger_fill.color = HUNGER_FILL


func _update_action() -> void:
	if _player == null:
		return
	if _is_current_turn or _is_operation_focus:
		var action_count: int = _player.get_effective_action_count() if _player.has_method("get_effective_action_count") else _player.get("action_count")
		if _is_operation_focus and not _is_current_turn:
			_action_label.text = "临时行动 %d" % action_count
		else:
			_action_label.text = "行动 %d/%d" % [action_count, _player.get("max_action_count")]
		_action_label.visible = true
	else:
		_action_label.visible = false


func _update_monster_zone() -> void:
	if _player == null:
		return
	var zone: Array = _player.get("monster_zone")
	var n: int = zone.size()
	_monster_button.text = "怪物 ×%d" % n
	if n > 0:
		_set_slot_font_color(_monster_button, TEXT_MONSTER)
	else:
		_set_slot_font_color(_monster_button, TEXT_MAIN)


func _update_equipment_zone() -> void:
	if _player == null:
		return
	var zone: Array = _player.get("equipment_zone")
	var total_size: int = 0
	for e in zone:
		if e != null and is_instance_valid(e):
			total_size += int(e.get("size"))
	var capacity: int = 0
	var role: Variant = _player.get("role_card")
	if role != null and is_instance_valid(role):
		capacity = int(role.get("equipment_capacity"))
	_equipment_button.text = "装备 %d/%d" % [total_size, capacity]
	if capacity > 0 and total_size >= capacity:
		_set_slot_font_color(_equipment_button, TEXT_WARN)
	else:
		_set_slot_font_color(_equipment_button, TEXT_MAIN)


func _update_hand() -> void:
	if _player == null:
		return
	var hand: Array = _player.get("hand")
	_hand_button.text = "手牌 ×%d" % hand.size()
	_hand_button.disabled = not _is_self
	_set_slot_font_color(_hand_button, TEXT_MAIN)


func _apply_border() -> void:
	if _border == null:
		return
	if _is_current_turn:
		_border.add_theme_stylebox_override("panel", _make_border_style(GOLD_BORDER, CURRENT_TURN_BORDER_WIDTH))
	elif _player != null and is_instance_valid(_player) and not _player.is_alive():
		_border.add_theme_stylebox_override("panel", _make_border_style(DEAD_BORDER, 2))
	else:
		_border.add_theme_stylebox_override("panel", _make_border_style(Color(0.22, 0.20, 0.18, 1.0), 1))


# === 反馈动画（公开方法，供 GameScene2D 调用，均为 fire-and-forget） ===

## 当前回合呼吸高亮开关。
## 描边方案：复用既有 _border——透明背景、仅描边，对 modulate.a 做呼吸不影响面板内容。
func set_turn_highlight(active: bool) -> void:
	if _border == null or not is_instance_valid(_border):
		return
	var should_breath: bool = active and _player != null and is_instance_valid(_player) and _player.is_alive()
	if should_breath == _breath_active and _breath_tween != null and _breath_tween.is_valid():
		return
	_kill_tween(_breath_tween)
	_breath_active = should_breath
	if should_breath:
		_border.add_theme_stylebox_override("panel", _make_border_style(GOLD_BORDER, CURRENT_TURN_BORDER_WIDTH))
		_border.modulate.a = 1.0
		_breath_tween = create_tween()
		_breath_tween.bind_node(_border)
		_breath_tween.set_loops()
		_breath_tween.tween_property(_border, "modulate:a", 0.55, 0.75)
		_breath_tween.tween_property(_border, "modulate:a", 1.0, 0.75)
	else:
		_border.modulate.a = 1.0
		_apply_border()


## 受伤反馈：面板整体红闪 + HP 标签红色「-N」飘字。
func play_damage_feedback(amount: int) -> void:
	if not is_inside_tree():
		return
	_kill_tween(_feedback_tween)
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "modulate", Color(1.0, 0.5, 0.5), 0.15)
	_feedback_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.15)
	_spawn_float_label("-" + str(amount), Color(1.0, 0.35, 0.35), _hp_track)


## 回复反馈：HP 标签绿色「+N」飘字（无整体闪烁）。
func play_heal_feedback(amount: int) -> void:
	_spawn_float_label("+" + str(amount), Color(0.35, 0.9, 0.45), _hp_track)


## 饥饿变化反馈：面板整体黄闪。
func play_hunger_flash() -> void:
	if not is_inside_tree():
		return
	_kill_tween(_feedback_tween)
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "modulate", Color(1.0, 0.9, 0.5), 0.15)
	_feedback_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.15)


## 行动数消耗弹跳。
func play_action_bounce() -> void:
	if not is_inside_tree() or _action_label == null or not is_instance_valid(_action_label):
		return
	_action_label.pivot_offset = _action_label.size * 0.5
	_action_label.scale = Vector2.ONE
	var tween := create_tween()
	tween.bind_node(_action_label)
	tween.tween_property(_action_label, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_action_label, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 面板震动。
func play_shake() -> void:
	if not is_inside_tree():
		return
	var tween := create_tween()
	for _i in 5:
		tween.tween_property(self, "position", _home_position + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)), 0.05)
	tween.tween_property(self, "position", _home_position, 0.05)


## 怪物死亡脉冲。
func play_monster_pulse() -> void:
	if not is_inside_tree() or _monster_button == null or not is_instance_valid(_monster_button):
		return
	_monster_button.pivot_offset = _monster_button.size * 0.5
	_monster_button.scale = Vector2.ONE
	var tween := create_tween()
	tween.bind_node(_monster_button)
	tween.tween_property(_monster_button, "scale", Vector2(1.2, 1.2), 0.125).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_monster_button, "scale", Vector2.ONE, 0.125).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 教程挖洞：返回指定元素的全局矩形。key 为 hp / sneak / hunger / ap / monster_zone。
func get_element_rect(key: String) -> Rect2:
	var node: Control = null
	match key:
		"hp":
			node = _hp_track
		"sneak":
			node = _sneak_label
		"hunger":
			node = _hunger_track
		"ap":
			node = _action_label
		"monster_zone":
			node = _monster_button
	if node == null or not is_instance_valid(node):
		return Rect2()
	return node.get_global_rect()


## 返回怪物区按钮的全局中心位置（供怪物抓取动画计算飞行终点）。
func get_monster_zone_button_global_position() -> Vector2:
	if _monster_button == null or not is_instance_valid(_monster_button):
		return Vector2.ZERO
	return _monster_button.global_position + _monster_button.size * 0.5


## 返回角色牌的全局中心位置（供目标指向动画计算端点）。
func get_role_card_global_position() -> Vector2:
	if _role_card_panel == null or not is_instance_valid(_role_card_panel):
		return Vector2.ZERO
	return _role_card_panel.global_position + _role_card_panel.size * 0.5


## 在锚点控件位置生成上浮淡出飘字。
func _spawn_float_label(text: String, color: Color, anchor: Control) -> void:
	if not is_inside_tree() or anchor == null or not is_instance_valid(anchor):
		return
	var label := Label.new()
	label.text = text
	var local_pos: Vector2 = anchor.global_position - global_position
	label.position = Vector2(local_pos.x, local_pos.y - 8.0)
	label.size = Vector2(maxf(anchor.size.x, 48.0), 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 50
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	var tween := create_tween()
	tween.bind_node(label)
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 30.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(label.queue_free)


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


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
	label.position = Vector2(rect.position.x + _x_offset, rect.position.y + _y_offset)
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_MAIN)
	return label


func _make_stat_chip(rect: Rect2, font_size: int) -> Label:
	var label := _make_label(rect, font_size)
	label.add_theme_stylebox_override("normal", _make_fill_style(STAT_TRACK_BG, 1, 3))
	return label


func _make_panel(rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = Vector2(rect.position.x + _x_offset, rect.position.y + _y_offset)
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _make_fill_style(CARD_BG, 1, 3))
	return panel


func _make_bar_track(rect: Rect2, bg: Color) -> Panel:
	var track := Panel.new()
	track.position = Vector2(rect.position.x + _x_offset, rect.position.y + _y_offset)
	track.size = rect.size
	track.clip_contents = true
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", _make_fill_style(bg, 1, 3))
	return track


func _make_bar_fill(track: Panel, color: Color) -> ColorRect:
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(2, 2)
	fill.size = Vector2(maxf(track.size.x - 4.0, 0.0), maxf(track.size.y - 4.0, 0.0))
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	return fill


func _make_overlay_label(track: Panel, font_size: int) -> Label:
	var label := Label.new()
	label.set_anchors_preset(PRESET_FULL_RECT)
	label.offset_left = 0
	label.offset_top = 0
	label.offset_right = 0
	label.offset_bottom = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", TEXT_MAIN)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 2)
	track.add_child(label)
	return label


func _set_bar_ratio(fill: ColorRect, track: Panel, ratio: float) -> void:
	if fill == null or track == null:
		return
	var inner_w: float = maxf(track.size.x - 4.0, 0.0)
	var inner_h: float = maxf(track.size.y - 4.0, 0.0)
	fill.position = Vector2(2, 2)
	fill.size = Vector2(inner_w * clampf(ratio, 0.0, 1.0), inner_h)


func _make_slot_button(rect: Rect2, text: String, font_size: int) -> Button:
	var btn := Button.new()
	btn.position = Vector2(rect.position.x + _x_offset, rect.position.y + _y_offset)
	btn.size = rect.size
	btn.text = text
	HudTheme.apply_slot_button(btn, font_size)
	return btn


func _set_slot_font_color(btn: Button, color: Color) -> void:
	if btn == null:
		return
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", color)
	btn.add_theme_color_override("font_pressed_color", color)
	btn.add_theme_color_override("font_focus_color", color)


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


func _make_chrome_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CHROME_BG
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	return style


func _make_fill_style(color: Color, border_width: int = 1, corner: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = Color(0.15, 0.15, 0.15, 1.0)
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
	return style


func _make_border_style(border_color: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.border_color = border_color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style
