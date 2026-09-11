extends Control

const NetProtocol = preload("res://src/net/net_protocol.gd")
const SEAT_ITEM_SCENE := preload("res://scenes/SeatItem.tscn")
const LoadingScreenScript := preload("res://src/ui/loading_screen.gd")
const MAX_SEATS := 6
const MIN_SEATS := 1
const RANDOM_MISSION_IDX := 0

@onready var _back_button: Button = $BottomBar/BackButton
@onready var _reset_button: Button = $BottomBar/ResetButton
@onready var _mission_option: OptionButton = $MissionSelectArea/ScrollContainer/VBoxContainer/MissionSection/MissionOption
@onready var _variant_list: VBoxContainer = $MissionSelectArea/ScrollContainer/VBoxContainer/VariantSection/VariantList
@onready var _online_multiplayer_checkbox: CheckBox = $MissionSelectArea/ScrollContainer/VBoxContainer/AdvancedSection/OnlineMultiplayerCheckBox
@onready var _host_name_edit: LineEdit = $MissionSelectArea/ScrollContainer/VBoxContainer/AdvancedSection/HostNameEdit
@onready var _port_edit: LineEdit = $MissionSelectArea/ScrollContainer/VBoxContainer/AdvancedSection/PortEdit
@onready var _start_server_button: Button = $MissionSelectArea/ScrollContainer/VBoxContainer/AdvancedSection/StartServerButton
@onready var _network_hint_label: Label = $MissionSelectArea/ScrollContainer/VBoxContainer/AdvancedSection/NetworkHintLabel
@onready var _mission_name_label: Label = $MissionDetailArea/VBoxContainer/MissionNameLabel
@onready var _difficulty_label: Label = $MissionDetailArea/VBoxContainer/DifficultyLabel
@onready var _detail_view: MissionDetailView = $MissionDetailArea/VBoxContainer/ScrollContainer/DetailView
@onready var _start_game_button: Button = $BottomBar/StartGameButton
@onready var _add_seat_button: Button = $PlayerSettingArea/VBoxContainer/SeatsHeader/AddSeatButton
@onready var _remove_seat_button: Button = $PlayerSettingArea/VBoxContainer/SeatsHeader/RemoveSeatButton
@onready var _seat_list: VBoxContainer = $PlayerSettingArea/VBoxContainer/SeatList
@onready var _background: ColorRect = $Background
@onready var _title_label: Label = $TopBar/TitleLabel

var _variant_checkboxes: Dictionary = {}
var _entered_match: bool = false

