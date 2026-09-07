extends Control

## 主菜单「加入房间」浮层。本轮仅收集昵称与网络地址，确认后提示功能开发中。

signal closed

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title_label: Label = $Center/Panel/VBox/TitleLabel
@onready var _nickname_label: Label = $Center/Panel/VBox/NicknameLabel
@onready var _nickname_edit: LineEdit = $Center/Panel/VBox/NicknameEdit
@onready var _address_label: Label = $Center/Panel/VBox/AddressLabel
@onready var _address_edit: LineEdit = $Center/Panel/VBox/AddressEdit
@onready var _hint_label: Label = $Center/Panel/VBox/HintLabel
@onready var _confirm_button: Button = $Center/Panel/VBox/Buttons/ConfirmButton
@onready var _cancel_button: Button = $Center/Panel/VBox/Buttons/CancelButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	HudTheme.apply_section_panel(_panel, Color("#1b1b17"), HudTheme.SLOT_BORDER)
	var panel_style := _panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style != null:
		panel_style.content_margin_left = 16
		panel_style.content_margin_right = 16
		panel_style.content_margin_top = 14
		panel_style.content_margin_bottom = 14
	HudTheme.apply_title(_title_label, 24)
	_nickname_label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT_DIM)
	_address_label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT_DIM)
	_style_line_edit(_nickname_edit)
	_style_line_edit(_address_edit)
	_hint_label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT)
	_hint_label.text = ""
	HudTheme.apply_mission_slot_button(_confirm_button, 14)
	HudTheme.apply_slot_button(_cancel_button, 14)
	_confirm_button.pressed.connect(_on_confirm)
	_cancel_button.pressed.connect(_on_close)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()


func _style_line_edit(edit: LineEdit) -> void:
	edit.add_theme_color_override("font_color", HudTheme.TEXT_MAIN)
	edit.add_theme_color_override("font_placeholder_color", HudTheme.TEXT_DIM)
	edit.add_theme_stylebox_override("normal", HudTheme.make_slot_style(HudTheme.SLOT_BG, HudTheme.SLOT_BORDER))
	edit.add_theme_stylebox_override("focus", HudTheme.make_slot_style(HudTheme.SLOT_BG_HOVER, HudTheme.GOLD_BORDER))


func _on_confirm() -> void:
	_hint_label.text = "功能开发中"


func _on_close() -> void:
	closed.emit()
	queue_free()
