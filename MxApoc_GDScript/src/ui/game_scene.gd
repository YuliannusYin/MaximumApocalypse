extends Control

@onready var snapshot_rich: RichTextLabel = $MarginContainer/VBoxContainer/SnapshotRich
@onready var back_button: Button = $MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	snapshot_rich.text = RoomState.snapshot()
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	RoomState.clear()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