func _ready() -> void:
	HudTheme.apply_screen_background(_background, Color("#111311"))
	HudTheme.add_wasteland_backdrop(self, _background)
	HudTheme.apply_title(_title_label, 26)
	HudTheme.apply_section_panel($MissionSelectArea, Color("#211f1a"))
	HudTheme.apply_section_panel($MissionDetailArea, Color("#1d1c19"))
	var detail_style := $MissionDetailArea.get_theme_stylebox("panel") as StyleBoxFlat
	if detail_style != null:
		detail_style.content_margin_left = 12
		detail_style.content_margin_right = 12
		detail_style.content_margin_top = 10
		detail_style.content_margin_bottom = 10
	HudTheme.apply_section_panel($PlayerSettingArea, Color("#211f1a"))
	HudTheme.apply_slot_button(_mission_option, 14, HudTheme.GOLD_BORDER, HudTheme.GOLD_TEXT)
	HudTheme.apply_slot_button(_online_multiplayer_checkbox, 13)
	_online_multiplayer_checkbox.tooltip_text = "开启后将允许其他玩家通过「加入房间」连入。默认端口：7777"
	_style_network_edit(_host_name_edit)
	_style_network_edit(_port_edit)
	HudTheme.apply_slot_button(_start_server_button, 13, HudTheme.GOLD_BORDER, HudTheme.GOLD_TEXT)
	_network_hint_label.add_theme_color_override("font_color", Color("#e26d6d"))
	$MissionSelectArea/ScrollContainer/VBoxContainer/AdvancedSection/HostNameLabel.text = "昵称"
	HudTheme.apply_slot_button(_add_seat_button, 14, HudTheme.SLOT_BORDER, HudTheme.TEXT_MAIN)
	HudTheme.apply_slot_button(_remove_seat_button, 14, HudTheme.SLOT_BORDER, HudTheme.TEXT_MAIN)
	HudTheme.apply_slot_button(_back_button, 13)
	HudTheme.apply_slot_button(_reset_button, 13)
	HudTheme.apply_mission_slot_button(_start_game_button, 13)
	_mission_name_label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT)
	_difficulty_label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT_DIM)
	if not _has_active_multiplayer_peer():
		RoomState.load_from_disk()
	_populate_missions()
	_populate_variants()
	_restore_state()
	_host_name_edit.text = RoomState.host_name
	_port_edit.text = str(RoomState.listen_port)
	_rebuild_seats()
	_update_start_button()
	RoomState.save()
	_back_button.pressed.connect(_on_back)
	_reset_button.pressed.connect(_on_reset)
	_mission_option.item_selected.connect(_on_mission_selected)
	_online_multiplayer_checkbox.toggled.connect(_on_online_multiplayer_toggled)
	_host_name_edit.text_changed.connect(_on_host_name_changed)
	_port_edit.text_changed.connect(_on_port_changed)
	_start_server_button.pressed.connect(_on_start_server_pressed)
	NetSession.network_error.connect(_on_network_error)
	NetSession.connection_state_changed.connect(_on_connection_state_changed)
	_start_game_button.pressed.connect(_on_start_game)
	_add_seat_button.pressed.connect(_on_add_seat)
	_remove_seat_button.pressed.connect(_on_remove_seat)
	NetSession.session_changed.connect(_on_network_snapshot)
	NetSession.message_received.connect(_on_network_message)
	if RoomState.online_multiplayer and NetSession.multiplayer.multiplayer_peer == null:
		_update_server_controls()
	var returning_to_room := LoadingScreenScript.consume_returning_to_room()
	if NetSession.is_remote_client():
		_set_client_view()
		if not returning_to_room:
			_enter_online_match_if_needed()
			if _entered_match:
				return
	else:
		_update_server_controls()


func _exit_tree() -> void:
	if NetSession == null:
		return
	if NetSession.network_error.is_connected(_on_network_error):
		NetSession.network_error.disconnect(_on_network_error)
	if NetSession.connection_state_changed.is_connected(_on_connection_state_changed):
		NetSession.connection_state_changed.disconnect(_on_connection_state_changed)
	if NetSession.session_changed.is_connected(_on_network_snapshot):
		NetSession.session_changed.disconnect(_on_network_snapshot)
	if NetSession.message_received.is_connected(_on_network_message):
		NetSession.message_received.disconnect(_on_network_message)


func _has_active_multiplayer_peer() -> bool:
	return NetSession != null and NetSession.multiplayer != null \
			and NetSession.multiplayer.multiplayer_peer != null


## 启动服务器或客机入房后，房间 UI 放开全部任务/随机/变体。勾选本身不算。
func _online_content_unlocked() -> bool:
	if NetSession == null:
		return false
	return NetSession.has_listen_server() or NetSession.is_room_owner() \
			or NetSession.is_remote_client()


func _unlock_all_content() -> bool:
	return Settings.dev_mode or _online_content_unlocked() \
			or ArchiveManager.is_random_and_variants_unlocked()


func _is_mission_locked(mission_id: int) -> bool:
	if Settings.dev_mode or _online_content_unlocked():
		return false
	return not ArchiveManager.is_mission_unlocked(mission_id)


func _refresh_unlock_ui() -> void:
	_populate_missions()
	_populate_variants()
	_restore_state()


