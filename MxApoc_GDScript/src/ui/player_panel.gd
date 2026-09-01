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
const GOLD_BORDER := Color(1.0, 0.8, 0.3, 1.0)  # 当前回合金色描边（呼吸高亮用色）
const CURRENT_TURN_BORDER_WIDTH := 3

# 布局配置：is_self → {element_key → Rect2(position, size)}
const SELF_LAYOUT: Dictionary = {
	"A": Rect2(120, 560, 25, 25),
	"B": Rect2(120, 560, 120, 210),
	"C": Rect2(120, 680, 120, 90),
	"D": Rect2(240, 560, 60, 30),
	"E": Rect2(240, 590, 60, 30),
	"F": Rect2(240, 620, 60, 30),
	"G": Rect2(240, 650, 60, 30),
	"I": Rect2(240, 680, 60, 30),
	"J": Rect2(240, 710, 60, 30),
	"K": Rect2(240, 740, 60, 30),
}
const TEAMMATE_LAYOUT: Dictionary = {
	"A": Rect2(10, 10, 20, 20),
	"B": Rect2(10, 10, 100, 175),
	"C": Rect2(10, 110, 100, 75),
	"D": Rect2(110, 10, 50, 25),
	"E": Rect2(110, 35, 50, 25),
	"F": Rect2(110, 60, 50, 25),
	"G": Rect2(110, 85, 50, 25),
	"I": Rect2(110, 110, 50, 25),
	"J": Rect2(110, 135, 50, 25),
	"K": Rect2(110, 160, 50, 25),
}

var _player: Variant = null
var _is_self: bool = false
var _is_current_turn: bool = false
var _layout: Dictionary = {}
var _x_offset: int = 0  # 队友面板的 x 偏移（队友2=155, 队友3=310）
var _y_offset: int = 0  # 队友面板的 y 偏移（保留字段，始终为 0）

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

# === 反馈动画状态 ===
var _feedback_tween: Tween = null  # 根容器红闪/黄闪 Tween（后到覆盖先到）
var _breath_tween: Tween = null    # 当前回合描边呼吸 Tween（循环播放）
var _breath_active: bool = false   # 呼吸是否已激活（避免 refresh 重复重启导致相位跳变）
var _home_position: Vector2 = Vector2.ZERO  # 根容器原位置（震动动画复位基准）


func _ready() -> void:
	# 记录根容器原位置作为震动复位基准（面板由外部以全屏锚点摆放，通常为 (0,0)）
	_home_position = position
	_build_layout()


## 设置面板索引（0=self, 1=队友1, 2=队友2, 3=队友3），计算 x 偏移。
func set_panel_index(idx: int) -> void:
	var new_x: int = 0
	match idx:
		2: new_x = 155
		3: new_x = 310
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
		_action_label.visible = is_current


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
	# 终止旧动画并复位根容器表现（子节点即将重建，防止 Tween 引用已释放节点）
	_kill_tween(_feedback_tween)
	_kill_tween(_breath_tween)
	_breath_active = false
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	position = _home_position
	_clear_children()
	_layout = SELF_LAYOUT if _is_self else TEAMMATE_LAYOUT
	# 边框（围绕内容区域）
	var content_rect: Rect2 = _compute_content_rect()
	_border = Panel.new()
	_border.position = Vector2(content_rect.position.x + _x_offset, content_rect.position.y + _y_offset)
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
	_role_card_texture.offset_left = 5
	_role_card_texture.offset_top = 5
	_role_card_texture.offset_right = -5
	_role_card_texture.offset_bottom = -5
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
	_role_name_label.offset_left = 5
	_role_name_label.offset_top = 5
	_role_name_label.offset_right = -5
	_role_name_label.offset_bottom = -5
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
	set_turn_highlight(_is_current_turn)


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
		set_turn_highlight(false)  # 死亡：停止呼吸高亮，恢复普通边框（既有变灰表现不变）
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
	_role_card_panel.add_theme_stylebox_override("panel", _make_fill_style(bg, 5))


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
	_marks_label.text = ", ".join(parts)
	_marks_label.tooltip_text = "\n".join(tooltips)


