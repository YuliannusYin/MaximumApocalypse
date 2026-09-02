extends Control

const SEAT_ITEM_SCENE := preload("res://scenes/SeatItem.tscn")
const MAX_SEATS := 6
const RANDOM_MISSION_IDX := 0

@onready var _back_button: Button = $BottomBar/BackButton
@onready var _reset_button: Button = $BottomBar/ResetButton
@onready var _mission_option: OptionButton = $MissionSelectArea/ScrollContainer/VBoxContainer/MissionSection/MissionOption
@onready var _variant_list: VBoxContainer = $MissionSelectArea/ScrollContainer/VBoxContainer/VariantSection/VariantList
@onready var _mission_name_label: Label = $MissionDetailArea/VBoxContainer/MissionNameLabel
@onready var _difficulty_label: Label = $MissionDetailArea/VBoxContainer/DifficultyLabel
@onready var _detail_rich: RichTextLabel = $MissionDetailArea/VBoxContainer/ScrollContainer/DetailRich
@onready var _start_game_button: Button = $BottomBar/StartGameButton
@onready var _add_seat_button: Button = $PlayerSettingArea/VBoxContainer/SeatsHeader/AddSeatButton
@onready var _remove_seat_button: Button = $PlayerSettingArea/VBoxContainer/SeatsHeader/RemoveSeatButton
@onready var _seat_list: VBoxContainer = $PlayerSettingArea/VBoxContainer/SeatList
@onready var _background: ColorRect = $Background
@onready var _title_label: Label = $TopBar/TitleLabel
@onready var _net_status_label: Label = $TopBar/NetStatusLabel

var _variant_checkboxes: Dictionary = {}

## 房间模式：主机（NetSession.HOST）或客机（NetSession.CLIENT）。
var _is_host := false
var _is_client := false
## 客机模式下的座位列表容器（代码构建，替代 SeatItem 列表）。
var _client_seat_list: VBoxContainer = null


func _ready() -> void:
	HudTheme.apply_screen_background(_background, Color("#111311"))
	HudTheme.add_wasteland_backdrop(self, _background)
	HudTheme.apply_title(_title_label, 26)
	HudTheme.apply_section_panel($MissionSelectArea, Color("#211f1a"))
	HudTheme.apply_section_panel($MissionDetailArea, Color("#1d1c19"))
	HudTheme.apply_section_panel($PlayerSettingArea, Color("#211f1a"))
	HudTheme.apply_slot_button(_mission_option, 14, HudTheme.GOLD_BORDER, HudTheme.GOLD_TEXT)
	HudTheme.apply_slot_button(_add_seat_button, 14, HudTheme.SLOT_BORDER, HudTheme.TEXT_MAIN)
	HudTheme.apply_slot_button(_remove_seat_button, 14, HudTheme.SLOT_BORDER, HudTheme.TEXT_MAIN)
	HudTheme.apply_slot_button(_back_button, 13)
	HudTheme.apply_slot_button(_reset_button, 13)
	HudTheme.apply_mission_slot_button(_start_game_button, 13)
	_mission_name_label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT)
	_difficulty_label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT_DIM)
	_net_status_label.add_theme_color_override("font_color", HudTheme.TEXT_DIM)
	_back_button.pressed.connect(_on_back)

	_is_host = NetSession.mode == NetSession.Mode.HOST
	_is_client = NetSession.mode == NetSession.Mode.CLIENT

	if _is_client:
		_setup_client_mode()
	else:
		_setup_host_mode()


# === 主机模式 ===

func _setup_host_mode() -> void:
	_is_host = true
	# 兜底：直接从编辑器运行本场景时自动创建主机
	if NetSession.mode != NetSession.Mode.HOST:
		NetSession.start_host(7000, "玩家")
	# 初始化座位：主机座位 + 空座位
	RoomState.init_host_seats(NetSession.player_name, NetSession.HOST_PEER_ID)
	_populate_missions()
	_populate_variants()
	_restore_state()
	_rebuild_seats()
	_update_start_button()
	# 联机信号
	NetSession.peer_connected.connect(_on_peer_connected)
	NetSession.peer_disconnected.connect(_on_peer_disconnected)
	NetSession.host_message.connect(_on_host_message)
	_reset_button.pressed.connect(_on_reset)
	_mission_option.item_selected.connect(_on_mission_selected)
	_start_game_button.pressed.connect(_on_start_game)
	_add_seat_button.pressed.connect(_on_add_seat)
	_remove_seat_button.pressed.connect(_on_remove_seat)
	_refresh_host_status()
	# 向已连接客机广播初始房间状态
	_broadcast_room_state()


