extends Control

const SEAT_ITEM_SCENE := preload("res://scenes/SeatItem.tscn")
const MAX_SEATS := 4
const MIN_SEATS := 1
const RANDOM_MISSION_IDX := 0

@onready var _back_button: Button = $MarginContainer/VBoxContainer/TopBar/BackButton
@onready var _mission_option: OptionButton = $MarginContainer/VBoxContainer/Content/LeftPanel/ScrollContainer/VBoxContainer/MissionSection/MissionOption
@onready var _variant_list: VBoxContainer = $MarginContainer/VBoxContainer/Content/LeftPanel/ScrollContainer/VBoxContainer/VariantSection/VariantList
@onready var _mission_name_label: Label = $MarginContainer/VBoxContainer/Content/MiddlePanel/VBoxContainer/MissionNameLabel
@onready var _difficulty_label: Label = $MarginContainer/VBoxContainer/Content/MiddlePanel/VBoxContainer/DifficultyLabel
@onready var _detail_rich: RichTextLabel = $MarginContainer/VBoxContainer/Content/MiddlePanel/VBoxContainer/ScrollContainer/DetailRich
@onready var _start_game_button: Button = $MarginContainer/VBoxContainer/Content/MiddlePanel/VBoxContainer/StartGameButton
@onready var _add_seat_button: Button = $MarginContainer/VBoxContainer/Content/RightPanel/VBoxContainer/SeatsHeader/AddSeatButton
@onready var _remove_seat_button: Button = $MarginContainer/VBoxContainer/Content/RightPanel/VBoxContainer/SeatsHeader/RemoveSeatButton
@onready var _seat_list: VBoxContainer = $MarginContainer/VBoxContainer/Content/RightPanel/VBoxContainer/SeatList

var _variant_checkboxes: Dictionary = {}

func _ready() -> void:
	_populate_missions()
	_populate_variants()
	_restore_state()
	_rebuild_seats()
	_update_start_button()
	_back_button.pressed.connect(_on_back)
	_mission_option.item_selected.connect(_on_mission_selected)
	_start_game_button.pressed.connect(_on_start_game)
	_add_seat_button.pressed.connect(_on_add_seat)
	_remove_seat_button.pressed.connect(_on_remove_seat)

func _populate_missions() -> void:
	_mission_option.clear()
	_mission_option.add_item("随机任务", 0)
	_mission_option.set_item_metadata(0, null)
	var missions := DataManager.get_all_missions()
	for i in range(missions.size()):
		var mission = missions[i]
		_mission_option.add_item("%s（%s）" % [mission.mission_name, mission.difficulty_display], i + 1)
		_mission_option.set_item_metadata(i + 1, mission)

func _populate_variants() -> void:
	for child in _variant_list.get_children():
		child.queue_free()
	_variant_checkboxes.clear()
	var variants := DataManager.get_all_variants()
	for variant in variants:
		var cb := CheckBox.new()
		cb.text = variant.display_name
		cb.tooltip_text = variant.desc
		var vid: String = variant.id
		cb.toggled.connect(func(toggled: bool): _on_variant_toggled(vid, toggled))
		_variant_list.add_child(cb)
		_variant_checkboxes[variant.id] = cb

func _restore_state() -> void:
	if RoomState.selected_mission_is_random:
		_mission_option.select(RANDOM_MISSION_IDX)
	elif RoomState.selected_mission != null:
		for i in range(_mission_option.item_count):
			var meta = _mission_option.get_item_metadata(i)
			if meta != null and meta is MissionData and meta.mission_id == RoomState.selected_mission.mission_id:
				_mission_option.select(i)
				break
	for key in _variant_checkboxes:
		_variant_checkboxes[key].set_pressed_no_signal(RoomState.variants.get(key, false))
	_refresh_detail_panel()

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
		item.changed.connect(_on_seat_changed)
	_refresh_seats_disabled()
	_sync_seats_to_state()
	_update_seat_buttons()

func _update_seat_buttons() -> void:
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
	var meta = _mission_option.get_item_metadata(idx)
	if meta == null:
		RoomState.selected_mission_is_random = true
		RoomState.selected_mission = null
	else:
		RoomState.selected_mission_is_random = false
		RoomState.selected_mission = meta
	_refresh_detail_panel()

func _on_variant_toggled(id: String, toggled: bool) -> void:
	RoomState.variants[id] = toggled

func _on_add_seat() -> void:
	if RoomState.seats.size() >= MAX_SEATS:
		return
	RoomState.seats.append({"type": "ai", "survivor": null})
	_rebuild_seats()
	_update_start_button()

func _on_remove_seat() -> void:
	if RoomState.seats.size() <= MIN_SEATS:
		return
	RoomState.seats.pop_back()
	_rebuild_seats()
	_update_start_button()

func _on_seat_changed(_idx: int) -> void:
	_refresh_seats_disabled()
	_sync_seats_to_state()
	_update_start_button()

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
	_detail_rich.text = bbcode

func _update_start_button() -> void:
	_start_game_button.disabled = not RoomState.is_ready_to_start()

func _on_start_game() -> void:
	if not RoomState.is_ready_to_start():
		return
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
