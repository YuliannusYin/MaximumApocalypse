extends Control

const GITHUB_URL := "https://github.com/YuliannusYin/MaximumApocalypse"
const WIKI_OVERLAY_SCENE := preload("res://scenes/WikiOverlay.tscn")
## 连续点击时间窗口（秒）
const CLICK_WINDOW := 1.5
## 触发切换所需点击次数
const CLICKS_REQUIRED := 3
const DEFAULT_PORT := 7000
const DEFAULT_IP := "127.0.0.1"

@onready var create_room_button: Button = $CreateRoomButton
@onready var join_room_button: Button = $JoinRoomButton
@onready var quit_button: Button = $QuitButton
@onready var settings_button: Button = $SettingsButton
@onready var wiki_button: Button = $WikiButton
@onready var achievement_button: Button = $AchievementButton
@onready var github_button: Button = $GithubButton
@onready var version_label: Label = $VersionLabel
@onready var background: TextureRect = $Background

## 版本号点击计数器
var _version_click_count: int = 0
## 上次点击时间戳
var _last_click_time: float = 0.0
var _wiki_overlay: Control = null

## 等待加入主机的标志（连接为异步，需等待握手结果）
var _awaiting_join: bool = false
var _dialog_overlay: Control = null
var _dialog_error_label: Label = null

func _ready() -> void:
	# 保留现有主菜单背景图，以统一的暗色遮罩和金属按钮承接废土桌游风。
	background.modulate = Color(0.78, 0.78, 0.78, 1.0)
	HudTheme.add_wasteland_backdrop(self, background)
	HudTheme.apply_slot_button(create_room_button, 18, HudTheme.GOLD_BORDER, HudTheme.GOLD_TEXT)
	HudTheme.apply_slot_button(join_room_button, 18)
	HudTheme.apply_slot_button(quit_button, 18)
	HudTheme.apply_slot_button(settings_button, 10, HudTheme.SLOT_BORDER, HudTheme.GOLD_TEXT)
	HudTheme.apply_slot_button(wiki_button, 10, HudTheme.SLOT_BORDER, HudTheme.GOLD_TEXT)
	HudTheme.apply_slot_button(achievement_button, 10, HudTheme.SLOT_BORDER, HudTheme.GOLD_TEXT)
	HudTheme.apply_slot_button(github_button, 10)
	version_label.add_theme_color_override("font_color", HudTheme.TEXT_DIM)
	create_room_button.pressed.connect(_on_create_room_pressed)
	join_room_button.pressed.connect(_on_join_room_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	wiki_button.pressed.connect(_on_wiki_pressed)
	achievement_button.pressed.connect(_on_achievement_pressed)
	github_button.pressed.connect(_on_github_pressed)
	version_label.gui_input.connect(_on_version_label_gui_input)
	# 加入房间：弹出 IP/端口/昵称 输入框
	NetSession.host_ready.connect(_on_host_ready)
	NetSession.connection_failed.connect(_on_connection_failed)
	NetSession.host_start_failed.connect(_on_host_start_failed)

func _on_create_room_pressed() -> void:
	if _awaiting_join:
		return
	_open_net_dialog("创建房间", [
		{"key": "name", "label": "昵称", "default": _last_name(), "placeholder": "输入昵称"},
		{"key": "port", "label": "端口", "default": str(DEFAULT_PORT), "placeholder": "监听端口"},
	], _confirm_create)

func _confirm_create(entries: Dictionary, error_label: Label) -> void:
	var name := str(entries["name"].text).strip_edges()
	if name == "":
		name = "玩家"
	var port := int(entries["port"].text)
	if port <= 0 or port > 65535:
		error_label.text = "端口无效（1-65535）"
		return
	var err := NetSession.start_host(port, name)
	if err != OK:
		error_label.text = "创建房间失败（端口被占用？）：%d" % err
		return
	_close_dialog()
	get_tree().change_scene_to_file("res://scenes/GameRoom.tscn")

func _on_join_room_pressed() -> void:
	if _awaiting_join:
		return
	_open_net_dialog("加入房间", [
		{"key": "name", "label": "昵称", "default": _last_name(), "placeholder": "输入昵称"},
		{"key": "host", "label": "主机地址", "default": _last_host(), "placeholder": "例：192.168.1.10:7000"},
	], _confirm_join)

func _confirm_join(entries: Dictionary, error_label: Label) -> void:
	var name := str(entries["name"].text).strip_edges()
	if name == "":
		name = "玩家"
	var host := str(entries["host"].text).strip_edges()
	# 解析主机地址：按最后一个 ":" 分割 IP 与端口；无 ":" 时端口取默认 7000
	var ip := host
	var port := DEFAULT_PORT
	var colon := host.rfind(":")
	if colon >= 0:
		ip = host.substr(0, colon).strip_edges()
		var port_str := host.substr(colon + 1).strip_edges()
		if port_str != "":
			if not port_str.is_valid_int():
				error_label.text = "端口无效（1-65535）"
				return
			port = int(port_str)
	if ip == "":
		error_label.text = "请输入主机地址（例：192.168.1.10:7000）"
		return
	if port <= 0 or port > 65535:
		error_label.text = "端口无效（1-65535）"
		return
	var err := NetSession.join_host(ip, port, name)
	if err != OK:
		error_label.text = "发起连接失败：%d" % err
		return
	_awaiting_join = true
	error_label.text = "正在连接 %s:%d ..." % [ip, port]
	error_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45, 1.0))