func _refresh_host_status() -> void:
	_net_status_label.text = "主机模式 | 端口：%d | 已连接：%d" % [
		NetSession.host_port, NetSession.get_peer_ids().size()
	]


func _on_peer_connected(_pid: int) -> void:
	_refresh_host_status()


func _on_peer_disconnected(pid: int) -> void:
	# 客机断开：释放其占用的座位
	var changed := false
	for i in range(RoomState.seats.size()):
		if int(RoomState.seats[i].get("peer_id", 0)) == pid:
			RoomState.seats[i] = {"type": "empty", "survivor": null, "player_name": "", "peer_id": 0}
			changed = true
	if changed:
		_rebuild_seats()
		_sync_seats_to_state()
		_update_start_button()
		_broadcast_room_state()
	_refresh_host_status()


func _on_host_message(pid: int, msg_type: int, data: Dictionary) -> void:
	if msg_type == NetProtocol.Msg.SEAT_CLAIM:
		_handle_seat_claim(pid, data)


## 客机认领/放弃座位请求处理。
## 空 survivor_id：座位若已被本客机占用 → 放弃；若为空座 → 认领（尚未选角）。
func _handle_seat_claim(pid: int, data: Dictionary) -> void:
	var seat_index := int(data.get("seat_index", -1))
	if seat_index < 0 or seat_index >= RoomState.seats.size():
		return
	var survivor_id := str(data.get("survivor_id", ""))
	var seat: Dictionary = RoomState.seats[seat_index]
	var owner := int(seat.get("peer_id", 0))
	# 已被其他客机占用则拒绝
	if owner != 0 and owner != pid:
		return
	# 热座"真人"座位（本地、peer_id==0）不可被客机认领；仅"空"座位可认领
	if owner == 0 and str(seat.get("type", "empty")) != "empty":
		return
	if survivor_id == "":
		if owner == pid:
			# 自己占用中 → 放弃座位：释放为"空"
			RoomState.seats[seat_index] = {"type": "empty", "survivor": null, "player_name": "", "peer_id": 0}
		else:
			# 空座认领（占座，未选角）
			RoomState.seats[seat_index] = {
				"type": "human", "survivor": null,
				"player_name": NetSession.get_peer_name(pid), "peer_id": pid,
			}
	else:
		var survivor: SurvivorData = DataManager.get_survivor(survivor_id)
		if survivor == null:
			return
		RoomState.seats[seat_index] = {
			"type": "human", "survivor": survivor,
			"player_name": NetSession.get_peer_name(pid), "peer_id": pid,
		}
	_rebuild_seats()
	_sync_seats_to_state()
	_update_start_button()
	_broadcast_room_state()


func _broadcast_room_state() -> void:
	if NetSession.mode == NetSession.Mode.HOST:
		NetSession.host_broadcast(NetProtocol.Msg.ROOM_STATE, {"room_state": RoomState.to_dict()})


# === 客机模式 ===

func _setup_client_mode() -> void:
	_is_client = true
	_net_status_label.text = "已连接主机 %s:%d" % [NetSession.host_ip, NetSession.host_port]
	# 只读：任务/变体/座位
	_mission_option.disabled = true
	_add_seat_button.visible = false
	_remove_seat_button.visible = false
	_reset_button.visible = false
	_start_game_button.disabled = true
	_start_game_button.text = "等待主机开始..."
	# 联机信号
	NetSession.client_message.connect(_on_client_message)
	NetSession.game_started.connect(_on_host_started_game)
	NetSession.disconnected.connect(_on_back)
	# 首次渲染房间状态（握手时已 apply 到 RoomState）
	_refresh_client_room_view()


func _on_client_message(msg_type: int, data: Dictionary) -> void:
	match msg_type:
		NetProtocol.Msg.ROOM_STATE:
			RoomState.apply_dict(data.get("room_state", {}))
			_refresh_client_room_view()


