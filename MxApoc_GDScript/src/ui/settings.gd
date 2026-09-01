extends Node

## 全屏状态变更时发射。
signal fullscreen_changed(is_fullscreen: bool)
## 音量变更时发射。
signal volume_changed(value: float)
## 跳过目标选择变更时发射。
signal skip_target_selection_changed(value: bool)
## 教程模式变更时发射。
signal tutorial_mode_changed(value: bool)
## 开发者模式变更时发射。
signal dev_mode_changed(value: bool)

const CONFIG_PATH_PLAYER := "user://settings.cfg"
const CONFIG_PATH_DEBUG := "user://settings_debug.cfg"
const SECTION_DISPLAY := "display"
const KEY_FULLSCREEN := "fullscreen"
const SECTION_AUDIO := "audio"
const KEY_VOLUME := "volume"
const SECTION_GAMEPLAY := "gameplay"
const KEY_SKIP_TARGET := "skip_target_selection"
const KEY_TUTORIAL_MODE := "tutorial_mode"
const SECTION_GENERAL := "general"
const KEY_DEV_MODE := "dev_mode"

## 是否全屏。
var fullscreen: bool = false
## 音量（0.0 ~ 1.0）。
var volume: float = 1.0
## 是否跳过目标选择（仅一个或全选目标时自动确认）。
var skip_target_selection: bool = false
## 是否在所有任务中显示教程（任务 0 无论此项都会显示，除非跳过）。
var tutorial_mode: bool = false
## 是否开发者模式。
var dev_mode: bool = false

func _ready() -> void:
	_load()
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()
			get_viewport().set_input_as_handled()

## 根据当前模式返回配置文件路径。
func get_config_path() -> String:
	return CONFIG_PATH_DEBUG if dev_mode else CONFIG_PATH_PLAYER

## 切换全屏状态，应用并持久化，发射 fullscreen_changed。
func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	_apply()
	_save()
	fullscreen_changed.emit(fullscreen)

## 设置音量，应用并持久化，发射 volume_changed。
func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	_apply()
	_save()
	volume_changed.emit(volume)

## 设置跳过目标选择，持久化，发射 skip_target_selection_changed。
func set_skip_target_selection(value: bool) -> void:
	skip_target_selection = value
	_save()
	skip_target_selection_changed.emit(skip_target_selection)

## 设置教程模式，持久化，发射 tutorial_mode_changed。
func set_tutorial_mode(value: bool) -> void:
	tutorial_mode = value
	_save()
	tutorial_mode_changed.emit(tutorial_mode)

## 切换开发者模式。先保存当前配置到旧文件，切换后保存到新文件，发射信号。
func toggle_dev_mode() -> void:
	_save()
	dev_mode = not dev_mode
	_save()
	dev_mode_changed.emit(dev_mode)

func _apply() -> void:
	var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	# 应用音量
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(volume))
		AudioServer.set_bus_mute(bus_idx, volume <= 0.0)

func _load() -> void:
	# 先从 player 配置读取 dev_mode
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH_PLAYER)
	if err == OK:
		dev_mode = bool(config.get_value(SECTION_GENERAL, KEY_DEV_MODE, false))
	else:
		dev_mode = false
	# 根据 dev_mode 从对应配置文件读取全部配置
	var path := get_config_path()
	var cfg := ConfigFile.new()
	err = cfg.load(path)
	if err == OK:
		fullscreen = bool(cfg.get_value(SECTION_DISPLAY, KEY_FULLSCREEN, false))
		volume = float(cfg.get_value(SECTION_AUDIO, KEY_VOLUME, 1.0))
		skip_target_selection = bool(cfg.get_value(SECTION_GAMEPLAY, KEY_SKIP_TARGET, false))
		tutorial_mode = bool(cfg.get_value(SECTION_GAMEPLAY, KEY_TUTORIAL_MODE, false))
		# dev_mode 也从实际配置文件读取（可能与 player 配置中的一致）
		dev_mode = bool(cfg.get_value(SECTION_GENERAL, KEY_DEV_MODE, dev_mode))
	else:
		fullscreen = false
		volume = 1.0
		skip_target_selection = false
		tutorial_mode = true

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_GENERAL, KEY_DEV_MODE, dev_mode)
	config.set_value(SECTION_DISPLAY, KEY_FULLSCREEN, fullscreen)
	config.set_value(SECTION_AUDIO, KEY_VOLUME, volume)
	config.set_value(SECTION_GAMEPLAY, KEY_SKIP_TARGET, skip_target_selection)
	config.set_value(SECTION_GAMEPLAY, KEY_TUTORIAL_MODE, tutorial_mode)
	config.save(get_config_path())
