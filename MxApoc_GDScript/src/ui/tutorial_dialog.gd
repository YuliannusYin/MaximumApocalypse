extends CanvasLayer

## 聚光灯式教程：挖洞遮罩 + 气泡旁白，不挡住被讲解的 UI。

signal dialog_finished
signal skip_pressed

const HOLE_PAD := 8.0
const BUBBLE_W := 460.0
const BUBBLE_H := 132.0
const PORTRAIT_SIZE := 56.0
const DIM_COLOR := Color(0, 0, 0, 0.55)

var _click_catcher: ColorRect
var _dim_top: ColorRect
var _dim_bottom: ColorRect
var _dim_left: ColorRect
var _dim_right: ColorRect
var _bubble: Panel
var _portrait: TextureRect
var _dialog_label: RichTextLabel
var _skip_button: Button
var _hint_label: Label
var _know_button: Button

var _full_text: String = ""
var _typewriter_tween: Tween = null
var _is_typing: bool = false
var _hole: Rect2 = Rect2()


func _ready() -> void:
	layer = 100
	visible = false
	_build_ui()


func show_step(text: String, hole: Rect2 = Rect2()) -> void:
	_hole = hole
	_full_text = text
	visible = true
	var vp: Vector2 = _viewport_size()
	_click_catcher.position = Vector2.ZERO
	_click_catcher.size = vp
	_layout_hole(hole)
	_layout_bubble(hole)
	_dialog_label.text = _full_text
	_load_portrait()
	_start_typewriter()


func _build_ui() -> void:
	_click_catcher = ColorRect.new()
	_click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_click_catcher.color = Color(0, 0, 0, 0)
	_click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_catcher.gui_input.connect(_on_catcher_input)
	add_child(_click_catcher)

	_dim_top = _make_dim()
	_dim_bottom = _make_dim()
	_dim_left = _make_dim()
	_dim_right = _make_dim()

	_bubble = Panel.new()
	_bubble.size = Vector2(BUBBLE_W, BUBBLE_H)
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.12, 0.13, 0.16, 0.96)
	bubble_style.border_width_left = 2
	bubble_style.border_width_top = 2
	bubble_style.border_width_right = 2
	bubble_style.border_width_bottom = 2
	bubble_style.border_color = Color(0.85, 0.72, 0.35, 1.0)
	bubble_style.corner_radius_top_left = 8
	bubble_style.corner_radius_top_right = 8
	bubble_style.corner_radius_bottom_left = 8
	bubble_style.corner_radius_bottom_right = 8
	bubble_style.content_margin_left = 10
	bubble_style.content_margin_top = 10
	bubble_style.content_margin_right = 10
	bubble_style.content_margin_bottom = 10
	_bubble.add_theme_stylebox_override("panel", bubble_style)
	add_child(_bubble)

	_portrait = TextureRect.new()
	_portrait.position = Vector2(10, 10)
	_portrait.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_portrait)

	_dialog_label = RichTextLabel.new()
	_dialog_label.position = Vector2(10 + PORTRAIT_SIZE + 10, 8)
	_dialog_label.size = Vector2(BUBBLE_W - PORTRAIT_SIZE - 30, 78)
	_dialog_label.bbcode_enabled = true
	_dialog_label.fit_content = false
	_dialog_label.scroll_active = false
	_dialog_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_label.add_theme_font_size_override("normal_font_size", 16)
	_dialog_label.add_theme_font_size_override("bold_font_size", 16)
	_bubble.add_child(_dialog_label)

	_know_button = Button.new()
	_know_button.text = "知道了"
	_know_button.position = Vector2(BUBBLE_W - 108, BUBBLE_H - 40)
	_know_button.size = Vector2(90, 28)
	_know_button.pressed.connect(_advance)
	_bubble.add_child(_know_button)

	_skip_button = Button.new()
	_skip_button.text = "跳过教程"
	_skip_button.position = Vector2(0, 20)
	_skip_button.size = Vector2(110, 32)
	_skip_button.pressed.connect(_on_skip_button_pressed)
	add_child(_skip_button)

	_hint_label = Label.new()
	_hint_label.text = "空格继续"
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.7))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)


func _make_dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	return dim