func _refresh_client_room_view() -> void:
	_refresh_client_mission()
	_refresh_client_variants()
	_refresh_detail_panel()
	_build_client_seat_list()


func _refresh_client_mission() -> void:
	_mission_option.clear()
	if RoomState.selected_mission_is_random:
		_mission_option.add_item("随机任务")
	elif RoomState.selected_mission != null:
		var m: MissionData = RoomState.selected_mission
		_mission_option.add_item("%s（%s）" % [m.mission_name, m.difficulty_display])
	else:
		_mission_option.add_item("未选择")
	_mission_option.select(0)


func _refresh_client_variants() -> void:
	for child in _variant_list.get_children():
		child.queue_free()
	_variant_checkboxes.clear()
	var variants := DataManager.get_all_variants()
	for variant in variants:
		var cb := CheckBox.new()
		cb.text = variant.display_name
		cb.disabled = true
		cb.set_pressed_no_signal(RoomState.variants.get(variant.id, false))
		_variant_list.add_child(cb)
		_variant_checkboxes[variant.id] = cb


func _build_client_seat_list() -> void:
	if _client_seat_list == null:
		_client_seat_list = VBoxContainer.new()
		_client_seat_list.add_theme_constant_override("separation", 6)
		_seat_list.add_child(_client_seat_list)
	for child in _client_seat_list.get_children():
		_client_seat_list.remove_child(child)
		child.queue_free()
	# 其他座位已选求生者集合
	var taken_ids: Array = []
	for seat in RoomState.seats:
		if seat.get("survivor", null) != null and int(seat.get("peer_id", 0)) != NetSession.peer_id:
			taken_ids.append(seat.survivor.english_name)
	for i in range(RoomState.seats.size()):
		_add_client_seat_row(i, RoomState.seats[i], taken_ids)


func _add_client_seat_row(i: int, seat: Dictionary, taken_ids: Array) -> void:
	var pid := int(seat.get("peer_id", 0))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 46)
	HudTheme.apply_section_panel(panel, Color("#1a1917"))
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)
	var idx_label := Label.new()
	idx_label.text = "座位%d" % (i + 1)
	idx_label.custom_minimum_size = Vector2(64, 0)
	idx_label.add_theme_color_override("font_color", HudTheme.GOLD_TEXT)
	hbox.add_child(idx_label)
	var info_label := Label.new()
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.add_theme_color_override("font_color", HudTheme.TEXT_MAIN)
	hbox.add_child(info_label)

	if pid == NetSession.peer_id:
		# 我的座位：可换角 / 放弃
		var sname := str(seat.get("player_name", ""))
		info_label.text = "%s（我）" % sname
		var survivor = seat.get("survivor", null)
		var current_id := ""
		if survivor != null:
			current_id = survivor.english_name
		var survivor_opt := OptionButton.new()
		survivor_opt.add_item("未选择", 0)
		survivor_opt.set_item_metadata(0, null)
		var survivors := DataManager.get_available_survivors()
		for j in range(survivors.size()):
			var sd: SurvivorData = survivors[j]
			survivor_opt.add_item(sd.character_name, j + 1)
			survivor_opt.set_item_metadata(j + 1, sd)
			survivor_opt.set_item_disabled(j + 1, sd.english_name in taken_ids)
			if sd.english_name == current_id:
				survivor_opt.select(j + 1)
		if current_id == "":
			survivor_opt.select(0)
		hbox.add_child(survivor_opt)
		survivor_opt.item_selected.connect(_on_client_survivor_selected.bind(i, survivor_opt))
		var release_btn := Button.new()
		release_btn.text = "放弃"
		HudTheme.apply_slot_button(release_btn, 11)
		hbox.add_child(release_btn)
		release_btn.pressed.connect(_send_seat_claim.bind(i, ""))
	elif pid == 0 and str(seat.get("type", "empty")) == "empty":
		info_label.text = "空"
		var claim_btn := Button.new()
		claim_btn.text = "认领"
		HudTheme.apply_slot_button(claim_btn, 11)
		hbox.add_child(claim_btn)
		claim_btn.pressed.connect(_send_seat_claim.bind(i, ""))
	else:
		var sname := str(seat.get("player_name", ""))
		var survivor_name := "未选择"
		if seat.get("survivor", null) != null:
			survivor_name = seat.survivor.character_name
		if pid == 0:
			# 主机本地热座真人座位，客机不可认领
			info_label.text = "主机（热座） - %s" % survivor_name
		else:
			info_label.text = "%s - %s" % [sname, survivor_name]
	_client_seat_list.add_child(panel)


