extends Control

const GITHUB_URL := "https://github.com/YuliannusYin/MaximumApocalypse"
const WIKI_OVERLAY_SCENE := preload("res://scenes/WikiOverlay.tscn")
## 连续点击时间窗口（秒）
const CLICK_WINDOW := 1.5
## 触发切换所需点击次数
const CLICKS_REQUIRED := 3

@onready var create_room_button: Button = $CreateRoomButton
@onready var join_room_button: Button = $JoinRoomButton
@onready var editor_button: Button = $EditorButton
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

func _ready() -> void:
	# 保留现有主菜单背景图的原始亮度，仅叠加很轻的废土纹理。
	background.modulate = Color.WHITE
	var backdrop := HudTheme.add_wasteland_backdrop(self, background)
	if backdrop != null:
		backdrop.modulate.a = 0.35
	HudTheme.apply_slot_button(create_room_button, 18, HudTheme.GOLD_BORDER, HudTheme.GOLD_TEXT)
	HudTheme.apply_slot_button(join_room_button, 18)
	HudTheme.apply_slot_button(editor_button, 18)
	HudTheme.apply_slot_button(quit_button, 18)
	HudTheme.apply_slot_button(settings_button, 10, HudTheme.SLOT_BORDER, HudTheme.GOLD_TEXT)
	HudTheme.apply_slot_button(wiki_button, 10, HudTheme.SLOT_BORDER, HudTheme.GOLD_TEXT)
	HudTheme.apply_slot_button(achievement_button, 10, HudTheme.SLOT_BORDER, HudTheme.GOLD_TEXT)
	HudTheme.apply_slot_button(github_button, 10)
	version_label.add_theme_color_override("font_color", HudTheme.TEXT_DIM)
	create_room_button.pressed.connect(_on_create_room_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	wiki_button.pressed.connect(_on_wiki_pressed)
	achievement_button.pressed.connect(_on_achievement_pressed)
	github_button.pressed.connect(_on_github_pressed)
	version_label.gui_input.connect(_on_version_label_gui_input)
	# JoinRoomButton / EditorButton 保持禁用占位，不连接信号

func _on_create_room_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/GameRoom.tscn")

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