func _load_portrait() -> void:
	var tex: Texture2D = ImageCache.get_player_avatar("firefighter")
	if tex != null:
		_portrait.texture = tex


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _layout_hole(hole: Rect2) -> void:
	var vp: Vector2 = _viewport_size()
	if hole.size.x <= 1.0 or hole.size.y <= 1.0:
		_dim_top.position = Vector2.ZERO
		_dim_top.size = vp
		_dim_bottom.size = Vector2.ZERO
		_dim_left.size = Vector2.ZERO
		_dim_right.size = Vector2.ZERO
		_dim_bottom.visible = false
		_dim_left.visible = false
		_dim_right.visible = false
		_dim_top.visible = true
		return
	_dim_bottom.visible = true
	_dim_left.visible = true
	_dim_right.visible = true
	_dim_top.visible = true
	var r: Rect2 = hole.grow(HOLE_PAD)
	r.position.x = clampf(r.position.x, 0.0, vp.x)
	r.position.y = clampf(r.position.y, 0.0, vp.y)
	r.size.x = clampf(r.size.x, 0.0, vp.x - r.position.x)
	r.size.y = clampf(r.size.y, 0.0, vp.y - r.position.y)
	_dim_top.position = Vector2.ZERO
	_dim_top.size = Vector2(vp.x, maxf(r.position.y, 0.0))
	_dim_bottom.position = Vector2(0.0, r.position.y + r.size.y)
	_dim_bottom.size = Vector2(vp.x, maxf(vp.y - (r.position.y + r.size.y), 0.0))
	_dim_left.position = Vector2(0.0, r.position.y)
	_dim_left.size = Vector2(maxf(r.position.x, 0.0), r.size.y)
	_dim_right.position = Vector2(r.position.x + r.size.x, r.position.y)
	_dim_right.size = Vector2(maxf(vp.x - (r.position.x + r.size.x), 0.0), r.size.y)


func _layout_bubble(hole: Rect2) -> void:
	var vp: Vector2 = _viewport_size()
	_skip_button.position = Vector2(vp.x - 130.0, 20.0)
	_hint_label.position = Vector2(vp.x - 170.0, vp.y - 32.0)
	_hint_label.size = Vector2(150.0, 20.0)
	var pos := Vector2((vp.x - BUBBLE_W) * 0.5, vp.y - BUBBLE_H - 48.0)
	if hole.size.x > 1.0 and hole.size.y > 1.0:
		var r: Rect2 = hole.grow(HOLE_PAD)
		var below_y: float = r.position.y + r.size.y + 16.0
		var above_y: float = r.position.y - BUBBLE_H - 16.0
		if below_y + BUBBLE_H <= vp.y - 8.0:
			pos.y = below_y
			pos.x = clampf(r.position.x, 16.0, vp.x - BUBBLE_W - 16.0)
		elif above_y >= 8.0:
			pos.y = above_y
			pos.x = clampf(r.position.x, 16.0, vp.x - BUBBLE_W - 16.0)
		else:
			var left_x: float = r.position.x - BUBBLE_W - 16.0
			if left_x >= 16.0:
				pos.x = left_x
				pos.y = clampf(r.position.y, 16.0, vp.y - BUBBLE_H - 16.0)
			else:
				pos.x = clampf(r.position.x + r.size.x + 16.0, 16.0, vp.x - BUBBLE_W - 16.0)
				pos.y = clampf(r.position.y, 16.0, vp.y - BUBBLE_H - 16.0)
	_bubble.position = pos


func _start_typewriter() -> void:
	_is_typing = true
	_dialog_label.visible_ratio = 0.0
	if _typewriter_tween != null:
		_typewriter_tween.kill()
	_typewriter_tween = create_tween()
	var char_count := _full_text.length()
	var duration: float = max(0.25, float(char_count) * 0.025)
	_typewriter_tween.tween_property(_dialog_label, "visible_ratio", 1.0, duration)
	_typewriter_tween.tween_callback(func(): _is_typing = false)


func _advance() -> void:
	if not visible:
		return
	if _is_typing:
		if _typewriter_tween != null:
			_typewriter_tween.kill()
		_dialog_label.visible_ratio = 1.0
		_is_typing = false
		return
	_close_dialog()


func _close_dialog() -> void:
	visible = false
	_full_text = ""
	dialog_finished.emit()


func _on_skip_button_pressed() -> void:
	visible = false
	_full_text = ""
	skip_pressed.emit()


func _on_catcher_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_advance()
			get_viewport().set_input_as_handled()