func _update_hp() -> void:
	if _player == null:
		return
	_hp_label.text = "%d/%d" % [_player.get("hp"), _player.get("max_hp")]


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
	var hunger: int = _player.get("hunger")
	_hunger_label.text = "饥饿 %d/6" % hunger
	# 饥饿 ≥5 临界（角色牌即将翻面）：持续橙黄警示色；回落时移除覆盖恢复默认色
	if hunger >= 5:
		_hunger_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.15))
	else:
		_hunger_label.remove_theme_color_override("font_color")


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


# === 反馈动画（公开方法，供 GameScene2D 调用，均为 fire-and-forget） ===

## 当前回合呼吸高亮开关。
## 描边方案：复用既有 _border——它本就是"透明背景、仅描边"的 Panel，
## 对它的 modulate.a 做呼吸不会影响面板内容；关闭时复位 alpha 并恢复普通边框。
func set_turn_highlight(active: bool) -> void:
	if _border == null or not is_instance_valid(_border):
		return
	# 仅"激活且玩家存活"时呼吸；未激活或玩家死亡一律恢复静态普通边框
	var should_breath: bool = active and _player != null and is_instance_valid(_player) and _player.is_alive()
	if should_breath == _breath_active and _breath_tween != null and _breath_tween.is_valid():
		return  # 状态未变且呼吸仍在运行，避免重复重启导致相位跳变
	_kill_tween(_breath_tween)
	_breath_active = should_breath
	if should_breath:
		_border.add_theme_stylebox_override("panel", _make_border_style(GOLD_BORDER, CURRENT_TURN_BORDER_WIDTH))
		_border.modulate.a = 1.0
		_breath_tween = create_tween()
		_breath_tween.bind_node(_border)  # 边框面板释放时自动终止（布局重建防泄漏）
		_breath_tween.set_loops()
		_breath_tween.tween_property(_border, "modulate:a", 0.55, 0.75)
		_breath_tween.tween_property(_border, "modulate:a", 1.0, 0.75)
	else:
		_border.modulate.a = 1.0
		_border.add_theme_stylebox_override("panel", _make_border_style(Color(0.15, 0.15, 0.15, 1.0), 1))


## 受伤反馈：面板整体红闪（变红 0.15 秒 → 复位 0.15 秒）+ HP 标签红色「-N」飘字。
func play_damage_feedback(amount: int) -> void:
	if not is_inside_tree():
		return
	_kill_tween(_feedback_tween)
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "modulate", Color(1.0, 0.5, 0.5), 0.15)
	_feedback_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.15)
	_spawn_float_label("-" + str(amount), Color(1.0, 0.35, 0.35), _hp_label)


## 回复反馈：HP 标签绿色「+N」飘字（无整体闪烁）。
func play_heal_feedback(amount: int) -> void:
	_spawn_float_label("+" + str(amount), Color(0.35, 0.9, 0.45), _hp_label)


## 饥饿变化反馈：面板整体黄闪（变黄 0.15 秒 → 复位 0.15 秒，共约 0.3 秒）。
func play_hunger_flash() -> void:
	if not is_inside_tree():
		return
	_kill_tween(_feedback_tween)
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "modulate", Color(1.0, 0.9, 0.5), 0.15)
	_feedback_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.15)


