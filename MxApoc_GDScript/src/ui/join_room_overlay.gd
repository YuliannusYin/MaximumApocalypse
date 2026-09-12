extends Control

## 主菜单「加入房间」浮层。本轮仅收集昵称与网络地址，确认后提示功能开发中。
const NetProtocol = preload("res://src/net/net_protocol.gd")
const LoadingScreenScript := preload("res://src/ui/loading_screen.gd")
const JOIN_CONFIG_PATH := "user://join_room.json"

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
	modulate.a = 0.0
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
	_load_join_config()
	HudTheme.apply_mission_slot_button(_confirm_button, 14)
	HudTheme.apply_slot_button(_cancel_button, 14)
	_confirm_button.pressed.connect(_on_confirm)
	_cancel_button.pressed.connect(_on_close)
	NetSession.connection_state_changed.connect(_on_connection_state_changed)
	NetSession.network_error.connect(_on_network_error)
	HudTheme.play_overlay_appear(self, _panel)


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
	var nickname := NetProtocol.normalize_nickname(_nickname_edit.text)
	if nickname.is_empty():
		_show_error("请输入玩家昵称")
		return
	var parsed := NetProtocol.parse_address(_address_edit.text)
	if not bool(parsed.get("ok", false)):
		_show_error(_error_text(String(parsed.get("error", NetProtocol.ERROR_INVALID_ADDRESS))))
		return
	_confirm_button.disabled = true
	_hint_label.text = "正在连接..."
	_save_join_config(nickname, _address_edit.text.strip_edges())
	if not NetSession.join(_address_edit.text, nickname):
		_confirm_button.disabled = false

func _load_join_config() -> void:
	if not FileAccess.file_exists(JOIN_CONFIG_PATH):
		return
	var file := FileAccess.open(JOIN_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_nickname_edit.text = String(parsed.get("nickname", ""))
		_address_edit.text = String(parsed.get("address", ""))

func _save_join_config(nickname: String, address: String) -> void:
	var file := FileAccess.open(JOIN_CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"nickname": nickname, "address": address}))
	file.close()

func _show_error(text: String) -> void:
	_hint_label.text = text
	_hint_label.add_theme_color_override("font_color", Color("#e26d6d"))

func _error_text(code: String) -> String:
	match code:
		NetProtocol.ERROR_INVALID_ADDRESS:
			return "地址格式无效，请填写 IP:端口，例如 192.168.1.10:7777"
		NetProtocol.ERROR_INVALID_PORT:
			return "端口无效"
		NetProtocol.ERROR_CONNECT_TIMEOUT:
			return "连接超时"
		NetProtocol.ERROR_CONNECTION_REFUSED:
			return "无法连接到房间"
		NetProtocol.ERROR_PROTOCOL_MISMATCH:
			return "客户端版本不兼容"
		NetProtocol.ERROR_INVALID_TOKEN, NetProtocol.ERROR_TOKEN_EXPIRED:
			return "重连凭证已失效，正在重新加入"
		_:
			return "无法解析地址"

func _on_connection_state_changed(state: String, detail: String) -> void:
	if state == "joined":
		_confirm_button.disabled = false
		if NetSession.should_enter_match_scene():
			LoadingScreenScript.go_enter_game(get_tree())
		else:
			get_tree().change_scene_to_file("res://scenes/GameRoom.tscn")
	elif state == "connecting" or state == "connected":
		_hint_label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT)
		if detail != "":
			_hint_label.text = detail

func _on_network_error(code: String, _detail: String) -> void:
	_confirm_button.disabled = false
	_show_error(_error_text(code))


func _on_close() -> void:
	closed.emit()
	queue_free()