func _on_client_survivor_selected(_idx: int, seat_index: int, opt: OptionButton) -> void:
	var meta = opt.get_item_metadata(opt.selected)
	var sid := ""
	if meta != null:
		sid = meta.english_name
	_send_seat_claim(seat_index, sid)


func _send_seat_claim(seat_index: int, survivor_id: String) -> void:
	NetSession.client_send(NetProtocol.Msg.SEAT_CLAIM, {"seat_index": seat_index, "survivor_id": survivor_id})


func _on_host_started_game() -> void:
	get_tree().change_scene_to_file("res://scenes/LoadingScreen.tscn")


# === 通用 ===

## 填充任务下拉框：恒显示全部任务；玩家模式下未解锁任务置灰不可选并附解锁提示，
## “随机任务”选项仅在全部任务通关（或开发者模式）后出现。
func _populate_missions() -> void:
	_mission_option.clear()
	if Settings.dev_mode or ArchiveManager.is_random_and_variants_unlocked():
		_mission_option.add_item("随机任务", RANDOM_MISSION_IDX)
		_mission_option.set_item_metadata(RANDOM_MISSION_IDX, null)
	for mission in DataManager.get_all_missions():
		var idx := _mission_option.item_count
		var locked := not Settings.dev_mode and not ArchiveManager.is_mission_unlocked(mission.mission_id)
		var label := "%s（%s）" % [mission.mission_name, mission.difficulty_display]
		if locked:
			label += "（未解锁）"
		_mission_option.add_item(label, idx)
		_mission_option.set_item_metadata(idx, mission)
		_mission_option.set_item_disabled(idx, locked)

## 填充变体复选框：未解锁（且非开发者模式）时置灰并附提示文案；
## 只创建控件，不改动 RoomState.variants 既有值（勾选状态由 _restore_state 恢复）。
func _populate_variants() -> void:
	for child in _variant_list.get_children():
		child.queue_free()
	_variant_checkboxes.clear()
	var variants := DataManager.get_all_variants()
	var variants_locked := not Settings.dev_mode and not ArchiveManager.is_random_and_variants_unlocked()
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
		var seat = RoomState.seats[i]
		var item: SeatItem = SEAT_ITEM_SCENE.instantiate()
		item.seat_index = i
		_seat_list.add_child(item)
		item.setup(seat)
		# 客机占用的座位主机端只读
		var pid := int(seat.get("peer_id", 0))
		if pid != 0 and pid != NetSession.HOST_PEER_ID:
			item.set_locked(true)
		item.changed.connect(_on_seat_changed)
	_refresh_seats_disabled()
	_sync_seats_to_state()
	_update_seat_buttons()

func _update_seat_buttons() -> void:
	if _is_host:
		# 主机模式座位固定为 6 个，不再增删
		_add_seat_button.disabled = (RoomState.seats.size() >= MAX_SEATS)
		_remove_seat_button.disabled = (RoomState.seats.size() <= 1)
	else:
		_add_seat_button.visible = false
		_remove_seat_button.visible = false

func _refresh_seats_disabled() -> void:
	var children := _seat_list.get_children()
	var seat_survivor_ids := []
	for i in range(children.size()):
		var data = children[i].collect()
		var sid := ""
		if data.type != "empty" and data.survivor != null:
			sid = data.survivor.english_name
		seat_survivor_ids.append(sid)
	# 每个求生者由最早选择它的"座位"拥有，其他座位的重复选择会被重置
	var owner_of := {}
	for i in range(children.size()):
		var sid = seat_survivor_ids[i]
		if sid == "" or owner_of.has(sid):
			continue
		owner_of[sid] = i
	for i in range(children.size()):
		if children[i].is_locked():
			continue  # 客机座位不受主机端去重逻辑影响
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
	var meta = _mission_option.get_item_metadata(idx)
	if meta == null:
		RoomState.selected_mission_is_random = true
		RoomState.selected_mission = null
	else:
		RoomState.selected_mission_is_random = false
		RoomState.selected_mission = meta
	_refresh_detail_panel()
	if _is_host:
		_broadcast_room_state()

