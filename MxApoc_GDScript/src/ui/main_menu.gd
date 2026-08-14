extends Control

const SETTINGS_DIALOG_SCENE := preload("res://scenes/SettingsDialog.tscn")
const GITHUB_URL := "https://github.com/YuliannusYin/MaximumApocalypse"

@onready var create_room_button: Button = $CreateRoomButton
@onready var join_room_button: Button = $JoinRoomButton
@onready var quit_button: Button = $QuitButton
@onready var settings_button: Button = $SettingsButton
@onready var wiki_button: Button = $WikiButton
@onready var achievement_button: Button = $AchievementButton
@onready var github_button: Button = $GithubButton
@onready var version_label: Label = $VersionLabel

func _ready() -> void:
	create_room_button.pressed.connect(_on_create_room_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	github_button.pressed.connect(_on_github_pressed)
	# JoinRoomButton / WikiButton / AchievementButton 保持禁用占位，不连接信号

func _on_create_room_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/GameRoom.tscn")

func _on_settings_pressed() -> void:
	var dialog := SETTINGS_DIALOG_SCENE.instantiate()
	add_child(dialog)
	dialog.popup_centered(Vector2i(360, 180))

func _on_github_pressed() -> void:
	OS.shell_open(GITHUB_URL)

func _on_quit_pressed() -> void:
	get_tree().quit()