## 填充任务下拉框：恒显示全部任务；玩家模式下未解锁任务置灰不可选并附解锁提示，
## “随机任务”选项仅在全部任务通关、开发者模式或联机会话建立后出现。
func _populate_missions() -> void:
	_mission_option.clear()
	if _unlock_all_content():
		_mission_option.add_item("随机任务", RANDOM_MISSION_IDX)
		_mission_option.set_item_metadata(RANDOM_MISSION_IDX, null)
	for mission in DataManager.get_all_missions():
		var idx := _mission_option.item_count
		var locked := _is_mission_locked(mission.mission_id)
		var label := "%s（%s）" % [mission.mission_name, mission.difficulty_display]
		if locked:
			label += "（未解锁）"
		_mission_option.add_item(label, idx)
		_mission_option.set_item_metadata(idx, mission)
		_mission_option.set_item_disabled(idx, locked)
	_apply_client_select_lock()

## 填充变体复选框：未解锁（且非开发者模式、非联机会话）时置灰并附提示文案；
## 只创建控件，不改动 RoomState.variants 既有值（勾选状态由 _restore_state 恢复）。
func _populate_variants() -> void:
	for child in _variant_list.get_children():
		child.queue_free()
	_variant_checkboxes.clear()
	var variants := DataManager.get_all_variants()
	var variants_locked := not _unlock_all_content()
	for variant in variants:
		var cb := CheckBox.new()
		cb.text = variant.display_name
		HudTheme.apply_slot_button(cb, 13)
		if variants_locked:
			cb.disabled = true
			cb.tooltip_text = "%s\n\n（通关全部任务后解锁）" % variant.desc
		else:
			cb.tooltip_text = variant.desc
		var vid: String = variant.id
		cb.toggled.connect(func(toggled: bool): _on_variant_toggled(vid, toggled))
		_variant_list.add_child(cb)
		_variant_checkboxes[variant.id] = cb
	_apply_client_select_lock()

func _restore_state() -> void:
	if RoomState.selected_mission_is_random and _has_random_option():
		_mission_option.select(RANDOM_MISSION_IDX)
	elif RoomState.selected_mission == null:
		_select_default_mission()
	elif not _select_mission_if_enabled(RoomState.selected_mission.mission_id):
		# 残留的既往选择已锁定（如开发者模式切换后）：回退到第一个可选项
		_select_default_mission()
	for key in _variant_checkboxes:
		_variant_checkboxes[key].set_pressed_no_signal(RoomState.variants.get(key, false))
	_online_multiplayer_checkbox.set_pressed_no_signal(RoomState.online_multiplayer)
	_set_network_settings_visible(RoomState.online_multiplayer)
	_refresh_detail_panel()

## “随机任务”选项当前是否存在（存在时必为第 0 项，metadata 为 null）。
func _has_random_option() -> bool:
	return _mission_option.item_count > 0 and _mission_option.get_item_metadata(RANDOM_MISSION_IDX) == null

## 选中指定任务（若未置灰）；返回是否选中成功。
func _select_mission_if_enabled(mission_id: int) -> bool:
	for i in range(_mission_option.item_count):
		var meta = _mission_option.get_item_metadata(i)
		if meta != null and meta is MissionData and meta.mission_id == mission_id:
			if _mission_option.is_item_disabled(i):
				return false
			_mission_option.select(i)
			return true
	return false

## 默认选中第一个可选项（“随机任务”存在时即随机任务，否则为任务 0）并同步 RoomState。
func _select_default_mission() -> void:
	for i in range(_mission_option.item_count):
		if _mission_option.is_item_disabled(i):
			continue
		_mission_option.select(i)
		_on_mission_selected(i)
		return

