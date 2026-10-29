extends Control

## 游戏设置场景。从主菜单跳转进入，提供显示、音量、动画速度与玩法设置。

@onready var fullscreen_checkbox: CheckBox = $Panel/FullscreenCheckBox
@onready var volume_slider: HSlider = $Panel/VolumeSlider
@onready var animation_speed_option: OptionButton = $Panel/AnimationSpeedOption
@onready var skip_target_checkbox: CheckBox = $Panel/SkipTargetCheckBox
@onready var tutorial_mode_checkbox: CheckBox = $Panel/TutorialModeCheckBox
@onready var back_button: Button = $Panel/BackButton
@onready var background: ColorRect = $Background
@onready var title_label: Label = $Panel/TitleLabel

func _ready() -> void:
	HudTheme.apply_screen_background(background, Color("#101110"))
	HudTheme.add_wasteland_backdrop(self, background)
	HudTheme.apply_title(title_label, 28)
	HudTheme.apply_slot_button(fullscreen_checkbox, 16)
	HudTheme.apply_slot_button(animation_speed_option, 16)
	HudTheme.apply_slot_button(skip_target_checkbox, 16)
	HudTheme.apply_slot_button(tutorial_mode_checkbox, 16)
	HudTheme.apply_mission_slot_button(back_button, 16)
	$Panel/VolumeLabel.add_theme_color_override("font_color", HudTheme.GOLD_TEXT_DIM)
	$Panel/AnimationSpeedLabel.add_theme_color_override("font_color", HudTheme.GOLD_TEXT_DIM)
	# 初始化 UI 状态
	fullscreen_checkbox.button_pressed = Settings.fullscreen
	volume_slider.value = Settings.volume * 100.0
	_setup_animation_speed_option()
	skip_target_checkbox.button_pressed = Settings.skip_target_selection
	tutorial_mode_checkbox.button_pressed = Settings.tutorial_mode
	# 连接控件信号
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	animation_speed_option.item_selected.connect(_on_animation_speed_selected)
	skip_target_checkbox.toggled.connect(_on_skip_target_toggled)
	tutorial_mode_checkbox.toggled.connect(_on_tutorial_mode_toggled)
	back_button.pressed.connect(_on_back_pressed)
	# 监听 Settings 信号同步 UI
	Settings.fullscreen_changed.connect(_on_settings_fullscreen_changed)
	Settings.volume_changed.connect(_on_settings_volume_changed)
	Settings.animation_speed_changed.connect(_on_settings_animation_speed_changed)

func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed != Settings.fullscreen:
		Settings.toggle_fullscreen()

func _on_settings_fullscreen_changed(is_fullscreen: bool) -> void:
	if fullscreen_checkbox.button_pressed != is_fullscreen:
		fullscreen_checkbox.button_pressed = is_fullscreen

func _on_volume_changed(value: float) -> void:
	Settings.set_volume(value / 100.0)

func _on_settings_volume_changed(vol: float) -> void:
	var slider_val := vol * 100.0
	if abs(volume_slider.value - slider_val) > 0.01:
		volume_slider.value = slider_val

func _setup_animation_speed_option() -> void:
	animation_speed_option.clear()
	animation_speed_option.add_item("标准", Settings.AnimationSpeed.STANDARD)
	animation_speed_option.add_item("快速", Settings.AnimationSpeed.FAST)
	animation_speed_option.add_item("关闭", Settings.AnimationSpeed.OFF)
	_select_animation_speed(Settings.animation_speed)

func _on_animation_speed_selected(index: int) -> void:
	Settings.set_animation_speed(animation_speed_option.get_item_id(index))

func _on_settings_animation_speed_changed(value: int) -> void:
	_select_animation_speed(value)

func _select_animation_speed(value: int) -> void:
	for index in animation_speed_option.item_count:
		if animation_speed_option.get_item_id(index) == value:
			animation_speed_option.select(index)
			return

func _on_skip_target_toggled(pressed: bool) -> void:
	Settings.set_skip_target_selection(pressed)

func _on_tutorial_mode_toggled(pressed: bool) -> void:
	Settings.set_tutorial_mode(pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
