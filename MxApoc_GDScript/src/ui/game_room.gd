extends Control

const SEAT_ITEM_SCENE := preload("res://scenes/SeatItem.tscn")
const MAX_SEATS := 4
const MIN_SEATS := 1
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

var _variant_checkboxes: Dictionary = {}

func _ready() -> void:
	_populate_missions()
	_populate_variants()
	_restore_state()
	_rebuild_seats()
	_update_start_button()
	_back_button.pressed.connect(_on_back)
	_reset_button.pressed.connect(_on_reset)
	_mission_option.item_selected.connect(_on_mission_selected)
	_start_game_button.pressed.connect(_on_start_game)
	_add_seat_button.pressed.connect(_on_add_seat)
	_remove_seat_button.pressed.connect(_on_remove_seat)

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
	_start_game_button.disabled = not RoomState.is_ready_to_start()

func _on_start_game() -> void:
	if not RoomState.is_ready_to_start():
		return
	get_tree().change_scene_to_file("res://scenes/LoadingScreen.tscn")

func _on_back() -> void:
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
