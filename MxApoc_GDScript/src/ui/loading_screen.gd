extends Control

## 加载界面：灰屏 + 中间白色小球旋转 + "加载中..."文字。
## 1.5 秒后切换到 GameScene2D。

const DURATION := 1.5
const DOT_COUNT := 5
const DOT_RADIUS := 6.0
const ORBIT_RADIUS := 30.0
const ROTATION_SPEED := 2.0

var _dot_container: Node2D
var _elapsed: float = 0.0


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	HudTheme.apply_screen_background(bg, Color("#101110"))
	add_child(bg)
	HudTheme.add_wasteland_backdrop(self, bg)

	var frame := Panel.new()
	frame.position = Vector2(555.0, 285.0)
	frame.size = Vector2(320.0, 235.0)
	HudTheme.apply_section_panel(frame, Color("#1d1c18"), HudTheme.GOLD_TEXT_DIM)
	add_child(frame)

	_dot_container = Node2D.new()
	_dot_container.position = Vector2(715.0, 360.0)
	add_child(_dot_container)

	for i in range(DOT_COUNT):
		var dot := ColorRect.new()
		var angle: float = TAU * i / DOT_COUNT
		dot.position = Vector2(cos(angle), sin(angle)) * ORBIT_RADIUS - Vector2(DOT_RADIUS, DOT_RADIUS)
		dot.size = Vector2(DOT_RADIUS * 2.0, DOT_RADIUS * 2.0)
		dot.color = HudTheme.GOLD_TEXT if i % 2 == 0 else HudTheme.TEXT_DIM
		_dot_container.add_child(dot)

	var label := Label.new()
	label.text = "加载中..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(615.0, 430.0)
	label.size = Vector2(200.0, 30.0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT)
	add_child(label)


func _process(delta: float) -> void:
	_elapsed += delta
	if _dot_container != null and is_instance_valid(_dot_container):
		_dot_container.rotation += delta * ROTATION_SPEED
	if _elapsed >= DURATION:
		set_process(false)
		get_tree().change_scene_to_file("res://scenes/GameScene2D.tscn")