func _rebuild_seats() -> void:
	# 规避Bug: queue_free 是延迟删除,旧子节点仍在树中直到帧结束,
	# 直接遍历 get_children() 会与 RoomState.seats 索引错位（添加座位时报越界）
	for child in _seat_list.get_children():
		_seat_list.remove_child(child)
		child.queue_free()
	for i in range(RoomState.seats.size()):
		var seat: Dictionary = RoomState.seats[i]
		var online_seat: bool = RoomState.online_multiplayer \
			and NetSession.registry.seats.size() == RoomState.seats.size()
		if online_seat:
			seat = NetSession.registry.seats[i]
		var item: SeatItem = SEAT_ITEM_SCENE.instantiate()
		item.seat_index = i
		_seat_list.add_child(item)
		if online_seat:
			var controller_id := String(seat.get("controller_id", ""))
			var can_edit_survivor := NetSession.is_room_owner() \
				or controller_id == NetSession.local_player_id
			item.configure_controller_options(
				NetSession.registry.players.values(),
				controller_id,
				NetSession.is_room_owner(),
				can_edit_survivor)
		item.setup(seat)
		item.changed.connect(_on_seat_changed)
	_refresh_seats_disabled()
	_sync_seats_to_state()
	_update_seat_buttons()

func _update_seat_buttons() -> void:
	if NetSession != null and NetSession.is_remote_client():
		_add_seat_button.disabled = true
		_remove_seat_button.disabled = true
		return
	var count := RoomState.seats.size()
	_add_seat_button.disabled = (count >= MAX_SEATS)
	_remove_seat_button.disabled = (count <= MIN_SEATS)

func _refresh_seats_disabled() -> void:
	var children := _seat_list.get_children()
	var seat_survivor_ids := []
	for i in range(children.size()):
		var data = children[i].collect()
		var sid := ""
		if data.type != "empty" and data.survivor != null:
			sid = data.survivor.english_name
		seat_survivor_ids.append(sid)
	# 每个求生者由最早选择它的座位"拥有"，其他座位的重复选择会被重置
	var owner_of := {}
	for i in range(children.size()):
		var sid = seat_survivor_ids[i]
		if sid == "" or owner_of.has(sid):
			continue
		owner_of[sid] = i
	for i in range(children.size()):
		var others_taken := []
		for sid in owner_of:
			if owner_of[sid] != i:
				others_taken.append(sid)
		children[i].refresh_survivor_disabled(others_taken)

func _sync_seats_to_state() -> void:
	var children := _seat_list.get_children()
	for i in range(children.size()):
		RoomState.seats[i] = children[i].collect()

func _on_mission_selected(idx: int) -> void:
	if not _can_edit_mission_config():
		return
	var meta = _mission_option.get_item_metadata(idx)
	if meta == null:
		RoomState.selected_mission_is_random = true
		RoomState.selected_mission = null
	else:
		RoomState.selected_mission_is_random = false
		RoomState.selected_mission = meta
	_refresh_detail_panel()
	if NetSession != null and NetSession.is_authority():
		NetSession.sync_room_config()
	RoomState.save()

func _on_variant_toggled(id: String, toggled: bool) -> void:
	if not _can_edit_mission_config():
		return
	RoomState.variants[id] = toggled
	if NetSession != null and NetSession.is_authority():
		NetSession.sync_room_config()
	RoomState.save()

func _style_network_edit(edit: LineEdit) -> void:
	edit.add_theme_color_override("font_color", HudTheme.TEXT_MAIN)
	edit.add_theme_color_override("font_placeholder_color", HudTheme.TEXT_DIM)
	edit.add_theme_stylebox_override("normal",
		HudTheme.make_slot_style(HudTheme.SLOT_BG, HudTheme.SLOT_BORDER))
	edit.add_theme_stylebox_override("focus",
		HudTheme.make_slot_style(HudTheme.SLOT_BG_HOVER, HudTheme.GOLD_BORDER))

func _on_host_name_changed(value: String) -> void:
	RoomState.host_name = NetProtocol.normalize_nickname(value)
	RoomState.save()

func _on_port_changed(value: String) -> void:
	if value.is_valid_int():
		var port := int(value)
		if port >= 1 and port <= NetProtocol.MAX_PORT:
			RoomState.listen_port = port
			RoomState.save()

