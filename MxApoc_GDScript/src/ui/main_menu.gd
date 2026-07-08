extends Control

const SETTINGS_DIALOG_SCENE := preload("res://scenes/SettingsDialog.tscn")

@onready var start_button: Button = $MarginContainer/VBoxContainer/StartGameButton
@onready var settings_button: Button = $MarginContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/GameRoom.tscn")

func _on_settings_pressed() -> void:
	var dialog := SETTINGS_DIALOG_SCENE.instantiate()
	add_child(dialog)
	dialog.popup_centered(Vector2i(360, 180))

func _on_quit_pressed() -> void:
	get_tree().quit()
