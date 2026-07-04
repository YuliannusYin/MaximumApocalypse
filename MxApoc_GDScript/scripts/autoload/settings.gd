extends Node

signal fullscreen_changed(is_fullscreen: bool)

const CONFIG_PATH := "user://settings.cfg"
const SECTION_DISPLAY := "display"
const KEY_FULLSCREEN := "fullscreen"

var fullscreen: bool = false

func _ready() -> void:
	_load()
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()
			get_viewport().set_input_as_handled()

func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	_apply()
	_save()
	fullscreen_changed.emit(fullscreen)

func _apply() -> void:
	var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _load() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err == OK:
		fullscreen = bool(config.get_value(SECTION_DISPLAY, KEY_FULLSCREEN, false))
	else:
		fullscreen = false

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_DISPLAY, KEY_FULLSCREEN, fullscreen)
	config.save(CONFIG_PATH)
