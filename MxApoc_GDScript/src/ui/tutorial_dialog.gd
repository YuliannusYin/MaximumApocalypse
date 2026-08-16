extends CanvasLayer

## Galgame 风格教程对话框。显示消防员立绘和多行对话文本。

signal dialog_finished
signal skip_pressed

@onready var _overlay: ColorRect = $Overlay
@onready var _portrait: TextureRect = $Portrait
@onready var _dialog_box: Panel = $DialogBox
@onready var _dialog_label: RichTextLabel = $DialogBox/DialogLabel
@onready var _skip_button: Button = $SkipButton
@onready var _hint_label: Label = $HintLabel

var _lines: Array = []
var _current_index: int = 0
var _typewriter_tween: Tween = null
var _is_typing: bool = false
var _full_text: String = ""

const PORTRAIT_PATH := "res://images/survivor/firefighter/消防员角色牌正面.jpg"

func _ready() -> void:
	visible = false
	_skip_button.pressed.connect(_on_skip_button_pressed)

func show_dialog(lines: Array) -> void:
	_lines = lines
	_current_index = 0
	visible = true
	# 加载立绘
	var tex: Texture2D = load(PORTRAIT_PATH)
	if tex != null:
		_portrait.texture = tex
	_show_current_line()

func _show_current_line() -> void:
	if _current_index >= _lines.size():
		_close_dialog()
		return
	_full_text = _lines[_current_index]
	_dialog_label.text = _full_text
	_start_typewriter()

func _start_typewriter() -> void:
	_is_typing = true
	_dialog_label.visible_ratio = 0.0
	if _typewriter_tween != null:
		_typewriter_tween.kill()
	_typewriter_tween = create_tween()
	var char_count := _full_text.length()
	var duration: float = max(0.3, float(char_count) * 0.03)
	_typewriter_tween.tween_property(_dialog_label, "visible_ratio", 1.0, duration)
	_typewriter_tween.tween_callback(func(): _is_typing = false)

func _advance() -> void:
	if _is_typing:
		# 跳过打字机效果，直接显示全文
		if _typewriter_tween != null:
			_typewriter_tween.kill()
		_dialog_label.visible_ratio = 1.0
		_is_typing = false
		return
	_current_index += 1
	_show_current_line()

func _close_dialog() -> void:
	visible = false
	_lines = []
	_current_index = 0
	dialog_finished.emit()

func _on_skip_button_pressed() -> void:
	_close_dialog()
	skip_pressed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_advance()
			get_viewport().set_input_as_handled()
