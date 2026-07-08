extends AcceptDialog

@onready var fullscreen_checkbox: CheckBox = $FullscreenCheckBox

func _ready() -> void:
	fullscreen_checkbox.button_pressed = Settings.fullscreen
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	Settings.fullscreen_changed.connect(_on_settings_fullscreen_changed)
	confirmed.connect(_on_closed)
	canceled.connect(_on_closed)

func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed != Settings.fullscreen:
		Settings.toggle_fullscreen()

func _on_settings_fullscreen_changed(is_fullscreen: bool) -> void:
	if fullscreen_checkbox.button_pressed != is_fullscreen:
		fullscreen_checkbox.button_pressed = is_fullscreen

func _on_closed() -> void:
	queue_free()