func _on_online_multiplayer_toggled(toggled: bool) -> void:
	RoomState.online_multiplayer = toggled
	_set_network_settings_visible(toggled)
	if not toggled and NetSession.is_authority():
		NetSession.close_session()
	_update_server_controls()
	_refresh_unlock_ui()
	RoomState.save()

func _set_network_settings_visible(visible: bool) -> void:
	$MissionSelectArea/ScrollContainer/VBoxContainer/AdvancedSection/HostNameLabel.visible = visible
	_host_name_edit.visible = visible
	$MissionSelectArea/ScrollContainer/VBoxContainer/AdvancedSection/PortLabel.visible = visible
	_port_edit.visible = visible
	_start_server_button.visible = visible
	_network_hint_label.visible = visible

func _update_server_controls() -> void:
	if NetSession != null and NetSession.is_remote_client():
		_host_name_edit.editable = false
		_port_edit.editable = false
		_start_server_button.disabled = true
		_start_server_button.text = "客机模式"
		return
	var server_started := NetSession != null and (NetSession.has_listen_server() \
			or NetSession.is_room_owner())
	_host_name_edit.editable = not server_started
	_port_edit.editable = not server_started
	_start_server_button.disabled = server_started
	_start_server_button.text = "服务器已启动" if server_started else "启动服务器"

func _on_start_server_pressed() -> void:
	if NetSession.is_remote_client():
		_show_network_hint("当前是加入房间的客机，不能启动服务器")
		return
	if NetSession.has_listen_server() or NetSession.is_room_owner():
		_show_network_hint("服务器已启动")
		return
	if not _validate_network_settings():
		return
	if not RoomState.online_multiplayer:
		_show_network_hint("请先勾选在线多人游戏")
		return
	if NetSession.create_host(RoomState.host_name, RoomState.listen_port, RoomState.seats):
		RoomState.save()
		NetSession.sync_room_config()
		_rebuild_seats()
		_update_server_controls()
		_update_start_button()
		_refresh_unlock_ui()
		_network_hint_label.add_theme_color_override("font_color", Color("#65d47a"))
		_show_network_hint("服务器已启动，正在连入本机房间…")

func _validate_network_settings() -> bool:
	var host_name := NetProtocol.normalize_nickname(_host_name_edit.text)
	if host_name.is_empty():
		_show_network_hint("房主昵称不能为空")
		return false
	if not _port_edit.text.is_valid_int():
		_show_network_hint("端口必须是数字")
		return false
	var port := int(_port_edit.text)
	if port < 1 or port > NetProtocol.MAX_PORT:
		_show_network_hint("端口范围必须为 1-65535")
		return false
	RoomState.host_name = host_name
	RoomState.listen_port = port
	_host_name_edit.text = host_name
	_port_edit.text = str(port)
	_network_hint_label.text = ""
	return true

func _show_network_hint(text: String) -> void:
	_network_hint_label.text = text

func _on_network_error(code: String, detail: String) -> void:
	_network_hint_label.add_theme_color_override("font_color", Color("#e26d6d"))
	if code == NetProtocol.ERROR_PORT_IN_USE or code == NetProtocol.ERROR_INVALID_PORT:
		RoomState.online_multiplayer = false
		_online_multiplayer_checkbox.set_pressed_no_signal(false)
		_set_network_settings_visible(false)
		_refresh_unlock_ui()
	_update_server_controls()
	_show_network_hint(detail)

func _on_add_seat() -> void:
	if NetSession != null and NetSession.is_remote_client():
		return
	if RoomState.seats.size() >= MAX_SEATS:
		return
	RoomState.seats.append({"type": "ai", "survivor": null})
	if NetSession != null and NetSession.is_authority():
		NetSession.registry.replace_seats(RoomState.seats, NetSession.local_player_id)
	_rebuild_seats()
	_sync_network_seats()
	_update_start_button()
	RoomState.save()