## 行动数消耗弹跳：行动标签缩放 1→1.3→1（TRANS_BACK 回弹，共约 0.25 秒）。
func play_action_bounce() -> void:
	if not is_inside_tree() or _action_label == null or not is_instance_valid(_action_label):
		return
	_action_label.pivot_offset = _action_label.size * 0.5
	_action_label.scale = Vector2.ONE
	var tween := create_tween()
	tween.bind_node(_action_label)  # 标签释放时自动终止（布局重建防泄漏）
	tween.tween_property(_action_label, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_action_label, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 面板震动：根容器以原位置为基准随机偏移（±4px，6 步每步 0.05 秒共约 0.3 秒），结束复位。
func play_shake() -> void:
	if not is_inside_tree():
		return
	var tween := create_tween()  # 默认绑定自身（Node.create_tween），面板释放时自动终止
	for _i in 5:
		tween.tween_property(self, "position", _home_position + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)), 0.05)
	tween.tween_property(self, "position", _home_position, 0.05)


## 怪物死亡脉冲：怪物区按钮缩放 1→1.2→1（TRANS_BACK 回弹，共约 0.25 秒）。
func play_monster_pulse() -> void:
	if not is_inside_tree() or _monster_button == null or not is_instance_valid(_monster_button):
		return
	_monster_button.pivot_offset = _monster_button.size * 0.5
	_monster_button.scale = Vector2.ONE
	var tween := create_tween()
	tween.bind_node(_monster_button)  # 按钮释放时自动终止（布局重建防泄漏）
	tween.tween_property(_monster_button, "scale", Vector2(1.2, 1.2), 0.125).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_monster_button, "scale", Vector2.ONE, 0.125).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 教程挖洞：返回指定元素的全局矩形。key 为 hp / sneak / hunger / ap / monster_zone。
func get_element_rect(key: String) -> Rect2:
	var node: Control = null
	match key:
		"hp":
			node = _hp_label
		"sneak":
			node = _sneak_label
		"hunger":
			node = _hunger_label
		"ap":
			node = _action_label
		"monster_zone":
			node = _monster_button
	if node == null or not is_instance_valid(node):
		return Rect2()
	return node.get_global_rect()


## 返回怪物区按钮的全局中心位置（供怪物抓取动画计算飞行终点）。
## 按钮不存在或已释放时返回 Vector2.ZERO（调用方据此让动画原地淡出）。
func get_monster_zone_button_global_position() -> Vector2:
	if _monster_button == null or not is_instance_valid(_monster_button):
		return Vector2.ZERO
	return _monster_button.global_position + _monster_button.size * 0.5


## 返回角色牌的全局中心位置（供目标指向动画计算端点）。
## 角色牌不存在或已释放时返回 Vector2.ZERO。
func get_role_card_global_position() -> Vector2:
	if _role_card_panel == null or not is_instance_valid(_role_card_panel):
		return Vector2.ZERO
	return _role_card_panel.global_position + _role_card_panel.size * 0.5


## 在锚点控件位置生成上浮淡出飘字（18 号字 + 黑描边），约 0.8 秒后自动释放。
func _spawn_float_label(text: String, color: Color, anchor: Control) -> void:
	if not is_inside_tree() or anchor == null or not is_instance_valid(anchor):
		return
	var label := Label.new()
	label.text = text
	# x 与锚点对齐（取锚点宽度，不足 48 时加宽），水平居中；起始位置略高于锚点
	label.position = Vector2(anchor.position.x, anchor.position.y - 8.0)
	label.size = Vector2(maxf(anchor.size.x, 48.0), 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 50  # 确保飘字绘制在面板其他元素之上
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	add_child(label)
	var tween := create_tween()
	tween.bind_node(label)  # 飘字释放时自动终止（回调因此不会访问已释放节点）
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 30.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(label.queue_free)


## 终止旧 Tween（防泄漏，同 DiceAnimationView 模式）。
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
	return label


func _make_panel(rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = Vector2(rect.position.x + _x_offset, rect.position.y + _y_offset)
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _make_fill_style(Color(0.20, 0.22, 0.26, 1.0)))
	return panel


func _make_button(rect: Rect2, text: String) -> Button:
	var btn := Button.new()
	btn.position = Vector2(rect.position.x + _x_offset, rect.position.y + _y_offset)
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


func _make_fill_style(color: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
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