func _on_host_ready(_peer_id: int, _player_name: String, room_state: Dictionary) -> void:
	if not _awaiting_join:
		return
	_awaiting_join = false
	# 将主机房间状态镜像到本地 RoomState，供客机房间界面渲染
	RoomState.apply_dict(room_state)
	_close_dialog()
	get_tree().change_scene_to_file("res://scenes/GameRoom.tscn")

func _on_connection_failed() -> void:
	if not _awaiting_join:
		return
	_awaiting_join = false
	if is_instance_valid(_dialog_error_label):
		_dialog_error_label.text = "无法连接到主机，请检查 IP 与端口"
		_dialog_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3, 1.0))

func _on_host_start_failed(_port: int, _error: int) -> void:
	# 同步失败已在 _confirm_create 中处理；此处兜底
	pass

func _last_name() -> String:
	if NetSession.player_name != "":
		return NetSession.player_name
	return "玩家"


## 上次连接的主机 IP（成功连接过则记忆，否则回退默认值）。
func _last_ip() -> String:
	if NetSession.host_ip != "":
		return NetSession.host_ip
	return DEFAULT_IP


## 上次连接的主机端口（成功连接过则记忆，否则回退默认值）。
func _last_port() -> String:
	if NetSession.host_port > 0:
		return str(NetSession.host_port)
	return str(DEFAULT_PORT)


## 上次连接的主机地址（ip:port 一体，供加入对话框默认值）。
func _last_host() -> String:
	return "%s:%s" % [_last_ip(), _last_port()]

# === 通用对话框 ===

## 弹出居中模态输入框。fields 每项 {key, label, default, placeholder}。
func _open_net_dialog(title: String, fields: Array, on_confirm: Callable) -> void:
	_close_dialog()
	var overlay := Control.new()
	overlay.name = "NetDialogOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	_dialog_overlay = overlay

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	overlay.add_child(dim)

	# CenterContainer 全屏包裹：面板无论尺寸都水平垂直居中
	# （原 set_anchors_preset(PRESET_CENTER) 只设锚点不设偏移，面板从中心点向右下生长导致偏移）
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	HudTheme.apply_section_panel(panel, Color("#211f1a"), HudTheme.GOLD_BORDER)
	center.add_child(panel)
	panel.custom_minimum_size = Vector2(380, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title_label := Label.new()
	title_label.text = title
	HudTheme.apply_title(title_label, 20)
	vbox.add_child(title_label)

	var entries: Dictionary = {}
	for field in fields:
		var lbl := Label.new()
		lbl.text = str(field.label)
		lbl.add_theme_color_override("font_color", HudTheme.TEXT_MAIN)
		lbl.add_theme_font_size_override("font_size", 14)
		vbox.add_child(lbl)
		var edit := LineEdit.new()
		edit.text = str(field.get("default", ""))
		edit.placeholder_text = str(field.get("placeholder", ""))
		edit.custom_minimum_size = Vector2(0, 34)
		edit.add_theme_font_size_override("font_size", 15)
		vbox.add_child(edit)
		entries[field.key] = edit

	_dialog_error_label = Label.new()
	_dialog_error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3, 1.0))
	_dialog_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_error_label.custom_minimum_size = Vector2(0, 18)
	vbox.add_child(_dialog_error_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	HudTheme.apply_slot_button(cancel_btn, 14)
	buttons.add_child(cancel_btn)
	var confirm_btn := Button.new()
	confirm_btn.text = "确认"
	confirm_btn.custom_minimum_size = Vector2(120, 36)
	HudTheme.apply_mission_slot_button(confirm_btn, 14)
	buttons.add_child(confirm_btn)

	cancel_btn.pressed.connect(_close_dialog)
	confirm_btn.pressed.connect(func() -> void:
		on_confirm.call(entries, _dialog_error_label)
	)
	# 回车触发确认
	panel.focus_mode = Control.FOCUS_ALL
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
			on_confirm.call(entries, _dialog_error_label)
	)

func _close_dialog() -> void:
	if _dialog_overlay != null and is_instance_valid(_dialog_overlay):
		_dialog_overlay.queue_free()
	_dialog_overlay = null
	_dialog_error_label = null

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SettingsScene.tscn")

func _on_wiki_pressed() -> void:
	if _wiki_overlay != null and is_instance_valid(_wiki_overlay):
		return
	_wiki_overlay = WIKI_OVERLAY_SCENE.instantiate()
	add_child(_wiki_overlay)
	_wiki_overlay.closed.connect(func() -> void: _wiki_overlay = null)

func _on_achievement_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/AchievementScene.tscn")

func _on_github_pressed() -> void:
	OS.shell_open(GITHUB_URL)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_version_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_click_time > CLICK_WINDOW:
			_version_click_count = 0
		_version_click_count += 1
		_last_click_time = now
		if _version_click_count >= CLICKS_REQUIRED:
			_version_click_count = 0
			Settings.toggle_dev_mode()
			_show_mode_switch_hint()

func _show_mode_switch_hint() -> void:
	var hint_text := "已切换到开发者模式" if Settings.dev_mode else "已切换到玩家模式"
	var hint := Label.new()
	hint.text = hint_text
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hint)
	# 创建 Tween 实现淡出效果
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(hint, "modulate:a", 0.0, 0.5)
	tween.tween_callback(hint.queue_free)