func _on_remove_seat() -> void:
	if NetSession != null and NetSession.is_remote_client():
		return
	if RoomState.seats.size() <= MIN_SEATS:
		return
	RoomState.seats.pop_back()
	if NetSession != null and NetSession.is_authority():
		NetSession.registry.replace_seats(RoomState.seats, NetSession.local_player_id)
	_rebuild_seats()
	_sync_network_seats()
	_update_start_button()
	RoomState.save()

func _on_seat_changed(idx: int) -> void:
	_refresh_seats_disabled()
	_sync_seats_to_state()
	if NetSession != null and NetSession.is_remote_client():
		var data: Dictionary = _seat_list.get_child(idx).collect()
		if String(data.get("controller_id", "")) == NetSession.local_player_id:
			var survivor = data.get("survivor", null)
			NetSession.send_room_command("set_survivor", {
				"seat_id": idx,
				"survivor_id": String(survivor.english_name) if survivor != null else "",
			})
	else:
		_sync_network_seats()
	_update_start_button()
	RoomState.save()

func _sync_network_seats() -> void:
	if NetSession == null or not NetSession.is_room_owner() \
			or NetSession.registry.phase != "lobby":
		return
	if NetSession.is_awaiting_room_accept():
		return
	for i in range(_seat_list.get_child_count()):
		var data: Dictionary = _seat_list.get_child(i).collect()
		var controller_id := String(data.get("controller_id", NetSession.local_player_id))
		var survivor = data.get("survivor", null)
		var survivor_id := String(survivor.english_name) if survivor != null else ""
		if NetSession.uses_network_view():
			NetSession.send_room_command("bind_seat", {
				"seat_id": i,
				"controller_id": controller_id,
				"survivor_id": survivor_id,
				"is_ai": controller_id.is_empty(),
			})
			continue
		NetSession.registry.bind_seat(
			i,
			controller_id,
			survivor_id,
			controller_id.is_empty())
	if not NetSession.uses_network_view():
		NetSession.session_changed.emit(NetSession.registry.snapshot())
		NetSession._broadcast(NetProtocol.ROOM_SNAPSHOT, NetSession.registry.snapshot())

func _refresh_detail_panel() -> void:
	if RoomState.selected_mission_is_random:
		_mission_name_label.text = "随机任务"
		_difficulty_label.text = ""
		_detail_view.populate(null, MissionDetailView.PLACEHOLDER_RANDOM)
		return
	var mission = RoomState.selected_mission
	if mission == null:
		_mission_name_label.text = "未选择"
		_difficulty_label.text = ""
		_detail_view.populate(null)
		return
	_mission_name_label.text = mission.mission_name
	_difficulty_label.text = "难度：%s" % mission.difficulty_display
	_detail_view.populate(mission)

func _update_start_button() -> void:
	if NetSession != null and NetSession.is_remote_client():
		_start_game_button.disabled = true
		return
	if RoomState.online_multiplayer and NetSession != null \
			and NetSession.is_room_owner() and NetSession.is_awaiting_room_accept():
		_start_game_button.disabled = true
		return
	_start_game_button.disabled = not RoomState.is_ready_to_start()

func _on_start_game() -> void:
	if not RoomState.is_ready_to_start():
		return
	if RoomState.online_multiplayer:
		if not _validate_network_settings():
			return
		if not NetSession.is_room_owner():
			_show_network_hint("请先启动服务器")
			return
		if NetSession.is_awaiting_room_accept():
			_show_network_hint("正在连入本机房间，请稍候")
			return
		if NetSession.registry.phase == "lobby":
			NetSession.send_room_command("start")
			_show_network_hint("正在开始对局…")
		return
	LoadingScreenScript.go_enter_game(get_tree())

func _set_client_view() -> void:
	_add_seat_button.disabled = true
	_remove_seat_button.disabled = true
	_start_game_button.disabled = true
	_online_multiplayer_checkbox.disabled = true
	_host_name_edit.editable = false
	_port_edit.editable = false
	_start_server_button.disabled = true
	_apply_client_select_lock()