func _on_variant_toggled(id: String, toggled: bool) -> void:
	RoomState.variants[id] = toggled
	if _is_host:
		_broadcast_room_state()

func _on_add_seat() -> void:
	if RoomState.seats.size() >= MAX_SEATS:
		return
	RoomState.seats.append({"type": "empty", "survivor": null, "player_name": "", "peer_id": 0})
	_rebuild_seats()
	_update_start_button()
	if _is_host:
		_broadcast_room_state()

func _on_remove_seat() -> void:
	if RoomState.seats.size() <= 1:
		return
	RoomState.seats.pop_back()
	_rebuild_seats()
	_update_start_button()
	if _is_host:
		_broadcast_room_state()

func _on_seat_changed(_idx: int) -> void:
	_refresh_seats_disabled()
	_sync_seats_to_state()
	_update_start_button()
	if _is_host:
		_broadcast_room_state()

func _refresh_detail_panel() -> void:
	if RoomState.selected_mission_is_random:
		_mission_name_label.text = "随机任务"
		_difficulty_label.text = ""
		_detail_rich.text = "[i]随机任务（开局时抽取）[/i]"
		return
	var mission = RoomState.selected_mission
	if mission == null:
		_mission_name_label.text = "未选择"
		_difficulty_label.text = ""
		_detail_rich.text = ""
		return
	_mission_name_label.text = mission.mission_name
	_difficulty_label.text = "难度：%s" % mission.difficulty_display
	var fuel_text = str(mission.van_fuel_required) if mission.van_fuel_required != null else "(未指定)"
	var bbcode := ""
	bbcode += "[b]燃料：[/b]%s\n" % fuel_text
	bbcode += "[b]怪物包：[/b]%s\n\n" % mission.monster_pack_type
	bbcode += "[b]任务介绍：[/b]\n%s\n\n" % mission.intro_text
	bbcode += "[b]任务目标：[/b]\n%s\n\n" % mission.objective_text
	bbcode += "[b]特殊设置：[/b]%s" % mission.special_setup
	# 地图块配置
	var block_parts: PackedStringArray = []
	for block_name in mission.map_blocks_config:
		block_parts.append("%s×%d" % [block_name, mission.map_blocks_config[block_name]])
	bbcode += "\n\n[b]地图块配置：[/b]\n%s" % ", ".join(block_parts)
	# 拾荒牌堆配置
	var color_names: Dictionary = {"red": "红色", "green": "绿色", "blue": "蓝色"}
	bbcode += "\n\n[b]拾荒牌堆配置：[/b]"
	for color in ["red", "green", "blue"]:
		var card_entries: Array = mission.scavenge_config.get(color, [])
		var card_parts: PackedStringArray = []
		for entry in card_entries:
			card_parts.append("%s×%d" % [entry.get("card_name", ""), int(entry.get("count", 0))])
		bbcode += "\n%s：%s" % [color_names[color], ", ".join(card_parts)]
	_detail_rich.text = bbcode

func _update_start_button() -> void:
	if _is_client:
		_start_game_button.disabled = true
		return
	_start_game_button.disabled = not RoomState.is_ready_to_start()

func _on_start_game() -> void:
	if not _is_host or not RoomState.is_ready_to_start():
		return
	# 广播开始游戏，再切换场景
	NetSession.host_broadcast(NetProtocol.Msg.START_GAME, {})
	get_tree().change_scene_to_file("res://scenes/LoadingScreen.tscn")

func _on_back() -> void:
	NetSession.stop()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_reset() -> void:
	RoomState.clear()
	# 刷新任务选择下拉框选中项（随机任务未解锁时回退到第一个可选任务）
	_select_default_mission()
	# 刷新变体复选框
	for key in _variant_checkboxes:
		_variant_checkboxes[key].set_pressed_no_signal(false)
	# 重建座位
	_rebuild_seats()
	# 刷新详情面板与开始按钮状态
	_refresh_detail_panel()
	_update_start_button()
	if _is_host:
		_broadcast_room_state()
