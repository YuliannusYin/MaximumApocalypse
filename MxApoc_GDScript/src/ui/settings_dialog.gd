extends AcceptDialog

@onready var fullscreen_checkbox: CheckBox = $Content/FullscreenCheckBox
@onready var animation_speed_option: OptionButton = $Content/AnimationSpeedRow/AnimationSpeedOption
@onready var hosting_checkbox: CheckBox = $Content/HostingCheckBox

func _ready() -> void:
	fullscreen_checkbox.button_pressed = Settings.fullscreen
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	Settings.fullscreen_changed.connect(_on_settings_fullscreen_changed)
	_setup_animation_speed_option()
	animation_speed_option.item_selected.connect(_on_animation_speed_selected)
	Settings.animation_speed_changed.connect(_on_settings_animation_speed_changed)
	_setup_hosting_checkbox()
	confirmed.connect(_on_closed)
	canceled.connect(_on_closed)

func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed != Settings.fullscreen:
		Settings.toggle_fullscreen()

func _on_settings_fullscreen_changed(is_fullscreen: bool) -> void:
	if fullscreen_checkbox.button_pressed != is_fullscreen:
		fullscreen_checkbox.button_pressed = is_fullscreen

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

## 主动托管仅在联机对局进行中显示;状态以权威端快照为准。
func _setup_hosting_checkbox() -> void:
	hosting_checkbox.visible = _hosting_available()
	if not hosting_checkbox.visible:
		return
	hosting_checkbox.button_pressed = NetSession.is_local_player_hosted()
	hosting_checkbox.toggled.connect(_on_hosting_toggled)
	NetSession.session_changed.connect(_on_session_changed)

func _hosting_available() -> bool:
	if NetSession == null or RoomState == null or not RoomState.online_multiplayer:
		return false
	return NetSession.registry.phase == "playing" \
		and NetSession.registry.players.has(NetSession.local_player_id)

func _on_hosting_toggled(pressed: bool) -> void:
	if pressed != NetSession.is_local_player_hosted():
		NetSession.request_set_hosting(pressed)

func _on_session_changed(_snapshot: Dictionary) -> void:
	var hosted := NetSession.is_local_player_hosted()
	if hosting_checkbox.button_pressed != hosted:
		hosting_checkbox.set_pressed_no_signal(hosted)

func _exit_tree() -> void:
	if NetSession != null and NetSession.session_changed.is_connected(_on_session_changed):
		NetSession.session_changed.disconnect(_on_session_changed)

func _on_closed() -> void:
	queue_free()