func _can_edit_mission_config() -> bool:
	return NetSession == null or not NetSession.is_remote_client()


func _apply_client_select_lock() -> void:
	if not _can_edit_mission_config():
		_mission_option.disabled = true
		for key in _variant_checkboxes:
			_variant_checkboxes[key].disabled = true


func _enter_online_match_if_needed() -> void:
	if _entered_match or not is_inside_tree():
		return
	if NetSession == null:
		return
	if String(NetSession.registry.phase) != "playing":
		return
	if not NetSession.should_enter_match_scene() and not NetSession.is_room_owner():
		return
	var tree := get_tree()
	if tree == null:
		return
	_entered_match = true
	LoadingScreenScript.go_enter_game(tree)

func _on_network_snapshot(snapshot: Dictionary) -> void:
	if NetSession.uses_network_view():
		_apply_network_room_config(snapshot)
		_online_multiplayer_checkbox.set_pressed_no_signal(true)
		_host_name_edit.text = String(snapshot.get("host_name", NetSession.registry.host_name))
		_port_edit.text = str(int(snapshot.get("port", NetSession.registry.port)))
	_rebuild_seats()
	_update_server_controls()
	_update_start_button()
	if String(snapshot.get("phase", "")) == "playing":
		_start_game_button.disabled = true
		_enter_online_match_if_needed()

func _apply_network_room_config(snapshot: Dictionary) -> void:
	var mission_config: Dictionary = snapshot.get("mission", {})
	RoomState.selected_mission_is_random = String(mission_config.get("mode", "random")) == "random"
	if RoomState.selected_mission_is_random and _has_random_option():
		_mission_option.select(RANDOM_MISSION_IDX)
	elif not RoomState.selected_mission_is_random and RoomState.selected_mission != null:
		_select_mission_if_enabled(RoomState.selected_mission.mission_id)
	for key in _variant_checkboxes:
		_variant_checkboxes[key].set_pressed_no_signal(RoomState.variants.get(key, false))
	_refresh_detail_panel()

func _on_network_message(message: Dictionary) -> void:
	if String(message.get("message_type", "")) == NetProtocol.MATCH_START:
		_enter_online_match_if_needed()


func _on_connection_state_changed(state: String, detail: String) -> void:
	if state == "connecting":
		_show_network_hint(detail if detail != "" else "正在连接房间")
		_update_start_button()
		return
	if state == "joined" and NetSession.is_room_owner():
		_network_hint_label.add_theme_color_override("font_color", Color("#65d47a"))
		_show_network_hint("服务器已启动，已连入本机房间，端口：%d" % RoomState.listen_port)
		_rebuild_seats()
		_update_server_controls()
		_update_start_button()

func _on_back() -> void:
	if NetSession != null and NetSession.multiplayer.multiplayer_peer != null:
		NetSession.leave_room()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_reset() -> void:
	if NetSession != null and NetSession.is_authority():
		NetSession.close_session()
	RoomState.reset_to_default()
	_populate_missions()
	_populate_variants()
	# 刷新任务选择下拉框选中项（随机任务未解锁时回退到第一个可选任务）
	_select_default_mission()
	# 刷新变体复选框
	for key in _variant_checkboxes:
		_variant_checkboxes[key].set_pressed_no_signal(false)
	_online_multiplayer_checkbox.set_pressed_no_signal(RoomState.online_multiplayer)
	_host_name_edit.text = RoomState.host_name
	_port_edit.text = str(RoomState.listen_port)
	_set_network_settings_visible(RoomState.online_multiplayer)
	_network_hint_label.text = ""
	_update_server_controls()
	# 重建座位
	_rebuild_seats()
	# 刷新详情面板与开始按钮状态
	_refresh_detail_panel()
	_update_start_button()
	RoomState.save()
